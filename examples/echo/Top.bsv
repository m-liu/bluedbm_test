// bsv libraries
import Vector::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import Portal::*;
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;
import AxiMasterSlave::*;


// generated by tool
import EchoIndicationProxy::*;
import EchoRequestWrapper::*;
import SwallowWrapper::*;

// defined by user
import Echo::*;
import Swallow::*;

typedef enum {EchoIndication, EchoRequest, Swallow} IfcNames deriving (Eq,Bits);

module mkPortalTop(StdPortalTop#(addrWidth));

   // instantiate user portals
   EchoIndicationProxy echoIndicationProxy <- mkEchoIndicationProxy(EchoIndication);
   EchoRequestInternal echoRequestInternal <- mkEchoRequestInternal(echoIndicationProxy.ifc);
   EchoRequestWrapper echoRequestWrapper <- mkEchoRequestWrapper(EchoRequest,echoRequestInternal.ifc);
   
   Swallow swallow <- mkSwallow();
   SwallowWrapper swallowWrapper <- mkSwallowWrapper(Swallow, swallow);
   
   Vector#(3,StdPortal) portals;
   portals[0] = echoIndicationProxy.portalIfc;
   portals[1] = echoRequestWrapper.portalIfc; 
   portals[2] = swallowWrapper.portalIfc; 
   let interrupt_mux <- mkInterruptMux(portals);
   
   // instantiate system directory
   StdDirectory dir <- mkStdDirectory(portals);
   Vector#(1,StdPortal) directories;
   directories[0] = dir.portalIfc;
   
   // when constructing the ctrl mux, directories must be the first argument
   let ctrl_mux <- mkAxiSlaveMux(directories,portals);
   
   interface interrupt = interrupt_mux;
   interface ctrl = ctrl_mux;
   interface m_axi = null_axi_master;
   interface leds = echoRequestInternal.leds;

endmodule : mkPortalTop
