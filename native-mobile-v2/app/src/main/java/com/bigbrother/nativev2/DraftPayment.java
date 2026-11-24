package com.bigbrother.nativev2;
import java.math.BigDecimal;
import java.math.RoundingMode;

/** Pure decimal calculations for draft display only; no payment registration. */
final class DraftPayment {
    static final BigDecimal ZERO=BigDecimal.ZERO;
    static final BigDecimal ONE=BigDecimal.ONE;
    static BigDecimal amount(String text){
        String s=text.trim().replace(',','.');
        if(s.isEmpty())return ZERO;
        if(!s.matches("[0-9]{1,12}(\\.[0-9]{0,4})?"))throw new IllegalArgumentException("Enter a nonnegative number (up to 4 decimals).");
        return new BigDecimal(s);
    }
    static int scale(String currency){if("USD".equals(currency))return 2;if("KHR".equals(currency))return 0;throw new IllegalArgumentException("Unsupported currency");}
    static BigDecimal round(BigDecimal amount,String currency){return amount.setScale(scale(currency),RoundingMode.HALF_UP);}
    static BigDecimal exchange(BigDecimal amount,String from,String to,BigDecimal rate){
        scale(from);scale(to);
        if(from.equals(to))return amount;
        if(rate.compareTo(ONE)<=0)throw new IllegalArgumentException("Enter today's exchange rate.");
        return "USD".equals(from)?amount.multiply(rate):amount.divide(rate,12,RoundingMode.HALF_UP);
    }
    static final class Totals {
        final BigDecimal subtotal,discount,grand,paid,outstanding,bank,cash;
        Totals(BigDecimal subtotal,BigDecimal discount,BigDecimal grand,BigDecimal paid,BigDecimal bank,BigDecimal cash){
            this.subtotal=subtotal;this.discount=discount;this.grand=grand;this.paid=paid;this.outstanding=grand.subtract(paid);this.bank=bank;this.cash=cash;
        }
    }
    static Totals calculate(BigDecimal subtotal,String currency,boolean percent,BigDecimal discountInput,String method,BigDecimal partial,BigDecimal splitCash,BigDecimal splitBank){
        if(subtotal.signum()<0||discountInput.signum()<0)throw new IllegalArgumentException("Invalid discount.");
        if(percent&&discountInput.compareTo(new BigDecimal("100"))>0)throw new IllegalArgumentException("Discount cannot exceed 100%.");
        BigDecimal sub=round(subtotal,currency);
        BigDecimal discount=round(percent?subtotal.multiply(discountInput).movePointLeft(2):discountInput,currency);
        if(discount.compareTo(sub)>0)throw new IllegalArgumentException("Discount cannot exceed subtotal.");
        BigDecimal grand=sub.subtract(discount),cash=ZERO,bank=ZERO,paid=ZERO;
        switch(method){
            case "Cash":cash=grand;paid=grand;break;
            case "Bank":bank=grand;paid=grand;break;
            case "Credit":break;
            case "Partially Paid in Cash":
            case "Partially Paid in Bank":
                paid=round(partial,currency);
                if(paid.signum()<=0||paid.compareTo(grand)>=0)throw new IllegalArgumentException("Partial payment must be greater than zero and less than grand total.");
                if("Partially Paid in Cash".equals(method))cash=paid;else bank=paid;
                break;
            case "Cash + Bank":
                cash=round(splitCash,currency);bank=round(splitBank,currency);paid=cash.add(bank);
                if(cash.signum()<=0||bank.signum()<=0||paid.compareTo(grand)!=0)throw new IllegalArgumentException("Cash + Bank must equal grand total; both amounts must be positive.");
                break;
            default:throw new IllegalArgumentException("Select payment method.");
        }
        return new Totals(sub,discount,grand,paid,bank,cash);
    }
}
