package com.bigbrother.nativev2;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.RectF;
import android.graphics.Paint;
import android.graphics.pdf.PdfDocument;
import android.graphics.pdf.PdfRenderer;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;
import android.print.PageRange;
import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.PrintDocumentInfo;
import org.json.JSONObject;
import java.io.*;
import java.util.ArrayList;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Native, watermarked development exports only. Never registers an original. */
final class InvoiceNativeActions {
    private static final int MAX_PAGES=50;
    private static File makePdf(Context ctx,JSONObject invoice) throws IOException {
        File pdf=File.createTempFile("bb-print-", ".pdf", ctx.getCacheDir());
        try(FileOutputStream out=new FileOutputStream(pdf)){InvoicePdf.write(invoice,out);}
        catch(Exception e){pdf.delete();throw new IOException("Invoice render failed",e);}
        return pdf;
    }
    private static Bitmap bitmap(PdfRenderer.Page page,int scale,int mode){
        Bitmap b=Bitmap.createBitmap(page.getWidth()*scale,page.getHeight()*scale,Bitmap.Config.ARGB_8888);
        try {
            b.eraseColor(Color.WHITE);Matrix m=new Matrix();m.setScale(scale,scale);
            page.render(b,null,m,mode);return b;
        }catch(RuntimeException e){b.recycle();throw e;}
    }
    static ArrayList<File> pngs(Context ctx,JSONObject invoice,File folder) throws IOException{
        File pdf=makePdf(ctx,invoice);
        ArrayList<File> files=new ArrayList<>();
        boolean ok=false;
        try(PdfRenderer renderer=new PdfRenderer(ParcelFileDescriptor.open(pdf,ParcelFileDescriptor.MODE_READ_ONLY))){
            int count=renderer.getPageCount();
            if(count<1||count>12)throw new IOException("Use PDF for invoices exceeding 12 pages");
            for(int i=0;i<count;i++){
                File png=File.createTempFile("BB-Invoice-page-"+(i+1)+"-", ".png",folder);
                files.add(png);
                try(PdfRenderer.Page page=renderer.openPage(i);FileOutputStream out=new FileOutputStream(png)){
                    Bitmap b=bitmap(page,2,PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);
                    try{if(!b.compress(Bitmap.CompressFormat.PNG,100,out))throw new IOException("PNG encoding failed");}
                    finally{b.recycle();}
                }
            }
            ok=true;return files;
        }finally{pdf.delete();if(!ok)for(File file:files)file.delete();}
    }
    static final class Adapter extends PrintDocumentAdapter {
        private final Context context;
        private final JSONObject invoice;
        private final ExecutorService worker=Executors.newSingleThreadExecutor();
        private File pdf;
        private int count;
        private PrintAttributes attributes;
        Adapter(Context context,JSONObject invoice){this.context=context.getApplicationContext();this.invoice=invoice;}
        @Override public void onLayout(PrintAttributes old,PrintAttributes next,CancellationSignal cancel,LayoutResultCallback cb,Bundle extras){
            worker.execute(() -> {
                if(cancel.isCanceled()){cb.onLayoutCancelled();return;}
                try{
                    if(pdf==null)pdf=makePdf(context,invoice);
                    try(PdfRenderer r=new PdfRenderer(ParcelFileDescriptor.open(pdf,ParcelFileDescriptor.MODE_READ_ONLY))){count=r.getPageCount();}
                    if(count<1||count>MAX_PAGES)throw new IOException("Page limit");
                    attributes=next;
                    if(cancel.isCanceled()){cb.onLayoutCancelled();return;}
                    cb.onLayoutFinished(new PrintDocumentInfo.Builder("BIG-BROTHER-Invoice.pdf").setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT).setPageCount(count).build(),!next.equals(old));
                }catch(Exception e){cb.onLayoutFailed("Could not prepare invoice");}
            });
        }
        private boolean requested(int i,PageRange[] pages){for(PageRange p:pages)if(p.getStart()<=i&&i<=p.getEnd())return true;return false;}
        @Override public void onWrite(PageRange[] pages,ParcelFileDescriptor dest,CancellationSignal cancel,WriteResultCallback cb){
            worker.execute(() -> {
                ArrayList<PageRange> written=new ArrayList<>();
                try(ParcelFileDescriptor.AutoCloseOutputStream out=new ParcelFileDescriptor.AutoCloseOutputStream(dest)){
                    if(pdf==null||attributes==null)throw new IOException("Layout unavailable");
                    PrintAttributes.MediaSize media=attributes.getMediaSize();
                    PrintAttributes.Margins margins=attributes.getMinMargins();
                    if(media==null||margins==null)throw new IOException("Print settings unavailable");
                    int w=Math.round(media.getWidthMils()*72f/1000),h=Math.round(media.getHeightMils()*72f/1000);
                    float l=margins.getLeftMils()*72f/1000,t=margins.getTopMils()*72f/1000;
                    float r=w-margins.getRightMils()*72f/1000,b=h-margins.getBottomMils()*72f/1000;
                    if(r<=l||b<=t)throw new IOException("Invalid paper margins");
                    PdfDocument output=new PdfDocument();
                    try(PdfRenderer renderer=new PdfRenderer(ParcelFileDescriptor.open(pdf,ParcelFileDescriptor.MODE_READ_ONLY))){
                        for(int i=0;i<count;i++){
                            if(cancel.isCanceled())break;
                            if(!requested(i,pages))continue;
                            try(PdfRenderer.Page input=renderer.openPage(i)){
                                Bitmap image=bitmap(input,3,PdfRenderer.Page.RENDER_MODE_FOR_PRINT);
                                try{
                                    PdfDocument.Page p=output.startPage(new PdfDocument.PageInfo.Builder(w,h,i+1).create());
                                    try {
                                        float scale=Math.min((r-l)/image.getWidth(),(b-t)/image.getHeight());
                                        float width=image.getWidth()*scale,height=image.getHeight()*scale;
                                        float x=l+(r-l-width)/2,y=t+(b-t-height)/2;
                                        p.getCanvas().drawBitmap(image,null,new RectF(x,y,x+width,y+height),new Paint(Paint.FILTER_BITMAP_FLAG));
                                    }finally{output.finishPage(p);}
                                }finally{image.recycle();}
                            }
                            written.add(new PageRange(i,i));
                        }
                        if(!cancel.isCanceled()&&!written.isEmpty())output.writeTo(out);
                    }finally{output.close();}
                    if(cancel.isCanceled())cb.onWriteCancelled();
                    else if(written.isEmpty())cb.onWriteFailed("No pages selected");
                    else cb.onWriteFinished(written.toArray(new PageRange[0]));
                }catch(Exception e){if(cancel.isCanceled())cb.onWriteCancelled();else cb.onWriteFailed("Could not print invoice");}
            });
        }
        @Override public void onFinish(){worker.execute(()->{if(pdf!=null)pdf.delete();});worker.shutdown();}
    }
}
