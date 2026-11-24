package com.bigbrother.nativev2;

import android.graphics.Color;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.pdf.PdfDocument;
import android.text.StaticLayout;
import android.text.TextPaint;
import android.text.Layout;
import org.json.JSONObject;
import org.json.JSONArray;
import java.io.OutputStream;
import java.io.IOException;

/** Read-only development export. Uses the server's stored amounts, never recalculates. */
final class InvoicePdf {
    private static final int WIDTH=595, HEIGHT=842, MARGIN=36;
    private final PdfDocument doc=new PdfDocument();
    private final TextPaint paint=new TextPaint(Paint.ANTI_ALIAS_FLAG);
    private PdfDocument.Page page;
    private int number=0, y;
    private final String invoiceNo;
    private InvoicePdf(String invoiceNo){this.invoiceNo=invoiceNo;}
    static String value(JSONObject obj,String key) {
        Object raw=obj.opt(key);
        return raw==null||raw==JSONObject.NULL?"":String.valueOf(raw);
    }
    static String first(JSONObject obj,String... keys){
        for(String key:keys){String v=value(obj,key);if(!v.isEmpty())return v;}return "";
    }
    static void write(JSONObject invoice,OutputStream out) throws IOException {
        JSONArray items=invoice.optJSONArray("items");
        if(items==null || items.length()==0 || items.length()>1000)throw new IOException("Invoice lines missing or exceed export limit");
        if(value(invoice,"invoiceNo").isEmpty()||value(invoice,"grandTotal").isEmpty()||value(invoice,"currency").isEmpty())throw new IOException("Invoice data incomplete");
        InvoicePdf pdf=new InvoicePdf(value(invoice,"invoiceNo"));
        try {
            pdf.start();
            pdf.line("Date: "+value(invoice,"invoiceDate"),12);
            pdf.line("Customer: "+value(invoice,"customer"),12);
            pdf.line("Address: "+value(invoice,"address"),12);
            pdf.line("Phone: "+value(invoice,"phone"),12);
            pdf.line("Currency: "+value(invoice,"currency"),12);
            pdf.line("Products",15);
            for(int i=0;i<items.length();i++){
                JSONObject item=items.optJSONObject(i);
                if(item==null)throw new IOException("Invalid invoice line");
                String name=first(item,"productName","description","name","product");
                String qty=first(item,"qty","quantity");
                String price=first(item,"unitPrice","price");
                String amount=first(item,"amount","total");
                if(name.isEmpty()||qty.isEmpty()||price.isEmpty()||amount.isEmpty())throw new IOException("Invoice line data incomplete");
                pdf.line((i+1)+". "+name+" | Qty: "+qty+" | Price: "+price+" | Amount: "+amount,11);
            }
            for(String[] field:new String[][]{{"Subtotal","subtotal"},{"Discount","discount"},{"Grand total","grandTotal"},{"Paid","amountPaid"},{"Outstanding","outstanding"},{"Payment method","paymentMethod"},{"Note","note"}}){
                String v=value(invoice,field[1]);if(!v.isEmpty())pdf.line(field[0]+": "+v,12);
            }
            pdf.finish();
            pdf.doc.writeTo(out);
        }finally{if(pdf.page!=null)pdf.finish();pdf.doc.close();}
    }
    private void start(){
        page=doc.startPage(new PdfDocument.PageInfo.Builder(WIDTH,HEIGHT,++number).create());
        y=MARGIN;
        paint.setColor(Color.rgb(23,74,145));paint.setTextSize(19);
        page.getCanvas().drawText("BIG BROTHER",MARGIN,y+19,paint);y+=28;
        paint.setColor(Color.DKGRAY);paint.setTextSize(11);
        page.getCanvas().drawText("DEVELOPMENT COPY — NOT DIGITAL ORIGINAL",MARGIN,y+12,paint);y+=20;
        page.getCanvas().drawText("Invoice: "+invoiceNo.substring(0,Math.min(60,invoiceNo.length())),MARGIN,y+12,paint);y+=23;
    }
    private void finish(){
        paint.setTextSize(10);paint.setColor(Color.DKGRAY);
        page.getCanvas().drawText("Page "+number,MARGIN,HEIGHT-18,paint);
        doc.finishPage(page);page=null;
    }
    private void line(String text,int size) throws IOException {
        if(text.length()>5000)throw new IOException("Invoice text exceeds export limit");
        paint.setColor(Color.BLACK);paint.setTextSize(size);
        StaticLayout layout=StaticLayout.Builder.obtain(text,0,text.length(),paint,WIDTH-2*MARGIN)
          .setAlignment(Layout.Alignment.ALIGN_NORMAL).setIncludePad(true).build();
        if(layout.getHeight()>HEIGHT-2*MARGIN-100)throw new IOException("Invoice field too long for preview export");
        if(y+layout.getHeight()>HEIGHT-MARGIN){finish();start();paint.setColor(Color.BLACK);paint.setTextSize(size);}
        Canvas canvas=page.getCanvas();canvas.save();canvas.translate(MARGIN,y);layout.draw(canvas);canvas.restore();
        y+=layout.getHeight()+7;
    }
}
