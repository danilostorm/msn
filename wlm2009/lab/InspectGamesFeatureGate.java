// @category StormMSN
// Non-destructive Ghidra lab: decompile native WLM2009 Games enablement chain.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;
import java.util.ArrayList;
import java.util.List;
public class InspectGamesFeatureGate extends GhidraScript {
 public void run() throws Exception {
   String[][] targets={
     {"GamesAvailabilityDispatcher","005de735"},
     {"GamesAvailabilityWrapper","00575651"},
     {"GamesLobbyAction","0056618b"},
     {"NativeConfigLookup","005b2622"},
     {"ActivityAttach","00584509"},
     {"ActivityDetach","00584349"},
     {"UIControlActivation","00566e37"}
   };
   DecompInterface d=new DecompInterface();
   d.openProgram(currentProgram);
   try {
     println("ORIGINAL_WLM_GAMES_GATE_ANALYSIS_START");
     for(String[] t:targets){
       Function f=currentProgram.getFunctionManager().getFunctionAt(toAddr(t[1]));
       if(f==null){println("FUNCTION_MISSING="+t[0]);continue;}
       DecompileResults r=d.decompileFunction(f,30,monitor);
       if(!r.decompileCompleted()||r.getDecompiledFunction()==null){
         println("DECOMPILE_FAILED="+t[0]+" "+r.getErrorMessage());continue;
       }
       String c=r.getDecompiledFunction().getC();
       println("FUNCTION="+t[0]+" ENTRY="+f.getEntryPoint()+
               " LENGTH_BYTES="+f.getBody().getNumAddresses()+
               " C_CHARS="+c.length());
       // All relevant functions are small enough to dump bounded source.
       println("C_START "+t[0]+"\n"+c.substring(0,Math.min(c.length(),12000))
               +"\nC_END "+t[0]);
     }
     // Find callers of the game feature-gate routine to see which native
     // conditions depend on the result. References are static-only.
     for(String va:new String[]{"005de735","00575651","0056618b"}){
       var refs=currentProgram.getReferenceManager().getReferencesTo(toAddr(va));
       int count=0;
       while(refs.hasNext()&&count<35){
         var ref=refs.next();
         Function owner=currentProgram.getFunctionManager().getFunctionContaining(ref.getFromAddress());
         println("CALLER gate="+va+" at="+ref.getFromAddress()+" in="+
             (owner==null?"none":owner.getEntryPoint()+" "+owner.getName()));
         count++;
       }
       println("CALLER_COUNT_EMITTED "+va+" = "+count);
     }
     println("ORIGINAL_WLM_GAMES_GATE_ANALYSIS_DONE");
   }finally{d.dispose();}
 }
}
