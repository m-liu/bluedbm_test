// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;


// portz libraries
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;
import PortalMemory::*;
import AxiDma::*;
import Dma::*;
import DmaUtils::*;

// generated by tool
import MempokeRequestWrapper::*;
import DmaConfigWrapper::*;
import MempokeIndicationProxy::*;
import DmaIndicationProxy::*;

// defined by user
import Mempoke::*;

module mkPortalTop(StdPortalTop#(addrWidth)) 

   provisos(Add#(addrWidth, a__, 52),
	    Add#(b__, addrWidth, 64),
	    Add#(c__, 12, addrWidth),
	    Add#(addrWidth, d__, 44),
	    Add#(e__, c__, 40),
	    Add#(f__, addrWidth, 40));

   DmaIndicationProxy dmaIndicationProxy <- mkDmaIndicationProxy(9);
   DmaWriteBuffer#(64,16) dma_stream_write_chan <- mkDmaWriteBuffer();
   DmaReadBuffer#(64,16) dma_stream_read_chan <- mkDmaReadBuffer();

   Vector#(1, DmaReadClient#(64))   readClients = newVector();
   Vector#(1, DmaWriteClient#(64)) writeClients = newVector();
   writeClients[0] = dma_stream_write_chan.dmaClient;
   readClients[0]  = dma_stream_read_chan.dmaClient;
   Integer               numRequests = 8;
   AxiDmaServer#(addrWidth,64)   dma <- mkAxiDmaServer(dmaIndicationProxy.ifc, numRequests, readClients, writeClients);
   DmaConfigWrapper dmaRequestWrapper <- mkDmaConfigWrapper(1005,dma.request);

   
   MempokeIndicationProxy mempokeIndicationProxy <- mkMempokeIndicationProxy(7);
   MempokeRequest mempokeRequest <- mkMempokeRequest(mempokeIndicationProxy.ifc, dma_stream_write_chan.dmaServer, dma_stream_read_chan.dmaServer);
   MempokeRequestWrapper mempokeRequestWrapper <- mkMempokeRequestWrapper(1008,mempokeRequest);

   Vector#(4,StdPortal) portals;
   portals[0] = mempokeRequestWrapper.portalIfc;
   portals[1] = mempokeIndicationProxy.portalIfc; 
   portals[2] = dmaRequestWrapper.portalIfc;
   portals[3] = dmaIndicationProxy.portalIfc; 
   
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
