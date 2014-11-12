/* Copyright (c) 2014 Quanta Research Cambridge, Inc
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
import FIFOF::*;
import FIFO::*;
import BRAMFIFO::*;
import BRAM::*;
import GetPut::*;
import ClientServer::*;
import Vector::*;
import RegFile::*;


import ControllerTypes::*;
//import FlashCtrlVirtex::*;
import FlashBusModel::*;



(* synthesize *)
(* descending_urgency = "forwardReads, forwardReads_1, forwardReads_2, forwardReads_3, forwardReads_4, forwardReads_5, forwardReads_6, forwardReads_7" *) 
(* descending_urgency = "forwardWrDataReq, forwardWrDataReq_1, forwardWrDataReq_2, forwardWrDataReq_3, forwardWrDataReq_4, forwardWrDataReq_5, forwardWrDataReq_6, forwardWrDataReq_7" *)
(* descending_urgency = "forwardAck, forwardAck_1, forwardAck_2, forwardAck_3, forwardAck_4, forwardAck_5, forwardAck_6, forwardAck_7" *)
module mkFlashCtrlModel(FlashCtrlUser);

	//Flash bus models
	Vector#(NUM_BUSES, FlashBusModelIfc) flashBuses <- replicateM(mkFlashBusModel());

	RegFile#(TagT, FlashCmd) tagTable <- mkRegFileFull();
	FIFO#(Tuple2#(Bit#(WordSz), TagT)) rdDataQ <- mkSizedFIFO(16); //TODO size?
	FIFO#(TagT) wrDataReqQ <- mkSizedFIFO(16);
	FIFO#(Tuple2#(TagT, StatusT)) ackQ <- mkSizedFIFO(16);
	
	//GTX-GTP Aurora. Unused in model
	//AuroraIfc auroraIntra <- mkAuroraIntra(gtx_clk_p, gtx_clk_n, clk250);


	//handle reads, acks, writedataReq
	for (Integer b=0; b < valueOf(NUM_BUSES); b=b+1) begin
		rule forwardReads;
			let rd <- flashBuses[b].readWord();
			rdDataQ.enq(rd);
		endrule

		rule forwardWrDataReq;
			let req <- flashBuses[b].writeDataReq();
			wrDataReqQ.enq(req);
		endrule
	
		rule forwardAck;
			let ack <- flashBuses[b].ackStatus();
			ackQ.enq(ack);
		endrule
	end


		method Action sendCmd (FlashCmd cmd);
			tagTable.upd(cmd.tag, cmd);
			flashBuses[cmd.bus].sendCmd(cmd);
			$display("FlashEmu: received cmd: tag=%d, bus=%d, chip=%d, blk=%d, page=%d", cmd.tag, cmd.bus, cmd.chip, cmd.block, cmd.page);
		endmethod
		method Action writeWord (Tuple2#(Bit#(WordSz), TagT) taggedData);
			FlashCmd cmd = tagTable.sub(tpl_2(taggedData));
			flashBuses[cmd.bus].writeWord(taggedData);
		endmethod
			
		method ActionValue#(Tuple2#(Bit#(WordSz), TagT)) readWord ();
			rdDataQ.deq();
			return rdDataQ.first();
		endmethod

		method ActionValue#(TagT) writeDataReq();
			wrDataReqQ.deq();
			return wrDataReqQ.first();
		endmethod

		method ActionValue#(Tuple2#(TagT, StatusT)) ackStatus();
			ackQ.deq();
			return ackQ.first();
		endmethod

endmodule



	/*
	rule doHandleCmd if (state==SEND_DATA);
		FlashCmd cmd = flashCmdQ.first;
		Bit#(16) data0 = truncate(rdataCnt);
		Bit#(16) data1 = zeroExtend(cmd.tag);
		Bit#(16) data2 = zeroExtend(cmd.bus);
		Bit#(16) data3 = zeroExtend(cmd.chip);
		Bit#(16) data4 = zeroExtend(cmd.block);
		Bit#(16) data5 = zeroExtend(cmd.page);
		Bit#(128) rData = zeroExtend({data0, data1, data2, data3, data4, data5});
		rdDataQ.enq(tuple2(rData, cmd.tag));
		$display("@%t: Flash Emu enqueued cnt=%d, tag=%x, data=%x", $time, rdataCnt, cmd.tag, rData);

		if (rdataCnt == fromInteger(pageSizeUser/16)-1) begin
			state <= FINISHED_CMD;
			rdataCnt <= 0;
		end
		else begin
			state <= WAIT;
			rdataCnt <= rdataCnt + 1;
		end

	endrule

	rule doWait if (state==WAIT);
		if (waitCnt == 0) begin
			state <= SEND_DATA;
			waitCnt <= fromInteger(waitCycles);
		end
		else begin
			waitCnt <= waitCnt - 1;
		end
	endrule


	rule doFinish if (state==FINISHED_CMD);
		flashCmdQ.deq;
		let cmd = flashCmdQ.first;
		state <= SEND_DATA;
		$display("@%t: Flash Emu: finished command tag=%x, bus=%x, chip=%x, block=%x, page=%x", $time,
			cmd.tag, cmd.bus, cmd.chip, cmd.block, cmd.page);	
	endrule
	*/
