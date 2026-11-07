// @category StormMSN
// Locate native WLM 2009 GamesLobby references within the original decompiled
// registration routine. Read-only, no patch, no attach to a live process.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;
import ghidra.program.model.address.Address;

public class InspectGamesLobbyCallSite extends GhidraScript {
    @Override
    public void run() throws Exception {
        Function function = currentProgram.getFunctionManager().getFunctionAt(toAddr("0056f11b"));
        println("GAMESLOBBY_CALLSITE_START");
        if (function == null) {
            println("MISSING_FUNCTION");
            return;
        }
        DecompInterface d = new DecompInterface();
        d.openProgram(currentProgram);
        try {
            DecompileResults result = d.decompileFunction(function, 40, monitor);
            if (!result.decompileCompleted() || result.getDecompiledFunction() == null) {
                println("DECOMPILE_FAILED " + result.getErrorMessage());
                return;
            }
            String code = result.getDecompiledFunction().getC();
            println("DECOMPILED_TOTAL_CHARS="+code.length());
            String[] anchors = {"DAT_004332b0", "DAT_0043328c", "GamesLobby", "gamesdropdownbtn", "DAT_004357fc"};
            for (String anchor : anchors) {
                int searchAt = 0;
                int matches = 0;
                while (true) {
                    int index = code.indexOf(anchor, searchAt);
                    if (index < 0 || matches >= 12) break;
                    int begin = Math.max(0, index - 500);
                    int end = Math.min(code.length(), index + anchor.length() + 650);
                    println("ANCHOR="+anchor+" INDEX="+index);
                    println("CODE_CONTEXT_START\n"+code.substring(begin, end)+"\nCODE_CONTEXT_END");
                    matches++;
                    searchAt = index + anchor.length();
                }
                println("ANCHOR_TOTAL_SCANNED "+anchor+" = "+matches);
            }
        } finally {
            d.dispose();
        }
        println("GAMESLOBBY_CALLSITE_COMPLETE");
    }
}
