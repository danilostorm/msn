// @category StormMSN
// Analyze a crash RVA in a copied Ghidra project; no edits to live DLL or WLM resources.
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolIterator;
import java.util.Locale;
public class InspectWldlogCrash extends GhidraScript {
  @Override
  public void run() throws Exception {
    if (currentProgram == null) throw new IllegalStateException("No program");
    long rva = 0x1933L;
    Address crash = currentProgram.getImageBase().add(rva);
    println("STORMMSN_WLDLOG_CRASH_AUDIT");
    println("file=" + currentProgram.getName());
    println("imageBase=" + currentProgram.getImageBase());
    println("crashRVA=0x1933");
    println("crashVA=" + crash);
    println("memoryContainsCrash=" + currentProgram.getMemory().contains(crash));
    for (MemoryBlock m : currentProgram.getMemory().getBlocks()) {
        println("section=" + m.getName() + " range=" + m.getStart() + ".." + m.getEnd());
    }
    Function f = currentProgram.getFunctionManager().getFunctionContaining(crash);
    println("containingFunction=" + (f == null ? "unknown" : f.getName() + " at " + f.getEntryPoint()));
    Listing l = currentProgram.getListing();
    Instruction ins = l.getInstructionContaining(crash);
    println("containingInstruction=" + (ins == null ? "not-disassembled" : ins.toString()));
    Instruction p = ins;
    for (int i = 0; i < 12 && p != null; i++) p = p.getPrevious();
    for (int i = 0; i < 28 && p != null; i++) {
      println("instruction[" + i + "]=" + p.getAddress() + " " + p.toString());
      p = p.getNext();
    }
    SymbolIterator itr = currentProgram.getSymbolTable().getExternalSymbols();
    int ext = 0;
    while (itr.hasNext()) {
      Symbol s = itr.next();
      ext++;
      String n = s.getName().toLowerCase(Locale.ROOT);
      if (n.contains("log") || n.contains("heap") || n.contains("string") ||
          n.contains("event") || n.contains("registry") || n.contains("file") ||
          n.contains("error")) {
        println("relevantImport=" + s.getName());
      }
    }
    println("externalSymbols=" + ext);
    println("AUDIT_COMPLETE_READ_ONLY");
  }
}
