package com.bigbrother.nativev2;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Color;
import android.view.ViewGroup;
import android.widget.*;
import android.text.InputType;
import android.content.Intent;
import android.provider.Settings;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;
import org.json.JSONObject;
import org.json.JSONArray;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private final CloudAuth auth = new CloudAuth();
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private LinearLayout root;
    private TextView status;
    private boolean destroyed;
    private int dp(int n) { return Math.round(n * getResources().getDisplayMetrics().density); }
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        showLogin();
    }
    private void screen() {
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(24),dp(48),dp(24),dp(32));
        root.setBackgroundColor(Color.WHITE);
        scroll.addView(root);
        setContentView(scroll);
        label("BIG BROTHER",28,Color.rgb(23,74,145));
        label(getString(R.string.app_name),18,Color.DKGRAY);
        label("Development build — not for accounting work",14,Color.DKGRAY);
        status = label("",14,Color.DKGRAY);
        refreshStatus();
    }
    private void showLogin() {
        screen();
        if (!"online".equals(BuildConfig.FLAVOR)) {
            label("Local Brain authentication is not connected yet.",16,Color.DKGRAY);
            TextView connection = label("",14,Color.DKGRAY);
            Button probe = button("Check Local Brain connection");
            probe.setOnClickListener(v -> {
                probe.setEnabled(false); connection.setText("Checking secure LAN connection…");
                worker.execute(() -> {
                    String message;
                    try { message = LocalConnection.check(); }
                    catch (Exception e) { message = "Secure LAN connection failed. Check Wi-Fi, Local Brain V6 and Caddy certificate."; }
                    final String result = message;
                    runOnUiThread(() -> { if (!destroyed) { connection.setText(result); probe.setEnabled(true); } });
                });
            });
            button("Network settings").setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_WIRELESS_SETTINGS)));
            return;
        }
        EditText email = new EditText(this);
        email.setHint("Email"); email.setSingleLine(true);
        email.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS);
        email.setSaveEnabled(false); root.addView(email);
        EditText password = new EditText(this);
        password.setHint("Password"); password.setSingleLine(true);
        password.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        password.setSaveEnabled(false); root.addView(password);
        TextView result = label("",14,Color.DKGRAY);
        Button signIn = button("Sign in");
        signIn.setOnClickListener(v -> {
            String address = email.getText().toString().trim();
            String secret = password.getText().toString();
            if (address.isEmpty() || secret.isEmpty()) { result.setText("Enter email and password."); return; }
            signIn.setEnabled(false); email.setEnabled(false); password.setEnabled(false);
            password.setText(""); result.setText("Signing in…");
            worker.execute(() -> {
                try {
                    JSONObject profile = auth.signIn(address,secret);
                    runOnUiThread(() -> { if (!destroyed) showProfile(profile); });
                } catch (Exception e) {
                    runOnUiThread(() -> { if (!destroyed) {
                        result.setText("Sign-in or permission lookup failed. Check credentials and connection.");
                        signIn.setEnabled(true); email.setEnabled(true); password.setEnabled(true);
                    }});
                }
            });
        });
    }
    private void showProfile(JSONObject profile) {
        screen();
        label("Permission profile loaded",20,Color.rgb(23,74,145));
        label("Available modules — preview only; accounting screens are not connected.",14,Color.DKGRAY);
        String[][] modules = {
            {"Invoice Generator","invoice_generator","canCreate"},
            {"Invoice History","invoice_history","canView"},
            {"Accounts Receivable","accounts_receivable","canView"},
            {"Sales Support","sales_support","canView"},
            {"Stock Report","Stock Report","canView"},
            {"Daily Cash Collection","daily_cash_collection","canView"},
            {"Admin Work","admin_work","canView"}
        };
        int visible=0;
        for (String[] m:modules) if (allowed(profile,m[1],m[2])) {
            label(m[0] + " — migration pending",16,Color.DKGRAY); visible++;
        }
        if (visible==0) label("No supported module grants found.",15,Color.DKGRAY);
        Button logout=button("Sign out");
        logout.setOnClickListener(v -> {
            logout.setEnabled(false);
            worker.execute(() -> {
                try { auth.signOut(); } catch (Exception ignored) {}
                runOnUiThread(() -> { if (!destroyed) showLogin(); });
            });
        });
    }
    private boolean allowed(JSONObject profile,String key,String action) {
        JSONObject user=profile.optJSONObject("user");
        if (user!=null && Boolean.TRUE.equals(user.opt("isAdmin"))) return true;
        JSONArray grants=profile.optJSONArray("modules");
        if(grants==null) return false;
        JSONObject exact=null;
        for(int i=0;i<grants.length();i++){
            JSONObject grant=grants.optJSONObject(i);
            if(grant==null) continue;
            String k=grant.optString("moduleKey").trim();
            if("*".equals(k)) return Boolean.TRUE.equals(grant.opt(action));
            if(exact==null && key.equalsIgnoreCase(k)) exact=grant;
        }
        return exact!=null && Boolean.TRUE.equals(exact.opt(action));
    }
    private TextView label(String value,int sp,int color) {
        TextView text=new TextView(this);
        text.setText(value);text.setTextSize(sp);text.setTextColor(color);
        text.setPadding(0,dp(8),0,dp(8));
        root.addView(text,new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,ViewGroup.LayoutParams.WRAP_CONTENT));
        return text;
    }
    private Button button(String value) { Button b=new Button(this);b.setText(value);root.addView(b);return b; }
    @Override protected void onResume(){super.onResume();if(status!=null)refreshStatus();}
    private void refreshStatus(){
        ConnectivityManager manager=getSystemService(ConnectivityManager.class);
        NetworkCapabilities caps=manager==null?null:manager.getNetworkCapabilities(manager.getActiveNetwork());
        status.setText(caps==null?"Device network: disconnected":"Device network: connected (server not verified)");
    }
    @Override protected void onDestroy(){destroyed=true;worker.shutdown();super.onDestroy();}
}
