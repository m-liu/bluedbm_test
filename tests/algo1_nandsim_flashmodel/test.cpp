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

#include <fstream>
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/mman.h>
#include <assert.h>
#include <mp.h>

#include "StdDmaIndication.h"
#include "MMURequest.h"
#include "GeneratedTypes.h" 
#include "StrstrIndication.h"
#include "StrstrRequest.h"

static int trace_memory = 1;
extern "C" {
#include "sys/ioctl.h"
#include "portalmem.h"
#include "sock_utils.h"
#include "dmaManager.h"
#include "userReference.h"
}

#include "nandsim.h"
#include "strstr.h"

size_t numBytes = 1 << 10;

int main(int argc, const char **argv)
{
  fprintf(stderr, "Main::%s %s\n", __DATE__, __TIME__);

  MMURequestProxy *hostMMURequest = new MMURequestProxy(IfcNames_AlgoMMURequest);
  DmaManager *hostDma = new DmaManager(hostMMURequest);
  MMUIndication *hostMMUIndication = new MMUIndication(hostDma, IfcNames_AlgoMMUIndication);

  MMURequestProxy *nandsimMMURequest = new MMURequestProxy(IfcNames_NandsimMMU0Request);
  DmaManager *nandsimDma = new DmaManager(nandsimMMURequest);
  MMUIndication *nandsimMMUIndication = new MMUIndication(nandsimDma,IfcNames_NandsimMMU0Indication);

  StrstrRequestProxy *strstrRequest = new StrstrRequestProxy(IfcNames_AlgoRequest);
  StrstrIndication *strstrIndication = new StrstrIndication(IfcNames_AlgoIndication);
  
  MemServerIndication *hostMemServerIndication = new MemServerIndication(IfcNames_HostMemServerIndication);
  MemServerIndication *nandsimMemServerIndication = new MemServerIndication(IfcNames_NandsimMemServer0Indication);

  portalExec_start();
  fprintf(stderr, "Main::allocating memory...\n");

  // allocate memory for strstr data
  int needleAlloc = portalAlloc(numBytes);
  int mpNextAlloc = portalAlloc(numBytes);
  int ref_needleAlloc = hostDma->reference(needleAlloc);
  int ref_mpNextAlloc = hostDma->reference(mpNextAlloc);

  fprintf(stderr, "%08x %08x\n", ref_needleAlloc, ref_mpNextAlloc);

  char *needle = (char *)portalMmap(needleAlloc, numBytes);
  int *mpNext = (int *)portalMmap(mpNextAlloc, numBytes);

  const char *needle_text = "ababab";
  int needle_len = strlen(needle_text);
  strncpy(needle, needle_text, needle_len);
  compute_MP_next(needle, mpNext, needle_len);

  // fprintf(stderr, "mpNext=[");
  // for(int i= 0; i <= needle_len; i++) 
  //   fprintf(stderr, "%d ", mpNext[i]);
  // fprintf(stderr, "]\nneedle=[");
  // for(int i= 0; i < needle_len; i++) 
  //   fprintf(stderr, "%d ", needle[i]);
  // fprintf(stderr, "]\n");

  portalDCacheFlushInval(needleAlloc, numBytes, needle);
  portalDCacheFlushInval(mpNextAlloc, numBytes, mpNext);
  fprintf(stderr, "Main::flush and invalidate complete\n");

  fprintf(stderr, "Main::waiting to connect to nandsim_exe\n");
  wait_for_connect_nandsim_exe();
  fprintf(stderr, "Main::connected to nandsim_exe\n");
  // base of haystack in "flash" memory
  // this is read from nandsim_exe, but could also come from kernel driver
  int haystack_base = read_from_nandsim_exe();
  int haystack_len  = read_from_nandsim_exe();

  // request the next sglist identifier from the sglistMMU hardware module
  // which is used by the mem server accessing flash memory.
  int id = 0;
  MMURequest_idRequest(nandsimDma->priv.sglDevice, 0);
  sem_wait(&nandsimDma->priv.sglIdSem);
  id = nandsimDma->priv.sglId;
  // pairs of ('offset','size') pointing to space in nandsim memory
  // this is unsafe.  To do it properly, we should get this list from
  // nandsim_exe or from the kernel driver.  This code here might overrun
  // the backing store allocated by nandsim_exe.
  RegionRef region[] = {{0, 0x100000}, {0x100000, 0x100000}};
  printf("[%s:%d]\n", __FUNCTION__, __LINE__);
  int ref_haystackInNandMemory = send_reference_to_portal(nandsimDma->priv.sglDevice, sizeof(region)/sizeof(region[0]), region, id);
  sem_wait(&(nandsimDma->priv.confSem));
  fprintf(stderr, "%08x\n", ref_haystackInNandMemory);

  // at this point, ref_needleAlloc and ref_mpNextAlloc are valid sgListIds for use by 
  // the host memory dma hardware, and ref_haystackInNandMemory is a valid sgListId for
  // use by the nandsim dma hardware

  fprintf(stderr, "about to setup device %d %d\n", ref_needleAlloc, ref_mpNextAlloc);
  strstrRequest->setup(ref_needleAlloc, ref_mpNextAlloc, needle_len);
  fprintf(stderr, "about to invoke search %d\n", ref_haystackInNandMemory);
  strstrRequest->search(ref_haystackInNandMemory, haystack_len);
  strstrIndication->wait();  

  exit(!(strstrIndication->match_cnt==3));
}
