// @category StormMSN
// Ghidra read-only inspection of the exact wldlog.dll WER fault RVA 0x1933.
// Runs in an isolated Ghidra project; never edits live Messenger or disk DLL.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;

public class DecompileWldlogFault extends GhidraScript {
  @Override public void run() throws Exception {
    Address address = currentProgram.getImageBase().add(0x1933L);
    Function f = currentProgram.getFunctionManager().getFunctionContaining(address);
    println("WLDLOG_FAULT_RVA_1933");
    println("fault_address="+address);
    if (f == null) {
      println("function=NOT_FOUND");
      return;
    }
    println("function_entry="+f.getEntryPoint());
    println("function_bytes="+f.getBody().getNumAddresses());
    println("parameter_count="+f.getParameterCount());
    int refs=0;
    ReferenceIterator iter=currentProgram.getReferenceManager().getReferencesTo(f.getEntryPoint());
    while(iter.hasNext()){
      Reference ref=iter.next();
      if(refs<35)println("caller_reference="+ref.getFromAddress()+" type="+ref.getReferenceType());
      refs++;
    }
    println("total_caller_refs="+refs);
    DecompInterface decomp=new DecompInterface();
    decomp.openProgram(currentProgram);
    try{
      DecompileResults result=decomp.decompileFunction(f,30,monitor);
      if(result.decompileCompleted() && result.getDecompiledFunction()!=null) {
        String txt=result.getDecompiledFunction().getC();
        if(txt.length()>10000)txt=txt.substring(0,10000);
        println("DECOMPILED_C_START\n"+txt+"\nDECOMPILED_C_END");
      } else {
        println("DECOMPILATION_FAILED="+result.getErrorMessage());
      }
    } finally {
      decomp.dispose();
    }
    println("WLDLOG_FAULT_AUDIT_COMPLETE");
  }
}
