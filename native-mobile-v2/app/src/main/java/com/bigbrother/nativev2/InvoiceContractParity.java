package com.bigbrother.nativev2;

import java.math.BigDecimal;
import java.math.RoundingMode;

/** Development release gate based on deployed core arithmetic and stored numeric scales.
 * Does not call the server or assert transaction success. */
final class InvoiceContractParity {
    static BigDecimal stored(BigDecimal v){return v.setScale(2,RoundingMode.HALF_UP);}
    static BigDecimal line(BigDecimal baseQty,BigDecimal basePrice,BigDecimal displayAmount){
        if(baseQty.signum()<=0||basePrice.signum()<0)throw new IllegalArgumentException("Invalid base quantity/price.");
        if(baseQty.stripTrailingZeros().scale()>4)throw new IllegalArgumentException("Base quantity exceeds stored 4-decimal precision.");
        BigDecimal recomputed=baseQty.multiply(basePrice);
        BigDecimal storedLine=baseQty.multiply(basePrice.setScale(4,RoundingMode.HALF_UP));
        if(stored(recomputed).compareTo(stored(displayAmount))!=0||stored(storedLine).compareTo(stored(displayAmount))!=0)
            throw new IllegalArgumentException("Selling-unit price does not match stored base-price precision. Adjust the price.");
        return recomputed;
    }
    static void totals(BigDecimal computed,BigDecimal discount,BigDecimal plannedSubtotal,BigDecimal plannedGrand,BigDecimal plannedPaid,BigDecimal plannedOutstanding,String method){
        BigDecimal grand=computed.subtract(discount.min(computed)).max(BigDecimal.ZERO);
        BigDecimal paid=plannedPaid.min(grand).max(BigDecimal.ZERO);
        if("Cash".equals(method)||"Bank".equals(method)||"Cash + Bank".equals(method))paid=grand;
        if("Credit".equals(method))paid=BigDecimal.ZERO;
        if(stored(computed).compareTo(stored(plannedSubtotal))!=0||stored(grand).compareTo(stored(plannedGrand))!=0||
           stored(paid).compareTo(stored(plannedPaid))!=0||stored(grand.subtract(paid)).compareTo(stored(plannedOutstanding))!=0)
            throw new IllegalArgumentException("Invoice display rounding differs from stored server totals. Adjust quantity, price or discount.");
    }
    static void bank(BigDecimal actual,String sourceCurrency,String invoiceCurrency,BigDecimal rate,BigDecimal invoiceAmount){
        BigDecimal debit=DraftPayment.exchange(invoiceAmount,invoiceCurrency,sourceCurrency,rate);
        BigDecimal tolerance=new BigDecimal("KHR".equals(sourceCurrency)?"0.5":"0.005");
        if(actual.signum()<=0||invoiceAmount.signum()<=0||actual.subtract(debit).abs().compareTo(tolerance)>0)
            throw new IllegalArgumentException("Selected bank amount differs from the server debit. Review exchange and allocation.");
    }
}
