package com.bigbrother.nativev2;

import android.app.Activity;
import android.graphics.Color;
import android.view.View;
import android.widget.*;
import org.json.*;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.function.BooleanSupplier;

/** Explicit read-only registered transfer allocation. No financial writes. */
final class NativeBankDraft {
    private final Activity activity;
    private final CloudAuth api;
    private final ExecutorService worker;
    private final BooleanSupplier active;
    private final LinearLayout panel,list;
    private final TextView balance,summary;
    private final Button sync;
    private String customer="",saleDate="",currency="USD",method="";
    private BigDecimal rate=BigDecimal.ZERO,planned=BigDecimal.ZERO;
    private boolean admin,loading,synced;
    private int generation;
    private final ArrayList<Row> rows=new ArrayList<>();
    private final LinkedHashMap<String,BigDecimal> selected=new LinkedHashMap<>();
    private static final class Row {
        String id,currency,date,bank;
        BigDecimal remaining,approved;
        Row(JSONObject r) throws JSONException {
            id=r.optString("transaction_id").trim();
            currency=r.optString("currency").trim().toUpperCase(Locale.ROOT);
            date=r.optString("received_date").trim();
            if(date.length()>=10)date=date.substring(0,10);
            LocalDate.parse(date);
            bank=r.optString("bank_name",r.optString("bank","Bank"));
            remaining=new BigDecimal(r.getString("remaining_amount"));
            String raw=InvoicePdf.value(r,"approved_exchange_rate");
            approved=raw.isEmpty()?BigDecimal.ZERO:new BigDecimal(raw);
            DraftPayment.scale(currency);
            if(id.isEmpty()||remaining.signum()<=0||approved.signum()<0)throw new IllegalArgumentException();
        }
    }
    NativeBankDraft(Activity activity,LinearLayout root,CloudAuth api,ExecutorService worker,BooleanSupplier active){
        this.activity=activity;this.api=api;this.worker=worker;this.active=active;
        panel=new LinearLayout(activity);panel.setOrientation(LinearLayout.VERTICAL);root.addView(panel);
        text(panel,"Customer Bank Balance",18);
        balance=text(panel,"Select customer and Sync Bank.",14);
        sync=button(panel,"Sync Bank",this::sync);
        list=new LinearLayout(activity);list.setOrientation(LinearLayout.VERTICAL);panel.addView(list);
        summary=text(panel,"",14);
        render();
    }
    private TextView text(LinearLayout p,String value,int size){
        TextView t=new TextView(activity);t.setText(value);t.setTextColor(Color.rgb(23,74,145));t.setTextSize(size);t.setPadding(0,6,0,6);p.addView(t);return t;
    }
    private Button button(LinearLayout p,String title,Runnable action){
        Button b=new Button(activity);b.setAllCaps(false);b.setText(title);p.addView(b);b.setOnClickListener(v->action.run());return b;
    }
    private String money(BigDecimal n,String c){return c+" "+DraftPayment.round(n,c).toPlainString();}
    void customer(String value){
        if(customer.equals(value))return;
        customer=value;generation++;rows.clear();selected.clear();loading=false;synced=false;admin=false;render();
    }
    void clear(){
        generation++;rows.clear();selected.clear();loading=false;synced=false;admin=false;render();
    }
    void context(String date,String cur,String method,BigDecimal rate,BigDecimal planned){
        boolean changed=!saleDate.equals(date)||!currency.equals(cur)||!this.method.equals(method)||this.rate.compareTo(rate)!=0;
        boolean amountChanged=this.planned.compareTo(planned)!=0;
        if(!changed&&!amountChanged)return;
        if(changed)selected.clear();
        saleDate=date;currency=cur;this.method=method;this.rate=rate;this.planned=planned;render();
    }
    private boolean bankMethod(){return Arrays.asList("Bank","Partially Paid in Bank","Cash + Bank").contains(method);}
    private boolean eligible(Row r){
        try{LocalDate d=LocalDate.parse(saleDate);return admin||!LocalDate.parse(r.date).isBefore(d);}catch(Exception e){return false;}
    }
    private void sync(){
        if(loading||customer.isEmpty())return;
        loading=true;synced=false;rows.clear();selected.clear();render();
        final int token=++generation;final String id=customer;
        worker.execute(()->{
            JSONObject data=null;try{data=api.generatorBankBalances(id);}catch(Exception ignored){}
            final JSONObject result=data;
            activity.runOnUiThread(()->{
                if(!active.getAsBoolean()||token!=generation||!customer.equals(id))return;
                loading=false;
                if(result==null){balance.setText("Bank sync failed. Retry.");sync.setEnabled(true);return;}
                admin=Boolean.TRUE.equals(result.opt("admin"));
                JSONArray source=result.optJSONArray("rows");if(source==null){render();return;}
                // Reject duplicate transaction identities instead of double-counting balances.
                HashSet<String> seen=new HashSet<>();HashSet<String> duplicates=new HashSet<>();
                for(int i=0;i<source.length();i++)try{
                    JSONObject raw=source.getJSONObject(i);
                    if(!id.equals(raw.optString("customer_id").trim()))continue;
                    Row row=new Row(raw);String key=row.id.toUpperCase(Locale.ROOT);
                    if(!seen.add(key))duplicates.add(key);else rows.add(row);
                }catch(Exception ignored){}
                rows.removeIf(row->duplicates.contains(row.id.toUpperCase(Locale.ROOT)));
                rows.sort(Comparator.comparing((Row row)->row.date).thenComparing(row->row.id));
                synced=true;render();
            });
        });
    }
    private boolean multiAllowed(){return admin&&("Bank".equals(method)||"Partially Paid in Bank".equals(method));}
    private boolean compatible(Row row){
        if(!eligible(row)||!bankMethod())return false;
        if(row.currency.equals(currency))return true;
        if(rate.compareTo(BigDecimal.ONE)<=0)return false;
        return row.approved.compareTo(BigDecimal.ONE)<=0||row.approved.compareTo(rate)==0;
    }
    private BigDecimal equivalent(Row row,BigDecimal amount){
        return DraftPayment.exchange(amount,row.currency,currency,rate);
    }
    private Row find(String id){for(Row r:rows)if(r.id.equals(id))return r;return null;}
    private void choose(Row row){
        if(!synced||!compatible(row))return;
        if(!selected.isEmpty()&&!selected.containsKey(row.id)){
            if(!multiAllowed()||!row.currency.equals(currency)){
                Toast.makeText(activity,"Only one transfer is supported for this payment type or currency.",Toast.LENGTH_LONG).show();return;
            }
            for(String id:selected.keySet())if(!find(id).currency.equals(currency)){
                Toast.makeText(activity,"Multiple transfers must use the invoice currency.",Toast.LENGTH_LONG).show();return;
            }
        }
        EditText amount=new EditText(activity);amount.setInputType(android.text.InputType.TYPE_CLASS_NUMBER|android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL);
        amount.setHint("Use amount in "+row.currency);
        BigDecimal used=BigDecimal.ZERO;
        for(Map.Entry<String,BigDecimal> e:selected.entrySet())if(!row.id.equals(e.getKey()))used=used.add(equivalent(find(e.getKey()),e.getValue()));
        BigDecimal needed=planned.subtract(used).max(BigDecimal.ZERO);
        BigDecimal max=DraftPayment.exchange(needed,currency,row.currency,rate).min(row.remaining);
        BigDecimal suggested=max.setScale(DraftPayment.scale(row.currency),RoundingMode.DOWN);
        amount.setText((selected.containsKey(row.id)?selected.get(row.id):suggested).toPlainString());
        final int token=generation;
        android.app.AlertDialog dialog=new android.app.AlertDialog.Builder(activity).setTitle("Use "+row.id).setMessage("Available "+money(row.remaining,row.currency)+" · draft only").setView(amount).setNegativeButton("Cancel",null).setPositiveButton("Use",null).create();
        dialog.setOnShowListener(d->dialog.getButton(-1).setOnClickListener(v->{
            try{
                if(token!=generation||!compatible(row)||!active.getAsBoolean())throw new IllegalArgumentException();
                BigDecimal value=DraftPayment.amount(amount.getText().toString());
                if(value.signum()<=0||value.compareTo(row.remaining)>0||value.stripTrailingZeros().scale()>DraftPayment.scale(row.currency))throw new IllegalArgumentException();
                selected.put(row.id,value);dialog.dismiss();render();
            }catch(Exception e){amount.setError("Enter a positive amount within the available balance.");}
        }));dialog.show();
    }
    private void render(){
        sync.setEnabled(!customer.isEmpty()&&!loading);
        list.removeAllViews();summary.setText("");
        if(customer.isEmpty()){balance.setText("Select customer and Sync Bank.");return;}
        if(loading){balance.setText("Syncing registered bank balances…");return;}
        if(!synced){balance.setText("Bank balances not synced. Tap Sync Bank.");return;}
        BigDecimal usd=BigDecimal.ZERO,khr=BigDecimal.ZERO;int usable=0;
        for(Row row:rows){if("USD".equals(row.currency))usd=usd.add(row.remaining);else khr=khr.add(row.remaining);if(eligible(row))usable++;}
        balance.setText(money(usd,"USD")+" · "+money(khr,"KHR")+"\n"+usable+" eligible transfer(s) · oldest first · snapshot only");
        if(!bankMethod()){summary.setText("Choose a bank payment method to select transfers.");return;}
        if(rows.isEmpty()){summary.setText("No registered balance for this customer.");return;}
        for(Row row:rows){
            if(!eligible(row))continue;
            text(list,row.date+" · "+row.bank+"\n"+row.id+" · Remaining "+money(row.remaining,row.currency),14);
            if(!compatible(row)){text(list,"Unavailable: exchange rate missing or differs from approved rate.",12);continue;}
            BigDecimal allocated=selected.get(row.id);
            button(list,allocated==null?"Use transfer":"Edit "+money(allocated,row.currency),()->choose(row));
            if(allocated!=null)button(list,"Remove selection",()->{selected.remove(row.id);render();});
        }
        BigDecimal amount=BigDecimal.ZERO;
        for(Map.Entry<String,BigDecimal> e:selected.entrySet())amount=amount.add(equivalent(find(e.getKey()),e.getValue()));
        BigDecimal displayed=DraftPayment.round(amount,currency);
        String match=selected.isEmpty()?"Select a registered transfer.":displayed.compareTo(planned)==0?"Matches planned bank amount.":"Does not match planned bank amount.";
        summary.setText("Selected equivalent: "+money(displayed,currency)+" / "+money(planned,currency)+"\n"+match+
          (selected.size()>1?"\nMultiple-source admin pilot preview only.":"")+"\nNo funds reserved or debited.");
    }
}
