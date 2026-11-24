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
    private JSONArray locations,products,batches,sellingUnits,warehouse;
    private JSONObject location,batch,customer,prices;
    private boolean busy,customersReady;
    private int generation;
    private TextView status,customerLabel,total;
    private EditText number;
    private TextView preflightResult,recoveryStatus,duePreview;
    private String draftId="",settlementRequestId="";
    private EditText dueOverride;
    private boolean recoveryChecking;
    private boolean checkingDraft;
    private EditText date,productQuery,rateInput,discountInput,partialInput,cashInput,bankInput,actualBankInput;
    private Spinner discountMode,paymentMethod,bankCurrency;
    private TextView paymentSummary,exchangeSummary,bankSummary;
    private NativeBankDraft bankDraft;
    private String lastCurrency;
    private boolean resettingPayment;
    private Spinner locationPicker,batchPicker,currency;
    private LinearLayout customerBox,productBox,linesBox;
    private final ArrayList<Line> lines=new ArrayList<>();
    private static final int BLUE=Color.rgb(23,74,145);
    private static class Line{
        String code,name,unit,currency,baseUnit,sellingUnit,barcode,lineId;boolean group;BigDecimal qty,price,factor,purchased,zero;
        Line(String c,String n,String u,String curr,BigDecimal q,BigDecimal p,BigDecimal f,BigDecimal purchased,BigDecimal zero,String baseUnit,String sellingUnit,String barcode,boolean group){code=c;name=n;unit=u;currency=curr;qty=q;price=p;factor=f;this.purchased=purchased;this.zero=zero;this.baseUnit=baseUnit;this.sellingUnit=sellingUnit;this.barcode=barcode;this.group=group;lineId=java.util.UUID.randomUUID().toString();}
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
        number=field(root,"Invoice No. (INV-...)",InputType.TYPE_CLASS_TEXT);
        date=field(root,"Selling date (YYYY-MM-DD)",InputType.TYPE_CLASS_DATETIME|InputType.TYPE_DATETIME_VARIATION_DATE);
        date.setText(java.time.LocalDate.now(java.time.ZoneId.of("Asia/Phnom_Penh")).toString());
        duePreview=text(root,"Due date: select customer",14);
        dueOverride=field(root,"Override due date (YYYY-MM-DD), optional",InputType.TYPE_CLASS_TEXT);
        text(root,"Batch / Direct Sale",15);batchPicker=new Spinner(a);root.addView(batchPicker);
        text(root,"Main Location",15);locationPicker=new Spinner(a);root.addView(locationPicker);
        text(root,"Currency",15);currency=new Spinner(a);root.addView(currency);
        choices(currency,new ArrayList<>(java.util.Arrays.asList("USD","KHR")));
        currency.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener(){
            public void onNothingSelected(android.widget.AdapterView<?> p){}
            public void onItemSelected(android.widget.AdapterView<?> p,View v,int pos,long id){
                if(lastCurrency!=null&&!lastCurrency.equals(curr())){
                    lines.clear();clearPayment();renderLines();renderProducts();
                    status.setText("Currency changed. Draft items and payment amounts cleared.");
                }
                lastCurrency=curr();
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
        paymentPanel();
        preflightResult=text(root,"Read-only checks; no invoice will be submitted.",14);
        button(root,"Validate draft against server",this::preflight);
        button(root,"Prepare invoice payload preview",this::previewPayload);
        recoveryStatus=text(root,"Recovery journal: not checked",14);
        button(root,"Check previous invoice save",this::checkRecovery);
        checkRecovery();
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
                    sellingUnits=data.optJSONArray("sellingUnits");
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
    private void reset(){generation++;draftId="";settlementRequestId="";dueOverride.setText("");location=null;batch=null;customer=null;prices=null;warehouse=null;customersReady=false;lines.clear();customerBox.removeAllViews();productBox.removeAllViews();customerLabel.setText("Customer: not selected");number.setText("");if(bankDraft!=null)bankDraft.customer("");clearPayment();renderLines();}
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
                JSONObject stock=id.isEmpty()?api.generatorWarehouse():null;
                if(stock!=null&&(!Boolean.TRUE.equals(stock.opt("success"))||stock.optJSONArray("balances")==null))throw new IllegalStateException("Warehouse balances unavailable");
                final JSONArray balances=stock==null?null:stock.getJSONArray("balances");
                JSONArray rows=data.getJSONArray("customers");String no=val(seq,"invoiceNo");
                if(no.isEmpty())throw new IllegalStateException();
                a.runOnUiThread(()->{if(!active.getAsBoolean()||request!=generation)return;busy=false;warehouse=balances;customersReady=true;number.setText(no);
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
                    status.setText("Select customer. Stock snapshot loaded; payment submission remains disabled.");
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
        customer=row;draftId="";dueOverride.setText("");prices=null;lines.clear();if(bankDraft!=null)bankDraft.customer(val(row,"customerId"));clearPayment();renderLines();customerLabel.setText("Customer: "+val(row,"name"));busy=true;
        status.setText("Loading customer prices…");int request=++generation;
        worker.execute(()->{
            JSONObject result=null;try{result=api.generatorPrices(val(row,"customerId")).optJSONObject("prices");}catch(Exception ignored){}
            final JSONObject fresh=result;
            a.runOnUiThread(()->{if(!active.getAsBoolean()||request!=generation)return;busy=false;prices=fresh;status.setText(prices==null?"Customer prices unavailable. Manual draft prices only.":"Customer prices loaded. Verify price and quantity.");renderProducts();});
        });
    }
    private static boolean tracked(JSONObject p){
        return !"SERVICE".equalsIgnoreCase(val(p,"itemType"))&&!"false".equalsIgnoreCase(val(p,"trackStock"));
    }
    private BigDecimal[] available(String code){
        JSONArray rows=batch==null?warehouse:batch.optJSONArray("exactItems");
        if(rows==null)return null;
        for(int i=0;i<rows.length();i++){
            JSONObject row=rows.optJSONObject(i);if(row==null||!code.equals(val(row,"productCode")))continue;
            String p=batch==null?val(row,"purchasedAvailable"):first(row,"purchasedPendingQty","purchasedRemainingQty");
            String z=batch==null?val(row,"zeroCostAvailable"):first(row,"zeroCostPendingQty","zeroCostRemainingQty");
            try{
                BigDecimal purchased=new BigDecimal(p),zero=new BigDecimal(z);
                if(purchased.signum()<0||zero.signum()<0)return null;
                for(Line line:lines)if(!line.group&&code.equals(line.code)){purchased=purchased.subtract(line.purchased);zero=zero.subtract(line.zero);}
                if(purchased.signum()<0||zero.signum()<0)return null;
                return new BigDecimal[]{purchased,zero};
            }catch(Exception e){return null;}
        }
        return null;
    }
    private String plain(BigDecimal n){return n.stripTrailingZeros().toPlainString();}
    private BigDecimal quantity(EditText field){return new BigDecimal(field.getText().toString().trim().replace(',','.'));}
    private BigDecimal groupAvailable(String code){
        if(batch==null)return null;
        JSONArray rows=batch.optJSONArray("groupItems");if(rows==null)return null;
        JSONObject found=null;
        for(int i=0;i<rows.length();i++){JSONObject row=rows.optJSONObject(i);if(row!=null&&code.equals(val(row,"groupCode"))){if(found!=null)return null;found=row;}}
        if(found==null)return null;
        try{
            BigDecimal n=new BigDecimal(first(found,"remainingQty","issuedQty"));
            for(Line line:lines)if(line.group&&code.equals(line.code))n=n.subtract(line.qty.multiply(line.factor));
            return n.signum()<0?null:n;
        }catch(Exception e){return null;}
    }
    private void renderProducts(){
        productBox.removeAllViews();if(busy||!customersReady||customer==null||!sameScope()){status.setText("Apply batch and select customer first.");return;}
        String q=productQuery.getText().toString().trim().toLowerCase(Locale.ROOT);int shown=0;
        if(batch!=null){
            JSONArray groups=batch.optJSONArray("groupItems");
            if(groups!=null)for(int i=0;i<groups.length()&&shown<30;i++){
                JSONObject g=groups.optJSONObject(i);if(g==null)continue;
                String code=val(g,"groupCode"),name=val(g,"groupName");
                if(code.isEmpty()||name.isEmpty()||!(name+" "+code).toLowerCase(Locale.ROOT).contains(q))continue;
                BigDecimal n=groupAvailable(code);if(n==null||n.signum()<=0)continue;
                try{
                    JSONObject entry=new JSONObject().put("code",code).put("name",name).put("unit",val(g,"unit")).put("entryType","GROUP");
                    shown++;button(productBox,name+" · Group · Available "+plain(n),()->editLine(entry));
                }catch(JSONException ignored){}
            }
        }
        for(int i=0;i<products.length()&&shown<30;i++){
            JSONObject p=products.optJSONObject(i);String code=val(p,"code"),name=val(p,"name");
            if(code.isEmpty()||name.isEmpty()||!(name+" "+code+" "+first(p,"productBarcode","barcode")).toLowerCase(Locale.ROOT).contains(q))continue;
            BigDecimal[] stock=tracked(p)?available(code):null;
            if(tracked(p)&&(stock==null||stock[0].add(stock[1]).signum()<=0))continue;
            shown++;button(productBox,name+" · "+val(p,"unit")+(stock==null?"":" · Available "+plain(stock[0].add(stock[1]))),()->editLine(p));
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
        final boolean group="GROUP".equals(val(p,"entryType"));
        final boolean tracks=!group&&tracked(p);
        final BigDecimal[] stock=tracks?available(code):null;
        if(tracks&&(stock==null||stock[0].add(stock[1]).signum()<=0)){status.setText("Exact stock source balances unavailable or exhausted.");return;}
        LinearLayout form=new LinearLayout(a);form.setOrientation(LinearLayout.VERTICAL);form.setPadding(24,12,24,12);
        text(form,"Base unit: "+unit+(group?" · Group balance "+plain(groupAvailable(code)):""),13);
        ArrayList<String> names=new ArrayList<>(),unitNames=new ArrayList<>();ArrayList<BigDecimal> factors=new ArrayList<>();
        names.add(unit.isEmpty()?"Unit":unit);unitNames.add(unit.isEmpty()?"Unit":unit);factors.add(BigDecimal.ONE);
        if(sellingUnits!=null)for(int i=0;i<sellingUnits.length();i++){
            JSONObject u=sellingUnits.optJSONObject(i);
            if(u==null||!(group?"GROUP":"PRODUCT").equalsIgnoreCase(val(u,"targetType"))||!code.equals(val(u,"targetCode")))continue;
            try{
                BigDecimal factor=new BigDecimal(val(u,"baseQty"));String n=val(u,"sellingUnitName");
                if(factor.compareTo(BigDecimal.ONE)>0&&!n.isEmpty()){
                    names.add(n+" (1 = "+plain(factor)+" "+unit+")");unitNames.add(n);factors.add(factor);
                }
            }catch(Exception ignored){}
        }
        Spinner units=new Spinner(a);form.addView(units);choices(units,names);
        EditText qty=field(form,"Selling quantity",InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_FLAG_DECIMAL);
        EditText price=field(form,"Price per selected selling unit ("+current+")",InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_FLAG_DECIMAL);
        JSONObject specific=prices==null?null:prices.optJSONObject(code);
        final String basePrice=!group&&specific!=null?val(specific,"USD".equals(current)?"priceUSD":"priceKHR"):"";
        final EditText purchased,zero;
        if(tracks){
            text(form,"Stock source in base units · Purchased "+plain(stock[0])+" / Zero-Cost "+plain(stock[1]),13);
            purchased=field(form,"Purchased base quantity",InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_FLAG_DECIMAL);
            zero=field(form,"Zero-Cost base quantity",InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_FLAG_DECIMAL);
            purchased.setText("0");zero.setText("0");
        }else{purchased=null;zero=null;}
        Runnable allocate=()->{
            if(!tracks)return;
            try{
                BigDecimal q=quantity(qty).multiply(factors.get(units.getSelectedItemPosition()));
                if(q.signum()<0)return;
                BigDecimal z=q.min(stock[1]);zero.setText(plain(z));purchased.setText(plain(q.subtract(z)));
            }catch(Exception ignored){}
        };
        units.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener(){
            public void onNothingSelected(AdapterView<?> p){}
            public void onItemSelected(AdapterView<?> p,View v,int pos,long id){
                if(!basePrice.isEmpty())try{price.setText(plain(new BigDecimal(basePrice).multiply(factors.get(pos))));}catch(Exception e){price.setText("");}
                else price.setText("");
                allocate.run();
            }
        });
        qty.addTextChangedListener(new android.text.TextWatcher(){
            public void beforeTextChanged(CharSequence s,int st,int count,int after){}
            public void onTextChanged(CharSequence s,int st,int before,int count){allocate.run();}
            public void afterTextChanged(android.text.Editable e){}
        });
        android.app.AlertDialog dialog=new android.app.AlertDialog.Builder(a).setTitle(val(p,"name")).setView(form).setNegativeButton("Cancel",null).setPositiveButton("Add item",null).create();
        dialog.setOnShowListener(d->dialog.getButton(-1).setOnClickListener(v->{
            try{
                if(!sameScope()||!current.equals(curr()))throw new IllegalStateException();
                BigDecimal q=quantity(qty),u=quantity(price),factor=factors.get(units.getSelectedItemPosition());
                if(q.signum()<=0||u.signum()<0||q.scale()>4||u.scale()>4||q.compareTo(new BigDecimal("1000000"))>0||u.compareTo(new BigDecimal("1000000"))>0)throw new IllegalArgumentException();
                BigDecimal base=q.multiply(factor),pQty=BigDecimal.ZERO,zQty=BigDecimal.ZERO;
                if(group){BigDecimal remaining=groupAvailable(code);if(remaining==null||base.compareTo(remaining)>0){qty.setError("Group quantity exceeds current draft availability.");return;}}
                if(tracks){
                    pQty=quantity(purchased);zQty=quantity(zero);BigDecimal[] fresh=available(code);
                    if(fresh==null||pQty.signum()<0||zQty.signum()<0||pQty.compareTo(fresh[0])>0||zQty.compareTo(fresh[1])>0||pQty.add(zQty).compareTo(base)!=0){
                        purchased.setError("Source total must equal "+plain(base)+" base units and not exceed available stock.");return;
                    }
                }
                lines.add(new Line(code,val(p,"name"),names.get(units.getSelectedItemPosition()),current,q,u,factor,pQty,zQty,unit,unitNames.get(units.getSelectedItemPosition()),first(p,"productBarcode","barcode"),group));renderLines();renderProducts();dialog.dismiss();
            }catch(Exception e){qty.setError("Enter valid positive quantity and nonnegative price (max 4 decimals).");}
        }));dialog.show();
    }
    private Spinner select(String... values){
        Spinner p=new Spinner(a);root.addView(p);choices(p,new ArrayList<>(java.util.Arrays.asList(values)));return p;
    }
    private void observe(EditText field){
        field.addTextChangedListener(new android.text.TextWatcher(){
            public void beforeTextChanged(CharSequence s,int start,int count,int after){}
            public void onTextChanged(CharSequence s,int start,int before,int count){updatePayment();}
            public void afterTextChanged(android.text.Editable e){}
        });
    }
    private void observe(Spinner spinner){
        spinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener(){
            public void onNothingSelected(AdapterView<?> p){}
            public void onItemSelected(AdapterView<?> p,View v,int pos,long id){updatePayment();}
        });
    }
    private void paymentPanel(){
        text(root,"Discount & Payment",18);
        int numeric=InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_FLAG_DECIMAL;
        rateInput=field(root,"Daily exchange rate: 1 USD = ? KHR",numeric);
        discountMode=select("Fixed amount","Percentage");
        discountInput=field(root,"Discount",numeric);
        paymentMethod=select("Cash","Bank","Credit","Partially Paid in Cash","Partially Paid in Bank","Cash + Bank");
        partialInput=field(root,"Partial payment (invoice currency)",numeric);
        cashInput=field(root,"Cash amount (invoice currency)",numeric);
        bankInput=field(root,"Bank amount (invoice currency)",numeric);
        bankCurrency=select("USD","KHR");
        actualBankInput=field(root,"Actual bank amount (selected bank currency)",numeric);
        paymentSummary=text(root,"",16);exchangeSummary=text(root,"",14);bankSummary=text(root,"",14);
        bankDraft=new NativeBankDraft(a,root,api,worker,active);
        observe(date);observe(dueOverride);
        for(EditText f:new EditText[]{rateInput,discountInput,partialInput,cashInput,bankInput,actualBankInput})observe(f);
        for(Spinner p:new Spinner[]{discountMode,paymentMethod,bankCurrency})observe(p);
        updatePayment();
    }
    private void clearPayment(){
        if(paymentSummary==null)return;
        resettingPayment=true;
        if(bankDraft!=null)bankDraft.clear();
        for(EditText f:new EditText[]{discountInput,partialInput,cashInput,bankInput,actualBankInput})f.setText("");
        resettingPayment=false;updatePayment();
    }
    private String money(BigDecimal n,String currency){
        return currency+" "+DraftPayment.round(n,currency).toPlainString();
    }
    private void updatePayment(){
        if(paymentSummary==null||resettingPayment)return;
        try{duePreview.setText(customer==null?"Due date: select customer":"Due date: "+dueDate());}catch(Exception e){duePreview.setText("Due date: invalid date");}
        String method=String.valueOf(paymentMethod.getSelectedItem()),cur=curr();
        boolean partial=method.startsWith("Partially"),split="Cash + Bank".equals(method);
        boolean bank=split||"Bank".equals(method)||"Partially Paid in Bank".equals(method);
        partialInput.setVisibility(partial?View.VISIBLE:View.GONE);
        cashInput.setVisibility(split?View.VISIBLE:View.GONE);bankInput.setVisibility(split?View.VISIBLE:View.GONE);
        bankCurrency.setVisibility(bank?View.VISIBLE:View.GONE);actualBankInput.setVisibility(bank?View.VISIBLE:View.GONE);
        exchangeSummary.setText("");bankSummary.setText("");
        BigDecimal subtotal=BigDecimal.ZERO;for(Line line:lines)subtotal=subtotal.add(line.qty.multiply(line.price));
        BigDecimal bankPlanned=BigDecimal.ZERO,bankRate=BigDecimal.ZERO;
        try{
            DraftPayment.Totals t=DraftPayment.calculate(subtotal,cur,discountMode.getSelectedItemPosition()==1,
                DraftPayment.amount(discountInput.getText().toString()),method,
                partial?DraftPayment.amount(partialInput.getText().toString()):BigDecimal.ZERO,
                split?DraftPayment.amount(cashInput.getText().toString()):BigDecimal.ZERO,
                split?DraftPayment.amount(bankInput.getText().toString()):BigDecimal.ZERO);
            paymentSummary.setText("Discount: "+money(t.discount,cur)+"\nGrand Total: "+money(t.grand,cur)+"\nAmount Paid: "+money(t.paid,cur)+"\nCredit Amount: "+money(t.outstanding,cur));
            bankPlanned=t.bank;
            BigDecimal rate=DraftPayment.amount(rateInput.getText().toString());bankRate=rate;
            if(rate.compareTo(BigDecimal.ONE)>0){
                String other="USD".equals(cur)?"KHR":"USD";
                exchangeSummary.setText("Exchange equivalent: "+money(DraftPayment.exchange(t.grand,cur,other,rate),other));
            }else exchangeSummary.setText("Enter today's exchange rate to calculate equivalent.");
            if(bank){
                String bc=String.valueOf(bankCurrency.getSelectedItem());
                BigDecimal actual=DraftPayment.amount(actualBankInput.getText().toString());
                BigDecimal equivalent=DraftPayment.exchange(actual,bc,cur,rate);
                BigDecimal expected=DraftPayment.exchange(t.bank,cur,bc,rate);
                bankSummary.setText("Bank amount required: "+money(expected,bc)+"\nEntered bank equivalent: "+money(equivalent,cur)+
                    "\n"+(equivalent.compareTo(t.bank)<0?"Entered amount is insufficient. ":"Entered amount covers planned bank payment. ")+
                    "No registered transfer verified. Draft only.");
            }
        }catch(IllegalArgumentException e){paymentSummary.setText("Draft payment incomplete: "+e.getMessage());}
        if(bankDraft!=null)bankDraft.context(date.getText().toString().trim(),cur,method,bankRate,bankPlanned);
    }
    private String dueDate(){
        java.time.LocalDate sale=java.time.LocalDate.parse(date.getText().toString().trim());
        String override=dueOverride.getText().toString().trim();
        java.time.LocalDate due=override.isEmpty()?InvoiceDraftPayload.due(sale,customer):java.time.LocalDate.parse(override);
        if(due.isBefore(sale))throw new IllegalArgumentException("Due date cannot precede sale.");
        return due.toString();
    }
    private void checkRecovery(){
        if(recoveryChecking)return;
        recoveryChecking=true;recoveryStatus.setText("Checking recovery journal…");
        worker.execute(()->{
            String result;
            try{
                InvoiceSaveJournal journal=new InvoiceSaveJournal(a,api.generatorAccount());
                JSONObject pending=journal.pending();
                if(pending==null)result="Recovery journal: no unresolved invoice on this device.";
                else{
                    String id=pending.getString("invoiceId");
                    JSONObject verified=api.generatorVerifySave(id);
                    if(Boolean.TRUE.equals(verified.opt("found")))
                        result="Original invoice "+pending.optString("invoiceNo")+" exists. Do not submit it again. Admin reconciliation required before clearing journal.";
                    else result="Original save unresolved: "+pending.optString("invoiceNo")+". Do not retry or create a replacement. Ask Admin.";
                }
            }catch(Exception e){result="Recovery verification unavailable. No save permitted.";}
            final String message=result;
            a.runOnUiThread(()->{recoveryChecking=false;if(active.getAsBoolean())recoveryStatus.setText(message);});
        });
    }
    private void previewPayload(){
        try{
            if(busy||!sameScope()||customer==null||lines.isEmpty())throw new IllegalArgumentException("Select location, customer and products.");
            String method=String.valueOf(paymentMethod.getSelectedItem()),cur=curr(),sale=date.getText().toString().trim();
            String due=dueDate(),no=invoiceNumber();
            BigDecimal rate=DraftPayment.amount(rateInput.getText().toString());
            if(rate.compareTo(BigDecimal.ONE)<=0)throw new IllegalArgumentException("Enter daily exchange rate.");

            String staffId=batch==null?val(location,"salespersonStaffId"):val(batch,"salesmanStaffId");
            String salesperson=batch==null?first(location,"salespersonName","salesperson"):val(batch,"salesmanName");
            BigDecimal subtotal=BigDecimal.ZERO;JSONArray items=new JSONArray();
            for(Line l:lines){
                if(!cur.equals(l.currency))throw new IllegalArgumentException("Draft currency mismatch.");
                subtotal=subtotal.add(l.qty.multiply(l.price));
                items.put(InvoiceDraftPayload.item(l.lineId,l.code,l.name,l.barcode,l.baseUnit,l.sellingUnit,l.factor,l.qty,l.price,l.purchased,l.zero,l.group));
            }
            DraftPayment.Totals t=DraftPayment.calculate(subtotal,cur,discountMode.getSelectedItemPosition()==1,
                DraftPayment.amount(discountInput.getText().toString()),method,
                method.startsWith("Partially")?DraftPayment.amount(partialInput.getText().toString()):BigDecimal.ZERO,
                "Cash + Bank".equals(method)?DraftPayment.amount(cashInput.getText().toString()):BigDecimal.ZERO,
                "Cash + Bank".equals(method)?DraftPayment.amount(bankInput.getText().toString()):BigDecimal.ZERO);
            if(draftId.isEmpty())draftId="BB-"+java.time.LocalDateTime.now(java.time.ZoneId.of("Asia/Phnom_Penh")).format(java.time.format.DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss"))+"-"+java.util.UUID.randomUUID().toString();
            if(settlementRequestId.isEmpty())settlementRequestId=java.util.UUID.randomUUID().toString();
            JSONObject registered=t.bank.signum()>0?bankDraft.capturedSelection(val(customer,"customerId"),sale,cur,method,rate,t.bank):null;
            JSONObject payload=InvoiceDraftPayload.bundle(draftId,no,sale,due,batch==null?"":val(batch,"batchId"),first(location,"locationCode","code"),val(customer,"customerId"),val(customer,"name"),staffId,salesperson,method,cur,rate,t,items,registered,settlementRequestId);
            String endpoint=InvoiceDraftPayload.endpoint(payload);
            String fingerprint=InvoiceSaveJournal.digest(endpoint+"\n"+payload.toString());
            new android.app.AlertDialog.Builder(a).setTitle("Development payload preview")
                .setMessage("Invoice "+no+"\nCustomer: "+val(customer,"name")+"\nDue: "+due+"\nItems: "+items.length()+"\nGrand total: "+money(t.grand,cur)+"\nPaid: "+money(t.paid,cur)+"\nOutstanding: "+money(t.outstanding,cur)+"\nDraft ID: "+draftId+"\nEndpoint: "+endpoint+"\nPayload SHA-256: "+fingerprint.substring(0,16)+"…\nNo request submitted. No recovery record created.")
                .setPositiveButton("Close",null).show();
        }catch(Exception e){preflightResult.setText("Payload preview blocked: "+(e instanceof IllegalArgumentException?e.getMessage():"Invalid invoice data."));}
    }
    private String invoiceNumber(){
        String raw=number.getText().toString().trim();
        StringBuilder normalized=new StringBuilder();
        for(int i=0;i<raw.length();i++){
            char ch=raw.charAt(i);
            int digit=Character.digit(ch,10);
            normalized.append(digit>=0?(char)('0'+digit):ch);
        }
        String value=normalized.toString().toUpperCase(Locale.ROOT);
        if(value.matches("[0-9]+"))value="INV-"+value;
        if(!value.matches("INV-[0-9]+"))throw new IllegalArgumentException("Enter a valid invoice number.");
        return value;
    }
    private void preflight(){
        if(checkingDraft||busy)return;
        try{
            if(!sameScope()||!customersReady||customer==null||lines.isEmpty())throw new IllegalArgumentException("Apply batch/location, select customer and add items.");
            String no=invoiceNumber(),cid=val(customer,"customerId"),loc=first(location,"locationCode","code");
            if(cid.isEmpty()||loc.isEmpty())throw new IllegalArgumentException("Customer or location identity missing.");
            String bid=batch==null?"":val(batch,"batchId"),sale=date.getText().toString().trim(),cur=curr();
            java.time.LocalDate.parse(sale);
            String method=String.valueOf(paymentMethod.getSelectedItem());
            BigDecimal rate=DraftPayment.amount(rateInput.getText().toString());
            if(rate.compareTo(BigDecimal.ONE)<=0)throw new IllegalArgumentException("Enter a valid daily exchange rate.");
            BigDecimal subtotal=BigDecimal.ZERO;
            java.util.LinkedHashMap<String,BigDecimal[]> allocations=new java.util.LinkedHashMap<>();
            java.util.LinkedHashMap<String,BigDecimal> groupAllocations=new java.util.LinkedHashMap<>();
            for(Line l:lines){
                if(!cur.equals(l.currency))throw new IllegalArgumentException("Invoice currency changed.");
                subtotal=subtotal.add(l.qty.multiply(l.price));
                if(l.group)groupAllocations.merge(l.code,l.qty.multiply(l.factor),BigDecimal::add);
                if(l.purchased.add(l.zero).signum()>0){
                    if(l.purchased.add(l.zero).compareTo(l.qty.multiply(l.factor))!=0)throw new IllegalArgumentException("Invalid source allocation.");
                    BigDecimal[] sum=allocations.computeIfAbsent(l.code,k->new BigDecimal[]{BigDecimal.ZERO,BigDecimal.ZERO});
                    sum[0]=sum[0].add(l.purchased);sum[1]=sum[1].add(l.zero);
                }
            }
            DraftPayment.calculate(subtotal,cur,discountMode.getSelectedItemPosition()==1,
                DraftPayment.amount(discountInput.getText().toString()),method,
                method.startsWith("Partially")?DraftPayment.amount(partialInput.getText().toString()):BigDecimal.ZERO,
                "Cash + Bank".equals(method)?DraftPayment.amount(cashInput.getText().toString()):BigDecimal.ZERO,
                "Cash + Bank".equals(method)?DraftPayment.amount(bankInput.getText().toString()):BigDecimal.ZERO);
            checkingDraft=true;preflightResult.setText("Checking captured draft against current server data…");
            worker.execute(()->{
                String result;
                try{
                    JSONObject duplicate=api.generatorDuplicateCheck(no,cid);
                    if(!Boolean.TRUE.equals(duplicate.opt("success"))||!(duplicate.opt("exists") instanceof Boolean))throw new IllegalStateException("Duplicate check unavailable.");
                    if(Boolean.TRUE.equals(duplicate.opt("exists")))throw new IllegalStateException("This invoice number already exists for the selected customer.");
                    JSONArray stock;
                    if(bid.isEmpty()){
                        if(!groupAllocations.isEmpty())throw new IllegalStateException("Group stock requires a batch.");
                        JSONObject data=api.generatorWarehouse();
                        if(!Boolean.TRUE.equals(data.opt("success")))throw new IllegalStateException("Warehouse balance unavailable.");
                        stock=data.getJSONArray("balances");
                    }else{
                        JSONArray current=api.generatorBatches().getJSONArray("batches");
                        JSONObject found=null;
                        for(int i=0;i<current.length();i++){JSONObject x=current.optJSONObject(i);if(x!=null&&bid.equals(val(x,"batchId"))){found=x;break;}}
                        if(found==null||!loc.equals(val(found,"locationCode"))||java.util.Arrays.asList("CLOSED","CANCELLED","CANCELED").contains(val(found,"status").toUpperCase(Locale.ROOT)))throw new IllegalStateException("Batch is closed, unavailable or location changed.");
                        java.time.LocalDate d=java.time.LocalDate.parse(sale);
                        String from=val(found,"sellingDateFrom"),to=val(found,"sellingDateTo");
                        if(from.length()<10||to.length()<10||d.isBefore(java.time.LocalDate.parse(from.substring(0,10)))||d.isAfter(java.time.LocalDate.parse(to.substring(0,10))))throw new IllegalStateException("Selling date is outside the current batch range.");
                        stock=found.getJSONArray("exactItems");
                        if(!groupAllocations.isEmpty()){
                            JSONArray groups=found.getJSONArray("groupItems");
                            for(java.util.Map.Entry<String,BigDecimal> e:groupAllocations.entrySet()){
                                JSONObject row=null;
                                for(int i=0;i<groups.length();i++){JSONObject x=groups.optJSONObject(i);if(x!=null&&e.getKey().equals(val(x,"groupCode"))){if(row!=null)throw new IllegalStateException("Ambiguous group balance.");row=x;}}
                                if(row==null||new BigDecimal(first(row,"remainingQty","issuedQty")).compareTo(e.getValue())<0)throw new IllegalStateException("Group stock changed for "+e.getKey());
                            }
                        }
                    }
                    for(java.util.Map.Entry<String,BigDecimal[]> e:allocations.entrySet()){
                        JSONObject row=null;
                        for(int i=0;i<stock.length();i++){JSONObject x=stock.optJSONObject(i);if(x!=null&&e.getKey().equals(val(x,"productCode"))){if(row!=null)throw new IllegalStateException("Ambiguous stock source.");row=x;}}
                        if(row==null)throw new IllegalStateException("Stock no longer available for "+e.getKey());
                        BigDecimal p=new BigDecimal(bid.isEmpty()?val(row,"purchasedAvailable"):first(row,"purchasedPendingQty","purchasedRemainingQty"));
                        BigDecimal z=new BigDecimal(bid.isEmpty()?val(row,"zeroCostAvailable"):first(row,"zeroCostPendingQty","zeroCostRemainingQty"));
                        if(p.compareTo(e.getValue()[0])<0||z.compareTo(e.getValue()[1])<0)throw new IllegalStateException("Stock balance changed for "+e.getKey()+". Refresh and review.");
                    }
                    result="Captured draft: "+no+" / "+cid+" — duplicate, stock and batch checks passed at "+java.time.LocalTime.now(java.time.ZoneId.of("Asia/Phnom_Penh")).format(java.time.format.DateTimeFormatter.ofPattern("HH:mm:ss"))+". Not a reservation or save authorization. Bank settlement and final submission remain disabled.";
                }catch(IllegalStateException e){result="Draft check blocked: "+e.getMessage();}
                catch(Exception e){result="Draft check unavailable. Verify connection, date and current stock, then retry.";}
                final String message=result;
                a.runOnUiThread(()->{checkingDraft=false;if(active.getAsBoolean())preflightResult.setText(message);});
            });
        }catch(Exception e){preflightResult.setText("Draft check blocked: "+(e instanceof IllegalArgumentException?e.getMessage():"Invalid invoice data."));}
    }
    private void renderLines(){
        if(linesBox==null)return;
        linesBox.removeAllViews();BigDecimal sum=BigDecimal.ZERO;
        for(Line row:new ArrayList<>(lines)){
            BigDecimal amount=row.qty.multiply(row.price);sum=sum.add(amount);
            text(linesBox,row.name+" · "+row.qty.toPlainString()+" "+row.unit+" × "+row.price.toPlainString()+" = "+amount.stripTrailingZeros().toPlainString(),15);
            if(row.group)text(linesBox,"Group base quantity "+plain(row.qty.multiply(row.factor))+" · server allocation pending",13);
            if(row.purchased.add(row.zero).signum()>0)text(linesBox,"Base qty "+plain(row.qty.multiply(row.factor))+" · Purchased "+plain(row.purchased)+" · Zero-Cost "+plain(row.zero),13);
            button(linesBox,"Remove "+row.name,()->{lines.remove(row);renderLines();renderProducts();});
        }
        total.setText("Draft subtotal: "+curr()+" "+sum.setScale("KHR".equals(curr())?0:2,RoundingMode.HALF_UP).toPlainString()+" · unverified");
        updatePayment();
    }
}
