package com.bigbrother.nativev2;
import org.json.JSONObject;
import org.json.JSONArray;
final class NativeRoutes {
    static final String[][] ALL={
        {"stock-control-allocation","Stock Control","Stock Allocation","canView"},
        {"stock-control-batch-transfer","Stock Control","Batch Transfer","canView"},
        {"stock-control-back-sale","Stock Control","Back Sale","canView"},
        {"sales-support-calculator","Sales Support","Calculator","canView"},
        {"sales-support-request-delivery","Sales Support","Request Delivery","canCreate"},
        {"sales-support-your-customer","Sales Support","Your Customer","canView"},
        {"sales-support-add-customer","Sales Support","Add Customer","canView"},
        {"sales-support-customer-map","Sales Support","Customer Map","canView"},
        {"sales-support-your-stock","Sales Support","Your Stock","canView"},
        {"sales-support-batch-selling-tracker","Sales Support","Batch Selling Tracker","canView"},
        {"sales-support-your-collection","Sales Support","Your Collection","canView"},
        {"sales-support-your-invoices","Sales Support","Your Invoices","canView"},
        {"sales-support-your-receivable","Sales Support","Your Receivable","canView"},
        {"sales-support-successful-delivery","Sales Support","Successful Delivery","canView"},
        {"invoice","Sales","Create Invoice","canCreate"},
        {"history","Sales","Invoice History","canView"},
        {"sale-return","Sales","Invoice Reversal","canView"},
        {"reversal-history","Sales","Reversal History","canView"},
        {"payment-history","Sales","Payment History","canView"},
        {"daily-sale-summary","Sales","Daily Sale Summary","canView"},
        {"daily-cash-collection","Sales","Cash Collection","canView"},
        {"real-invoice","Receivable","Real Invoice Scanner","canView"},
        {"ar-all","Receivable","All Receivables","canView"},
        {"ar-your","Receivable","My Receivables","canView"},
        {"ar-payment-history","Receivable","Receivable Payments","canView"},
        {"ar-daily-receivable-cash","Receivable","Daily Receivable Cash","canView"},
        {"stock-keyin","Stock","Stock In / Out","canView"},
        {"stock-damaged","Stock","Damaged Stock","canView"},
        {"stock-damaged-report","Stock","Damaged Stock Report","canView"},
        {"stock-damaged-cleared","Stock","Cleared Damaged Stock","canView"},
        {"stock-damaged-accounting","Stock","Damaged Stock Accounting","canView"},
        {"stock-report","Stock","Stock Report","canView"},
        {"batch-report","Stock","Batch Report","canView"},
        {"closed-batch","Stock","Closed Batch","canView"},
        {"stock-transactions","Stock","Stock Transactions","canView"},
        {"stock-pending-borrow","Stock","Pending Borrowed Stock","canView"},
        {"stock-alerts","Stock","Smart Stock Alerts","canView"},
        {"monthly-sales-report","Reports","Monthly Sales","canView"},
        {"income-statement-report","Reports","Income Statement","canView"},
        {"purchase-order-report","Reports","Purchase Order Report","canView"},
        {"cogs-daily","Reports","Daily COGS","canView"},
        {"cogs-monthly","Reports","Monthly COGS","canView"},
        {"expense-monthly-report","Reports","Monthly Expense","canView"},
        {"purchase-create","Purchase","Create Purchase","canCreate"},
        {"purchase-history","Purchase","Purchase History","canView"},
        {"purchase-payable","Purchase","Purchase Payable","canView"},
        {"purchase-payment-history","Purchase","Purchase Payment","canView"},
        {"expense-add","Expenses","Add Expense","canCreate"},
        {"expense-accrued","Expenses","Accrued Expense","canView"},
        {"daily-cash","Expenses","Daily Cash","canView"},
        {"expense-history","Expenses","Expense History","canView"},
        {"customers-add","Master Data","Add Customer","canCreate"},
        {"customers-map","Master Data","Customer Map","canView"},
        {"customers-details","Master Data","Customer Details","canView"},
        {"clients-add","Master Data","Add Client","canCreate"},
        {"clients-details","Master Data","Client Details","canView"},
        {"products-add","Master Data","Add Product / Service","canCreate"},
        {"products-details","Master Data","Product Details","canView"},
        {"master-expense-categories","Master Data","Expense Categories","canView"},
        {"master-audit-center","Master Data","Audit & Correction Center","canView"},
        {"admin-pending-receivable","Admin Work","Pending Receivable Request","canView"},
        {"admin-pending-daily-cash","Admin Work","Pending Daily Cash Request","canView"},
        {"admin-pending-deposit","Admin Work","Pending Deposit","canView"},
        {"admin-deposit-history","Admin Work","Deposit History","canView"},
        {"admin-staff-request","Admin Work","Staff Request","canView"},
        {"admin-request","Admin Work","Admin Request","canView"},
        {"admin-user-permissions","Admin Work","User & Permission Manager","canView"},
        {"staff-relation","Company","Staff Relation","canView"},
        {"notification-center","Company","Notifications","canView"}
    };
    static boolean admin(JSONObject p){JSONObject u=p.optJSONObject("user");return u!=null&&Boolean.TRUE.equals(u.opt("isAdmin"));}
    static boolean allowed(JSONObject p,String route,String action){
        if(admin(p))return true;
        JSONObject user=p.optJSONObject("user");
        if("sales-support-batch-selling-tracker".equals(route)&&"canView".equals(action)&&user!=null&&"editor".equalsIgnoreCase(user.optString("role")))return true;
        JSONArray grants=p.optJSONArray("modules");
        JSONObject exact=null,wild=null;
        if(grants!=null)for(int i=0;i<grants.length();i++){
            JSONObject g=grants.optJSONObject(i);if(g==null)continue;
            String k=g.optString("moduleKey").trim();
            if(wild==null&&"*".equals(k))wild=g;
            if(exact==null&&("route."+route).equalsIgnoreCase(k))exact=g;
        }
        JSONObject g=wild!=null?wild:exact;
        return g!=null&&Boolean.TRUE.equals(g.opt(action));
    }
    static String name(JSONObject profile){
        JSONObject s=profile.optJSONObject("staff"),u=profile.optJSONObject("user");
        String n=s==null?"":s.optString("staffName");
        if(n.isEmpty()&&u!=null)n=u.optString("staffName");
        if(n.isEmpty()&&u!=null)n=u.optString("email").split("@",2)[0];
        return n.isEmpty()?"BIG BROTHER User":n;
    }
}
