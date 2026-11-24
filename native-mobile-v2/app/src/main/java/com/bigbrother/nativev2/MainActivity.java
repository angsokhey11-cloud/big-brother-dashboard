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
    private JSONObject pendingExport;
    private boolean exportBusy;
    private static final int SAVE_PDF=4101;
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
        final boolean local = "local".equals(BuildConfig.FLAVOR);
        if (local) {
            label("Local Brain V6 — secure LAN sign-in",16,Color.DKGRAY);
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
        }
        EditText publicKey = new EditText(this);
        if (local) {
            publicKey.setHint("Local public anon / publishable key");
            publicKey.setSingleLine(true); publicKey.setSaveEnabled(false);
            publicKey.setText(getPreferences(MODE_PRIVATE).getString("local_public_key",""));
            root.addView(publicKey);
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
            if (local) {
                try {
                    String key = publicKey.getText().toString().trim();
                    auth.configureLocalKey(key);
                    getPreferences(MODE_PRIVATE).edit().putString("local_public_key",key).apply();
                } catch (Exception e) { result.setText("Enter the Local Brain public anon or publishable key only."); return; }
            }
            signIn.setEnabled(false); email.setEnabled(false); password.setEnabled(false); publicKey.setEnabled(false);
            password.setText(""); result.setText("Signing in…");
            worker.execute(() -> {
                try {
                    JSONObject profile = auth.signIn(address,secret);
                    runOnUiThread(() -> { if (!destroyed) showProfile(profile); });
                } catch (Exception e) {
                    runOnUiThread(() -> { if (!destroyed) {
                        result.setText("Sign-in or permission lookup failed. Check credentials and connection.");
                        signIn.setEnabled(true); email.setEnabled(true); password.setEnabled(true); publicKey.setEnabled(true);
                    }});
                }
            });
        });
    }
    private void showProfile(JSONObject profile) {
        screen();
        label("Permission profile loaded",20,Color.rgb(23,74,145));
        label("Available modules — Invoice History read-only preview",14,Color.DKGRAY);
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
            if ("invoice_history".equals(m[1])) button(m[0]).setOnClickListener(v -> showHistory(profile));
            else label(m[0] + " — migration pending",16,Color.DKGRAY); visible++;
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
    private EditText field(String hint) {
        EditText value = new EditText(this);
        value.setHint(hint); value.setSingleLine(true); value.setSaveEnabled(false);
        root.addView(value); return value;
    }
    private void showHistory(JSONObject profile) {
        screen();
        label("Invoice History",22,Color.rgb(23,74,145));
        button("Back to dashboard").setOnClickListener(v -> showProfile(profile));
        EditText number=field("Invoice number");
        EditText customer=field("Customer name");
        EditText from=field("From date (YYYY-MM-DD)");
        EditText to=field("To date (YYYY-MM-DD)");
        TextView message=label("",14,Color.DKGRAY);
        Button search=button("Search invoices");
        LinearLayout results=new LinearLayout(this);
        results.setOrientation(LinearLayout.VERTICAL); root.addView(results);
        final LinearLayout page=root;
        search.setOnClickListener(v -> {
            String n=number.getText().toString(), c=customer.getText().toString();
            String a=from.getText().toString().trim(), b=to.getText().toString().trim();
            try {
                if(!a.isEmpty()) java.time.LocalDate.parse(a);
                if(!b.isEmpty()) java.time.LocalDate.parse(b);
                if(!a.isEmpty()&&!b.isEmpty()&&a.compareTo(b)>0) throw new IllegalArgumentException();
            } catch(Exception e) { message.setText("Enter valid dates in YYYY-MM-DD format."); return; }
            if(n.trim().isEmpty()&&c.trim().isEmpty()&&(a.isEmpty()||b.isEmpty())){
                message.setText("Enter an invoice number, customer, or both dates.");return;
            }
            search.setEnabled(false); results.removeAllViews(); message.setText("Searching…");
            worker.execute(() -> {
                try {
                    JSONObject data=auth.invoiceList(n,c,a,b);
                    JSONArray rows=data.getJSONArray("invoices");
                    runOnUiThread(() -> {
                        if(destroyed||root!=page)return;
                        search.setEnabled(true);
                        message.setText(rows.length()+" invoices found");
                        for(int i=0;i<rows.length()&&i<200;i++){
                            JSONObject row=rows.optJSONObject(i); if(row==null)continue;
                            String id=row.optString("invoiceId","");
                            Button entry=new Button(this);
                            entry.setAllCaps(false);
                            entry.setText(row.optString("invoiceNo")+" · "+row.optString("invoiceDate")+"\n"+row.optString("customer"));
                            entry.setEnabled(!id.isEmpty());
                            entry.setOnClickListener(w -> loadInvoice(profile,id,page,message,results,search));
                            results.addView(entry);
                        }
                        if(rows.length()>200)message.setText("Showing first 200 of "+rows.length()+" invoices. Refine your search.");
                    });
                }catch(Exception e){runOnUiThread(() -> {if(!destroyed&&root==page){search.setEnabled(true);message.setText("Search failed. Check connection and permissions.");}});}
            });
        });
    }
    private void loadInvoice(JSONObject profile,String id,LinearLayout page,TextView message,LinearLayout results,Button search){
        search.setEnabled(false);
        for(int i=0;i<results.getChildCount();i++)results.getChildAt(i).setEnabled(false);
        message.setText("Loading invoice…");
        worker.execute(() -> {
            try {
                JSONObject invoice=auth.invoiceDetail(id).getJSONObject("invoice");
                if(!id.equals(invoice.optString("invoiceId")))throw new IllegalStateException("Invoice identity mismatch");
                runOnUiThread(() -> {if(!destroyed&&root==page)showInvoice(profile,invoice);});
            } catch(Exception e){runOnUiThread(() -> {if(!destroyed&&root==page){
                message.setText("Could not load invoice. Search again.");
                search.setEnabled(true);results.removeAllViews();
            }});}
        });
    }
    private void showInvoice(JSONObject profile,JSONObject invoice){
        screen();
        label("Invoice preview — read only",22,Color.rgb(23,74,145));
        button("Back to Invoice History").setOnClickListener(v -> showHistory(profile));
        for(String[] field:new String[][]{{"Invoice","invoiceNo"},{"Date","invoiceDate"},{"Customer","customer"},{"Currency","currency"}})
            label(field[0]+": "+invoice.optString(field[1]),16,Color.DKGRAY);
        JSONArray items=invoice.optJSONArray("items");
        if(items!=null)for(int i=0;i<items.length();i++){
            JSONObject item=items.optJSONObject(i);if(item==null)continue;
            label((i+1)+". "+item.optString("productName",item.optString("description",item.optString("name")))+"\nQty: "+item.optString("qty",item.optString("quantity"))+"  |  Price: "+item.optString("unitPrice",item.optString("price"))+"  |  Amount: "+item.optString("amount",item.optString("total")),15,Color.DKGRAY);
        }
        for(String[] field:new String[][]{{"Subtotal","subtotal"},{"Discount","discount"},{"Grand total","grandTotal"},{"Paid","amountPaid"},{"Outstanding","outstanding"}})
            label(field[0]+": "+invoice.optString(field[1]),16,Color.DKGRAY);
        label("Development PDF only — official layout and Digital Original registration pending.",14,Color.DKGRAY);
        button("Save to Device (PDF)").setOnClickListener(v -> {
            if(exportBusy)return;
            pendingExport=invoice;exportBusy=true;
            Intent picker=new Intent(Intent.ACTION_CREATE_DOCUMENT);
            picker.addCategory(Intent.CATEGORY_OPENABLE);picker.setType("application/pdf");
            picker.putExtra(Intent.EXTRA_TITLE,"BIG-BROTHER-"+safeInvoiceName(invoice)+".pdf");
            try{startActivityForResult(picker,SAVE_PDF);}
            catch(Exception e){pendingExport=null;exportBusy=false;Toast.makeText(this,"Save picker unavailable",Toast.LENGTH_LONG).show();}
        });
        button("Share PDF (Telegram)").setOnClickListener(v -> shareInvoice(invoice));
        addDigitalOriginalStatus(invoice);
        button("Share invoice images (PNG)").setOnClickListener(v -> shareImages(invoice));
        button("Print A4 / PDF").setOnClickListener(v -> {
            if(exportBusy)return;
            android.print.PrintManager pm=(android.print.PrintManager)getSystemService(PRINT_SERVICE);
            if(pm==null){Toast.makeText(this,"Printing unavailable",Toast.LENGTH_LONG).show();return;}
            try{pm.print("BIG BROTHER Invoice "+safeInvoiceName(invoice),new InvoiceNativeActions.Adapter(this,invoice),
                new android.print.PrintAttributes.Builder().setMediaSize(android.print.PrintAttributes.MediaSize.ISO_A4).setColorMode(android.print.PrintAttributes.COLOR_MODE_COLOR).build());}
            catch(Exception e){Toast.makeText(this,"Printing unavailable",Toast.LENGTH_LONG).show();}
        });
    }
    private void addDigitalOriginalStatus(JSONObject invoice){
        String id=InvoicePdf.value(invoice,"invoiceId");
        TextView state=label("Digital Original: checking server status…",14,Color.DKGRAY);
        Button refresh=button("Refresh Digital Original status");
        final LinearLayout page=root;
        if(id.isEmpty()){state.setText("Digital Original: invoice identity unavailable");refresh.setEnabled(false);return;}
        refresh.setOnClickListener(v -> checkDigitalOriginal(id,invoice,page,state,refresh));
        checkDigitalOriginal(id,invoice,page,state,refresh);
    }
    private void checkDigitalOriginal(String id,JSONObject invoice,LinearLayout page,TextView state,Button refresh){
        refresh.setEnabled(false);
        state.setText("Digital Original: checking server status…");
        worker.execute(() -> {
            String result;
            try {
                JSONObject data=auth.digitalOriginalStatus(id);
                if(!(data.opt("hasImage") instanceof Boolean)||!(data.opt("eligible") instanceof Boolean))
                    throw new IllegalStateException("Incomplete original status");
                if(Boolean.TRUE.equals(data.opt("hasImage"))){
                    result="history_capture".equals(data.optString("source"))
                        ?"Digital Original already saved"
                        :"Invoice picture already uploaded — do not overwrite";
                }else if(Boolean.TRUE.equals(data.opt("eligible"))){
                    boolean credit="credit".equalsIgnoreCase(InvoicePdf.value(invoice,"paymentMethod").trim());
                    boolean outstanding=false;
                    try{outstanding=new java.math.BigDecimal(InvoicePdf.value(invoice,"outstanding")).signum()>0;}
                    catch(NumberFormatException ignored){}
                    result=credit&&outstanding
                        ?"Digital Original eligible — registration disabled in development build"
                        :"Invoice status changed — reopen the latest invoice";
                }else result="Digital Original not eligible";
            }catch(Exception e){result="Digital Original status unavailable. Retry or reopen invoice.";}
            final String text=result;
            runOnUiThread(() -> {if(!destroyed&&root==page){state.setText(text);refresh.setEnabled(true);}});
        });
    }
    private String safeInvoiceName(JSONObject invoice){
        String n=invoice.optString("invoiceNo","Invoice").replaceAll("[^A-Za-z0-9_-]","_");
        return n.substring(0,Math.min(60,n.length()));
    }
    @Override protected void onActivityResult(int request,int result,Intent data){
        super.onActivityResult(request,result,data);
        if(request!=SAVE_PDF)return;
        JSONObject invoice=pendingExport;pendingExport=null;
        if(result!=RESULT_OK||data==null||data.getData()==null||invoice==null){exportBusy=false;return;}
        android.net.Uri uri=data.getData();
        worker.execute(() -> {
            boolean ok=false;
            try(java.io.ByteArrayOutputStream bytes=new java.io.ByteArrayOutputStream()){
                InvoicePdf.write(invoice,bytes);
                try(java.io.OutputStream out=getContentResolver().openOutputStream(uri,"w")){
                    if(out==null)throw new java.io.IOException("Destination unavailable");
                    bytes.writeTo(out);out.flush();
                }
                ok=true;
            }catch(Exception e){}
            final boolean success=ok;
            runOnUiThread(() -> {exportBusy=false;if(!destroyed)Toast.makeText(this,success?"PDF saved":"Save failed; destination may contain an empty or partial file",Toast.LENGTH_LONG).show();});
        });
    }
    private void shareInvoice(JSONObject invoice){
        if(exportBusy)return;
        exportBusy=true;
        worker.execute(() -> {
            java.io.File file=null;
            try {
                java.io.File folder=new java.io.File(getCacheDir(),"invoice_exports");
                if(!folder.exists()&&!folder.mkdirs())throw new java.io.IOException("Cache unavailable");
                java.io.File[] previous=folder.listFiles();
                if(previous!=null)for(java.io.File old:previous)if(System.currentTimeMillis()-old.lastModified()>86400000L)old.delete();
                file=java.io.File.createTempFile("BB-"+safeInvoiceName(invoice)+"-",".pdf",folder);
                try(java.io.FileOutputStream out=new java.io.FileOutputStream(file)){InvoicePdf.write(invoice,out);}
                android.net.Uri uri=androidx.core.content.FileProvider.getUriForFile(this,getPackageName()+".exports",file);
                runOnUiThread(() -> {
                    exportBusy=false;if(destroyed)return;
                    Intent share=new Intent(Intent.ACTION_SEND);share.setType("application/pdf");
                    share.putExtra(Intent.EXTRA_STREAM,uri);
                    share.setClipData(android.content.ClipData.newRawUri("Invoice PDF",uri));
                    share.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    try{startActivity(Intent.createChooser(share,"Share invoice PDF"));}
                    catch(Exception e){Toast.makeText(this,"Sharing unavailable",Toast.LENGTH_LONG).show();}
                });
            }catch(Exception e){
                if(file!=null)file.delete();
                runOnUiThread(() -> {exportBusy=false;if(!destroyed)Toast.makeText(this,"Could not generate PDF",Toast.LENGTH_LONG).show();});
            }
        });
    }
    private void shareImages(JSONObject invoice){
        if(exportBusy)return;
        exportBusy=true;
        final LinearLayout page=root;
        worker.execute(() -> {
            java.util.ArrayList<java.io.File> files=null;
            try{
                java.io.File folder=new java.io.File(getCacheDir(),"invoice_exports");
                if(!folder.exists()&&!folder.mkdirs())throw new java.io.IOException("Cache unavailable");
                files=InvoiceNativeActions.pngs(this,invoice,folder);
                java.util.ArrayList<android.net.Uri> uris=new java.util.ArrayList<>();
                for(java.io.File file:files)uris.add(androidx.core.content.FileProvider.getUriForFile(this,getPackageName()+".exports",file));
                final java.util.ArrayList<java.io.File> created=files;
                runOnUiThread(() -> {
                    exportBusy=false;
                    if(destroyed||root!=page){for(java.io.File file:created)file.delete();return;}
                    Intent share=new Intent(uris.size()==1?Intent.ACTION_SEND:Intent.ACTION_SEND_MULTIPLE);
                    share.setType("image/png");
                    if(uris.size()==1)share.putExtra(Intent.EXTRA_STREAM,uris.get(0));
                    else share.putParcelableArrayListExtra(Intent.EXTRA_STREAM,uris);
                    android.content.ClipData clip=android.content.ClipData.newRawUri("Invoice image",uris.get(0));
                    for(int i=1;i<uris.size();i++)clip.addItem(new android.content.ClipData.Item(uris.get(i)));
                    share.setClipData(clip);share.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    try{startActivity(Intent.createChooser(share,"Share invoice images"));}
                    catch(Exception e){for(java.io.File file:created)file.delete();Toast.makeText(this,"Sharing unavailable",Toast.LENGTH_LONG).show();}
                });
            }catch(Exception e){
                if(files!=null)for(java.io.File file:files)file.delete();
                runOnUiThread(()->{exportBusy=false;if(!destroyed&&root==page)Toast.makeText(this,"Image export failed. Try PDF for long invoices.",Toast.LENGTH_LONG).show();});
            }
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
