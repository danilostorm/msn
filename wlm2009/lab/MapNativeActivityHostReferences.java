// @category StormMSN
// Read-only Ghidra report: where the WLM 2009 DirectUI game/activity hosts
// are referenced by functions. No binary modifications or process attachment.
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import java.nio.charset.StandardCharsets;

public class MapNativeActivityHostReferences extends GhidraScript {
    @Override public void run() throws Exception {
        String[] terms = {
            "convdraweractivityhost", "convdrawerroot", "p4gamecontainer",
            "p4appcontainer", "ActivityAreaRightTitleBarCont",
            "gamesdropdownbtn", "GamesLobby", "LocalizedConfig/AppDirConfig/GamesBrowserURL"
        };
        Memory mem=currentProgram.getMemory();
        println("STORM_WLM_ACTIVITY_HOST_REFERENCE_SCAN_START");
        for(String term:terms) {
            int hits=0;
            int refs=0;
            for(int enc=0;enc<2;enc++) {
                byte[] bytes = term.getBytes(enc==0?
                      StandardCharsets.UTF_16LE:StandardCharsets.US_ASCII);
                Address from = currentProgram.getMinAddress();
                while(from!=null && hits<60) {
                    Address located=mem.findBytes(from,bytes,null,true,monitor);
                    if(located==null)break;
                    hits++;
                    int count=0;
                    ReferenceIterator iter=currentProgram.getReferenceManager().getReferencesTo(located);
                    while(iter.hasNext()) {
                        Reference ref=iter.next();count++;refs++;
                        if(count<=12) {
                            Function fn=currentProgram.getFunctionManager()
                                .getFunctionContaining(ref.getFromAddress());
                            println("XREF term="+term+" stringAddress="+located+
                                " from="+ref.getFromAddress()+" type="+ref.getReferenceType()+
                                " fn="+(fn==null?"none":fn.getName()+"@"+fn.getEntryPoint()));
                        }
                    }
                    if(hits<=12) println("TERM_FOUND term="+term+" encoding="+
                        (enc==0?"UTF16LE":"ASCII")+" address="+located+
                        " xrefCount="+count);
                    try{from=located.add(1);}catch(Exception ex){break;}
                }
            }
            println("TERM_SUMMARY term="+term+" hits="+hits+" xrefs="+refs);
        }
        println("STORM_WLM_ACTIVITY_HOST_REFERENCE_SCAN_COMPLETE");
    }
}
