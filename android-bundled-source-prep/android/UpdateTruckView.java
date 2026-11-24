package com.bigbrother.online;

import android.content.Context;
import android.graphics.*;
import android.os.SystemClock;
import android.view.View;

/** Original lightweight truck illustration, no network, image files or Lottie dependency. */
final class UpdateTruckView extends View {
    private final Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final long start=SystemClock.uptimeMillis();
    UpdateTruckView(Context c){super(c);setContentDescription("BIG BROTHER delivery truck animation");}
    private void color(int c){p.setColor(c);p.setStyle(Paint.Style.FILL);}
    private void rect(Canvas c,float x,float y,float w,float h,float radius,int col){color(col);c.drawRoundRect(x,y,x+w,y+h,radius,radius,p);}
    private void line(Canvas c,float x,float y,float x2,float y2,int col,float width){color(col);p.setStrokeWidth(width);p.setStrokeCap(Paint.Cap.ROUND);c.drawLine(x,y,x2,y2,p);}
    private void circle(Canvas c,float x,float y,float r,int col){color(col);c.drawCircle(x,y,r,p);}
    private void path(Canvas c,float[] points,int col){Path shape=new Path();shape.moveTo(points[0],points[1]);for(int i=2;i<points.length;i+=2)shape.lineTo(points[i],points[i+1]);shape.close();color(col);c.drawPath(shape,p);}
    private void text(Canvas c,String text,float x,float y,float size,int col,boolean bold){color(col);p.setTextSize(size);p.setTextAlign(Paint.Align.CENTER);p.setTypeface(bold?Typeface.DEFAULT_BOLD:Typeface.DEFAULT);c.drawText(text,x,y,p);}
    @Override protected void onDraw(Canvas c){
        super.onDraw(c);float scale=Math.min(getWidth()/320f,getHeight()/165f);if(scale<=0)return;
        float elapsed=(SystemClock.uptimeMillis()-start)/1000f;
        c.save();c.translate((getWidth()-320*scale)/2,(getHeight()-165*scale)/2);c.scale(scale,scale);c.clipRect(0,0,320,165);
        float wind=(elapsed%0.9f)/0.9f;int windAlpha=(int)(160*Math.sin(Math.PI*wind));int wc=(windAlpha<<24)|0x94b4d5;
        line(c,45-25*wind,70,80-25*wind,70,wc,3);line(c,23-25*wind,86,67-25*wind,86,wc,3);line(c,48-25*wind,101,72-25*wind,101,wc,3);
        c.save();c.translate(0,(float)(-1-Math.sin(elapsed*Math.PI*4)));
        rect(c,84,40,115,76,7,0xff174a91);
        path(c,new float[]{203,62,239,62,265,93,265,116,203,116},0xff3287c5);
        path(c,new float[]{211,70,235,70,254,93,211,93},0xffdceefb);
        rect(c,79,111,191,10,4,0xff173b70);
        text(c,"BIG BROTHER",141,76,13,0xffffffff,true);text(c,"M O B I L E",141,92,8,0xffc5ddf5,false);
        for(int x:new int[]{116,239}){circle(c,x,122,16,0xff253447);circle(c,x,122,7,0xffb5c8d9);c.save();c.rotate(elapsed*360,x,122);line(c,x-5,122,x+5,122,0xff657c94,1.5f);c.restore();}
        rect(c,255,101,10,5,2,0xffffe29a);
        c.restore();
        line(c,10,140,310,140,0xffa7b5c5,2);
        float shift=(elapsed%0.9f)/0.9f*50;
        for(int x=10;x<=360;x+=50)line(c,x-shift,149,x+25-shift,149,0xffa7b5c5,3);
        c.restore();if(isShown())postInvalidateOnAnimation();
    }
}
