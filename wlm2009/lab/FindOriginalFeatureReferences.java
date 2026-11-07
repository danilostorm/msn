// @category StormMSN
// Static read-only analysis of original WLM 2009 native feature references.
// No binary patching, no runtime attach, no graphics or UI reconstruction.
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;

public class FindOriginalFeatureReferences extends GhidraScript {
    @Override public void run() throws Exception {
        Memory memory = currentProgram.getMemory();
        String[] targets = {
            "GamesLobby", "P4Game", "VideoCall", "VoiceIM",
            "Webcam", "GameInvite", "Activity", "CallComputer",
            "videocallText", "gamesdropdownbtn",
            "convdraweractivityhost", "Invite", "ApplicationID"
        };
        println("STORMMSN_NATIVE_FEATURE_XREF_START");
        println("program="+currentProgram.getName());
        println("format="+currentProgram.getExecutableFormat());
        println("base="+currentProgram.getImageBase());

        for (String term : targets) {
            int total = 0;
            int xrefs = 0;
            for (int encoding = 0; encoding < 2; encoding++) {
                byte[] bytes = term.getBytes(encoding == 0 ?
                    StandardCharsets.UTF_16LE : StandardCharsets.US_ASCII);
                Address pos = currentProgram.getMinAddress();
                int found = 0;
                while (pos != null && found < 75) {
                    Address hit = memory.findBytes(pos, bytes, null, true, monitor);
                    if (hit == null) break;
                    found++;
                    total++;
                    ReferenceIterator iter = currentProgram.getReferenceManager().getReferencesTo(hit);
                    int refCount = 0;
                    while (iter.hasNext()) {
                        Reference ref = iter.next();
                        refCount++;
                        xrefs++;
                        if (refCount <= 10) {
                            Function fun = currentProgram.getFunctionManager().getFunctionContaining(ref.getFromAddress());
                            println("  ref="+ref.getFromAddress()+" "+ref.getReferenceType()+
                                    " func="+(fun == null ? "unknown" : fun.getName()+"@"+fun.getEntryPoint()));
                        }
                    }
                    if (found <= 18) {
                        println("match="+term+" encoding="+
                                (encoding == 0 ? "utf16le" : "ascii")+
                                " at="+hit+" references="+refCount);
                    }
                    try { pos = hit.add(1); } catch (Exception ex) {break;}
                }
            }
            println("FEATURE_SUMMARY term="+term+" matches="+total+" refs="+xrefs);
        }
        println("STORMMSN_NATIVE_FEATURE_XREF_COMPLETE");
    }
}
