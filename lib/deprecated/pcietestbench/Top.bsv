// bsv libraries
import Vector::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;
import MemTypes::*;

// generated by tool
import PcieTestBenchIndicationProxy::*;
import PcieTestBenchRequestWrapper::*;

// defined by user
import PcieTestBench::*;

typedef enum {PcieTestBenchIndication, PcieTestBenchRequest} IfcNames deriving (Eq,Bits);

module mkConnectalTop(StdConnectalTop#(addrWidth));

   // instantiate user portals
   PcieTestBenchIndicationProxy pcieTestBenchIndicationProxy <- mkPcieTestBenchIndicationProxy(PcieTestBenchIndication);
   PcieTestBenchRequest pcieTestBenchRequest <- mkPcieTestBenchRequest(pcieTestBenchIndicationProxy.ifc);
   PcieTestBenchRequestWrapper pcieTestBenchRequestWrapper <- mkPcieTestBenchRequestWrapper(PcieTestBenchRequest,pcieTestBenchRequest);
   
   Vector#(2,StdPortal) portals;
   portals[0] = pcieTestBenchRequestWrapper.portalIfc; 
   portals[1] = pcieTestBenchIndicationProxy.portalIfc;
   
   // instantiate system directory
   StdDirectory dir <- mkStdDirectory(portals);
   let ctrl_mux <- mkSlaveMux(dir,portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = nil;
   interface leds = default_leds;

endmodule : mkConnectalTop


