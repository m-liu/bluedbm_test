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

import Vector::*;
import ClientServer::*;
import BRAM::*;

import ConnectalMemory::*;
import MemTypes::*;
import BlueScope::*;
import MemreadEngine::*;
import MemwriteEngine::*;
import Dma2BRAM::*;
import Pipe::*;


interface TestRequest;
   method Action startWrite(Bit#(32) sglId);
endinterface

interface TestIndication;
   method Action writeDone(Bit#(32) v);
endinterface

interface Test;
   interface TestRequest request;
   interface MemReadClient#(64) readClient;
endinterface

module mkTestRequest#(TestIndication indication)(Test);
   
   MemreadEngine#(64,1)  re <- mkMemreadEngine;
   BRAM1Port#(Bit#(10),Bit#(8)) bram <- mkBRAM1Server(defaultValue);
   BRAMWriter#(10,64) bramWriter <- mkBRAMWriter(2, bram.portA, re.read_servers[0].cmdServer, re.read_servers[0].dataPipe);
      
   rule finishWrite;
      let rv <- bramWriter.finish;
      indication.writeDone(0);
   endrule
   
   interface TestRequest request;
      method Action startWrite(Bit#(32) sglId);
	 bramWriter.start(sglId, 0, minBound, maxBound);
      endmethod
   endinterface
   interface readClient = re.dmaClient;
endmodule

