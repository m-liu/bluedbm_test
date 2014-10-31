// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;

// portz libraries
import CtrlMux::*;
import Portal::*;
import Leds::*;
import BlueScope::*;
import ConnectalMemory::*;
import MemTypes::*;
import DmaUtils::*;
import MemServer::*;
import MMU::*;

// generated by tool
import SmithwatermanRequestWrapper::*;
import DmaDebugRequestWrapper::*;
import MMUConfigRequestWrapper::*;
import SmithwatermanIndicationProxy::*;
import DmaDebugIndicationProxy::*;
import MMUConfigIndicationProxy::*;

// defined by user
import Smithwaterman::*;

typedef enum {SmithwatermanIndication, SmithwatermanRequest, HostDmaDebugIndication, HostDmaDebugRequest, HostMMUConfigRequest, HostMMUConfigIndication} IfcNames deriving (Eq,Bits);
typedef 1 DegPar;


module mkConnectalTop(StdConnectalDmaTop#(PhysAddrWidth));

   DmaReadBuffer#(64,1) setupA_read_chan <- mkDmaReadBuffer();
   DmaReadBuffer#(64,1) setupB_read_chan <- mkDmaReadBuffer();
   
   MemReadClient#(64) setupA_read_client = setupA_read_chan.dmaClient;
   MemReadClient#(64) setupB_read_client = setupB_read_chan.dmaClient;
   
   Vector#(2,  MemReadClient#(64)) readClients;
   readClients[0] = setupA_read_client;
   readClients[1] = setupB_read_client;

   MMUConfigIndicationProxy hostMMUConfigIndicationProxy <- mkMMUConfigIndicationProxy(HostMMUConfigIndication);
   MMU#(PhysAddrWidth) hostMMU <- mkMMU(0, True, hostMMUConfigIndicationProxy.ifc);
   MMUConfigRequestWrapper hostMMUConfigRequestWrapper <- mkMMUConfigRequestWrapper(HostMMUConfigRequest, hostMMU.request);

   DmaDebugIndicationProxy hostDmaDebugIndicationProxy <- mkDmaDebugIndicationProxy(HostDmaDebugIndication);
   MemServer#(PhysAddrWidth,64,1) dma <- mkMemServerR(hostDmaDebugIndicationProxy.ifc, readClients, cons(hostMMU,nil));
   DmaDebugRequestWrapper hostDmaDebugRequestWrapper <- mkDmaDebugRequestWrapper(HostDmaDebugRequest, dma.request);

   SmithwatermanIndicationProxy smithwatermanIndicationProxy <- mkSmithwatermanIndicationProxy(SmithwatermanIndication);
   SmithwatermanRequest smithwatermanRequest <- mkSmithwatermanRequest(smithwatermanIndicationProxy.ifc, setupA_read_chan.dmaServer, setupB_read_chan.dmaServer);
   SmithwatermanRequestWrapper smithwatermanRequestWrapper <- mkSmithwatermanRequestWrapper(SmithwatermanRequest,smithwatermanRequest);

   Vector#(6,StdPortal) portals;
   portals[0] = smithwatermanRequestWrapper.portalIfc;
   portals[1] = smithwatermanIndicationProxy.portalIfc; 
   portals[2] = hostDmaDebugRequestWrapper.portalIfc;
   portals[3] = hostDmaDebugIndicationProxy.portalIfc; 
   portals[4] = hostMMUConfigRequestWrapper.portalIfc;
   portals[5] = hostMMUConfigIndicationProxy.portalIfc;
   let ctrl_mux <- mkSlaveMux(portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = dma.masters;
   interface leds = default_leds;
endmodule
