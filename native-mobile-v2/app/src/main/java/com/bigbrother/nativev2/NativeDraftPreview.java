package com.bigbrother.nativev2;

import android.app.Activity;
import android.app.AlertDialog;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.pdf.PdfRenderer;
import android.os.ParcelFileDescriptor;
import android.widget.*;
import org.json.JSONObject;
import java.io.*;
import java.util.concurrent.ExecutorService;
import java.util.function.BooleanSupplier;

/** Private-cache, page-at-a-time A4 preview. No export or financial posting. */
final class NativeDraftPreview {
    private final Activity a;
    private final JSONObject document;
    private final ExecutorService worker;
    private final BooleanSupplier active;
    private final LinearLayout body;
    private final TextView status;
    private final ImageView image;
    private final Button previous,next;
    private final AlertDialog dialog;
    private File pdf; // worker-owned
    private Bitmap shown;
    private int page,count;
    private boolean closed,busy;

    static void open(Activity a,JSONObject document,ExecutorService worker,BooleanSupplier active){
        if(!active.getAsBoolean())return;
        NativeDraftPreview p=new NativeDraftPreview(a,document,worker,active);
        p.dialog.show();p.load(0);
    }
    private NativeDraftPreview(Activity a,JSONObject document,ExecutorService worker,BooleanSupplier active){
        this.a=a;this.document=document;this.worker=worker;this.active=active;
        body=new LinearLayout(a);body.setOrientation(LinearLayout.VERTICAL);
        int pad=(int)(12*a.getResources().getDisplayMetrics().density);body.setPadding(pad,pad,pad,pad);
        status=new TextView(a);status.setText("Preparing unsaved draft…");body.addView(status);
        LinearLayout nav=new LinearLayout(a);nav.setOrientation(LinearLayout.HORIZONTAL);body.addView(nav);
        previous=new Button(a);previous.setAllCaps(false);previous.setText("Previous");nav.addView(previous,new LinearLayout.LayoutParams(0,-2,1));
        next=new Button(a);next.setAllCaps(false);next.setText("Next");nav.addView(next,new LinearLayout.LayoutParams(0,-2,1));
        previous.setOnClickListener(v->load(page-1));next.setOnClickListener(v->load(page+1));
        image=new ImageView(a);image.setBackgroundColor(Color.WHITE);image.setAdjustViewBounds(true);image.setScaleType(ImageView.ScaleType.FIT_CENTER);
        image.setContentDescription("Unsaved invoice preview page");
        ScrollView scroll=new ScrollView(a);scroll.addView(image,new ScrollView.LayoutParams(-1,-2));body.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        dialog=new AlertDialog.Builder(a).setTitle("Invoice Preview · Unsaved draft").setView(body)
            .setPositiveButton("Back to draft",null).create();
        dialog.setOnDismissListener(d->close());
        previous.setEnabled(false);next.setEnabled(false);
    }
    private void load(int requested){
        if(closed||busy||requested<0||(count>0&&requested>=count))return;
        busy=true;previous.setEnabled(false);next.setEnabled(false);status.setText("Rendering page…");
        worker.execute(()->{
            Bitmap bitmap=null;int pages=0;
            try{
                if(pdf==null){
                    pdf=File.createTempFile("bb-unsaved-preview-", ".pdf",a.getCacheDir());
                    try(FileOutputStream out=new FileOutputStream(pdf)){InvoicePdf.write(document,out);}
                }
                try(PdfRenderer renderer=new PdfRenderer(ParcelFileDescriptor.open(pdf,ParcelFileDescriptor.MODE_READ_ONLY))){
                    pages=renderer.getPageCount();if(pages<1||pages>50||requested>=pages)throw new IOException("Page count invalid");
                    try(PdfRenderer.Page p=renderer.openPage(requested)){
                        bitmap=Bitmap.createBitmap(p.getWidth()*2,p.getHeight()*2,Bitmap.Config.ARGB_8888);
                        bitmap.eraseColor(Color.WHITE);Matrix m=new Matrix();m.setScale(2,2);
                        p.render(bitmap,null,m,PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);
                    }
                }
            }catch(Exception e){if(bitmap!=null)bitmap.recycle();bitmap=null;if(pdf!=null){pdf.delete();pdf=null;}}
            final Bitmap result=bitmap;final int pageCount=pages;
            a.runOnUiThread(()->{
                busy=false;
                if(closed||!active.getAsBoolean()){if(result!=null)result.recycle();if(!closed)dialog.dismiss();return;}
                if(result==null){status.setText("Could not render invoice. Return to draft and review.");previous.setEnabled(page>0);next.setEnabled(page+1<count);return;}
                image.setImageDrawable(null);if(shown!=null)shown.recycle();
                shown=result;image.setImageBitmap(shown);page=requested;count=pageCount;
                status.setText("UNSAVED DRAFT · Page "+(page+1)+" of "+count);
                previous.setEnabled(page>0);next.setEnabled(page+1<count);
            });
        });
    }
    private void close(){
        if(closed)return;closed=true;image.setImageDrawable(null);
        if(shown!=null){shown.recycle();shown=null;}
        try{worker.execute(()->{if(pdf!=null){pdf.delete();pdf=null;}});}catch(java.util.concurrent.RejectedExecutionException ignored){}
    }
}
