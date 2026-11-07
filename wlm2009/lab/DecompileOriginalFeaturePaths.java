// @category StormMSN
// Read-only decompilation of narrow candidate features. Do not run against live process.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;

public class DecompileOriginalFeaturePaths extends GhidraScript {
  @Override public void run() throws Exception {
    String[][] targets={
      {"GamesLobby_and_gamesdropdownbtn","0056f11b"},
      {"P4Game_callback1","005e0473"},
      {"P4Game_callback2","005e049f"},
      {"ActivityDrawer1","00584349"},
      {"ActivityDrawer2","00584509"},
      {"CallComputerMenu","0056c995"},
      {"VoiceIM_main","0056358f"},
      {"VoiceIM_other","0055c634"}
    };
    DecompInterface ifc=new DecompInterface();
    ifc.openProgram(currentProgram);
    try{
      println("WLM_NATIVE_FEATURE_DECOMPILE_START");
      for(String[] target:targets) {
        String name=target[0]; Address addr=toAddr(target[1]);
        Function f=currentProgram.getFunctionManager().getFunctionAt(addr);
        println("FEATURE_BEGIN="+name+" function="+target[1]);
        if(f==null){println("NO_FUNCTION");continue;}
        DecompileResults result=ifc.decompileFunction(f,18,monitor);
        if(!result.decompileCompleted()||result.getDecompiledFunction()==null) {
           println("FAILED="+result.getErrorMessage());continue;
        }
        String code=result.getDecompiledFunction().getC();
        println("BYTES="+f.getBody().getNumAddresses()+" LENGTH_C="+code.length());
        // Each decompiled function is printed only in the LOCAL research log.
        if(code.length()>18000)code=code.substring(0,18000)+"\n/* truncated */";
        println("C_START\n"+code+"\nC_END");
      }
      println("WLM_NATIVE_FEATURE_DECOMPILE_COMPLETE");
    }finally{ifc.dispose();}
  }
}
