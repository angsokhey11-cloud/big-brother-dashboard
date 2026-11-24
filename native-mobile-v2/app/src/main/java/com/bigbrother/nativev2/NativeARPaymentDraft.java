package com.bigbrother.nativev2;

import android.app.Activity;
import android.app.AlertDialog;
import android.text.InputType;
import android.widget.*;
import org.json.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.function.BooleanSupplier;

/** Admin A/R payment preparation, following existing single/batch RPC contracts. No save calls. */
final class NativeARPaymentDraft {
    final Activity a;final CloudAuth api;final ExecutorService worker;final BooleanSupplier active;final ArrayList<JSONObject> rows;
    final LinkedHashMap<String,BigDecimal> needs=new LinkedHashMap<>();
    final String currency;final BigDecimal total;final boolean single;
    LinearLayout form,bankPanel,cashPanel;EditText amount,date,note,cashUSD,cashKHR,bank,tx,rate;Spinner method;
    TextView status;AlertDialog dialog;boolean closed,loading;int generation;
    JSONObject chosenBank;
    NativeARPaymentDraft(Activity a,CloudAuth api,ExecutorService worker,BooleanSupplier active,ArrayList<JSONObject> rows){
        this.a=a;this.api=api;this.worker=worker;this.active=active;this.rows=rows;single=rows.size()==1;currency=v(rows.get(0),"currency");
        BigDecimal t=BigDecimal.ZERO;
        for(JSONObject r:rows){BigDecimal n=new BigDecimal(v(r,"outstanding"));t=t.add(n);needs.merge(v(r,"customerId"),n,BigDecimal::add);}
        total=t;
    }
    String v(JSONObject j,String k){return InvoicePdf.value(j,k);}
    TextView text(LinearLayout p,String s){TextView t=new TextView(a);t.setText(s);p.addView(t);return t;}
    EditText field(LinearLayout p,String hint,boolean numeric){EditText e=new EditText(a);e.setHint(hint);e.setSingleLine(true);e.setInputType(numeric?InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_FLAG_DECIMAL:InputType.TYPE_CLASS_TEXT);p.addView(e);return e;}
    LinearLayout column(LinearLayout p){LinearLayout l=new LinearLayout(a);l.setOrientation(LinearLayout.VERTICAL);p.addView(l);return l;}
    Button button(LinearLayout p,String s,Runnable r){Button b=new Button(a);b.setAllCaps(false);b.setText(s);p.addView(b);b.setOnClickListener(w->r.run());return b;}
    void open(){
        if(!active.getAsBoolean())return;
        form=new LinearLayout(a);form.setOrientation(LinearLayout.VERTICAL);form.setPadding(18,12,18,12);
        text(form,rows.size()+" invoice(s) · "+currency+" "+total.toPlainString());
        for(JSONObject r:rows)text(form,v(r,"invoiceNo")+" · "+v(r,"customer")+" · "+v(r,"outstanding"));
        date=field(form,"Payment date YYYY-MM-DD",false);date.setText(LocalDate.now(java.time.ZoneId.of("Asia/Phnom_Penh")).toString());
        amount=field(form,"Amount in "+currency,true);amount.setText(total.toPlainString());amount.setEnabled(single);
        method=new Spinner(a);ArrayAdapter<String> methods=new ArrayAdapter<>(a,android.R.layout.simple_spinner_dropdown_item,new String[]{"Cash","Bank"});method.setAdapter(methods);form.addView(method);
        cashPanel=column(form);cashUSD=field(cashPanel,"Physical cash received USD",true);cashKHR=field(cashPanel,"Physical cash received KHR",true);
        bankPanel=column(form);button(bankPanel,"Refresh registered bank balances",this::wallet);
        status=text(bankPanel,"Select verified balance or enter Admin manual transaction.");
        bank=field(bankPanel,"Receiving bank",false);tx=field(bankPanel,"Transaction ID",false);rate=field(bankPanel,"Approved exchange rate (registered transfer)",true);rate.setEnabled(false);
        note=field(form,"Optional payment note",false);
        method.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener(){
            public void onNothingSelected(AdapterView<?> p){}
            public void onItemSelected(AdapterView<?> p,android.view.View v,int pos,long id){cashPanel.setVisibility(pos==0?0:8);bankPanel.setVisibility(pos==1?0:8);generation++;chosenBank=null;}
        });
        bankPanel.setVisibility(8);
        ScrollView scroll=new ScrollView(a);scroll.addView(form);
        dialog=new AlertDialog.Builder(a).setTitle("Admin payment · development preview").setView(scroll).setNegativeButton("Cancel",null).setPositiveButton("Validate draft",null).create();
        dialog.setOnDismissListener(d->{closed=true;generation++;});
        dialog.setOnShowListener(d->dialog.getButton(-1).setOnClickListener(w->preview()));dialog.show();
    }
    void wallet(){
        if(loading||closed||!active.getAsBoolean())return;
        loading=true;chosenBank=null;tx.setText("");bank.setText("");rate.setText("");status.setText("Loading live customer balances…");
        int token=++generation;
        worker.execute(()->{
            LinkedHashMap<String,LinkedHashMap<String,JSONObject>> grouped=new LinkedHashMap<>();boolean ok=false;
            try{
                for(String cid:needs.keySet()){
                    JSONArray list=api.receivableCustomerBank(cid);
                    for(int i=0;i<list.length();i++){
                        JSONObject row=list.getJSONObject(i);String cur=v(row,"currency"),inv=v(row,"invoice_currency");
                        if(!currency.equals(inv)||(!single&&!currency.equals(cur)))continue;
                        String id=v(row,"transaction_id").toUpperCase(Locale.ROOT);
                        grouped.computeIfAbsent(id,k->new LinkedHashMap<>()).put(cid,row);
                    }
                }ok=true;
            }catch(Exception ignored){}
            final boolean success=ok;
            a.runOnUiThread(()->{
                loading=false;if(closed||!active.getAsBoolean()||token!=generation)return;
                if(!success){status.setText("Could not refresh live balances.");return;}
                ArrayList<JSONObject> choices=new ArrayList<>();ArrayList<String> labels=new ArrayList<>();
                for(Map.Entry<String,LinkedHashMap<String,JSONObject>> e:grouped.entrySet()){
                    Map<String,JSONObject> per=e.getValue();if(!per.keySet().containsAll(needs.keySet()))continue;
                    JSONObject first=per.values().iterator().next();boolean sufficient=true;
                    try{
                        for(String cid:needs.keySet()){
                            JSONObject row=per.get(cid);
                            if(!single&&new BigDecimal(v(row,"remaining_amount")).compareTo(needs.get(cid))<0)sufficient=false;
                            if(!v(row,"bank_name").equals(v(first,"bank_name"))||!v(row,"received_date").equals(v(first,"received_date")))sufficient=false;
                        }
                        if(!sufficient)continue;
                        choices.add(first);labels.add(v(first,"transaction_id")+" · "+v(first,"currency")+" "+v(first,"remaining_amount")+" · "+v(first,"received_date"));
                    }catch(Exception ignored){}
                }
                status.setText(choices.size()+" eligible registered receipt(s)");
                if(choices.isEmpty())return;
                new AlertDialog.Builder(a).setTitle("Choose registered receipt").setItems(labels.toArray(new String[0]),(d,i)->{
                    if(closed||token!=generation||!active.getAsBoolean())return;
                    JSONObject r=choices.get(i);chosenBank=r;tx.setText(v(r,"transaction_id"));bank.setText(v(r,"bank_name"));rate.setText(v(r,"approved_exchange_rate"));
                    String received=v(r,"received_date");if(received.length()>=10)date.setText(received.substring(0,10));
                    if(single){
                        try{
                            BigDecimal rem=new BigDecimal(v(r,"remaining_amount")),fx=new BigDecimal(v(r,"approved_exchange_rate"));
                            BigDecimal equiv=DraftPayment.exchange(rem,v(r,"currency"),currency,fx);
                            amount.setText(total.min(equiv.setScale(DraftPayment.scale(currency),java.math.RoundingMode.DOWN)).toPlainString());
                        }catch(Exception ignored){}
                    }
                }).setNegativeButton("Cancel",null).show();
            });
        });
    }
    void preview(){
        try{
            if(!active.getAsBoolean()||loading)throw new IllegalArgumentException("Selection or wallet changed.");
            BigDecimal requested=single?DraftPayment.amount(amount.getText().toString()):total;
            if(requested.signum()<=0||requested.compareTo(total)>0||requested.stripTrailingZeros().scale()>DraftPayment.scale(currency))throw new IllegalArgumentException("Invalid amount.");
            String day=LocalDate.parse(date.getText().toString()).toString(),m=String.valueOf(method.getSelectedItem());
            boolean isBank="Bank".equals(m);
            BigDecimal usd=isBank?BigDecimal.ZERO:DraftPayment.amount(cashUSD.getText().toString()),khr=isBank?BigDecimal.ZERO:DraftPayment.amount(cashKHR.getText().toString());
            if(!isBank&&(usd.signum()<0||khr.signum()<0||usd.add(khr).signum()<=0))throw new IllegalArgumentException("Enter physical cash received.");
            String transaction=tx.getText().toString().trim(),bankName=bank.getText().toString().trim();
            if(isBank&&(transaction.isEmpty()||bankName.isEmpty()))throw new IllegalArgumentException("Bank and transaction ID required.");
            JSONObject payload=new JSONObject().put("paymentDate",day).put("paymentMethod",m).put("bankPayment",isBank?bankName:"").put("transactionId",isBank?transaction:"").put("bankReference","").put("physicalCashUSD",usd).put("physicalCashKHR",khr).put("note",note.getText().toString().trim());
            if(single){JSONObject r=rows.get(0);payload.put("invoiceId",v(r,"invoiceId")).put("invoiceNo",v(r,"invoiceNo")).put("customerId",v(r,"customerId")).put("amount",requested);}
            else{JSONArray ids=new JSONArray(),nos=new JSONArray();for(JSONObject r:rows){ids.put(v(r,"invoiceId"));nos.put(v(r,"invoiceNo"));}payload.put("invoiceIds",ids).put("invoiceNos",nos).put("customerId",needs.size()==1?needs.keySet().iterator().next():"");}
            if(isBank&&chosenBank!=null){
                if(!transaction.equals(v(chosenBank,"transaction_id")))throw new IllegalArgumentException("Refresh registered bank selection.");
                if(single){BigDecimal fx=new BigDecimal(v(chosenBank,"approved_exchange_rate"));BigDecimal rem=DraftPayment.exchange(new BigDecimal(v(chosenBank,"remaining_amount")),v(chosenBank,"currency"),currency,fx);if(requested.compareTo(rem)>0)throw new IllegalArgumentException("Insufficient registered balance.");payload.put("exchangeRate",fx);}
            }
            String endpoint=single?"bb_ar_receive_payment_v2":"bb_ar_receive_batch_payment_v2";
            String fingerprint=InvoiceSaveJournal.digest(new JSONObject().put("p_payload",payload).toString());
            new AlertDialog.Builder(a).setTitle("Admin payment preview").setMessage(currency+" "+requested.toPlainString()+" · "+m+"\n"+day+"\n"+endpoint+"\nFingerprint "+fingerprint.substring(0,16)+"…\nNo payment submitted.").setPositiveButton("Close",null).show();
        }catch(Exception e){Toast.makeText(a,e instanceof IllegalArgumentException?e.getMessage():"Check payment details.",Toast.LENGTH_LONG).show();}
    }
}
