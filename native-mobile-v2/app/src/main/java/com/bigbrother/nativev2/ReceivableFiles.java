package com.bigbrother.nativev2;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.*;
import android.graphics.*;
import android.graphics.pdf.PdfRenderer;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.widget.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.function.BooleanSupplier;

/** Private, short-lived original/summary exports. No public URLs or background sending. */
final class ReceivableFiles {
    static File folder(Activity a)throws IOException{
        File f=new File(a.getCacheDir(),"invoice_exports");
        if(!f.exists()&&!f.mkdirs())throw new IOException("Cache unavailable");
        File[] files=f.listFiles();
        if(files!=null)for(File old:files)if(old.getName().startsWith("BB-AR-")&&System.currentTimeMillis()-old.lastModified()>3600000L)old.delete();
        return f;
    }
    static String mime(File f){
        String n=f.getName().toLowerCase(Locale.ROOT);
        if(n.endsWith(".pdf"))return "application/pdf";
        if(n.endsWith(".jpg")||n.endsWith(".jpeg"))return "image/jpeg";
        if(n.endsWith(".png"))return "image/png";
        if(n.endsWith(".webp"))return "image/webp";
        if(n.endsWith(".gif"))return "image/gif";
        if(n.endsWith(".bmp"))return "image/bmp";
        throw new IllegalArgumentException("Unsupported format");
    }
    static boolean validFile(File f)throws IOException{
        byte[] h=new byte[12];int n;
        try(InputStream in=new FileInputStream(f)){n=in.read(h);}
        String type=mime(f);
        if(n<8)return false;
        if("application/pdf".equals(type))return h[0]=='%'&&h[1]=='P'&&h[2]=='D'&&h[3]=='F'&&h[4]=='-';
        if("image/jpeg".equals(type))return (h[0]&255)==255&&(h[1]&255)==216&&(h[2]&255)==255;
        if("image/png".equals(type))return (h[0]&255)==137&&h[1]=='P'&&h[2]=='N'&&h[3]=='G'&&h[4]==13&&h[5]==10&&h[6]==26&&h[7]==10;
        if("image/webp".equals(type))return n>=12&&h[0]=='R'&&h[1]=='I'&&h[2]=='F'&&h[3]=='F'&&h[8]=='W'&&h[9]=='E'&&h[10]=='B'&&h[11]=='P';
        if("image/gif".equals(type))return h[0]=='G'&&h[1]=='I'&&h[2]=='F'&&h[3]=='8'&&(h[4]=='7'||h[4]=='9')&&h[5]=='a';
        return h[0]=='B'&&h[1]=='M';
    }
    static Uri uri(Activity a,File f){return androidx.core.content.FileProvider.getUriForFile(a,a.getPackageName()+".exports",f);}
    static void share(Activity a,ArrayList<File> files)throws Exception{
        if(files.isEmpty())throw new IOException("No attachments");
        ArrayList<Uri> uris=new ArrayList<>();String type=mime(files.get(0));boolean allImages=type.startsWith("image/"),same=true;
        for(File f:files){uris.add(uri(a,f));String m=mime(f);same&=m.equals(type);allImages&=m.startsWith("image/");}
        Intent i=new Intent(files.size()==1?Intent.ACTION_SEND:Intent.ACTION_SEND_MULTIPLE);
        i.setType(same?type:allImages?"image/*":"*/*");
        if(files.size()==1)i.putExtra(Intent.EXTRA_STREAM,uris.get(0));else i.putParcelableArrayListExtra(Intent.EXTRA_STREAM,uris);
        ClipData clip=ClipData.newRawUri("BIG BROTHER documents",uris.get(0));
        for(int n=1;n<uris.size();n++)clip.addItem(new ClipData.Item(uris.get(n)));
        i.setClipData(clip);i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        a.startActivity(Intent.createChooser(i,"Share documents · choose Telegram or another app"));
    }
    static ArrayList<File> pngs(Activity a,File pdf)throws Exception{
        ArrayList<File> files=new ArrayList<>();boolean success=false;
        try(PdfRenderer r=new PdfRenderer(ParcelFileDescriptor.open(pdf,ParcelFileDescriptor.MODE_READ_ONLY))){
            if(r.getPageCount()<1||r.getPageCount()>12)throw new IOException("Use PDF for summaries over 12 pages");
            for(int n=0;n<r.getPageCount();n++){
                File f=File.createTempFile("BB-AR-Summary-page-"+(n+1)+"-", ".png",folder(a));files.add(f);
                try(PdfRenderer.Page p=r.openPage(n);FileOutputStream out=new FileOutputStream(f)){
                    Bitmap b=Bitmap.createBitmap(p.getWidth()*2,p.getHeight()*2,Bitmap.Config.ARGB_8888);
                    try{b.eraseColor(Color.WHITE);Matrix m=new Matrix();m.setScale(2,2);p.render(b,null,m,PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);
                        if(!b.compress(Bitmap.CompressFormat.PNG,100,out))throw new IOException("PNG encoding failed");
                    }finally{b.recycle();}
                }
            }
            success=true;return files;
        }finally{if(!success)delete(files);}
    }
    static void delete(Collection<File> files){for(File f:files)f.delete();}
    static void view(Activity a,File f,ExecutorService worker,BooleanSupplier active){
        if(!active.getAsBoolean()){f.delete();return;}
        if("application/pdf".equals(mime(f))){
            try{Intent i=new Intent(Intent.ACTION_VIEW);i.setDataAndType(uri(a,f),"application/pdf");i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                a.startActivity(Intent.createChooser(i,"Open original PDF"));
            }catch(Exception e){Toast.makeText(a,"No PDF viewer available",Toast.LENGTH_LONG).show();}
            return;
        }
        worker.execute(()->{
            Bitmap b=null;
            try{
                BitmapFactory.Options bounds=new BitmapFactory.Options();bounds.inJustDecodeBounds=true;BitmapFactory.decodeFile(f.getPath(),bounds);
                if(bounds.outWidth<1||bounds.outHeight<1||bounds.outWidth>50000||bounds.outHeight>50000)throw new IOException("Image dimensions invalid");
                BitmapFactory.Options options=new BitmapFactory.Options();options.inSampleSize=1;
                while(Math.max(bounds.outWidth,bounds.outHeight)/options.inSampleSize>2400)options.inSampleSize*=2;
                b=BitmapFactory.decodeFile(f.getPath(),options);
            }catch(Exception ignored){}
            final Bitmap image=b;
            a.runOnUiThread(()->{
                if(!active.getAsBoolean()||image==null){if(image!=null)image.recycle();f.delete();if(active.getAsBoolean())Toast.makeText(a,"Original image unavailable",Toast.LENGTH_LONG).show();return;}
                ImageView view=new ImageView(a);view.setAdjustViewBounds(true);view.setImageBitmap(image);view.setContentDescription("Original invoice photo");
                ScrollView scroll=new ScrollView(a);scroll.addView(view);
                AlertDialog dialog=new AlertDialog.Builder(a).setTitle("Original invoice").setView(scroll).setPositiveButton("Close",null).setNeutralButton("Share original",(d,w)->{
                    if(!active.getAsBoolean())return;
                    try{share(a,new ArrayList<>(Collections.singletonList(f)));}catch(Exception e){Toast.makeText(a,"Sharing unavailable",Toast.LENGTH_LONG).show();}
                }).create();
                dialog.setOnDismissListener(d->{view.setImageDrawable(null);image.recycle();});dialog.show();
            });
        });
    }
}
