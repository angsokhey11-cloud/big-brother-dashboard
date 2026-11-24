package com.bigbrother.nativev2;

import android.app.Activity;
import android.app.AlertDialog;
import android.graphics.Color;
import android.widget.*;
import org.json.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.function.BooleanSupplier;

/** Native read-only report screens backed by the existing module RPCs. */
final class NativeReadModules {
    static boolean supports(String route){return Arrays.asList("sales-support-your-customer","sales-support-your-stock","sales-support-your-collection","stock-report","daily-sale-summary","monthly-sales-report").contains(route);}
    private final Activity a;private final LinearLayout root;private final CloudAuth api;private final ExecutorService worker;private final BooleanSupplier active;private final String route;
    private TextView status,totals;private EditText search,period;private LinearLayout list;private Button more,refresh;
    private Spinner batches;private final ArrayList<String> batchIds=new ArrayList<>();private boolean changingBatches,loading;
    private JSONObject data;private int limit=30;
    NativeReadModules(Activity a,LinearLayout root,CloudAuth api,ExecutorService worker,BooleanSupplier active,String route){this.a=a;this.root=root;this.api=api;this.worker=worker;this.active=active;this.route=route;}
    private int dp(int n){return Math.round(n*a.getResources().getDisplayMetrics().density);}
    private TextView text(LinearLayout p,String s,int size,boolean bold){TextView t=new TextView(a);t.setText(s);t.setTextSize(size);t.setTextColor(Color.rgb(23,74,145));t.setPadding(0,dp(4),0,dp(4));if(bold)t.setTypeface(null,android.graphics.Typeface.BOLD);p.addView(t);return t;}
    private Button button(String s,Runnable r){Button b=new Button(a);b.setText(s);b.setAllCaps(false);root.addView(b);b.setOnClickListener(v->r.run());return b;}
    private String v(JSONObject j,String k){return InvoicePdf.value(j,k);}
    private String first(JSONObject j,String... keys){return InvoicePdf.first(j,keys);}
    private String fields(JSONObject j,String... pairs){StringBuilder b=new StringBuilder();for(int i=0;i<pairs.length;i+=2){String val=v(j,pairs[i+1]);if(!val.isEmpty()){if(b.length()>0)b.append(" · ");b.append(pairs[i]).append(" ").append(val);}}return b.toString();}
    void open(){
        status=text(root,"Loading authorized data…",14,false);
        if("daily-sale-summary".equals(route)||"monthly-sales-report".equals(route)){
            period=new EditText(a);period.setSingleLine(true);period.setHint("daily-sale-summary".equals(route)?"YYYY-MM-DD":"YYYY-MM");
            LocalDate now=LocalDate.now(ZoneId.of("Asia/Phnom_Penh"));period.setText("daily-sale-summary".equals(route)?now.toString():YearMonth.from(now).toString());root.addView(period);
        }
        if("sales-support-your-stock".equals(route)){batches=new Spinner(a);root.addView(batches);batchIds.add("");batches.setAdapter(new ArrayAdapter<String>(a,android.R.layout.simple_spinner_dropdown_item,new String[]{"Current batch"}));}
        refresh=button("Refresh",this::load);
        search=new EditText(a);search.setHint("Search");search.setSingleLine(true);root.addView(search);
        totals=text(root,"",15,true);list=new LinearLayout(a);list.setOrientation(LinearLayout.VERTICAL);root.addView(list);
        more=button("Show more",()->{limit+=30;render();});more.setVisibility(android.view.View.GONE);
        search.addTextChangedListener(new android.text.TextWatcher(){public void beforeTextChanged(CharSequence s,int st,int c,int f){}public void onTextChanged(CharSequence s,int st,int before,int count){limit=30;render();}public void afterTextChanged(android.text.Editable e){}});
        load();
    }
    private void load(){
        if(loading)return;loading=true;data=null;render();refresh.setEnabled(false);status.setText("Loading…");
        String p=period==null?"":period.getText().toString().trim();
        int pos=batches==null?0:batches.getSelectedItemPosition();String batch=pos>=0&&pos<batchIds.size()?batchIds.get(pos):"";
        worker.execute(()->{
            JSONObject result=null;try{result=api.nativeReport(route,p,batch);}catch(Exception ignored){}
            final JSONObject response=result;
            a.runOnUiThread(()->{if(!active.getAsBoolean())return;loading=false;refresh.setEnabled(true);data=response;limit=30;
                status.setText(data==null?"Unavailable · check date, permissions or network":"Online snapshot · read only");
                if(data!=null&&batches!=null)configureBatches(batch);render();});
        });
    }
    private void configureBatches(String selected){
        JSONArray rows=data.optJSONArray("batches");if(rows==null)return;
        ArrayList<String> names=new ArrayList<>();batchIds.clear();names.add("Current batch");batchIds.add("");
        for(int i=0;i<rows.length();i++){JSONObject r=rows.optJSONObject(i);if(r==null||v(r,"batchId").isEmpty())continue;batchIds.add(v(r,"batchId"));names.add(v(r,"batchId")+" · "+first(r,"locationName","locationCode"));}
        batches.setAdapter(new ArrayAdapter<>(a,android.R.layout.simple_spinner_dropdown_item,names));int i=batchIds.indexOf(selected);batches.setSelection(Math.max(i,0));
    }
    private static final class Row{
        final String title,subtitle,detail,search;Row(String t,String s,String d,String q){title=t;subtitle=s;detail=d;search=(t+" "+s+" "+q).toLowerCase(Locale.ROOT);}
    }
    private void addStock(ArrayList<Row> out,JSONArray a,boolean group){
        if(a==null)return;for(int i=0;i<a.length();i++){JSONObject r=a.optJSONObject(i);if(r==null)continue;
            String title=group?first(r,"groupName","groupCode"):first(r,"productName","productCode");StringBuilder d=new StringBuilder(fields(r,"Warehouse","warehouseGood","Batch","batchPending","Total","totalGood","Average cost","averageCost","Value","totalValue"));
            JSONArray members=r.optJSONArray("members"),bs=r.optJSONArray("batches");StringBuilder q=new StringBuilder();
            if(members!=null)for(int j=0;j<members.length();j++){JSONObject m=members.optJSONObject(j);if(m==null)continue;q.append(" ").append(first(m,"productName","productCode"));d.append("\n").append(first(m,"productName","productCode")).append(" · ").append(fields(m,"Warehouse","warehouseGood","Batch","batchPending","Total","totalGood"));}
            if(bs!=null)for(int j=0;j<bs.length();j++){JSONObject b=bs.optJSONObject(j);if(b!=null)d.append("\n").append(fields(b,"Batch","batchId","Salesman","salesmanName","Pending","pendingQty"));}
            out.add(new Row(title,fields(r,"Warehouse","warehouseGood","Batch","batchPending","Total","totalGood"),d.toString(),q+" "+v(r,"productCode")+" "+v(r,"barcode")));
        }
    }
    private JSONArray require(JSONObject j,String key){JSONArray r=j.optJSONArray(key);if(r==null)throw new IllegalArgumentException("Unexpected response");return r;}
    private ArrayList<Row> rows(){
        ArrayList<Row> out=new ArrayList<>();totals.setText("");
        if("stock-report".equals(route)){
            JSONObject grouped=data.optJSONObject("groupedLive"),t=data.optJSONObject("totals");
            if(t!=null)totals.setText(fields(t,"Warehouse","warehouseQty","Batch","batchQty","Total","totalGoodQty","USD value","totalGoodValue"));
            if(grouped!=null){addStock(out,require(grouped,"groups"),true);addStock(out,require(grouped,"exactProducts"),false);}else addStock(out,require(data,"products"),false);
        }else if("monthly-sales-report".equals(route)){
            JSONObject t=data.optJSONObject("totals");if(t!=null)totals.setText(fields(t,"Net USD","totalSaleUSD","Gross USD","grossSalesUSD","Returns USD","returnsUSD","Invoices","invoiceCount"));
            JSONArray arr=require(data,"locations");for(int i=0;i<arr.length();i++){JSONObject r=arr.getJSONObject(i);StringBuilder d=new StringBuilder(fields(r,"Gross USD","grossSalesUSD","Returns USD","returnsUSD","Net USD","totalSaleUSD"));
                JSONArray products=r.optJSONArray("products");StringBuilder q=new StringBuilder();
                if(products!=null)for(int j=0;j<products.length();j++){JSONObject p=products.optJSONObject(j);if(p==null)continue;String n=first(p,"productName","productCode");q.append(" ").append(n);d.append("\n").append(n).append(" · ").append(fields(p,"Gross qty","grossQty","Returned","returnQty","Net qty","netQty","Net USD","totalSaleUSD"));}
                out.add(new Row(first(r,"locationName","locationCode"),fields(r,"Net USD","totalSaleUSD","Net qty","netQty"),d.toString(),q.toString()));
            }
        }else{
            String key="sales-support-your-customer".equals(route)?"customers":"sales-support-your-stock".equals(route)?"items":"invoices";
            JSONArray arr=require(data,key);
            for(int i=0;i<arr.length();i++){
                JSONObject r=arr.optJSONObject(i);if(r==null)continue;
                if("daily-sale-summary".equals(route)&&v(r,"invoiceId").startsWith("AR-MIG-"))continue;
                if("customers".equals(key))out.add(new Row(first(r,"name","customerId"),fields(r,"ID","customerId","Location","locationCode","Phone","phone"),fields(r,"Address","address","Map","googleMapsLink"),v(r,"address")));
                else if("items".equals(key))out.add(new Row(first(r,"productName","productCode","groupName"),fields(r,"Unit","unit","Issued","issuedQty","Remaining","remainingQty","Pending","pendingQty"),fields(r,"Sold","soldQty","Returned","backQty","Damage","damageQty","Purchased","purchasedPendingQty","Zero cost","zeroCostPendingQty"),v(r,"productCode")));
                else out.add(new Row(v(r,"invoiceNo")+" · "+first(r,"customer","customerName"),fields(r,"Date","invoiceDate","Location","locationCode","Currency","currency","Total","grandTotal"),fields(r,"Method","paymentMethod","Paid","amountPaid","Outstanding","outstanding","Status","status"),v(r,"invoiceId")));
            }
        }return out;
    }
    private void render(){
        if(list==null)return;list.removeAllViews();totals.setText("");more.setVisibility(android.view.View.GONE);if(data==null)return;
        try{
            String q=search.getText().toString().trim().toLowerCase(Locale.ROOT);int count=0;
            for(Row r:rows()){
                if(!r.search.contains(q))continue;if(count++>=limit)continue;
                LinearLayout card=new LinearLayout(a);card.setOrientation(LinearLayout.VERTICAL);card.setPadding(dp(12),dp(8),dp(12),dp(8));
                android.graphics.drawable.GradientDrawable bg=new android.graphics.drawable.GradientDrawable();bg.setColor(Color.WHITE);bg.setCornerRadius(dp(10));bg.setStroke(dp(1),Color.rgb(218,228,239));card.setBackground(bg);
                LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.topMargin=dp(8);list.addView(card,lp);text(card,r.title,16,true);text(card,r.subtitle,13,false);
                if(!r.detail.isEmpty()){Button b=new Button(a);b.setText("Details");b.setAllCaps(false);card.addView(b);b.setOnClickListener(v->new AlertDialog.Builder(a).setTitle(r.title).setMessage(r.detail).setPositiveButton("Close",null).show());}
            }
            if(count==0)text(list,"No matching records.",14,false);if(count>limit)more.setVisibility(android.view.View.VISIBLE);
        }catch(Exception e){list.removeAllViews();totals.setText("");status.setText("Unexpected report format. No data displayed.");}
    }
}
