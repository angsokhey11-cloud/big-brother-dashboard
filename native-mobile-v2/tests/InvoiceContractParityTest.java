package com.bigbrother.nativev2;
import java.math.BigDecimal;
final class InvoiceContractParityTest {
    static BigDecimal n(String value){return new BigDecimal(value);}
    static void eq(BigDecimal a,String b){if(a.compareTo(n(b))!=0)throw new AssertionError(a+" != "+b);}
    static void reject(Runnable r){try{r.run();throw new AssertionError("Expected rejection");}catch(IllegalArgumentException expected){}}
    public static void main(String[] args){
        BigDecimal z=n("0");
        // 2 cartons of six, $15/carton: base 12 x $2.50.
        eq(InvoiceContractParity.line(n("12"),n("2.5"),n("30")),"30");
        // Recurring base price: safe at small quantity, unsafe at large quantity.
        InvoiceContractParity.line(n("6"),n("1.666666666667"),n("10"));
        reject(()->InvoiceContractParity.line(n("600"),n("1.666666666667"),n("1000")));
        reject(()->InvoiceContractParity.line(n("1.00001"),n("5"),n("5")));
        for(String method:new String[]{"Cash","Bank","Credit","Partially Paid in Cash","Partially Paid in Bank","Cash + Bank"}){
            DraftPayment.Totals t=DraftPayment.calculate(n("100"),"USD",true,n("5"),method,n("40"),n("35"),n("60"));
            eq(t.grand,"95");
            InvoiceContractParity.totals(n("100"),t.discount,t.subtotal,t.grand,t.paid,t.outstanding,method);
            eq(t.paid.add(t.outstanding),"95");
        }
        DraftPayment.Totals k=DraftPayment.calculate(n("100000"),"KHR",false,n("5000"),"Credit",z,z,z);
        eq(k.outstanding,"95000");
        InvoiceContractParity.totals(n("100000"),k.discount,k.subtotal,k.grand,k.paid,k.outstanding,"Credit");
        reject(()->InvoiceContractParity.totals(n("100.49"),z,n("100"),n("100"),z,n("100"),"Credit"));
        InvoiceContractParity.bank(n("41000"),"KHR","USD",n("4100"),n("10"));
        InvoiceContractParity.bank(n("10"),"USD","KHR",n("4100"),n("41000"));
        reject(()->InvoiceContractParity.bank(n("40990"),"KHR","USD",n("4100"),n("10")));
        reject(()->DraftPayment.calculate(n("100"),"USD",false,z,"Cash + Bank",z,n("20"),n("70")));
        reject(()->DraftPayment.calculate(n("100"),"USD",false,z,"Partially Paid in Cash",n("100"),z,z));
        System.out.println("Invoice arithmetic/contract parity fixtures passed");
    }
}
