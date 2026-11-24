package com.bigbrother.nativev2;

import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.graphics.pdf.PdfDocument;
import android.text.StaticLayout;
import android.text.TextPaint;
import android.text.Layout;
import org.json.JSONObject;
import org.json.JSONArray;
import java.io.OutputStream;
import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.util.Locale;

/** Native A4 layout candidate. Never recalculates totals or registers originals. */
final class InvoicePdf {
    private static final int W=595,H=842,M=34,R=W-M,B=H-M;
    private static final int BLUE=Color.rgb(68,114,185), NAVY=Color.rgb(23,74,145), GRAY=Color.rgb(153,153,153);
    private static final int[] COL={M,M+30,M+258,M+322,M+425,R};
    private final PdfDocument doc=new PdfDocument();
    private final JSONObject invoice;
    private final String currency;
    private PdfDocument.Page page;
    private int pageNo,y;
    private InvoicePdf(JSONObject invoice,String currency){this.invoice=invoice;this.currency=currency;}
    static String value(JSONObject obj,String key){
        Object raw=obj.opt(key);return raw==null||raw==JSONObject.NULL?"":String.valueOf(raw);
    }
    static String first(JSONObject obj,String... keys){
        for(String key:keys){String v=value(obj,key);if(!v.isEmpty())return v;}return "";
    }
    private static String format(String raw,int digits,boolean fixed) throws IOException {
        try{
            BigDecimal n=new BigDecimal(raw);
            DecimalFormat fmt=new DecimalFormat("#,##0",DecimalFormatSymbols.getInstance(Locale.US));
            fmt.setMinimumFractionDigits(fixed?digits:0);fmt.setMaximumFractionDigits(digits);
            fmt.setRoundingMode(RoundingMode.HALF_UP);
            return fmt.format(n);
        }catch(Exception e){throw new IOException("Invalid invoice numeric field",e);}
    }
    private String money(String raw,boolean unit) throws IOException {
        return currency.equals("KHR")?"៛"+format(raw,0,true):"$"+format(raw,unit?4:2,true);
    }
    private static String date(String raw){
        try{return java.time.LocalDate.parse(raw.substring(0,10)).format(java.time.format.DateTimeFormatter.ofPattern("dd-MMM-yyyy",Locale.US));}
        catch(Exception e){return raw;}
    }
    static void write(JSONObject invoice,OutputStream out) throws IOException{
        JSONArray items=invoice.optJSONArray("items");
        String c=value(invoice,"currency").toUpperCase(Locale.ROOT);
        if(items==null||items.length()==0||items.length()>1000||value(invoice,"invoiceNo").isEmpty()||
           !("USD".equals(c)||"KHR".equals(c)))throw new IOException("Incomplete invoice or unsupported currency");
        InvoicePdf p=new InvoicePdf(invoice,c);
        try{
            p.start();p.customer();p.header();
            for(int i=0;i<items.length();i++){
                JSONObject item=items.optJSONObject(i);if(item==null)throw new IOException("Invalid invoice line");
                p.row(i+1,item);
            }
            p.summary();p.finish();p.doc.writeTo(out);
        }finally{try{if(p.page!=null)p.finish();}finally{p.doc.close();}}
    }
    private StaticLayout layout(String text,int size,int color,boolean bold,int width,Layout.Alignment alignment) throws IOException{
        if(text.length()>5000)throw new IOException("Invoice text exceeds limit");
        TextPaint paint=new TextPaint(Paint.ANTI_ALIAS_FLAG);
        paint.setColor(color);paint.setTextSize(size);
        paint.setTypeface(bold?Typeface.create("sans-serif",Typeface.BOLD):Typeface.create("sans-serif",Typeface.NORMAL));
        return StaticLayout.Builder.obtain(text,0,text.length(),paint,width)
          .setAlignment(alignment).setIncludePad(true).build();
    }
    private void draw(StaticLayout l,int x,int top){
        Canvas c=page.getCanvas();c.save();c.translate(x,top);l.draw(c);c.restore();
    }
    private void rect(int x,int top,int right,int bottom,int color,boolean fill){
        Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);p.setColor(color);
        p.setStyle(fill?Paint.Style.FILL:Paint.Style.STROKE);p.setStrokeWidth(.6f);
        page.getCanvas().drawRect(x,top,right,bottom,p);
    }
    private void rule(int x,int top,int right,int color){
        Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);p.setColor(color);p.setStrokeWidth(.8f);
        page.getCanvas().drawLine(x,top,right,top,p);
    }
    private void start() throws IOException{
        page=doc.startPage(new PdfDocument.PageInfo.Builder(W,H,++pageNo).create());y=M;
        draw(layout("BIG BROTHER",22,NAVY,true,300,Layout.Alignment.ALIGN_NORMAL),M,y);
        draw(layout("Better Products\nA Brighter Tomorrow",10,NAVY,false,190,Layout.Alignment.ALIGN_OPPOSITE),R-190,y);
        y+=29;draw(layout("Ready to be your partner",10,Color.DKGRAY,false,300,Layout.Alignment.ALIGN_NORMAL),M,y);
        y+=21;rule(M,y,R,Color.DKGRAY);y+=8;
        draw(layout("INVOICE",25,NAVY,true,R-M,Layout.Alignment.ALIGN_CENTER),M,y);y+=32;
        draw(layout(invoice.optBoolean("_nativeUnsavedDraft")?"UNSAVED DRAFT — NOT A VALID INVOICE":"DEVELOPMENT COPY — NOT DIGITAL ORIGINAL",10,Color.DKGRAY,true,R-M,Layout.Alignment.ALIGN_CENTER),M,y);y+=18;
        StaticLayout id=layout("Invoice: "+value(invoice,"invoiceNo")+"  |  "+date(value(invoice,"invoiceDate")),11,NAVY,true,R-M,Layout.Alignment.ALIGN_NORMAL);
        if(id.getHeight()>70)throw new IOException("Invoice identifier too long");
        draw(id,M,y);y+=id.getHeight()+8;
    }
    private void finish(){
        Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);p.setColor(Color.DKGRAY);p.setTextSize(10);
        page.getCanvas().drawText("Page "+pageNo,M,H-16,p);
        PdfDocument.Page current=page;page=null;doc.finishPage(current);
    }
    private void space(int height,boolean table) throws IOException{
        if(height<0||height> B-200)throw new IOException("Invoice block too large");
        if(y+height>B){finish();start();if(table)header();}
        if(y+height>B)throw new IOException("Invoice block cannot fit");
    }
    private void customer() throws IOException{
        String left="Bill To\nName: "+value(invoice,"customer")+"\nLocation: "+value(invoice,"address")+"\nPhone Number: "+value(invoice,"phone");
        String middle="Shipping To\n"+value(invoice,"shippingTo");
        String right="Currency: "+currency+"\nInvoice Date: "+date(value(invoice,"invoiceDate"));
        if(!value(invoice,"dueDate").isEmpty())right+="\nDue Date: "+date(value(invoice,"dueDate"));
        StaticLayout a=layout(left,11,Color.BLACK,false,205,Layout.Alignment.ALIGN_NORMAL);
        StaticLayout b=layout(middle,11,Color.BLACK,false,145,Layout.Alignment.ALIGN_NORMAL);
        StaticLayout c=layout(right,11,NAVY,true,151,Layout.Alignment.ALIGN_NORMAL);
        int height=Math.max(a.getHeight(),Math.max(b.getHeight(),c.getHeight()))+14;
        space(height,false);draw(a,M,y);draw(b,M+216,y);draw(c,R-151,y);y+=height;
    }
    private void header() throws IOException{
        if(y+26>B){finish();start();}
        String[] labels={"N.o.","Description","Qty","Unit Price","Amount"};
        rect(M,y,R,y+26,BLUE,true);
        for(int i=0;i<labels.length;i++)draw(layout(labels[i],10,Color.WHITE,true,COL[i+1]-COL[i]-8,Layout.Alignment.ALIGN_CENTER),COL[i]+4,y+5);
        y+=26;
    }
    private void row(int n,JSONObject item) throws IOException{
        String name=first(item,"productName","productCode","description","name");
        String qty=first(item,"qty","quantity"),price=first(item,"price","unitPrice"),amount=first(item,"total","amount");
        if(name.isEmpty()||qty.isEmpty()||price.isEmpty()||amount.isEmpty())throw new IOException("Missing invoice line fields");
        String barcode=first(item,"productBarcode","barcode"), note=value(item,"productNote"),unit=value(item,"unit");
        if(!barcode.isEmpty())name+="\nBarcode: "+barcode;
        if(!note.isEmpty())name+="\nNote: "+note;
        if(invoice.optBoolean("_nativeUnsavedDraft")&&!value(item,"sellingQty").isEmpty()&&!value(item,"sellingUnitPrice").isEmpty()){
            name+="\nBase: "+format(qty,4,false)+(unit.isEmpty()?"":" "+unit);
            qty=value(item,"sellingQty");price=value(item,"sellingUnitPrice");unit=value(item,"sellingUnit");
        }
        String[] cells={String.valueOf(n),name,format(qty,invoice.optBoolean("_nativeUnsavedDraft")?4:2,false)+(unit.isEmpty()?"":"/"+unit),money(price,true),money(amount,false)};
        StaticLayout[] lines=new StaticLayout[5];int height=30;
        for(int i=0;i<5;i++){
            lines[i]=layout(cells[i],10,Color.BLACK,false,COL[i+1]-COL[i]-8,
                i==1?Layout.Alignment.ALIGN_NORMAL:i>=3?Layout.Alignment.ALIGN_OPPOSITE:Layout.Alignment.ALIGN_CENTER);
            height=Math.max(height,lines[i].getHeight()+10);
        }
        space(height,true);
        for(int i=0;i<5;i++){rect(COL[i],y,COL[i+1],y+height,GRAY,false);draw(lines[i],COL[i]+4,y+5);}y+=height;
    }
    private void textBlock(String text,int size,boolean bold) throws IOException{
        StaticLayout l=layout(text,size,Color.BLACK,bold,R-M,Layout.Alignment.ALIGN_NORMAL);
        space(l.getHeight()+8,false);draw(l,M,y);y+=l.getHeight()+8;
    }
    private void total(String title,String key,boolean grand,boolean optional) throws IOException{
        String raw=value(invoice,key);if(raw.isEmpty()&&optional)return;
        String text=money(raw,false);
        int ink=grand?Color.WHITE:Color.BLACK;
        StaticLayout a=layout(title,12,ink,true,180,Layout.Alignment.ALIGN_NORMAL);
        StaticLayout b=layout(text,12,ink,true,150,Layout.Alignment.ALIGN_OPPOSITE);
        int height=Math.max(a.getHeight(),b.getHeight())+10;
        space(height,false);if(grand)rect(R-340,y,R,y+height,BLUE,true);
        draw(a,R-335,y+5);draw(b,R-155,y+5);
        if(!grand)rule(R-340,y+height,R,GRAY);y+=height;
    }
    private void summary() throws IOException{
        y+=10;
        total("Subtotal","subtotal",false,true);total("Discount","discount",false,true);
        total("Grand Total","grandTotal",true,false);
        total("Amount Paid","amountPaid",false,false);
        total("Credit Amount","outstanding",false,false);
        y+=10;textBlock("Note: "+value(invoice,"note"),11,false);
        textBlock("Payment Method: "+value(invoice,"paymentMethod"),11,true);
        String bank=value(invoice,"bankPayment"),reference=value(invoice,"bankReference");
        if(!bank.isEmpty()||!reference.isEmpty())textBlock("Banking Details\n"+bank+"\nReference: "+reference,11,false);
        StaticLayout a=layout("Customer Name: "+value(invoice,"customer")+"\nSignature",11,Color.BLACK,false,245,Layout.Alignment.ALIGN_NORMAL);
        StaticLayout b=layout("Sale Person: "+value(invoice,"salesperson")+"\nSale Signature",11,Color.BLACK,false,245,Layout.Alignment.ALIGN_NORMAL);
        int height=Math.max(a.getHeight(),b.getHeight())+57;
        space(height,false);draw(a,M,y+8);draw(b,R-245,y+8);rule(M,y+height-5,M+245,GRAY);rule(R-245,y+height-5,R,GRAY);y+=height;
    }
}
