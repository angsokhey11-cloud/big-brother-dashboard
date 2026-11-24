package com.bigbrother.nativev2;

import android.app.Activity;
import android.graphics.Color;
import android.text.InputType;
import android.widget.*;
import org.json.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.function.BooleanSupplier;

/** Read-only native AR. Existing server determines the scope. Never posts collections. */
final class NativeReceivables {
    private final Activity a;private final LinearLayout root;private final CloudAuth api;
    private final ExecutorService worker;private final BooleanSupplier active;private final String route;
    private final ArrayList<JSONObject> rows=new ArrayList<>();
    private EditText search;private Spinner currency,statusFilter;
    private TextView status,totals;private LinearLayout cards;private Button more,refresh;
    private boolean loading,loaded,checking;private int limit=30,revision;
    private final LinkedHashSet<String> selected=new LinkedHashSet<>();
    private TextView selectionTotal;
    private Button summaryButton,requestButton;
    private static final int NAVY=Color.rgb(23,74,145);
    NativeReceivables(Activity a,LinearLayout root,CloudAuth api,ExecutorService worker,BooleanSupplier active,String route){
        this.a=a;this.root=root;this.api=api;this.worker=worker;this.active=active;this.route=route;
    }
    private int dp(int n){return Math.round(n*a.getResources().getDisplayMetrics().density);}
    private TextView text(LinearLayout p,String s,int size,boolean bold){
        TextView t=new TextView(a);t.setText(s);t.setTextSize(size);t.setTextColor(NAVY);t.setPadding(0,dp(3),0,dp(3));
        if(bold)t.setTypeface(null,android.graphics.Typeface.BOLD);p.addView(t);return t;
    }
    private Button button(String label,Runnable action){
        Button b=new Button(a);b.setText(label);b.setAllCaps(false);root.addView(b);b.setOnClickListener(v->action.run());return b;
    }
    private Spinner select(String... names){
        Spinner s=new Spinner(a);ArrayAdapter<String> ad=new ArrayAdapter<>(a,android.R.layout.simple_spinner_item,names);
        ad.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);s.setAdapter(ad);root.addView(s);return s;
    }
    private String val(JSONObject r,String key){return InvoicePdf.value(r,key);}
    private String ccy(JSONObject r){return val(r,"currency").toUpperCase(Locale.ROOT);}
    private BigDecimal amount(JSONObject r){return new BigDecimal(val(r,"outstanding"));}
    private String money(BigDecimal n,String c){return ("USD".equals(c)?"$":"៛")+String.format(Locale.US,"%,."+("USD".equals(c)?2:0)+"f",n);}
    private LocalDate date(JSONObject r){
        String raw=val(r,"invoiceDate").trim();
        for(String pattern:new String[]{"uuuu-MM-dd","dd-MM-uuuu","dd/MM/uuuu","dd-MMM-uuuu","dd-MM-uu"}){
            try{return LocalDate.parse(raw.length()>10&&raw.charAt(4)=='-'?raw.substring(0,10):raw,DateTimeFormatter.ofPattern(pattern,Locale.US));}catch(Exception ignored){}
        }
        return LocalDate.MAX;
    }
    void open(){
        text(root,"ar-all".equals(route)?"All receivables · server-authorized locations":"Your receivables · existing assigned scope",14,false);
        status=text(root,"Loading outstanding invoices…",14,false);
        refresh=button("Refresh receivables",this::load);
        search=new EditText(a);search.setSingleLine(true);search.setInputType(InputType.TYPE_CLASS_TEXT);search.setHint("Search invoice, customer or location");root.addView(search);
        currency=select("All currencies","USD","KHR");
        statusFilter=select("All statuses","Overdue","Unpaid","Processing");
        totals=text(root,"Outstanding: —",18,true);
        selectionTotal=text(root,"0 selected",14,true);
        summaryButton=button("Customer Summary",this::summary);summaryButton.setEnabled(false);
        if(!"ar-all".equals(route)){requestButton=button("Collection request preview",()->requestDraft(picked()));requestButton.setEnabled(false);}
        button("Select all matching invoices",()->{if(loaded&&!checking){selected.clear();for(JSONObject r:rows)if(matches(r)&&selectable(r))selected.add(val(r,"invoiceId"));revision++;render();}});
        button("Clear selection",()->{selected.clear();revision++;render();});
        cards=new LinearLayout(a);cards.setOrientation(LinearLayout.VERTICAL);root.addView(cards);
        more=button("Show more invoices",()->{limit+=30;render();});more.setVisibility(android.view.View.GONE);
        search.addTextChangedListener(new android.text.TextWatcher(){
            public void beforeTextChanged(CharSequence s,int start,int count,int after){}
            public void onTextChanged(CharSequence s,int start,int before,int count){limit=30;selected.clear();revision++;render();}
            public void afterTextChanged(android.text.Editable e){}
        });
        android.widget.AdapterView.OnItemSelectedListener listener=new android.widget.AdapterView.OnItemSelectedListener(){
            public void onNothingSelected(android.widget.AdapterView<?> p){}
            public void onItemSelected(android.widget.AdapterView<?> p,android.view.View v,int pos,long id){limit=30;selected.clear();revision++;render();}
        };
        currency.setOnItemSelectedListener(listener);statusFilter.setOnItemSelectedListener(listener);
        load();
    }
    private void load(){
        if(loading)return;
        loading=true;loaded=false;rows.clear();selected.clear();revision++;render();refresh.setEnabled(false);status.setText("Loading authorized receivable list…");
        worker.execute(()->{
            ArrayList<JSONObject> result=new ArrayList<>();boolean ok=false;
            try{
                JSONArray list=api.receivableList(route).getJSONArray("receivables");HashSet<String> seen=new HashSet<>();
                for(int i=0;i<list.length();i++){
                    JSONObject r=list.getJSONObject(i);String id=val(r,"invoiceId"),c=ccy(r);
                    if(id.isEmpty()||!seen.add(id)||(!"USD".equals(c)&&!"KHR".equals(c))||val(r,"invoiceNo").isEmpty())throw new IllegalArgumentException("Invalid or duplicate invoice row");
                    if(amount(r).signum()>0)result.add(r);
                }
                result.sort(Comparator.comparing(this::date).thenComparing(r->val(r,"invoiceNo")).thenComparing(r->val(r,"invoiceId")));ok=true;
            }catch(Exception ignored){}
            final boolean success=ok;
            a.runOnUiThread(()->{
                if(!active.getAsBoolean())return;
                loading=false;refresh.setEnabled(true);loaded=success;
                if(success){rows.addAll(result);limit=30;status.setText("Read-only snapshot · "+java.time.LocalTime.now(java.time.ZoneId.of("Asia/Phnom_Penh")).format(DateTimeFormatter.ofPattern("HH:mm")));}
                else status.setText("Receivables unavailable. Check permission or connection, then refresh.");
                render();
            });
        });
    }
    private boolean selectable(JSONObject r){return amount(r).signum()>0&&!"Processing".equalsIgnoreCase(val(r,"arStatus"));}
    private boolean matches(JSONObject r){
        String q=search.getText().toString().trim().toLowerCase(Locale.ROOT),c=String.valueOf(currency.getSelectedItem()),st=String.valueOf(statusFilter.getSelectedItem());
        return ("All currencies".equals(c)||c.equals(ccy(r)))&&("All statuses".equals(st)||st.equalsIgnoreCase(val(r,"arStatus")))&&
            (val(r,"invoiceNo")+" "+val(r,"customer")+" "+val(r,"customerId")+" "+val(r,"locationCode")).toLowerCase(Locale.ROOT).contains(q);
    }
    private ArrayList<JSONObject> picked(){
        ArrayList<JSONObject> out=new ArrayList<>();
        for(JSONObject r:rows)if(selected.contains(val(r,"invoiceId"))&&selectable(r)&&matches(r))out.add(r);
        return out;
    }
    private void updateSelection(){
        BigDecimal usd=BigDecimal.ZERO,khr=BigDecimal.ZERO;ArrayList<JSONObject> chosen=picked();
        for(JSONObject r:chosen)if("USD".equals(ccy(r)))usd=usd.add(amount(r));else khr=khr.add(amount(r));
        selectionTotal.setText(chosen.size()+" selected · "+money(usd,"USD")+" · "+money(khr,"KHR"));
        summaryButton.setEnabled(loaded&&!checking&&!chosen.isEmpty());
        if(requestButton!=null)requestButton.setEnabled(loaded&&!checking&&!chosen.isEmpty());
    }
    private void requestDraft(ArrayList<JSONObject> chosen){
        if(!loaded||checking||chosen.isEmpty()||"ar-all".equals(route))return;
        final int captured=revision;
        String cur=ccy(chosen.get(0));BigDecimal total=BigDecimal.ZERO;
        for(JSONObject r:chosen){
            if(!selectable(r)||!cur.equals(ccy(r))||val(r,"invoiceId").isEmpty()||val(r,"customerId").isEmpty()){
                status.setText("Select eligible outstanding invoices of one currency, with valid customer IDs.");return;
            }
            total=total.add(amount(r));
        }
        final BigDecimal full=total;
        LinearLayout form=new LinearLayout(a);form.setOrientation(LinearLayout.VERTICAL);form.setPadding(dp(16),dp(6),dp(16),dp(12));
        text(form,chosen.size()+" invoice(s) · "+money(full,cur),18,true);
        text(form,"Direct Request · Admin decides Cash or Bank during approval",14,false);
        for(JSONObject r:chosen)text(form,val(r,"invoiceNo")+" · "+val(r,"customer")+" · "+money(amount(r),cur),13,false);
        EditText paymentDate=new EditText(a);paymentDate.setSingleLine(true);paymentDate.setFocusable(false);paymentDate.setText(LocalDate.now(java.time.ZoneId.of("Asia/Phnom_Penh")).toString());
        text(form,"Collection date",13,true);form.addView(paymentDate);
        paymentDate.setOnClickListener(v->{
            LocalDate d=LocalDate.parse(paymentDate.getText().toString());
            new android.app.DatePickerDialog(a,(p,y,m,day)->paymentDate.setText(LocalDate.of(y,m+1,day).toString()),d.getYear(),d.getMonthValue()-1,d.getDayOfMonth()).show();
        });
        EditText input=new EditText(a);input.setInputType(InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_FLAG_DECIMAL);input.setSingleLine(true);input.setText(full.stripTrailingZeros().toPlainString());
        text(form,chosen.size()==1?"Requested amount ("+cur+")":"Full outstanding · batch requests",13,true);form.addView(input);input.setEnabled(chosen.size()==1);
        EditText note=new EditText(a);note.setHint("Note (optional)");note.setMaxLines(3);form.addView(note);
        ScrollView scroll=new ScrollView(a);scroll.addView(form);
        android.app.AlertDialog dialog=new android.app.AlertDialog.Builder(a).setTitle("Collection request · development preview").setView(scroll).setNegativeButton("Cancel",null).setPositiveButton("Validate draft",null).create();
        dialog.setOnShowListener(d->dialog.getButton(-1).setOnClickListener(v->{
            try{
                if(!active.getAsBoolean()||captured!=revision||checking)throw new IllegalArgumentException("Selection changed. Refresh.");
                BigDecimal requested=chosen.size()==1?DraftPayment.amount(input.getText().toString()):full;
                if(requested.signum()<=0||requested.compareTo(full)>0||requested.stripTrailingZeros().scale()>DraftPayment.scale(cur))throw new IllegalArgumentException("Invalid collection amount.");
                String day=LocalDate.parse(paymentDate.getText().toString()).toString();
                JSONObject payload=new JSONObject().put("paymentDate",day).put("note",note.getText().toString().trim()).put("requestType","Direct Request");
                if(chosen.size()==1){
                    JSONObject r=chosen.get(0);
                    payload.put("invoiceId",val(r,"invoiceId")).put("invoiceNo",val(r,"invoiceNo")).put("customerId",val(r,"customerId")).put("amount",requested);
                }else{
                    JSONArray ids=new JSONArray(),nos=new JSONArray();HashSet<String> customers=new HashSet<>();
                    for(JSONObject r:chosen){ids.put(val(r,"invoiceId"));nos.put(val(r,"invoiceNo"));customers.add(val(r,"customerId"));}
                    payload.put("invoiceIds",ids).put("invoiceNos",nos).put("customerId",customers.size()==1?customers.iterator().next():"");
                }
                String frozen=new JSONObject().put("p_payload",payload).toString();
                dialog.dismiss();verifyRequestDraft(chosen,captured,requested,cur,day,frozen);
            }catch(Exception e){input.setError("Check amount, currency and selection.");}
        }));dialog.show();
    }
    private void verifyRequestDraft(ArrayList<JSONObject> chosen,int captured,BigDecimal requested,String cur,String day,String frozen){
        checking=true;updateSelection();status.setText("Verifying collection draft against current outstanding…");
        worker.execute(()->{
            String fingerprint=null;
            try{verifyChosen(chosen);fingerprint=InvoiceSaveJournal.digest(frozen);}catch(Exception ignored){}
            final String result=fingerprint;
            a.runOnUiThread(()->{
                checking=false;if(!active.getAsBoolean())return;updateSelection();
                if(captured!=revision||result==null){status.setText("Collection draft changed or cannot be verified. Refresh.");return;}
                status.setText("Collection request draft verified · no request sent.");
                new android.app.AlertDialog.Builder(a).setTitle("Direct Request preview").setMessage(chosen.size()+" invoice(s)\nCollection date: "+day+"\nRequested: "+money(requested,cur)+"\nAdmin approval required.\n\nPayload fingerprint: "+result.substring(0,16)+"…\nNo payment or request has been submitted.").setPositiveButton("Close",null).show();
            });
        });
    }
    private void detail(JSONObject row){
        if(!loaded||checking)return;
        String id=val(row,"invoiceId");
        checking=true;updateSelection();status.setText("Loading invoice payment history…");
        worker.execute(()->{
            JSONObject data=null;try{data=api.receivableDetail(route,id);}catch(Exception ignored){}
            final JSONObject result=data;
            a.runOnUiThread(()->{
                checking=false;if(!active.getAsBoolean())return;updateSelection();
                if(result==null){status.setText("Invoice details unavailable. Refresh and retry.");return;}
                status.setText("Read-only detail loaded · list balances are snapshot values");
                StringBuilder b=new StringBuilder(val(row,"customer")+"\n"+val(row,"invoiceNo")+" · "+val(row,"invoiceDate")+"\nDue date: "+val(row,"dueDate")+"\nOutstanding (list snapshot): "+money(amount(row),ccy(row))+"\n\nPayment History\n");
                JSONArray payments=result.optJSONArray("payments");
                if(payments==null)b.append("Payment history unavailable.");
                else if(payments.length()==0)b.append("No previous payments.");
                else for(int i=0;i<payments.length();i++){
                    JSONObject p=payments.optJSONObject(i);if(p==null)continue;
                    try{
                        String cur=ccy(p);if(!Arrays.asList("USD","KHR").contains(cur))throw new IllegalArgumentException();
                        b.append(val(p,"paymentDate")).append(" · ").append(val(p,"paymentMethod")).append(" · ").append(money(new BigDecimal(val(p,"amount")),cur)).append("\n");
                        if(!val(p,"transactionId").isEmpty())b.append("Transaction: ").append(val(p,"transactionId")).append("\n");
                        if(!val(p,"approvedBy").isEmpty())b.append("Approved by: ").append(val(p,"approvedBy")).append("\n");
                    }catch(Exception e){b.append("Payment record unavailable.\n");}
                }
                new android.app.AlertDialog.Builder(a).setTitle("Receivable details").setMessage(b.toString()).setPositiveButton("Close",null).show();
            });
        });
    }
    private void verifyChosen(ArrayList<JSONObject> chosen)throws Exception{
                JSONArray fresh=api.receivableList(route).getJSONArray("receivables");
                HashMap<String,JSONObject> map=new HashMap<>();
                for(int i=0;i<fresh.length();i++){JSONObject r=fresh.getJSONObject(i);String id=val(r,"invoiceId");if(id.isEmpty()||map.put(id,r)!=null)throw new IllegalArgumentException();}
                for(JSONObject old:chosen){
                    JSONObject r=map.get(val(old,"invoiceId"));
                    if(r==null||!selectable(r))throw new IllegalArgumentException();
                    for(String k:new String[]{"invoiceNo","customerId","customer","locationCode","currency","invoiceDate","dueDate"})if(!val(old,k).equals(val(r,k)))throw new IllegalArgumentException();
                    for(String k:new String[]{"grandTotal","amountPaid","outstanding"})if(new BigDecimal(val(old,k)).compareTo(new BigDecimal(val(r,k)))!=0)throw new IllegalArgumentException();
                }

    }
    private void summary(){
        ArrayList<JSONObject> chosen=picked();
        if(checking||!loaded||chosen.isEmpty())return;
        final int captured=revision;
        checking=true;updateSelection();status.setText("Verifying selected balances with server…");
        worker.execute(()->{
            boolean valid=false;
            try{verifyChosen(chosen);valid=true;}catch(Exception ignored){}
            final boolean verified=valid;
            a.runOnUiThread(()->{
                checking=false;if(!active.getAsBoolean())return;updateSelection();
                if(!verified||captured!=revision){status.setText("Selection changed or cannot be verified. Refresh and select again.");return;}
                status.setText("Selected outstanding balances verified.");
                showSummary(chosen);
            });
        });
    }
    private static final class Group{
        String name,id;int count;LocalDate start,end;BigDecimal usd=BigDecimal.ZERO,khr=BigDecimal.ZERO;
        Group(String n,String i){name=n;id=i;}
    }
    private void showSummary(ArrayList<JSONObject> chosen){
        LinkedHashMap<String,Group> groups=new LinkedHashMap<>();
        BigDecimal usd=BigDecimal.ZERO,khr=BigDecimal.ZERO;
        for(JSONObject r:chosen){
            String id=val(r,"customerId"),name=val(r,"customer");
            String key=id.isEmpty()?"invoice:"+val(r,"invoiceId"):"id:"+id;
            Group g=groups.computeIfAbsent(key,k->new Group(name,id));g.count++;
            LocalDate d=date(r);if(!d.equals(LocalDate.MAX)){if(g.start==null||d.isBefore(g.start))g.start=d;if(g.end==null||d.isAfter(g.end))g.end=d;}
            if("USD".equals(ccy(r))){g.usd=g.usd.add(amount(r));usd=usd.add(amount(r));}
            else{g.khr=g.khr.add(amount(r));khr=khr.add(amount(r));}
        }
        StringBuilder b=new StringBuilder(chosen.size()+" selected invoices · "+groups.size()+" customer groups\n\n");
        DateTimeFormatter fmt=DateTimeFormatter.ofPattern("dd-MMM-uuuu",Locale.US);
        if(groups.size()==1){
            b.append(chosen.get(0).optString("customer")).append("\n");
            for(JSONObject r:chosen)b.append(val(r,"invoiceDate")).append(" · ").append(val(r,"invoiceNo")).append(" · ").append(money(amount(r),ccy(r))).append("\n");
        }else for(Group g:groups.values()){
            b.append(g.name).append(g.id.isEmpty()?" (customer ID unavailable)":" · "+g.id).append("\n").append(g.count).append(" invoice(s) · ").append(g.start==null?"—":g.start.format(fmt)).append(" to ").append(g.end==null?"—":g.end.format(fmt)).append("\n");
            b.append(money(g.usd,"USD")).append(" · ").append(money(g.khr,"KHR")).append("\n\n");
        }
        b.append("\nTOTAL OUTSTANDING\n").append(money(usd,"USD")).append("\n").append(money(khr,"KHR")).append("\n\nRead-only verified snapshot. No payment submitted.");
        final String snapshot=b.toString();
        final int capturedRevision=revision;
        new android.app.AlertDialog.Builder(a).setTitle("Customer Invoice Summary").setMessage(snapshot)
            .setPositiveButton("Close",null)
            .setNeutralButton("Check originals",(d,w)->checkOriginals(chosen,capturedRevision))
            .setNegativeButton("Share / Export",(d,w)->new android.app.AlertDialog.Builder(a).setTitle("Share customer summary").setItems(new String[]{"Summary PDF","Summary PNG pages","Summary PDF + available originals"},(dlg,index)->{if(index==0)shareSummary(chosen,capturedRevision,snapshot);else sharePackage(chosen,capturedRevision,snapshot,index==2);}).show()).show();
    }
    private void sharePackage(ArrayList<JSONObject> chosen,int captured,String snapshot,boolean originals){
        if(checking||!loaded||revision!=captured)return;
        if(originals&&chosen.size()>35){status.setText("Select up to 35 invoices per attachment package.");return;}
        checking=true;updateSelection();status.setText("Preparing verified documents…");
        worker.execute(()->{
            ArrayList<java.io.File> prepared=new ArrayList<>();ArrayList<String> missing=new ArrayList<>();boolean ok=false;
            try{
                verifyChosen(chosen);
                java.io.File pdf=ReceivableSummaryPdf.create(a,snapshot);prepared.add(pdf);
                if(originals){
                    JSONArray ids=new JSONArray();for(JSONObject r:chosen)ids.put(val(r,"invoiceId"));
                    JSONArray manifest=api.receivableOriginalManifest(route,ids);HashSet<String> accessible=new HashSet<>();
                    for(int i=0;i<manifest.length();i++)accessible.add(val(manifest.getJSONObject(i),"invoiceId"));
                    long bytes=pdf.length();
                    for(JSONObject r:chosen){
                        String id=val(r,"invoiceId");
                        if(!accessible.contains(id)){missing.add(val(r,"invoiceNo")+" · "+val(r,"customer"));continue;}
                        java.io.File f=api.receivableOriginal(route,id,ReceivableFiles.folder(a),Math.min(20L*1024*1024,65L*1024*1024-bytes));
                        prepared.add(f);bytes+=f.length();
                    }
                }else{prepared.addAll(ReceivableFiles.pngs(a,pdf));pdf.delete();prepared.remove(pdf);}
                verifyChosen(chosen);ok=true;
            }catch(Exception e){ReceivableFiles.delete(prepared);prepared.clear();}
            final boolean success=ok;
            a.runOnUiThread(()->{
                checking=false;
                if(!active.getAsBoolean()||revision!=captured){ReceivableFiles.delete(prepared);return;}
                updateSelection();
                if(!success){status.setText("Documents unavailable, changed, or exceed size limits. Refresh or select fewer invoices.");return;}
                String message=prepared.size()+" file(s) ready.";
                if(!missing.isEmpty())message+="\n\nOriginals not uploaded or not accessible:\n"+android.text.TextUtils.join("\n",missing);
                final boolean[] sharing={false};
                android.app.AlertDialog dialog=new android.app.AlertDialog.Builder(a).setTitle("Review sharing package").setMessage(message)
                    .setNegativeButton("Cancel",null).setPositiveButton("Share",(d,w)->{
                        if(!active.getAsBoolean()||revision!=captured)return;
                        try{ReceivableFiles.share(a,prepared);sharing[0]=true;status.setText("Choose recipient in the share app.");}catch(Exception e){status.setText("Sharing unavailable.");}
                    }).create();
                dialog.setOnDismissListener(d->{if(!sharing[0])ReceivableFiles.delete(prepared);});dialog.show();
            });
        });
    }
    private void openOriginal(JSONObject row){
        if(checking||!loaded)return;
        int captured=revision;
        checking=true;updateSelection();status.setText("Opening authorized original…");
        worker.execute(()->{
            java.io.File file=null;
            try{file=api.receivableOriginal(route,val(row,"invoiceId"),ReceivableFiles.folder(a),20L*1024*1024);}catch(Exception ignored){}
            final java.io.File result=file;
            a.runOnUiThread(()->{
                checking=false;
                if(!active.getAsBoolean()||revision!=captured){if(result!=null)result.delete();return;}
                updateSelection();
                if(result==null){status.setText("Original not accessible, missing, unsupported or too large.");return;}
                status.setText("Original downloaded online.");
                ReceivableFiles.view(a,result,worker,()->active.getAsBoolean()&&revision==captured);
            });
        });
    }
    private void checkOriginals(ArrayList<JSONObject> chosen,int captured){
        if(checking||!loaded||revision!=captured)return;
        if(chosen.size()>35){status.setText("Select up to 35 invoices to check original attachments.");return;}
        checking=true;updateSelection();status.setText("Checking authorized original attachments…");
        worker.execute(()->{
            String result;
            try{
                verifyChosen(chosen);JSONArray ids=new JSONArray();for(JSONObject r:chosen)ids.put(val(r,"invoiceId"));
                JSONArray manifest=api.receivableOriginalManifest(route,ids);HashSet<String> available=new HashSet<>();
                for(int i=0;i<manifest.length();i++)available.add(val(manifest.getJSONObject(i),"invoiceId"));
                StringBuilder b=new StringBuilder(available.size()+" of "+chosen.size()+" accessible originals\n\n");
                for(JSONObject r:chosen)b.append(val(r,"invoiceNo")).append(" · ").append(val(r,"customer")).append(" · ").append(available.contains(val(r,"invoiceId"))?"Available":"Not uploaded or not accessible").append("\n");
                result=b.toString();
            }catch(Exception e){result="Original availability could not be verified. Refresh and retry.";}
            final String message=result;
            a.runOnUiThread(()->{checking=false;if(!active.getAsBoolean())return;updateSelection();if(revision!=captured){status.setText("Selection changed. Reopen summary.");return;}
                status.setText("Original attachment check finished.");new android.app.AlertDialog.Builder(a).setTitle("Original invoice attachments").setMessage(message).setPositiveButton("Close",null).show();});
        });
    }
    private void shareSummary(ArrayList<JSONObject> chosen,int captured,String snapshot){
        if(checking||!loaded||revision!=captured)return;
        checking=true;updateSelection();status.setText("Rechecking balances and preparing PDF…");
        worker.execute(()->{
            java.io.File file=null;
            try{
                verifyChosen(chosen);
                file=ReceivableSummaryPdf.create(a,snapshot);
            }catch(Exception e){if(file!=null)file.delete();file=null;}
            final java.io.File prepared=file;
            a.runOnUiThread(()->{
                checking=false;
                if(!active.getAsBoolean()||revision!=captured){if(prepared!=null)prepared.delete();return;}
                updateSelection();
                if(prepared==null){status.setText("Summary changed or PDF unavailable. Refresh and retry.");return;}
                try{
                    android.net.Uri uri=androidx.core.content.FileProvider.getUriForFile(a,a.getPackageName()+".exports",prepared);
                    android.content.Intent intent=new android.content.Intent(android.content.Intent.ACTION_SEND);
                    intent.setType("application/pdf");intent.putExtra(android.content.Intent.EXTRA_STREAM,uri);
                    intent.setClipData(android.content.ClipData.newRawUri("Customer Summary PDF",uri));
                    intent.addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    a.startActivity(android.content.Intent.createChooser(intent,"Share customer summary (Telegram or other app)"));
                    status.setText("Summary PDF prepared · choose recipient in share app.");
                }catch(Exception e){prepared.delete();status.setText("PDF sharing unavailable.");}
            });
        });
    }
    private void render(){
        if(cards==null||more==null)return;
        cards.removeAllViews();more.setVisibility(android.view.View.GONE);
        if(!loaded){totals.setText("Outstanding: —");updateSelection();return;}
        String q=search.getText().toString().trim().toLowerCase(Locale.ROOT),c=String.valueOf(currency.getSelectedItem()),st=String.valueOf(statusFilter.getSelectedItem());
        BigDecimal usd=BigDecimal.ZERO,khr=BigDecimal.ZERO;int matched=0;
        for(JSONObject r:rows){
            if(!("All currencies".equals(c)||c.equals(ccy(r)))||!("All statuses".equals(st)||st.equalsIgnoreCase(val(r,"arStatus"))))continue;
            if(!(val(r,"invoiceNo")+" "+val(r,"customer")+" "+val(r,"customerId")+" "+val(r,"locationCode")).toLowerCase(Locale.ROOT).contains(q))continue;
            if("USD".equals(ccy(r)))usd=usd.add(amount(r));else khr=khr.add(amount(r));
            if(matched++>=limit)continue;
            LinearLayout card=new LinearLayout(a);card.setOrientation(LinearLayout.VERTICAL);card.setPadding(dp(12),dp(8),dp(12),dp(8));
            android.graphics.drawable.GradientDrawable bg=new android.graphics.drawable.GradientDrawable();bg.setColor(Color.WHITE);bg.setCornerRadius(dp(10));bg.setStroke(dp(1),Color.rgb(218,228,239));card.setBackground(bg);
            LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.topMargin=dp(8);cards.addView(card,lp);
            LocalDate d=date(r);String display=d.equals(LocalDate.MAX)?val(r,"invoiceDate"):d.format(DateTimeFormatter.ofPattern("dd-MM-yy",Locale.US));
            text(card,display+"  ·  "+val(r,"invoiceNo")+"  ·  "+val(r,"arStatus"),13,false);
            text(card,val(r,"customer"),16,true);
            text(card,val(r,"locationCode")+"  ·  Outstanding "+money(amount(r),ccy(r)),17,true);
            CheckBox check=new CheckBox(a);check.setText(selectable(r)?"Select invoice":"Processing · not selectable");check.setEnabled(selectable(r));check.setChecked(selected.contains(val(r,"invoiceId")));card.addView(check);
            check.setOnCheckedChangeListener((v,on)->{if(on)selected.add(val(r,"invoiceId"));else selected.remove(val(r,"invoiceId"));revision++;updateSelection();});
            Button detail=new Button(a);detail.setAllCaps(false);detail.setText("Invoice details");card.addView(detail);detail.setOnClickListener(v->detail(r));
            Button original=new Button(a);original.setAllCaps(false);original.setText("Original invoice");card.addView(original);original.setOnClickListener(v->openOriginal(r));
            if(!"ar-all".equals(route)&&selectable(r)){Button request=new Button(a);request.setAllCaps(false);request.setText("Collection request preview");card.addView(request);request.setOnClickListener(v->requestDraft(new ArrayList<>(Collections.singletonList(r))));}
        }
        totals.setText("Outstanding\n"+money(usd,"USD")+"  ·  "+money(khr,"KHR")+"\n"+matched+" invoice(s) · filtered totals");
        if(matched==0)text(cards,"No matching outstanding invoices.",14,false);
        if(matched>limit)more.setVisibility(android.view.View.VISIBLE);
        updateSelection();
    }
}
