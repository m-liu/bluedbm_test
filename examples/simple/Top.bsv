// bsv libraries
import Vector::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import CtrlMux::*;
import Portal::*;
import Leds::*;
import MemTypes::*;
import MemPortal::*;

// generated by tool
import SimpleProxy::*;
import SimpleWrapper::*;

// defined by user
import Simple::*;

typedef enum {SimpleIndication, SimpleRequest} IfcNames deriving (Eq,Bits);

module mkConnectalTop(StdConnectalTop#(PhysAddrWidth));

   // instantiate user portals
   SimpleProxy simpleIndicationProxy <- mkSimpleProxy(SimpleIndication);
   Simple simpleRequest <- mkSimple(simpleIndicationProxy.ifc);
   SimpleWrapper simpleRequestWrapper <- mkSimpleWrapper(SimpleRequest,simpleRequest);
   
   Vector#(2,StdPortal) portals;
   portals[0] = simpleRequestWrapper.portalIfc;
   portals[1] = simpleIndicationProxy.portalIfc;
   let ctrl_mux <- mkSlaveMux(portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = nil;
   interface leds = default_leds;

endmodule : mkConnectalTop


