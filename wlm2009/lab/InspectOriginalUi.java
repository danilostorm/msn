// @category StormMSN
// Read-only audit of the original WLM 2009 executable in Ghidra.
// This script DOES NOT write or patch the executable, graphics or installed client.
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolIterator;
import java.util.Locale;

public class InspectOriginalUi extends GhidraScript {
    @Override
    public void run() throws Exception {
        if (currentProgram == null) {
            printerr("No program is open.");
            return;
        }
        println("STORMMSN_ORIGINAL_UI_AUDIT");
        println("name=" + currentProgram.getName());
        println("executable=" + currentProgram.getExecutablePath());
        println("format=" + currentProgram.getExecutableFormat());
        println("language=" + currentProgram.getLanguageID().toString());
        println("image_base=" + currentProgram.getImageBase());
        for (MemoryBlock block : currentProgram.getMemory().getBlocks()) {
            println("section=" + block.getName() + " size=" + block.getSize());
        }
        long functions = 0;
        FunctionIterator funcIterator = currentProgram.getFunctionManager().getFunctions(true);
        while (funcIterator.hasNext()) {
            funcIterator.next();
            functions++;
        }
        println("recognized_functions=" + functions);
        SymbolIterator imports = currentProgram.getSymbolTable().getExternalSymbols();
        int externalCount = 0;
        int uiCount = 0;
        while (imports.hasNext()) {
            Symbol symbol = imports.next();
            externalCount++;
            String symbolName = symbol.getName();
            String lower = symbolName.toLowerCase(Locale.ROOT);
            if (lower.contains("window") || lower.contains("draw") ||
                lower.contains("theme") || lower.contains("dwm") ||
                lower.contains("render") || lower.contains("ux") ||
                lower.contains("bitblt") || lower.contains("create") ||
                lower.contains("gdi") || lower.contains("dialog")) {
                if (uiCount < 110) {
                    println("ui_import=" + symbolName);
                }
                uiCount++;
            }
        }
        println("external_symbols=" + externalCount);
        println("ui_related_external_symbols=" + uiCount);
        println("AUDIT_COMPLETE_READ_ONLY");
    }
}
