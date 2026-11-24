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
    private final ExecutorService updateWorker=Executors.newSingleThreadExecutor();
    private boolean updateBusy;
    private boolean autoChecked;
    private JSONObject pendingExport;
    private boolean exportBusy;
    private static final int SAVE_PDF=4101, SAVE_PNG_FOLDER=4102;
    private final ExecutorService imageWorker=Executors.newSingleThreadExecutor();
    private int dp(int n) { return Math.round(n * getResources().getDisplayMetrics().density); }
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        LocalTransport.init(this);
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
        if ("online".equals(BuildConfig.FLAVOR)) {
            int brand=getResources().getIdentifier("bb_brand","drawable",getPackageName());
            if(brand!=0){
                ImageView logo=new ImageView(this);
                logo.setImageResource(brand);logo.setScaleType(ImageView.ScaleType.FIT_CENTER);
                logo.setContentDescription("BIG BROTHER");
                LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(dp(78),dp(78));
                lp.gravity=android.view.Gravity.CENTER_HORIZONTAL;
                root.addView(logo,lp);
            }
        }
        label("BIG BROTHER",28,Color.rgb(23,74,145));
        label(getString(R.string.app_name),18,Color.DKGRAY);
        label("Development build — not for accounting work",14,Color.DKGRAY);
        status = label("",14,Color.DKGRAY);
        refreshStatus();
    }
    private void showLogin() {
        screen();
        addUpdatePanel();
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
                    catch (Exception e) { message = LocalTransport.explain(e); }
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
    private void addUpdatePanel(){
        final LinearLayout page=root;
        TextView info=label("App version: "+BuildConfig.VERSION_NAME,13,Color.DKGRAY);
        Button check=button("Check for updates");
        check.setOnClickListener(v -> checkUpdate(page,info,check));
        if(!autoChecked){autoChecked=true;checkUpdate(page,info,check);}
    }
    private void checkUpdate(LinearLayout page,TextView info,Button check){
        if(updateBusy)return;
        updateBusy=true;check.setEnabled(false);info.setText("Checking update channel…");
        updateWorker.execute(()->{
            try{
                AppUpdater.Offer offer=AppUpdater.check(this);
                runOnUiThread(()->{
                    updateBusy=false;if(destroyed||root!=page)return;
                    check.setEnabled(true);
                    if(offer==null){info.setText("No newer verified release listed.");return;}
                    info.setText("Update available: build "+offer.version);
                    new android.app.AlertDialog.Builder(this).setTitle("BIG BROTHER update")
                      .setMessage("Download and verify the new APK? Android will ask before installing.")
                      .setNegativeButton("Later",null)
                      .setPositiveButton("Download",(d,w)->downloadUpdate(page,info,check,offer)).show();
                });
            }catch(Exception e){runOnUiThread(()->{updateBusy=false;if(!destroyed&&root==page){check.setEnabled(true);info.setText("Update check unavailable. Current app remains installed.");}});}
        });
    }
    private void downloadUpdate(LinearLayout page,TextView info,Button check,AppUpdater.Offer offer){
        if(updateBusy||root!=page)return;
        if(!getPackageManager().canRequestPackageInstalls()){
            info.setText("Allow installation from this app, then check for updates again.");
            try{startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,android.net.Uri.parse("package:"+getPackageName())));}catch(Exception ignored){}
            return;
        }
        updateBusy=true;check.setEnabled(false);info.setText("Downloading and verifying update…");
        updateWorker.execute(()->{
            try{
                java.io.File apk=AppUpdater.download(this,offer);
                runOnUiThread(()->{
                    updateBusy=false;
                    if(destroyed||root!=page){apk.delete();return;}
                    check.setEnabled(true);
                    android.net.Uri uri=androidx.core.content.FileProvider.getUriForFile(this,getPackageName()+".exports",apk);
                    Intent install=new Intent(Intent.ACTION_VIEW);install.setDataAndType(uri,"application/vnd.android.package-archive");
                    install.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    try{startActivity(install);info.setText("Verified APK — confirm the update in Android.");}
                    catch(Exception e){apk.delete();info.setText("Android installer unavailable.");}
                });
            }catch(Exception e){runOnUiThread(()->{updateBusy=false;if(!destroyed&&root==page){check.setEnabled(true);info.setText("Update rejected or download failed. Current app remains installed.");}});}
        });
    }
    private void showProfile(JSONObject profile) {
        if ("online".equals(BuildConfig.FLAVOR)) { showNativeHome(profile); return; }
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
    private JSONObject overviewSnapshot,paymentSnapshot;
    private boolean overviewLoading;
    private static final int NAVY=Color.rgb(23,74,145), INK=Color.rgb(23,40,65), PALE=Color.rgb(240,245,251);
    private void showNativeHome(JSONObject profile){
        screen();
        root.setBackgroundColor(PALE);root.setPadding(dp(14),dp(42),dp(14),dp(24));
        label("Welcome, "+NativeRoutes.name(profile)+"!",23,NAVY);
        JSONArray locations=profile.optJSONArray("locations");
        String loc=NativeRoutes.admin(profile)?"All Locations":(locations==null||locations.length()==0?"No assigned location":locations.length()+" assigned location(s)");
        if(!NativeRoutes.admin(profile)&&locations!=null&&locations.length()==1&&locations.optJSONObject(0)!=null)
            loc=locations.optJSONObject(0).optString("locationName",loc);
        label(loc+"  ·  "+java.time.LocalDate.now(java.time.ZoneId.of("Asia/Phnom_Penh")).format(java.time.format.DateTimeFormatter.ofPattern("dd-MMM-yyyy",java.util.Locale.US)),13,INK);
        label(NativeRoutes.admin(profile)?"Overview":"My Overview",20,NAVY);
        LinearLayout cards=new LinearLayout(this);cards.setOrientation(LinearLayout.VERTICAL);root.addView(cards);
        fillOverview(cards,profile);
        Button refresh=button("Refresh overview");refresh.setAllCaps(false);
        final LinearLayout page=root;
        refresh.setOnClickListener(v -> loadOverview(profile,page,cards,refresh));
        if(overviewSnapshot==null&&!overviewLoading)loadOverview(profile,page,cards,refresh);
        label("Quick Actions",20,NAVY);
        for(String key:new String[]{"sales-support-calculator","invoice","history","sales-support-your-customer","ar-your","daily-cash-collection","stock-report","staff-relation"})
            for(String[] r:NativeRoutes.ALL)if(key.equals(r[0])&&NativeRoutes.allowed(profile,r[0],r[3])){routeTile(profile,r);break;}
        label("Main Menu",20,NAVY);
        java.util.LinkedHashSet<String> groups=new java.util.LinkedHashSet<>();
        for(String[] r:NativeRoutes.ALL)if(NativeRoutes.allowed(profile,r[0],r[3]))groups.add(r[1]);
        for(String group:groups){
            Button item=button(group+"  ›");item.setAllCaps(false);
            item.setOnClickListener(v -> showNativeGroup(profile,group));
        }
        button("Sign out").setOnClickListener(v -> {
            v.setEnabled(false);overviewSnapshot=null;paymentSnapshot=null;
            worker.execute(()->{try{auth.signOut();}catch(Exception ignored){}runOnUiThread(()->{if(!destroyed){overviewSnapshot=null;paymentSnapshot=null;showLogin();}});});
        });
    }
    private void showNativeGroup(JSONObject profile,String group){
        screen();root.setBackgroundColor(PALE);
        label(group,22,NAVY);button("Back to Home").setOnClickListener(v -> showNativeHome(profile));
        for(String[] r:NativeRoutes.ALL)if(group.equals(r[1])&&NativeRoutes.allowed(profile,r[0],r[3]))routeTile(profile,r);
    }
    private void routeTile(JSONObject profile,String[] r){
        boolean ar=java.util.Arrays.asList("ar-all","ar-your","sales-support-your-receivable").contains(r[0]);
        boolean ready="history".equals(r[0])||"invoice".equals(r[0])||ar;
        Button item=button(r[2]+(ready?"  ›":"  ·  Migration pending"));
        item.setAllCaps(false);item.setEnabled(ready);
        if(ready)item.setOnClickListener(v -> {if("invoice".equals(r[0]))showGenerator(profile);else if(ar)showReceivables(profile,r[0],r[2]);else showHistory(profile);});
    }
    private void showReceivables(JSONObject profile,String route,String title){
        screen();label(title,23,NAVY);
        final LinearLayout page=root;
        button("Back to Home").setOnClickListener(v->showNativeHome(profile));
        new NativeReceivables(this,page,auth,worker,()->!destroyed&&root==page,route).open();
    }
    private void showGenerator(JSONObject profile){
        screen();
        label("Invoice Generator",23,NAVY);
        final LinearLayout page=root;
        button("Back to Home").setOnClickListener(v -> new android.app.AlertDialog.Builder(this)
            .setTitle("Discard draft?").setMessage("Unsaved development draft will be cleared.")
            .setNegativeButton("Continue editing",null).setPositiveButton("Discard",(d,w)->showNativeHome(profile)).show());
        new NativeInvoiceDraft(this,root,auth,worker,()->!destroyed&&root==page).open();
    }
    private String metric(JSONObject obj,String key,boolean money){
        if(obj==null||obj.isNull(key))return "—";
        try{java.math.BigDecimal n=new java.math.BigDecimal(obj.optString(key));
            return money?String.format(java.util.Locale.US,"$%,.2f",n):n.stripTrailingZeros().toPlainString();
        }catch(Exception e){return "—";}
    }
    private void fillOverview(LinearLayout cards,JSONObject profile){
        cards.removeAllViews();JSONObject data=overviewSnapshot;
        if(NativeRoutes.admin(profile)){
            JSONObject m=data==null?null:data.optJSONObject("monthly"),c=data==null?null:data.optJSONObject("currentSnapshot");
            kpiRow(cards,"Monthly Sales",metric(m,"grossSalesUSD",true),"Receivable",metric(c,"receivableUSD",true));
            kpiRow(cards,"Stock Value",metric(c,"stockValueUSD",true),"Pending Tasks",metric(c,"pendingStaffRequests",false));
        }else{
            JSONObject m=data==null?null:data.optJSONObject("monthlySales"),a=data==null?null:data.optJSONObject("receivable"),stock=data==null?null:data.optJSONObject("stock");
            kpiRow(cards,"Monthly Sales",metric(m,"netUSD",true),"Receivable",metric(a,"equivalentUSD",true));
            java.math.BigDecimal usd=java.math.BigDecimal.ZERO,khr=java.math.BigDecimal.ZERO;boolean valid=paymentSnapshot!=null&&paymentSnapshot.optJSONArray("available")!=null;
            if(valid){JSONArray list=paymentSnapshot.optJSONArray("available");try{for(int i=0;i<list.length();i++){JSONObject row=list.getJSONObject(i);java.math.BigDecimal n=new java.math.BigDecimal(row.getString("amount"));String currency=row.optString("currency","USD");if("USD".equalsIgnoreCase(currency))usd=usd.add(n);else if("KHR".equalsIgnoreCase(currency))khr=khr.add(n);}}catch(Exception e){valid=false;}}
            kpiRow(cards,"Stock Qty",metric(stock,"physicalQty",false),"Your Earning",valid?String.format(java.util.Locale.US,"$%,.2f · ៛%,.0f",usd,khr):"—");
        }
    }
    private void kpiRow(LinearLayout parent,String a,String av,String b,String bv){
        LinearLayout row=new LinearLayout(this);row.setOrientation(LinearLayout.HORIZONTAL);parent.addView(row);
        for(String[] pair:new String[][]{{a,av},{b,bv}}){
            LinearLayout card=new LinearLayout(this);card.setOrientation(LinearLayout.VERTICAL);card.setPadding(dp(12),dp(12),dp(12),dp(12));
            android.graphics.drawable.GradientDrawable bg=new android.graphics.drawable.GradientDrawable();bg.setColor(Color.WHITE);bg.setCornerRadius(dp(13));card.setBackground(bg);
            LinearLayout.LayoutParams params=new LinearLayout.LayoutParams(0,ViewGroup.LayoutParams.WRAP_CONTENT,1);params.setMargins(dp(3),dp(3),dp(3),dp(3));row.addView(card,params);
            TextView title=new TextView(this);title.setText(pair[0]);title.setTextSize(12);title.setTextColor(INK);card.addView(title);
            TextView value=new TextView(this);value.setText(pair[1]);value.setTextSize(17);value.setTypeface(null,android.graphics.Typeface.BOLD);value.setTextColor(NAVY);card.addView(value);
        }
    }
    private void loadOverview(JSONObject profile,LinearLayout page,LinearLayout cards,Button refresh){
        if(overviewLoading)return;
        overviewLoading=true;refresh.setEnabled(false);refresh.setText("Loading overview…");
        worker.execute(()->{
            JSONObject fresh=null,pay=null;
            try{fresh=auth.dashboardOverview();if(!NativeRoutes.admin(profile))try{pay=auth.myPayments();}catch(Exception ignored){}}catch(Exception ignored){}
            final JSONObject result=fresh,earnings=pay;
            runOnUiThread(()->{
                overviewLoading=false;if(destroyed||root!=page)return;
                if(result!=null){overviewSnapshot=result;if(earnings!=null)paymentSnapshot=earnings;fillOverview(cards,profile);}
                refresh.setEnabled(true);refresh.setText(result==null?"Overview unavailable — retry":"Refresh overview");
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
        label("Development copies — Digital Original registration pending.",14,Color.DKGRAY);
        button("Save to Device (PNG)").setOnClickListener(v -> beginSaveImages(invoice));
        button("Share to Telegram (PNG)").setOnClickListener(v -> shareImages(invoice));
        addDigitalOriginalStatus(invoice);
        button("Save PDF (optional)").setOnClickListener(v -> {
            if(exportBusy)return;
            pendingExport=invoice;exportBusy=true;
            Intent picker=new Intent(Intent.ACTION_CREATE_DOCUMENT);
            picker.addCategory(Intent.CATEGORY_OPENABLE);picker.setType("application/pdf");
            picker.putExtra(Intent.EXTRA_TITLE,"BIG-BROTHER-"+safeInvoiceName(invoice)+".pdf");
            try{startActivityForResult(picker,SAVE_PDF);}
            catch(Exception e){pendingExport=null;exportBusy=false;Toast.makeText(this,"Save picker unavailable",Toast.LENGTH_LONG).show();}
        });
        button("Share PDF (optional)").setOnClickListener(v -> shareInvoice(invoice));
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
        if(request==SAVE_PNG_FOLDER){
            JSONObject invoice=pendingExport;pendingExport=null;
            if(result!=RESULT_OK||data==null||data.getData()==null||invoice==null){exportBusy=false;return;}
            saveImages(invoice,data.getData());
            return;
        }
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
    private void beginSaveImages(JSONObject invoice){
        if(exportBusy)return;
        exportBusy=true;
        if(android.os.Build.VERSION.SDK_INT>=29){saveImages(invoice,null);return;}
        pendingExport=invoice;
        try{startActivityForResult(new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE),SAVE_PNG_FOLDER);}
        catch(Exception e){pendingExport=null;exportBusy=false;Toast.makeText(this,"Folder picker unavailable",Toast.LENGTH_LONG).show();}
    }
    private void saveImages(JSONObject invoice,android.net.Uri tree){
        Toast.makeText(this,"Preparing invoice PNG…",Toast.LENGTH_SHORT).show();
        imageWorker.execute(() -> {
            java.util.ArrayList<java.io.File> files=null;
            java.util.ArrayList<android.net.Uri> saved=new java.util.ArrayList<>();
            boolean ok=false;
            try{
                java.io.File folder=new java.io.File(getCacheDir(),"invoice_exports");
                if(!folder.exists()&&!folder.mkdirs())throw new java.io.IOException("Cache unavailable");
                files=InvoiceNativeActions.pngs(this,invoice,folder);
                String base="BIG-BROTHER-"+safeInvoiceName(invoice)+"-"+System.currentTimeMillis();
                android.content.ContentResolver resolver=getContentResolver();
                for(int i=0;i<files.size();i++){
                    String name=base+(files.size()>1?"-page-"+(i+1):"")+".png";
                    android.net.Uri dest;
                    if(android.os.Build.VERSION.SDK_INT>=29){
                        android.content.ContentValues values=new android.content.ContentValues();
                        values.put(android.provider.MediaStore.Images.Media.DISPLAY_NAME,name);
                        values.put(android.provider.MediaStore.Images.Media.MIME_TYPE,"image/png");
                        values.put(android.provider.MediaStore.Images.Media.RELATIVE_PATH,android.os.Environment.DIRECTORY_PICTURES+"/BIG BROTHER");
                        values.put(android.provider.MediaStore.Images.Media.IS_PENDING,1);
                        dest=resolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI,values);
                    }else{
                        if(tree==null)throw new java.io.IOException("Destination folder missing");
                        android.net.Uri parent=android.provider.DocumentsContract.buildDocumentUriUsingTree(tree,android.provider.DocumentsContract.getTreeDocumentId(tree));
                        dest=android.provider.DocumentsContract.createDocument(resolver,parent,"image/png",name);
                    }
                    if(dest==null)throw new java.io.IOException("Cannot create PNG");
                    saved.add(dest);
                    try(java.io.InputStream in=new java.io.FileInputStream(files.get(i));java.io.OutputStream out=resolver.openOutputStream(dest,"w")){
                        if(out==null)throw new java.io.IOException("Destination unavailable");
                        byte[] buffer=new byte[32768];int n;
                        while((n=in.read(buffer))!=-1)out.write(buffer,0,n);
                        out.flush();
                    }
                }
                if(android.os.Build.VERSION.SDK_INT>=29){
                    for(android.net.Uri uri:saved){
                        android.content.ContentValues ready=new android.content.ContentValues();
                        ready.put(android.provider.MediaStore.Images.Media.IS_PENDING,0);
                        if(resolver.update(uri,ready,null,null)!=1)throw new java.io.IOException("Could not publish PNG");
                    }
                }
                ok=true;
            }catch(Exception e){
                for(android.net.Uri uri:saved)try{
                    if(android.os.Build.VERSION.SDK_INT>=29)getContentResolver().delete(uri,null,null);
                    else android.provider.DocumentsContract.deleteDocument(getContentResolver(),uri);
                }catch(Exception ignored){}
            }finally{if(files!=null)for(java.io.File file:files)file.delete();}
            final boolean success=ok;final int count=saved.size();
            runOnUiThread(()->{exportBusy=false;if(!destroyed)Toast.makeText(this,success?(count+" PNG image(s) saved"+(android.os.Build.VERSION.SDK_INT>=29?" to Pictures/BIG BROTHER":"")):"PNG save failed. Try again or use PDF for long invoices.",Toast.LENGTH_LONG).show();});
        });
    }
    private void shareImages(JSONObject invoice){
        if(exportBusy)return;
        exportBusy=true;
        final LinearLayout page=root;
        Toast.makeText(this,"Preparing invoice PNG…",Toast.LENGTH_SHORT).show();
        imageWorker.execute(() -> {
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
    @Override protected void onDestroy(){destroyed=true;worker.shutdown();updateWorker.shutdown();imageWorker.shutdown();super.onDestroy();}
}
