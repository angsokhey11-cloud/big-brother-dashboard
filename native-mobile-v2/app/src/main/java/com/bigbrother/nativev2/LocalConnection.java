package com.bigbrother.nativev2;
import okhttp3.Response;
import org.json.JSONObject;
import java.io.IOException;
final class LocalConnection {
    static String check() throws Exception {
        try(Response response=LocalTransport.client().newCall(LocalTransport.request("/v6-status").get().build()).execute()){
            if(!response.isSuccessful())throw new IOException("V6 status HTTP "+response.code());
            JSONObject data=new JSONObject(LocalTransport.read(response,65536));
            if(!data.optString("mode").contains("BIG BROTHER V6"))throw new IOException("Unexpected server status");
            boolean db=Boolean.TRUE.equals(data.opt("local_supabase_reachable"));
            return db?"Local Brain V6 connected — local database reachable":"Local Brain V6 connected — local database not ready";
        }
    }
}
