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
    private boolean loading,loaded;private int limit=30;
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
        cards=new LinearLayout(a);cards.setOrientation(LinearLayout.VERTICAL);root.addView(cards);
        more=button("Show more invoices",()->{limit+=30;render();});more.setVisibility(android.view.View.GONE);
        search.addTextChangedListener(new android.text.TextWatcher(){
            public void beforeTextChanged(CharSequence s,int start,int count,int after){}
            public void onTextChanged(CharSequence s,int start,int before,int count){limit=30;render();}
            public void afterTextChanged(android.text.Editable e){}
        });
        android.widget.AdapterView.OnItemSelectedListener listener=new android.widget.AdapterView.OnItemSelectedListener(){
            public void onNothingSelected(android.widget.AdapterView<?> p){}
            public void onItemSelected(android.widget.AdapterView<?> p,android.view.View v,int pos,long id){limit=30;render();}
        };
        currency.setOnItemSelectedListener(listener);statusFilter.setOnItemSelectedListener(listener);
        load();
    }
    private void load(){
        if(loading)return;
        loading=true;loaded=false;rows.clear();render();refresh.setEnabled(false);status.setText("Loading authorized receivable list…");
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
    private void render(){
        if(cards==null||more==null)return;
        cards.removeAllViews();more.setVisibility(android.view.View.GONE);
        if(!loaded){totals.setText("Outstanding: —");return;}
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
        }
        totals.setText("Outstanding\n"+money(usd,"USD")+"  ·  "+money(khr,"KHR")+"\n"+matched+" invoice(s) · filtered totals");
        if(matched==0)text(cards,"No matching outstanding invoices.",14,false);
        if(matched>limit)more.setVisibility(android.view.View.VISIBLE);
    }
}
