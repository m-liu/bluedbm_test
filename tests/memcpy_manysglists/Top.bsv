// Copyright (c) 2013 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;

// portz libraries
import CtrlMux::*;
import Portal::*;
import Leds::*;
import ConnectalMemory::*;
import MemTypes::*;
import MemServer::*;
import MMU::*;

// generated by tool
import MemcpyRequestWrapper::*;
import DmaDebugRequestWrapper::*;
import MMUConfigRequestWrapper::*;
import MemcpyIndicationProxy::*;
import DmaDebugIndicationProxy::*;
import MMUConfigIndicationProxy::*;

// defined by user
import Memcpy::*;

typedef enum {MemcpyIndication, 
	      MemcpyRequest, 

	      HostDmaDebugIndication, 
	      HostDmaDebugRequest, 

	      HostMMU0ConfigRequest, 
	      HostMMU0ConfigIndication,
	      
	      HostMMU1ConfigRequest, 
	      HostMMU1ConfigIndication,
	      
	      HostMMU2ConfigRequest, 
	      HostMMU2ConfigIndication,

	      HostMMU3ConfigRequest, 
	      HostMMU3ConfigIndication } IfcNames deriving (Eq,Bits);

module mkConnectalTop(StdConnectalDmaTop#(PhysAddrWidth));

   MemcpyIndicationProxy memcpyIndicationProxy <- mkMemcpyIndicationProxy(MemcpyIndication);
   Memcpy memcpy <- mkMemcpy(memcpyIndicationProxy.ifc);
   MemcpyRequestWrapper memcpyRequestWrapper <- mkMemcpyRequestWrapper(MemcpyRequest,memcpy.request);


   MMUConfigIndicationProxy hostMMU0ConfigIndicationProxy <- mkMMUConfigIndicationProxy(HostMMU0ConfigIndication);
   MMU#(PhysAddrWidth) hostMMU0 <- mkMMU(0, True, hostMMU0ConfigIndicationProxy.ifc);
   MMUConfigRequestWrapper hostMMU0ConfigRequestWrapper <- mkMMUConfigRequestWrapper(HostMMU0ConfigRequest, hostMMU0.request);
   
   MMUConfigIndicationProxy hostMMU1ConfigIndicationProxy <- mkMMUConfigIndicationProxy(HostMMU1ConfigIndication);
   MMU#(PhysAddrWidth) hostMMU1 <- mkMMU(1, True, hostMMU1ConfigIndicationProxy.ifc);
   MMUConfigRequestWrapper hostMMU1ConfigRequestWrapper <- mkMMUConfigRequestWrapper(HostMMU1ConfigRequest, hostMMU1.request);
   
   MMUConfigIndicationProxy hostMMU2ConfigIndicationProxy <- mkMMUConfigIndicationProxy(HostMMU2ConfigIndication);
   MMU#(PhysAddrWidth) hostMMU2 <- mkMMU(2, True, hostMMU2ConfigIndicationProxy.ifc);
   MMUConfigRequestWrapper hostMMU2ConfigRequestWrapper <- mkMMUConfigRequestWrapper(HostMMU2ConfigRequest, hostMMU2.request);

   MMUConfigIndicationProxy hostMMU3ConfigIndicationProxy <- mkMMUConfigIndicationProxy(HostMMU3ConfigIndication);
   MMU#(PhysAddrWidth) hostMMU3 <- mkMMU(3, True, hostMMU3ConfigIndicationProxy.ifc);
   MMUConfigRequestWrapper hostMMU3ConfigRequestWrapper <- mkMMUConfigRequestWrapper(HostMMU3ConfigRequest, hostMMU3.request);
   
   Vector#(1,  MemReadClient#(64))   readClients = cons(memcpy.dmaReadClient, nil);
   Vector#(1, MemWriteClient#(64))  writeClients = cons(memcpy.dmaWriteClient, nil);

   DmaDebugIndicationProxy hostDmaDebugIndicationProxy <- mkDmaDebugIndicationProxy(HostDmaDebugIndication);
   let sgls = cons(hostMMU0,cons(hostMMU1, cons(hostMMU2,cons(hostMMU3,nil))));  
   MemServer#(PhysAddrWidth,64,1) dma <- mkMemServerRW(hostDmaDebugIndicationProxy.ifc, readClients, writeClients, sgls);
   DmaDebugRequestWrapper hostDmaDebugRequestWrapper <- mkDmaDebugRequestWrapper(HostDmaDebugRequest, dma.request);

   Vector#(12,StdPortal) portals;
   portals[0] = memcpyRequestWrapper.portalIfc;
   portals[1] = memcpyIndicationProxy.portalIfc; 
   portals[2] = hostDmaDebugRequestWrapper.portalIfc;
   portals[3] = hostDmaDebugIndicationProxy.portalIfc; 
   
   portals[4] = hostMMU0ConfigRequestWrapper.portalIfc;
   portals[5] = hostMMU0ConfigIndicationProxy.portalIfc;
   
   portals[6] = hostMMU1ConfigRequestWrapper.portalIfc;
   portals[7] = hostMMU1ConfigIndicationProxy.portalIfc;
   
   portals[8] = hostMMU2ConfigRequestWrapper.portalIfc;
   portals[9] = hostMMU2ConfigIndicationProxy.portalIfc;

   portals[10] = hostMMU3ConfigRequestWrapper.portalIfc;
   portals[11] = hostMMU3ConfigIndicationProxy.portalIfc;
   let ctrl_mux <- mkSlaveMux(portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = dma.masters;
   interface leds = default_leds;
endmodule


