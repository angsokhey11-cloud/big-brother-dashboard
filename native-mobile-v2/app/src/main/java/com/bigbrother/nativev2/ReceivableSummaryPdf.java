package com.bigbrother.nativev2;

import android.content.Context;
import android.graphics.*;
import android.graphics.pdf.PdfDocument;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;
import java.io.*;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

/** A4 summary rendered from the exact reverified selected snapshot. No invoice or payment writes. */
final class ReceivableSummaryPdf {
    private static final int W=595,H=842,M=36,NAVY=Color.rgb(23,74,145);
    static File create(Context context,String snapshot)throws IOException{
        if(snapshot.isEmpty()||snapshot.length()>200000)throw new IOException("Summary exceeds preview limits");
        File folder=new File(context.getCacheDir(),"invoice_exports");
        if(!folder.exists()&&!folder.mkdirs())throw new IOException("Private cache unavailable");
        File[] old=folder.listFiles();
        if(old!=null)for(File f:old)if(f.getName().startsWith("BB-AR-Summary-")&&System.currentTimeMillis()-f.lastModified()>3600000L)f.delete();
        File file=File.createTempFile("BB-AR-Summary-", ".pdf",folder);
        boolean ok=false;
        try(PdfDocument doc=new PdfDocument();FileOutputStream out=new FileOutputStream(file)){
            Writer writer=new Writer(doc);
            try{
                writer.start();
                for(String line:snapshot.split("\n",-1))writer.line(line);
                writer.finish();doc.writeTo(out);ok=true;
            }finally{if(writer.page!=null)writer.finish();}
        }finally{if(!ok)file.delete();}
        return file;
    }
    private static final class Writer{
        final PdfDocument doc;PdfDocument.Page page;int number,y;
        Writer(PdfDocument doc){this.doc=doc;}
        StaticLayout layout(String s,int size,int color,boolean bold){
            TextPaint p=new TextPaint(Paint.ANTI_ALIAS_FLAG);p.setColor(color);p.setTextSize(size);
            p.setTypeface(Typeface.create("sans-serif",bold?Typeface.BOLD:Typeface.NORMAL));
            return StaticLayout.Builder.obtain(s,0,s.length(),p,W-2*M).setAlignment(Layout.Alignment.ALIGN_NORMAL).setIncludePad(true).build();
        }
        void draw(StaticLayout l){Canvas c=page.getCanvas();c.save();c.translate(M,y);l.draw(c);c.restore();y+=l.getHeight()+4;}
        void start()throws IOException{
            if(++number>50)throw new IOException("Select fewer invoices");
            page=doc.startPage(new PdfDocument.PageInfo.Builder(W,H,number).create());y=M;
            draw(layout("BIG BROTHER",24,NAVY,true));
            draw(layout("CUSTOMER INVOICE SUMMARY",16,NAVY,true));
            draw(layout("Development copy · "+LocalDate.now(ZoneId.of("Asia/Phnom_Penh")).format(DateTimeFormatter.ofPattern("dd-MMM-uuuu",Locale.US)),10,Color.DKGRAY,false));
            Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);p.setColor(NAVY);page.getCanvas().drawLine(M,y,W-M,y,p);y+=12;
        }
        void finish(){
            Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);p.setColor(Color.DKGRAY);p.setTextSize(10);
            page.getCanvas().drawText("Page "+number,M,H-18,p);PdfDocument.Page current=page;page=null;doc.finishPage(current);
        }
        void line(String text)throws IOException{
            if(text.length()>5000)throw new IOException("Summary row too large");
            boolean bold=text.equals("TOTAL OUTSTANDING");
            StaticLayout l=layout(text.isEmpty()?" ":text,bold?15:12,bold?NAVY:Color.BLACK,bold);
            if(l.getHeight()>H-180)throw new IOException("Summary row exceeds page");
            if(y+l.getHeight()+8>H-M){finish();start();}
            draw(l);
        }
    }
}
