// @category StormMSN
// Read-only call-chain investigation for original WLM 2009 GamesLobby command.
// Does not patch program, update resources, or attach to the live client.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.address.Address;
import java.nio.charset.StandardCharsets;

public class InspectNativeGamesCommand extends GhidraScript {
  public void run() throws Exception {
    println("WLM_GAMES_COMMAND_CALLCHAIN_START");
    String[][] targets={
      {"Games_Enabled_Action", "0056618b"},
      {"Games_Availability", "00575651"},
      {"Games_Element_Query", "005b2622"},
      {"Games_Fallback", "00566e37"},
      {"Games_Log_Or_Open", "006b58be"},
      {"Games_Window_Handler", "0056f11b"}
    };
    DecompInterface ifc = new DecompInterface();
    ifc.openProgram(currentProgram);
    try {
      for(String[] target:targets){
        Address a=toAddr(target[1]);
        Function f=currentProgram.getFunctionManager().getFunctionAt(a);
        println("FUNCTION_START name="+target[0]+" va="+a+
            " found="+(f!=null));
        if(f==null)continue;
        DecompileResults result=ifc.decompileFunction(f,25,monitor);
        if(!result.decompileCompleted() || result.getDecompiledFunction()==null){
          println("DECOMP_ERROR "+result.getErrorMessage());
          continue;
        }
        String c=result.getDecompiledFunction().getC();
        println("FUNCTION_SIZE="+f.getBody().getNumAddresses()+" C_CHARS="+c.length());
        // Full source stays on Nexus; bounded excerpts make review manageable.
        if(!target[0].equals("Games_Window_Handler")){
          println("C_START\n"+c.substring(0, Math.min(c.length(), 4500))+"\nC_END");
        }else{
          for(String needle:new String[]{"case 0x9eaa:","case 0x9d89:"}){
            int i=c.indexOf(needle);
            if(i>=0)println("BRANCH "+needle+"\n"+c.substring(
                 Math.max(0,i-200),Math.min(c.length(),i+900)));
          }
        }
      }
      Memory memory=currentProgram.getMemory();
      String[] globals={"0043328c","004332b0","004332c8","004333d0","004357fc"};
      for(String a:globals){
        Address addr=toAddr(a);
        byte[] bytes=new byte[180];
        memory.getBytes(addr,bytes);
        String s=new String(bytes,StandardCharsets.UTF_16LE);
        println("GLOBAL "+a+" UTF16_PREFIX="+s.replaceAll("[^\\x20-\\x7e]"," ").substring(0,Math.min(90,s.length())));
      }
    }finally{
      ifc.dispose();
    }
    println("WLM_GAMES_COMMAND_CALLCHAIN_COMPLETE");
  }
}
