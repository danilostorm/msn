// @category StormMSN
// Read-only map of genuine WLM 2009 DirectUI activity surface:
 // only copies bounded decompiler context into LOCAL lab logs.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;

public class InspectActivitySurfaceGeometry extends GhidraScript {
    @Override public void run() throws Exception {
        String[][] funcs={
            {"LocateOriginalDrawer","00584306"},
            {"AttachActivity","00584509"},
            {"DetachActivity","00584349"},
            {"P4AppLayout","00567f39"},
            {"P4AppSurface","0055fa7d"},
            {"P4AppProperties","0055ab3e"},
            {"DirectUIHostQuery","0055b9fe"},
            {"P4AppArea","00564a90"},
            {"DrawerHostSetup","00566051"},
        };
        DecompInterface ifc=new DecompInterface();ifc.openProgram(currentProgram);
        println("WLM_ACTIVITY_GEOMETRY_RESEARCH_START");
        try {
          for(String[] t:funcs){
            Function f=currentProgram.getFunctionManager().getFunctionAt(toAddr(t[1]));
            println("FUNCTION="+t[0]+" ADDRESS="+t[1]+" FOUND="+(f!=null));
            if(f==null)continue;
            DecompileResults r=ifc.decompileFunction(f,25,monitor);
            if(!r.decompileCompleted()||r.getDecompiledFunction()==null){
              println("DECOMPILE_FAILED="+r.getErrorMessage());continue;
            }
            String c=r.getDecompiledFunction().getC();
            println("C_LENGTH="+c.length()+" BYTES="+f.getBody().getNumAddresses());
            String[] targets={"DAT_004357fc","DAT_00449640","DAT_0044966c",
               "DAT_0043258c","GetRect","GetLayout","GetWindow","GetPosition",
               "GetBounds","GetSize","GetLocation","GetVisible","SetSize"};
            boolean hit=false;
            for(String needle:targets){
              int at=0, n=0;
              while((at=c.indexOf(needle,at))>=0&&n<4){
                hit=true;
                println("MATCH="+needle+" CONTEXT="+
                    c.substring(Math.max(0,at-310),Math.min(c.length(),at+needle.length()+430)).replace("\n"," "));
                at+=needle.length();n++;
              }
            }
            if(!hit)println("C_SUMMARY="+c.substring(0,Math.min(2600,c.length())));
          }
        }finally{ifc.dispose();}
        println("WLM_ACTIVITY_GEOMETRY_RESEARCH_COMPLETE");
    }
}
