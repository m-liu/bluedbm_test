/* Copyright (c) 2014 Sungjin Lee, MIT
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

#ifdef __KERNEL__
#include <linux/delay.h>  // msleep
#include <linux/kthread.h>
#else
#include <string.h>
#include <sys/mman.h>
#include <pthread.h>
#include <fcntl.h>
#include <sys/select.h>
#endif

#include "dmaManager.h"
#include "sock_utils.h"  // bsim_poll_interrupt()
#include "GeneratedTypes.h" 

#include "portalmem.h"

static int trace_memory;// = 1;

#define MAX_INDARRAY 4
static PortalInternal intarr[MAX_INDARRAY];

static sem_t test_sem;
static int burstLen = 16;
#ifndef BSIM
#define numWords 0x1240000/4 // make sure to allocate at least one entry of each size
#else
#define numWords 0x1240/4
#endif
static long back_sz  = numWords*sizeof(unsigned int);
static DmaManagerPrivate priv;

void NandSimIndicationWrappereraseDone_cb (  struct PortalInternal *p, const uint32_t tag )
{
  PORTAL_PRINTF( "cb: NandSim_eraseDone(tag = %x)\n", tag);
  sem_post(&test_sem);
}

void NandSimIndicationWrapperwriteDone_cb (  struct PortalInternal *p, const uint32_t tag )
{
  PORTAL_PRINTF( "cb: NandSim_writeDone(tag = %x)\n", tag);
  sem_post(&test_sem);
}

void NandSimIndicationWrapperreadDone_cb (  struct PortalInternal *p, const uint32_t tag )
{
  PORTAL_PRINTF( "cb: NandSim_readDone(tag = %x)\n", tag);
  sem_post(&test_sem);
}

void NandSimIndicationWrapperconfigureNandDone_cb (  struct PortalInternal *p )
{
  PORTAL_PRINTF( "cb: NandSim_NandDone\n");
  sem_post(&test_sem);
}

void MMUConfigIndicationWrapperconfigResp_cb (  struct PortalInternal *p, const uint32_t pointer )
{
  PORTAL_PRINTF("cb: MMUConfigIndicationWrapperconfigResp_cb(physAddr=%x)\n", pointer);
  sem_post(&priv.confSem);
}

void MMUConfigIndicationWrapperidResponse_cb (  struct PortalInternal *p, const uint32_t sglId ) 
{
  PORTAL_PRINTF("cb: MMUConfigIndicationWrapperidResponse_cb\n");
  priv.sglId = sglId;
  sem_post(&priv.sglIdSem);
}

void MMUConfigIndicationWrappererror_cb (  struct PortalInternal *p, const uint32_t code, const uint32_t pointer, const uint64_t offset, const uint64_t extra ) 
{
  PORTAL_PRINTF("cb: MMUConfigIndicationWrappererror_cb\n");
}

void manual_event(void)
{
    int i;
    for (i = 0; i < MAX_INDARRAY; i++)
      portalCheckIndication(&intarr[i]);
}

#ifdef __KERNEL__
DECLARE_COMPLETION(worker_completion);
#endif
static void *pthread_worker(void *p)
{
    void *rc = NULL;
    while (1) {
#if defined(BSIM) && !defined(__KERNEL__)
        if (bsim_poll_interrupt())
#endif
        manual_event();
#ifdef __KERNEL__
        msleep(10);
        if (kthread_should_stop()) {
		    PORTAL_PRINTF ("pthread_worker ends\n");
            break;
		}
#else ///////////////////////// userspace version
        struct timeval timeout;
        timeout.tv_sec = 0;
        timeout.tv_usec = 10000;
        select(0, NULL, NULL, NULL, &timeout);
#endif
    }
#ifdef __KERNEL__
    complete(&worker_completion);
#endif
    return rc;
}
NandSimIndicationWrapperCb NandSimIndication_cbTable = {
    NandSimIndicationWrappereraseDone_cb,
    NandSimIndicationWrapperwriteDone_cb,
    NandSimIndicationWrapperreadDone_cb,
    NandSimIndicationWrapperconfigureNandDone_cb,
};
MMUConfigIndicationWrapperCb MMUConfigIndication_cbTable = {
    MMUConfigIndicationWrapperconfigResp_cb,
    MMUConfigIndicationWrapperidResponse_cb,
    MMUConfigIndicationWrappererror_cb,
};
int main(int argc, const char **argv)
{
  int srcAlloc;
  int backAlloc;
  unsigned int *srcBuffer;
  unsigned int ref_srcAlloc;
  unsigned int *backBuffer;
  unsigned int ref_backAlloc;
  int rc = 0, i;
  pthread_t tid = 0;


  init_portal_internal(&intarr[2], IfcNames_BackingStoreMMUConfigRequest, NULL, NULL, MMUConfigRequestProxy_reqsize);         // fpga3
  init_portal_internal(&intarr[0], IfcNames_BackingStoreMMUConfigIndication, MMUConfigIndicationWrapper_handleMessage, MMUConfigIndication_cbTable, MMUConfigIndicationWrapper_reqsize);     // fpga1
  init_portal_internal(&intarr[3], IfcNames_NandSimRequest, NULL, NULL, NandSimRequestProxy_reqsize);    // fpga4
  init_portal_internal(&intarr[1], IfcNames_NandSimIndication, NandSimIndicationWrapper_handleMessage, NandSimIndication_cbTable, NandSimIndicationWrapper_reqsize); // fpga2

  DmaManager_init(&priv, NULL, &intarr[2]);
  sem_init(&test_sem, 0, 0);

  PORTAL_PRINTF( "Main: creating exec thread - %lu\n", sizeof (unsigned int) );
  if(pthread_create(&tid, NULL, pthread_worker, NULL)){
   PORTAL_PRINTF( "error creating exec thread\n");
   return -1;
  }

  backAlloc = portalAlloc (back_sz);
  PORTAL_PRINTF("backAlloc=%d\n", backAlloc);

  ref_backAlloc = DmaManager_reference(&priv, backAlloc);
  PORTAL_PRINTF("ref_backAlloc=%d\n", ref_backAlloc);

  backBuffer = (unsigned int*)portalMmap(backAlloc, back_sz); 
  portalDCacheFlushInval(backAlloc, back_sz, backBuffer);

  NandSimRequestProxy_configureNand (&intarr[3], ref_backAlloc, back_sz);
  PORTAL_PRINTF("Main::configure NAND fd=%d ref=%d\n", backAlloc, ref_backAlloc);
  sem_wait(&test_sem);

  srcAlloc = portalAlloc(back_sz);
  srcBuffer = (unsigned int *)portalMmap(srcAlloc, back_sz);
  ref_srcAlloc = DmaManager_reference(&priv, srcAlloc);

  PORTAL_PRINTF("about to start write\n");
  //write data to "flash" memory
  strcpy((char*)srcBuffer, "acabcabacababacababababababcacabcabacababacabababc\n012345678912");
  NandSimRequestProxy_startWrite(&intarr[3], ref_srcAlloc, 0, 0, 1024, 8);
  sem_wait(&test_sem);

  // at this point, if we were synchronizing with the algo_exe, we
  // could tell it that it was OK to start searching
  PORTAL_PRINTF ("initialization of data in \"flash\" memory complete\n");

#ifdef __KERNEL__
  if (tid && !kthread_stop (tid)) {
    PORTAL_PRINTF ("kthread stops\n");
  }
  wait_for_completion(&worker_completion);
  msleep(20000);
#else
  sleep(20);
#endif


#ifdef __KERNEL__
  portalmem_dmabuffer_destroy(backAlloc);
  portalmem_dmabuffer_destroy(srcAlloc);
#endif

  PORTAL_PRINTF ("Main: ends\n");
  return 0;
}
