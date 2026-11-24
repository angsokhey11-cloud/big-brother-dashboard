package com.bigbrother.nativev2;

import android.app.Activity;
import android.graphics.Color;
import android.text.InputType;
import android.widget.*;
import android.view.View;
import org.json.*;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.function.BooleanSupplier;

/** Online-only draft prototype. No stock, invoice or payment writes. */
final class NativeInvoiceDraft {
    private final Activity a;private final LinearLayout root;private final CloudAuth api;
    private final ExecutorService worker;private final BooleanSupplier active;
    private JSONArray locations,products,batches;
    private JSONObject location,batch,customer,prices;
    private boolean busy,customersReady;
    private int generation;
    private TextView status,number,customerLabel,total;
    private EditText date,productQuery;
    private Spinner locationPicker,batchPicker,currency;
    private LinearLayout customerBox,productBox,linesBox;
    private final ArrayList<Line> lines=new ArrayList<>();
    private static final int BLUE=Color.rgb(23,74,145);
    private static class Line{
        String code,name,unit,currency;BigDecimal qty,price;
        Line(String c,String n,String u,String curr,BigDecimal q,BigDecimal p){code=c;name=n;unit=u;currency=curr;qty=q;price=p;}
    }
    NativeInvoiceDraft(Activity a,LinearLayout root,CloudAuth api,ExecutorService worker,BooleanSupplier active){
        this.a=a;this.root=root;this.api=api;this.worker=worker;this.active=active;
    }
    private TextView text(LinearLayout p,String value,int size){
        TextView t=new TextView(a);t.setText(value);t.setTextSize(size);t.setTextColor(BLUE);t.setPadding(0,8,0,8);p.addView(t);return t;
    }
    private Button button(LinearLayout p,String title,Runnable action){
        Button b=new Button(a);b.setAllCaps(false);b.setText(title);p.addView(b);b.setOnClickListener(v->action.run());return b;
    }
    private EditText field(LinearLayout p,String hint,int type){
        EditText e=new EditText(a);e.setSingleLine(true);e.setHint(hint);e.setInputType(type);p.addView(e);return e;
    }
    private LinearLayout column(LinearLayout p){
        LinearLayout l=new LinearLayout(a);l.setOrientation(LinearLayout.VERTICAL);p.addView(l);return l;
    }
    private void choices(Spinner spinner,ArrayList<String> names){
        ArrayAdapter<String> ad=new ArrayAdapter<>(a,android.R.layout.simple_spinner_item,names);
        ad.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);spinner.setAdapter(ad);
    }
    private static String val(JSONObject j,String key){return InvoicePdf.value(j,key);}
    private static String first(JSONObject j,String... keys){return InvoicePdf.first(j,keys);}
    private static boolean enabled(JSONObject j){return "true".equalsIgnoreCase(j.optString("active"));}
    private static JSONArray activeRows(JSONArray raw,String... keys){
        JSONArray out=new JSONArray();
        if(raw!=null)for(int i=0;i<raw.length();i++){
            JSONObject row=raw.optJSONObject(i);if(row!=null&&enabled(row)&&!first(row,keys).isEmpty())out.put(row);
        }
        return out;
    }
    void open(){
        text(root,"Draft preview only — Complete is not enabled. No accounting records will change.",14);
        status=text(root,"Loading invoice master data…",14);
        button(root,"Reload master data",this::load);
        number=text(root,"Invoice No. —",16);
        date=field(root,"Selling date (YYYY-MM-DD)",InputType.TYPE_CLASS_DATETIME|InputType.TYPE_DATETIME_VARIATION_DATE);
        date.setText(java.time.LocalDate.now(java.time.ZoneId.of("Asia/Phnom_Penh")).toString());
        text(root,"Batch / Direct Sale",15);batchPicker=new Spinner(a);root.addView(batchPicker);
        text(root,"Main Location",15);locationPicker=new Spinner(a);root.addView(locationPicker);
        text(root,"Currency",15);currency=new Spinner(a);root.addView(currency);
        choices(currency,new ArrayList<>(java.util.Arrays.asList("USD","KHR")));
        currency.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener(){
            public void onNothingSelected(android.widget.AdapterView<?> p){}
            public void onItemSelected(android.widget.AdapterView<?> p,View v,int pos,long id){
                if(!lines.isEmpty()&&!lines.get(0).currency.equals(curr())){lines.clear();renderLines();status.setText("Currency changed. Draft lines cleared; enter prices in the new currency.");}
            }
        });
        button(root,"Apply batch and location",this::apply);
        customerLabel=text(root,"Customer: select batch / location first",15);
        customerBox=column(root);
        text(root,"Products",18);
        productQuery=field(root,"Search product name, code or barcode",InputType.TYPE_CLASS_TEXT);
        button(root,"Search products",this::renderProducts);
        productBox=column(root);
        text(root,"Invoice Items",18);linesBox=column(root);
        total=text(root,"Draft subtotal —",18);
        Button complete=button(root,"Complete — migration pending",()->{});complete.setEnabled(false);
        load();
    }
    private String curr(){return currency.getSelectedItem()==null?"USD":currency.getSelectedItem().toString();}
    private void load(){
        if(busy)return;
        busy=true;status.setText("Loading invoice master data…");
        worker.execute(()->{
            try{
                JSONObject data=api.generatorBootstrap(),open=api.generatorBatches();
                if(!Boolean.TRUE.equals(data.opt("success"))||data.optJSONArray("products")==null||data.optJSONArray("locations")==null||open.optJSONArray("batches")==null)throw new IllegalStateException();
                a.runOnUiThread(()->{if(!active.getAsBoolean())return;busy=false;
                    locations=activeRows(data.optJSONArray("locations"),"locationCode","code");
                    products=activeRows(data.optJSONArray("products"),"code");
                    batches=new JSONArray();JSONArray list=open.optJSONArray("batches");
                    ArrayList<String> names=new ArrayList<>();names.add("No Batch / Direct Sale");
                    for(int i=0;i<list.length();i++){
                        JSONObject x=list.optJSONObject(i);if(x==null||val(x,"batchId").isEmpty()||java.util.Arrays.asList("CLOSED","CANCELLED","CANCELED").contains(val(x,"status").toUpperCase(Locale.ROOT)))continue;
                        batches.put(x);names.add(val(x,"batchId")+" · "+val(x,"locationName")+" · "+val(x,"batchDate"));
                    }
                    choices(batchPicker,names);ArrayList<String> locs=new ArrayList<>();locs.add("Select location");
                    for(int i=0;i<locations.length();i++){JSONObject x=locations.optJSONObject(i);locs.add(first(x,"locationName","name")+" · "+first(x,"locationCode","code"));}
                    choices(locationPicker,locs);reset();status.setText("Master data loaded. Apply batch and location.");
                });
            }catch(Exception e){a.runOnUiThread(()->{if(active.getAsBoolean()){busy=false;status.setText("Master data unavailable — retry.");}});}
        });
    }
    private void reset(){generation++;location=null;batch=null;customer=null;prices=null;customersReady=false;lines.clear();customerBox.removeAllViews();productBox.removeAllViews();customerLabel.setText("Customer: not selected");number.setText("Invoice No. —");renderLines();}
    private boolean sameScope(){
        if(location==null)return false;
        int bi=batchPicker.getSelectedItemPosition(),li=locationPicker.getSelectedItemPosition();
        if(batch!=null)return bi>0&&batches!=null&&batches.optJSONObject(bi-1)==batch;
        return bi==0&&li>0&&locations!=null&&locations.optJSONObject(li-1)==location;
    }
    private void apply(){
        if(busy||locations==null||batches==null)return;
        if(!lines.isEmpty()){new android.app.AlertDialog.Builder(a).setTitle("Change batch / location?").setMessage("Current draft items will be cleared.").setNegativeButton("Cancel",null).setPositiveButton("Apply",(d,w)->applyScope()).show();return;}
        applyScope();
    }
    private void applyScope(){
        int bi=batchPicker.getSelectedItemPosition(),li=locationPicker.getSelectedItemPosition();
        JSONObject selected=bi>0?batches.optJSONObject(bi-1):null;
        JSONObject loc=li>0?locations.optJSONObject(li-1):null;
        if(selected!=null){
            loc=null;for(int i=0;i<locations.length();i++){JSONObject x=locations.optJSONObject(i);if(val(selected,"locationCode").equals(first(x,"locationCode","code"))){loc=x;locationPicker.setSelection(i+1);break;}}
        }
        if(loc==null){status.setText("Select a valid main location.");return;}
        reset();location=loc;batch=selected;busy=true;
        String code=first(loc,"locationCode","code"),id=selected==null?"":val(selected,"batchId");
        int request=++generation;status.setText("Loading customers and invoice number…");
        worker.execute(()->{
            try{
                JSONObject data=api.generatorCustomers(code),seq=api.generatorNumber(id);
                JSONArray rows=data.getJSONArray("customers");String no=val(seq,"invoiceNo");
                if(no.isEmpty())throw new IllegalStateException();
                a.runOnUiThread(()->{if(!active.getAsBoolean()||request!=generation)return;busy=false;customersReady=true;number.setText("Invoice No. "+no+" (suggested)");
                    EditText search=field(customerBox,"Search customer in selected location",InputType.TYPE_CLASS_TEXT);
                    LinearLayout results=column(customerBox);
                    button(customerBox,"Find customer",()->{
                        results.removeAllViews();if(!sameScope()){status.setText("Apply changed batch / location first.");return;}
                        String q=search.getText().toString().trim().toLowerCase(Locale.ROOT);int shown=0;
                        for(int i=0;i<rows.length()&&shown<30;i++){
                            JSONObject row=rows.optJSONObject(i);if(row==null||val(row,"customerId").isEmpty()||val(row,"name").isEmpty())continue;
                            if(!(val(row,"name")+" "+val(row,"customerId")+" "+val(row,"phone")).toLowerCase(Locale.ROOT).contains(q))continue;
                            shown++;button(results,val(row,"name")+" · "+val(row,"customerId"),()->selectCustomer(row));
                        }
                        if(shown==0)text(results,"No customers found",14);
                    });
                    status.setText("Select customer. Stock source and payment submission are not yet enabled.");
                });
            }catch(Exception e){a.runOnUiThread(()->{if(active.getAsBoolean()&&request==generation){busy=false;status.setText("Could not load customers / invoice number. Apply again.");}});}
        });
    }
    private void selectCustomer(JSONObject row){
        if(busy||!sameScope())return;
        if(!lines.isEmpty()){new android.app.AlertDialog.Builder(a).setTitle("Change customer?").setMessage("Current draft items will be cleared.").setNegativeButton("Cancel",null).setPositiveButton("Change",(d,w)->loadPrices(row)).show();return;}
        loadPrices(row);
    }
    private void loadPrices(JSONObject row){
        if(busy||!sameScope())return;
        customer=row;prices=null;lines.clear();renderLines();customerLabel.setText("Customer: "+val(row,"name"));busy=true;
        status.setText("Loading customer prices…");int request=++generation;
        worker.execute(()->{
            JSONObject result=null;try{result=api.generatorPrices(val(row,"customerId")).optJSONObject("prices");}catch(Exception ignored){}
            final JSONObject fresh=result;
            a.runOnUiThread(()->{if(!active.getAsBoolean()||request!=generation)return;busy=false;prices=fresh;status.setText(prices==null?"Customer prices unavailable. Manual draft prices only.":"Customer prices loaded. Verify price and quantity.");renderProducts();});
        });
    }
    private void renderProducts(){
        productBox.removeAllViews();if(busy||!customersReady||customer==null||!sameScope()){status.setText("Apply batch and select customer first.");return;}
        String q=productQuery.getText().toString().trim().toLowerCase(Locale.ROOT);int shown=0;
        for(int i=0;i<products.length()&&shown<30;i++){
            JSONObject p=products.optJSONObject(i);String code=val(p,"code"),name=val(p,"name");
            if(code.isEmpty()||name.isEmpty()||!(name+" "+code+" "+first(p,"productBarcode","barcode")).toLowerCase(Locale.ROOT).contains(q))continue;
            shown++;button(productBox,name+" · "+val(p,"unit"),()->editLine(p));
        }
        if(shown==0)text(productBox,"No matching products",14);
    }
    private void editLine(JSONObject p){
        if(!sameScope()||busy||customer==null)return;
        String code=val(p,"code"),unit=val(p,"unit"),current=curr();
        if(batch!=null){
            String from=val(batch,"sellingDateFrom"),to=val(batch,"sellingDateTo"),d=date.getText().toString().trim();
            try{java.time.LocalDate selected=java.time.LocalDate.parse(d);
                if(from.isEmpty()||to.isEmpty()||selected.isBefore(java.time.LocalDate.parse(from.substring(0,10)))||selected.isAfter(java.time.LocalDate.parse(to.substring(0,10))))throw new IllegalArgumentException();
            }catch(Exception e){status.setText("Selling date must be inside the assigned batch date range.");return;}
        }
        LinearLayout form=new LinearLayout(a);form.setOrientation(LinearLayout.VERTICAL);form.setPadding(24,12,24,12);
        text(form,"Base unit: "+unit+" · Draft only; available stock not yet verified",13);
        EditText qty=field(form,"Quantity",InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_FLAG_DECIMAL);
        EditText price=field(form,"Unit price ("+current+")",InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_FLAG_DECIMAL);
        JSONObject specific=prices==null?null:prices.optJSONObject(code);
        if("USD".equals(current)&&specific!=null&&!val(specific,"priceUSD").isEmpty())price.setText(val(specific,"priceUSD"));
        android.app.AlertDialog dialog=new android.app.AlertDialog.Builder(a).setTitle(val(p,"name")).setView(form).setNegativeButton("Cancel",null).setPositiveButton("Add item",null).create();
        dialog.setOnShowListener(d->dialog.getButton(-1).setOnClickListener(v->{
            try{
                if(!sameScope()||!current.equals(curr()))throw new IllegalStateException();
                BigDecimal q=new BigDecimal(qty.getText().toString().trim().replace(',','.')),u=new BigDecimal(price.getText().toString().trim().replace(',','.'));
                if(q.signum()<=0||u.signum()<0||q.scale()>4||u.scale()>4||q.compareTo(new BigDecimal("1000000"))>0||u.compareTo(new BigDecimal("1000000"))>0)throw new IllegalArgumentException();
                lines.add(new Line(code,val(p,"name"),unit,current,q,u));renderLines();dialog.dismiss();
            }catch(Exception e){qty.setError("Enter valid positive quantity and nonnegative price (max 4 decimals).");}
        }));dialog.show();
    }
    private void renderLines(){
        if(linesBox==null)return;
        linesBox.removeAllViews();BigDecimal sum=BigDecimal.ZERO;
        for(Line row:new ArrayList<>(lines)){
            BigDecimal amount=row.qty.multiply(row.price);sum=sum.add(amount);
            text(linesBox,row.name+" · "+row.qty.toPlainString()+" "+row.unit+" × "+row.price.toPlainString()+" = "+amount.stripTrailingZeros().toPlainString(),15);
            button(linesBox,"Remove "+row.name,()->{lines.remove(row);renderLines();});
        }
        total.setText("Draft subtotal: "+curr()+" "+sum.setScale("KHR".equals(curr())?0:2,RoundingMode.HALF_UP).toPlainString()+" · unverified");
    }
}
