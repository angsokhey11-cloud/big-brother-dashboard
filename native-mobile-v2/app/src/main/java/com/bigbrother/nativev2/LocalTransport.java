package com.bigbrother.nativev2;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import okhttp3.*;
import java.net.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import javax.net.ssl.SSLException;

/** LAN-only native HTTP transport, with legacy unicast mDNS fallback for V6. */
final class LocalTransport {
    static final String HOST="bigbrother.local";
    static final String ORIGIN="https://bigbrother.local:8443";
    private static Context app;
    static void init(Context context){app=context.getApplicationContext();}
    private static Network wifi() throws IOException {
        if(app==null)throw new IOException("Local transport not initialized");
        ConnectivityManager cm=app.getSystemService(ConnectivityManager.class);
        if(cm==null)throw new IOException("Network service unavailable");
        for(Network n:cm.getAllNetworks()){
            NetworkCapabilities cap=cm.getNetworkCapabilities(n);
            if(cap!=null&&cap.hasTransport(NetworkCapabilities.TRANSPORT_WIFI))return n;
        }
        throw new IOException("No Wi-Fi network found");
    }
    static OkHttpClient client() throws IOException {
        if(!"local".equals(BuildConfig.FLAVOR))throw new IOException("Local transport disabled");
        final Network n=wifi();
        return new OkHttpClient.Builder().socketFactory(n.getSocketFactory())
          .dns(name->{
              if(!HOST.equalsIgnoreCase(name))throw new UnknownHostException("Unexpected Local host");
              try{return Arrays.asList(n.getAllByName(HOST));}
              catch(UnknownHostException e){return Collections.singletonList(mdns(n));}
          }).proxy(Proxy.NO_PROXY).followRedirects(false).followSslRedirects(false)
          .connectTimeout(8,TimeUnit.SECONDS).readTimeout(15,TimeUnit.SECONDS)
          .callTimeout(45,TimeUnit.SECONDS).build();
    }
    static Request.Builder request(String path)throws IOException{
        if(!path.startsWith("/")||path.startsWith("//"))throw new IOException("Invalid Local route");
        return new Request.Builder().url(ORIGIN+path);
    }
    private static InetAddress mdns(Network n)throws UnknownHostException{
        try(DatagramSocket socket=new DatagramSocket(null)){
            n.bindSocket(socket);socket.bind(new InetSocketAddress(0));
            int tx=new java.security.SecureRandom().nextInt(65536);
            ByteArrayOutputStream bytes=new ByteArrayOutputStream();
            DataOutputStream q=new DataOutputStream(bytes);
            q.writeShort(tx);q.writeShort(0);q.writeShort(1);q.writeShort(0);q.writeShort(0);q.writeShort(0);
            for(String label:HOST.split("\\.")){q.writeByte(label.length());q.writeBytes(label);}
            q.writeByte(0);q.writeShort(1);q.writeShort(1);
            byte[] request=bytes.toByteArray();
            InetAddress group=InetAddress.getByName("224.0.0.251");
            socket.send(new DatagramPacket(request,request.length,group,5353));
            long deadline=android.os.SystemClock.elapsedRealtime()+3000;
            byte[] buffer=new byte[4096];
            while(android.os.SystemClock.elapsedRealtime()<deadline){
                socket.setSoTimeout((int)Math.max(1,deadline-android.os.SystemClock.elapsedRealtime()));
                DatagramPacket reply=new DatagramPacket(buffer,buffer.length);
                socket.receive(reply);
                if(reply.getPort()!=5353)continue;
                byte[] packet=Arrays.copyOf(reply.getData(),reply.getLength());
                try{
                    if(packet.length<12||u16(packet,0)!=tx||(u16(packet,2)&0x800f)!=0x8000)continue;
                    int pos=12,questions=u16(packet,4),answers=u16(packet,6);
                    if(questions!=1||answers<1||answers>32)continue;
                    Name question=name(packet,pos,0);pos=question.next;
                    if(!HOST.equals(question.text)||u16(packet,pos)!=1||u16(packet,pos+2)!=1)continue;
                    pos+=4;
                    for(int i=0;i<answers;i++){
                        Name rr=name(packet,pos,0);pos=rr.next;
                        int type=u16(packet,pos),clazz=u16(packet,pos+2)&0x7fff,length=u16(packet,pos+8);
                        pos+=10;if(pos+length>packet.length)throw new IOException("Truncated answer");
                        if(HOST.equals(rr.text)&&type==1&&clazz==1&&length==4){
                            InetAddress ip=InetAddress.getByAddress(Arrays.copyOfRange(packet,pos,pos+4));
                            // The uploaded V6 responder answers with its own LAN IPv4.
                            if(ip.isSiteLocalAddress()&&ip.equals(reply.getAddress()))return ip;
                        }
                        pos+=length;
                    }
                }catch(IOException ignored){}
            }
        }catch(Exception ignored){}
        throw new UnknownHostException("Local Brain name not resolved on Wi-Fi");
    }
    private static int u16(byte[] b,int i)throws IOException{
        if(i<0||i+1>=b.length)throw new IOException("DNS bounds");
        return ((b[i]&255)<<8)|(b[i+1]&255);
    }
    private static final class Name {final String text;final int next;Name(String t,int n){text=t;next=n;}}
    private static Name name(byte[] b,int pos,int depth)throws IOException{
        if(depth>8)throw new IOException("DNS pointer depth");
        StringBuilder result=new StringBuilder();
        for(int i=0;i<128&&pos<b.length;i++){
            int len=b[pos++]&255;
            if(len==0)return new Name(result.toString().toLowerCase(Locale.ROOT),pos);
            if((len&192)==192){
                if(pos>=b.length)throw new IOException("DNS pointer bounds");
                Name tail=name(b,((len&63)<<8)|(b[pos]&255),depth+1);
                if(result.length()>0&&tail.text.length()>0)result.append('.');
                result.append(tail.text);return new Name(result.toString().toLowerCase(Locale.ROOT),pos+1);
            }
            if(len>63||pos+len>b.length)throw new IOException("DNS label bounds");
            if(result.length()>0)result.append('.');
            result.append(new String(b,pos,len,java.nio.charset.StandardCharsets.US_ASCII));pos+=len;
        }
        throw new IOException("Invalid DNS name");
    }
    static String explain(Throwable e){
        for(Throwable t=e;t!=null;t=t.getCause()){
            if(t instanceof UnknownHostException)return "Local name resolution failed: bigbrother.local";
            if(t instanceof SSLException)return "HTTPS certificate or hostname verification failed. Check the installed Caddy CA.";
            if(t instanceof SocketTimeoutException)return "Local server timed out on Wi-Fi.";
            if(t instanceof ConnectException)return "Local HTTPS port 8443 could not be reached.";
        }
        return "Local connection failed: "+e.getClass().getSimpleName()+". Check Wi-Fi and V6 status.";
    }
    static String read(Response response,int max)throws IOException{
        if(response.body()==null)throw new IOException("Empty response");
        try(InputStream in=response.body().byteStream();ByteArrayOutputStream out=new ByteArrayOutputStream()){
            byte[] b=new byte[8192];int count;
            while((count=in.read(b))!=-1){if(out.size()+count>max)throw new IOException("Response too large");out.write(b,0,count);}
            return out.toString("UTF-8");
        }
    }
}
