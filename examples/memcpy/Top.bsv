// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;

// portz libraries
import AxiMasterSlave::*;
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;
import BlueScope::*;
import PortalMemory::*;
import Dma::*;
import DmaUtils::*;
import AxiDma::*;

// generated by tool
import MemcpyRequestWrapper::*;
import BlueScopeRequestWrapper::*;
import DmaConfigWrapper::*;
import MemcpyIndicationProxy::*;
import BlueScopeIndicationProxy::*;
import DmaIndicationProxy::*;

// defined by user
import Memcpy::*;

typedef enum {MemcpyIndication, MemcpyRequest, DmaIndication, DmaConfig, BluescopeIndication, BluescopeRequest} IfcNames deriving (Eq,Bits);

module mkPortalTop(StdPortalTop#(addrWidth)) 

   provisos(Add#(addrWidth, a__, 52),
	    Add#(b__, addrWidth, 64),
	    Add#(c__, 12, addrWidth),
	    Add#(addrWidth, d__, 44),
	    Add#(e__, c__, 40),
	    Add#(f__, addrWidth, 40));

   DmaIndicationProxy dmaIndicationProxy <- mkDmaIndicationProxy(DmaIndication);
   DmaReadBuffer#(64,8)   dma_stream_read_chan <- mkDmaReadBuffer();
   DmaWriteBuffer#(64,8) dma_stream_write_chan <- mkDmaWriteBuffer();
   DmaReadBuffer#(64,8)     dma_word_read_chan <- mkDmaReadBuffer();
   DmaWriteBuffer#(64,8)  dma_debug_write_chan <- mkDmaWriteBuffer();

   Vector#(2,  DmaReadClient#(64))   readClients = newVector();
   readClients[0] = dma_stream_read_chan.dmaClient;
   readClients[1] = dma_word_read_chan.dmaClient;

   Vector#(2, DmaWriteClient#(64)) writeClients = newVector();
   writeClients[0] = dma_stream_write_chan.dmaClient;
   writeClients[1] = dma_debug_write_chan.dmaClient;

   Integer               numRequests = 8;
   AxiDmaServer#(addrWidth, 64)   dma <- mkAxiDmaServer(dmaIndicationProxy.ifc, numRequests, readClients, writeClients);

   DmaConfigWrapper dmaRequestWrapper <- mkDmaConfigWrapper(DmaConfig,dma.request);

   BlueScopeIndicationProxy blueScopeIndicationProxy <- mkBlueScopeIndicationProxy(BluescopeIndication);
   BlueScope#(64) bs <- mkBlueScope(32, dma_debug_write_chan.dmaServer, blueScopeIndicationProxy.ifc);
   BlueScopeRequestWrapper blueScopeRequestWrapper <- mkBlueScopeRequestWrapper(BluescopeRequest,bs.requestIfc);

   MemcpyIndicationProxy memcpyIndicationProxy <- mkMemcpyIndicationProxy(MemcpyIndication);
   MemcpyRequest memcpyRequest <- mkMemcpyRequest(memcpyIndicationProxy.ifc, dma_stream_read_chan.dmaServer,
						  dma_stream_write_chan.dmaServer, dma_word_read_chan.dmaServer, bs);
   MemcpyRequestWrapper memcpyRequestWrapper <- mkMemcpyRequestWrapper(MemcpyRequest,memcpyRequest);

   Vector#(6,StdPortal) portals;
   portals[0] = memcpyRequestWrapper.portalIfc;
   portals[1] = memcpyIndicationProxy.portalIfc; 
   portals[2] = blueScopeRequestWrapper.portalIfc;
   portals[3] = blueScopeIndicationProxy.portalIfc; 
   portals[4] = dmaRequestWrapper.portalIfc;
   portals[5] = dmaIndicationProxy.portalIfc; 
   
   StdDirectory dir <- mkStdDirectory(portals);
   Vector#(1,StdPortal) directories;
   directories[0] = dir.portalIfc;
   
   // when constructing ctrl and interrupt muxes, directories must be the first argument
   let ctrl_mux <- mkAxiSlaveMux(directories,portals);
   let interrupt_mux <- mkInterruptMux(portals);
   
   interface interrupt = interrupt_mux;
   interface ctrl = ctrl_mux;
   interface m_axi = dma.m_axi;
   interface leds = default_leds;
endmodule


