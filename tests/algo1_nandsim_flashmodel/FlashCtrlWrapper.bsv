import FIFOF::*;
import FIFO::*;
import BRAMFIFO::*;
import BRAM::*;
import GetPut::*;
import ClientServer::*;
import Vector::*;
import RegFile::*;

import ControllerTypes::*;
import FlashCtrlModel::*;
import FlashBusModel::*;
import MemTypes::*;

interface FlashCtrlWrapper;
	interface MemReadServer#(64) readServer;
	interface MemWriteServer#(64) writeServer;
endinterface


module mkFlashCtrlWrapper(FlashCtrlWrapper);

	FlashCtrlUser flashCtrl <- mkFlashCtrlModel();
	FIFO#(MemRequest) readReqQ <- mkSizedFIFO(valueOf(NumTags));
	FIFO#(MemRequest) writeReqQ <- mkSizedFIFO(valueOf(NumTags));

	Vector#(NumTags, Reg#(Bit#(16))) tagBurstCntUpTable <- replicateM(mkReg(0));
	Vector#(NumTags, Reg#(Bit#(16))) tagBurstCntDownTable <- replicateM(mkReg(0));
	FIFO#(Tuple2#(Bit#(128), TagT)) rdataBufQ <- mkFIFO();
	FIFO#(MemData#(64)) readDataQ <- mkFIFO();
	FIFO#(MemData#(64)) writeDataQ <- mkFIFO();
	FIFO#(Bit#(MemTagSize)) writeDoneQ <- mkFIFO();


	//FIXME: because right now tags are not really been enforced; block 
	rule handleReadCmd;
		let req = readReqQ.first;

		//if (req.burstLen != fromInteger(pageWords*2)) begin //64-bit bursts. 8KB data
		//	$display("ERROR: burst length must be 8KB");
		//end

		let tagBurstCntRemain = tagBurstCntUpTable[req.tag] - tagBurstCntDownTable[req.tag];
		if (tagBurstCntRemain==0) begin
			//TODO: seems like sglID can be ignored. Only applicable for nandsim
			//Offset currently defined as 40-bits (MemOffsetSize)
			//Use naiive remapping to bus, chip, blk, page
			//All map to same chip/bus for in order read data
			tagBurstCntUpTable[req.tag] <= fromInteger(pageWords);
			FlashCmd cmd = FlashCmd {
				tag: zeroExtend(req.tag), 
				//FIXME DANGEROUS TRUNCATION!, 
				//but all tags are expected to be 0 right now
				op: READ_PAGE,
				bus: 0,
				chip: 0,
				block: truncate(req.offset),
				page: 0
			};
			flashCtrl.sendCmd(cmd);
			readReqQ.deq;
		end
		else begin
			$display("WARNING: tag is busy, command should not have been issued");
		end
	endrule

	rule buffReadData;
		let taggedRdata <- flashCtrl.readWord();
		rdataBufQ.enq(taggedRdata);
	endrule

	Reg#(Bit#(1)) phase <- mkReg(0);
	rule fwdReadData;
		let taggedRdata = rdataBufQ.first;
		let data = tpl_1(taggedRdata);
		let tag = tpl_2(taggedRdata);
		phase <= phase + 1; //truncated to 1 bit
		if (phase==0) begin
			//update tag cnt table	
			tagBurstCntDownTable[tag] <= tagBurstCntDownTable[tag] + 1;
			//send upper 64-bits
			Bit#(64) upperData = truncateLSB(data);
			MemData#(64) memD = MemData { 
											data: upperData,
											tag: truncate(tag), //again DANGEROUS. FIXME
											last: False //never last
										};
			readDataQ.enq(memD);
		end
		else begin
			rdataBufQ.deq;
			Bool last = (tagBurstCntUpTable[tag] - tagBurstCntDownTable[tag]==0); 
			//send lower 64 bit
			Bit#(64) lowerData = truncate(data);
			MemData#(64) memD = MemData { 
											data: lowerData,
											tag: truncate(tag), //again DANGEROUS. FIXME
											last: last //never last
										};
			readDataQ.enq(memD);
		end
	endrule

	interface MemReadServer readServer;
		interface Put readReq = toPut(readReqQ);
		interface Get readData = toGet(readDataQ);
	endinterface

	interface MemWriteServer writeServer;
		interface Put writeReq = toPut(writeReqQ);
		interface Put writeData = toPut(writeDataQ);
		interface Get writeDone = toGet(writeDoneQ);
	endinterface


endmodule
