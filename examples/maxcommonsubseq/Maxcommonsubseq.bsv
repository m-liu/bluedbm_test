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


import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPutF::*;
import Vector::*;
import BRAM::*;
import Gearbox::*;

import AxiMasterSlave::*;
import Dma::*;
import DmaUtils::*;
import MPEngine::*;

/* This module solves the maximum common subsequence problem.
 * It finds the longest subsequence of characters present in both input strings
 * the subsequence does not have to be contiguous and the characters can have different locations
 * and offsets in the two strings, just so long as they occur in the same order
 *
 *  To initialize, load string A with request setupA, and wait for indication setup complete
 * Then load string B with request setupB, and wait for indication setup complete
 * To start the unit, signal start, and wait for searchResult, which will tell you the length
 * To retreive the result, use fetch and wait for fetchComplete
 */

/* First pass implements Hirschberg Algorithm A and the fetch call returns the L matrix
 */
interface MaxcommonsubseqRequest;
   method Action setupA(Bit#(32) strPointer, Bit#(32) strLen);
   method Action setupB(Bit#(32) strPointer, Bit#(32) strLen);
   method Action fetch(Bit#(32) strPointer, Bit#(32) strLen);
   method Action start();
endinterface

interface MaxcommonsubseqIndication;
   method Action searchResult(Int#(32) v);
   method Action setupComplete(); 
   method Action fetchComplete(); 
endinterface


typedef 128 MaxStringLen;
typedef Bit#(TLog#(MaxStringLen)) StringIdx;
typedef Bit#TLog#(MaxStringLen*MaxStringLen)) LIdx;

module mkMaxcommonsubseqRequest#(MaxcommonsubseqIndication indication,
			DmaReadServer#(busWidth)   setupA_read_server,
			DmaReadServer#(busWidth)   setupB_read_server,
			DmaWriteServer#(busWidth)   fetch_write_server )(MaxcommonsubseqRequest)
   
   provisos(Add#(a__, 8, busWidth),
	    Div#(busWidth,8,nc),
	    Mul#(nc,8,busWidth),
	    Add#(1, b__, nc),
	    Add#(c__, 32, busWidth),
	    Add#(1, d__, TDiv#(busWidth, 32)),
	    Mul#(TDiv#(busWidth, 32), 32, busWidth),
	    Log#(p,lp));
   
  Reg#(Bit#(32)) aLen <- mkreg(0);
  Reg#(Bit#(32)) bLen <- mkreg(0);
  Reg#(Bit#(32)) rLen <- mkreg(0);
  
   BRAM2Port#(StringIdx, Char) strA  <- mkBRAM2Server(defaultValue);
   BRAM2Port#(StringIdx, Char) strB <- mkBRAM2Server(defaultValue);

   BRAM2Port#(LIdx, Bit#(StringIdx)) matL <- mkBRAM2Server(defaultValue);

   BRAMReadClient#(StringIdx,busWidth) n2a <- mkBRAMReadClient(strA.portB);
   mkConnection(n2a.dmaClient, setupA_read_server);
   BRAMReadClient#(StringIdx,busWidth) n2b <- mkBRAMReadClient(strB.portB);
   mkConnection(n2b.dmaClient, setupB_read_server);


   // create BRAM Write client for matL
