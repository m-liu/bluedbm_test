/* Copyright (c) 2013 Quanta Research Cambridge, Inc
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


#include <stdio.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <string.h>
#include <semaphore.h>
#include <iostream>
#include <fstream>
#include <sys/stat.h>

#include "StdDmaIndication.h"
#include "RegexpIndication.h"
#include "RegexpRequest.h"
#include "MemServerRequest.h"
#include "MMURequest.h"

#include "regexp_utils.h"

int main(int argc, const char **argv)
{

  fprintf(stderr, "%s %s\n", __DATE__, __TIME__);

  RegexpRequestProxy *device = new RegexpRequestProxy(IfcNames_RegexpRequest);
  MemServerRequestProxy *hostMemServerRequest = new MemServerRequestProxy(IfcNames_HostMemServerRequest);
  MMURequestProxy *hostMMURequest = new MMURequestProxy(IfcNames_HostMMURequest);
  DmaManager *hostDma = new DmaManager(hostMMURequest);
  MemServerIndication *hostMemServerIndication = new MemServerIndication(hostMemServerRequest, IfcNames_HostMemServerIndication);
  MMUIndication *hostMMUIndication = new MMUIndication(hostDma, IfcNames_HostMMUIndication);
  RegexpIndication *deviceIndication = new RegexpIndication(IfcNames_RegexpIndication);
  
  haystack_dma = hostDma;
  haystack_mmu = hostMMURequest;
  regexp = device;

  if(sem_init(&test_sem, 1, 0)){
    fprintf(stderr, "failed to init test_sem\n");
    return -1;
  }
  portalExec_start();

  // this is hard-coded into the REParser.java
  assert(32 == MAX_NUM_STATES);
  assert(32 == MAX_NUM_CHARS);

  if(1){
    P charMapP;
    P stateMapP;
    P stateTransitionsP;
    
    readfile("jregexp.charMap", &charMapP);
    readfile("jregexp.stateMap", &stateMapP);
    readfile("jregexp.stateTransitions", &stateTransitionsP);

    portalDCacheFlushInval(charMapP.alloc,          charMapP.length,          charMapP.mem);
    portalDCacheFlushInval(stateMapP.alloc,         stateMapP.length,         stateMapP.mem);
    portalDCacheFlushInval(stateTransitionsP.alloc, stateTransitionsP.length, stateTransitionsP.mem);

    for(int i = 0; i < num_tests; i++){

      device->setup(charMapP.ref, charMapP.length);
      device->setup(stateMapP.ref, stateMapP.length);
      device->setup(stateTransitionsP.ref, stateTransitionsP.length);

      readfile("test.bin", &haystackP[i]);
      portalDCacheFlushInval(haystackP[i].alloc, haystackP[i].length, haystackP[i].mem);

      if(i==0)
	sw_match_cnt = num_tests*sw_ref(&haystackP[0], &charMapP, &stateMapP, &stateTransitionsP);

      sem_wait(&test_sem);
      int token = deviceIndication->token;

      assert(token < max_num_tokens);
      token_map[token] = i;
      // Regexp uses a data-bus width of 8 bytes.  length must be a multiple of this dimension
      device->search(token, haystackP[i].ref, haystackP[i].length & ~((1<<3)-1));
    }

    sem_wait(&test_sem);
    close(charMapP.alloc);
    close(stateMapP.alloc);
    close(stateTransitionsP.alloc);
  }
  portalExec_stop();
  fprintf(stderr, "hw_match_cnt=%d, sw_match_cnt=%d\n", hw_match_cnt, sw_match_cnt);
  return (hw_match_cnt == sw_match_cnt ? 0 : -1);
}
