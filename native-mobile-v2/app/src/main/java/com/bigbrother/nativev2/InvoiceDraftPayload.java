package com.bigbrother.nativev2;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import org.json.*;

/** Development invoice contract preview. No network writes. */
final class InvoiceDraftPayload {
    static String endpoint(JSONObject bundle)throws JSONException{
        JSONObject invoice=bundle.getJSONObject("p_invoice"),payment=bundle.optJSONObject("p_payment");
        JSONArray sources=payment==null?null:payment.optJSONArray("settlement_sources");
        if(sources!=null&&sources.length()>1)return "bb_sales_save_invoice_multi_bank_v1";
        return "Cash + Bank".equals(invoice.getString("paymentMethod"))?"bb_sales_save_invoice_split_payment":"bb_sales_save_invoice_bundle";
    }
    static LocalDate due(LocalDate sale,JSONObject customer){
        String type=customer.optString("creditTermType","DAYS").toUpperCase(java.util.Locale.ROOT);
        int value=customer.optInt("creditTermValue",4);
        if("HALF_MONTH".equals(type))return sale.getDayOfMonth()<15?sale.withDayOfMonth(15):sale.plusMonths(1).withDayOfMonth(1);
        if("MONTHS".equals(type))return sale.plusMonths(Math.max(1,value)).withDayOfMonth(1);
        return sale.plusDays(Math.max(0,value));
    }
    static JSONObject item(String lineId,String code,String name,String barcode,String baseUnit,String sellingUnit,BigDecimal factor,BigDecimal qty,BigDecimal price,BigDecimal purchased,BigDecimal zero,boolean group)throws JSONException{
        BigDecimal baseQty=qty.multiply(factor),amount=qty.multiply(price);
        JSONArray sources=new JSONArray();
        if(purchased.signum()>0)sources.put(new JSONObject().put("source","PURCHASED").put("qty",purchased));
        if(zero.signum()>0)sources.put(new JSONObject().put("source","ZERO_COST").put("qty",zero));
        JSONObject item=new JSONObject().put("lineId",lineId).put("productCode",code).put("productName",name)
            .put("productBarcode",barcode).put("productNote","").put("unit",baseUnit)
            .put("qty",baseQty).put("unitPrice",price.divide(factor,12,RoundingMode.HALF_UP)).put("amount",amount)
            .put("entryType",group?"GROUP":"EXACT").put("productGroupCode",group?code:"").put("productGroupName",group?name:"");
        if(sources.length()>0)item.put("stockAllocations",sources); // service and group: omit explicit exact allocation
        if(factor.compareTo(BigDecimal.ONE)>0)item.put("sellingQty",qty).put("sellingUnit",sellingUnit).put("sellingUnitBaseQty",factor)
            .put("sellingUnitPrice",price).put("baseQty",baseQty).put("baseUnit",baseUnit);
        return item;
    }
    static JSONObject bundle(String id,String no,String sale,String due,String batch,String location,String customerId,String customer,String staffId,String salesperson,String method,String currency,BigDecimal rate,DraftPayment.Totals t,JSONArray items,JSONObject registered,String settlementRequestId)throws JSONException{
        boolean bank=java.util.Arrays.asList("Bank","Partially Paid in Bank","Cash + Bank").contains(method);
        boolean split="Cash + Bank".equals(method);
        if(!bank&&!java.util.Arrays.asList("Cash","Credit","Partially Paid in Cash").contains(method))throw new IllegalArgumentException("Unsupported method.");
        if(bank&&registered==null)throw new IllegalArgumentException("Select registered bank transfer.");
        JSONArray sources=bank?registered.getJSONArray("sources"):new JSONArray();
        boolean multi=sources.length()>1;
        if(multi&&(split||settlementRequestId.isEmpty()))throw new IllegalArgumentException("Invalid multi-bank pilot preview.");
        String transaction=bank?registered.getString("transactionId"):"",receivingBank=bank?registered.getString("bankName"):"";
        if(id.isEmpty()||staffId.isEmpty()||salesperson.isEmpty()||customerId.isEmpty()||items.length()==0)throw new IllegalArgumentException("Required invoice identity missing.");
        JSONObject invoice=new JSONObject().put("invoiceId",id).put("invoiceNo",no).put("invoiceDate",sale).put("dueDate",due)
            .put("batchNumber",batch).put("locationCode",location).put("customerId",customerId).put("customer",customer)
            .put("shippingTo","").put("salesperson",salesperson).put("salespersonStaffId",staffId).put("paymentMethod",method)
            .put("paymentBank",receivingBank).put("transactionId",transaction).put("bankReference",transaction).put("currency",currency).put("exchangeRate",rate)
            .put("subtotal",t.subtotal).put("discount",t.discount).put("grandTotal",t.grand).put("amountPaid",t.paid)
            .put("creditAmount",t.outstanding).put("outstanding",t.outstanding).put("change",BigDecimal.ZERO)
            .put("status",t.outstanding.signum()>0?(t.paid.signum()>0?"Processing":"Unpaid"):"Paid").put("note","").put("items",items);
        if(split)invoice.put("splitCashAmount",t.cash).put("splitBankAmount",t.bank);
        JSONObject payment=null;
        if(t.paid.signum()>0)payment=new JSONObject().put("invoiceId",id).put("invoiceNo",no).put("paymentDate",sale)
            .put("customer",customer).put("locationCode",location).put("salesperson",salesperson).put("paymentMethod",split?"Cash + Bank":bank?"Bank":"Cash")
            .put("bankPayment",receivingBank).put("transactionId",transaction).put("bankReference",split?transaction:"").put("currency",currency).put("exchangeRate",rate)
            .put("amount",t.paid).put("note","Initial invoice payment");
        if(payment!=null&&split)payment.put("cashAmount",t.cash).put("bankAmount",t.bank).put("note","Initial split invoice payment");
        if(payment!=null&&multi)payment.put("settlement_sources",sources).put("settlement_request_id",settlementRequestId);
        return new JSONObject().put("p_invoice",invoice).put("p_payment",payment==null?JSONObject.NULL:payment);
    }
}
