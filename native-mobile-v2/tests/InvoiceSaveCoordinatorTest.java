package com.bigbrother.nativev2;

final class InvoiceSaveCoordinatorTest {
    static final String RPC="bb_sales_save_invoice_bundle";
    static final class Journal implements InvoiceSaveCoordinator.Journal {
        boolean pending,failBegin,failAck;
        String id;
        public void begin(String id,String no,String frozen)throws Exception{
            if(pending||failBegin)throw new Exception("locked");
            if(!frozen.startsWith(RPC+"\n"))throw new AssertionError("endpoint not fingerprinted");
            pending=true;this.id=id;
        }
        public void acknowledge(String id)throws Exception{
            if(!pending||!this.id.equals(id)||failAck)throw new Exception("ack failed");
            pending=false;
        }
    }
    static final class Transport implements InvoiceSaveCoordinator.Transport {
        Journal journal;int sends,checks;boolean failSend,found,failCheck;
        Transport(Journal j){journal=j;}
        public void send(String endpoint,String frozen)throws Exception{
            if(!journal.pending)throw new AssertionError("sent before durable record");
            sends++;if(failSend)throw new Exception("connection interrupted");
        }
        public boolean verify(String id)throws Exception{
            checks++;if(failCheck)throw new Exception("offline");return found;
        }
    }
    static void check(boolean ok){if(!ok)throw new AssertionError();}
    static InvoiceSaveCoordinator.Outcome run(Journal j,Transport t)throws Exception{return InvoiceSaveCoordinator.execute(j,t,RPC,"BB-test","INV-1","frozen");}
    public static void main(String[] args)throws Exception{
        Journal j=new Journal();Transport t=new Transport(j);t.found=true;
        check(run(j,t)==InvoiceSaveCoordinator.Outcome.CONFIRMED&&!j.pending&&t.sends==1);
        j=new Journal();t=new Transport(j);t.failSend=true;t.found=true;
        check(run(j,t)==InvoiceSaveCoordinator.Outcome.CONFIRMED&&!j.pending&&t.sends==1);
        j=new Journal();t=new Transport(j);t.failSend=true;
        check(run(j,t)==InvoiceSaveCoordinator.Outcome.UNRESOLVED&&j.pending&&t.sends==1);
        try{run(j,t);throw new AssertionError("retry not blocked");}catch(Exception expected){}
        check(t.sends==1);
        j=new Journal();t=new Transport(j);t.failCheck=true;
        check(run(j,t)==InvoiceSaveCoordinator.Outcome.UNRESOLVED&&j.pending);
        j=new Journal();t=new Transport(j);j.failBegin=true;
        try{run(j,t);throw new AssertionError("journal failure ignored");}catch(Exception expected){}
        check(t.sends==0);
        j=new Journal();t=new Transport(j);j.failAck=true;t.found=true;
        check(run(j,t)==InvoiceSaveCoordinator.Outcome.UNRESOLVED&&j.pending);
        System.out.println("7 atomic save recovery scenarios passed (fake transport only)");
    }
}
