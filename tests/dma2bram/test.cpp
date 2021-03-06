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
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <monkit.h>
#include <semaphore.h>

#include "StdDmaIndication.h"
#include "MMURequest.h"
#include "TestIndication.h"
#include "TestRequest.h"

sem_t test_sem;
unsigned int alloc_sz = 1<<10;

class TestIndication : public TestIndicationWrapper
{

public:
  TestIndication(unsigned int id) : TestIndicationWrapper(id){}
  virtual void writeDone(uint32_t v) {
    fprintf(stderr, "writeDone %d\n", v);
    sem_post(&test_sem);    
  }
};

int main(int argc, const char **argv)
{

  TestRequestProxy *testRequest = new TestRequestProxy(IfcNames_TestRequest);
  MMURequestProxy *dmap = new MMURequestProxy(IfcNames_HostMMURequest);
  DmaManager *dma = new DmaManager(dmap);
  MMUIndication *hostMMUIndication = new MMUIndication(dma, IfcNames_HostMMUIndication);
  TestIndication *testIndication = new TestIndication(IfcNames_TestIndication);

  if(sem_init(&test_sem, 1, 0)){
    fprintf(stderr, "failed to init test_sem\n");
    return -1;
  }

  portalExec_start();

  int srcAlloc = portalAlloc(alloc_sz);
  unsigned int *srcBuffer = (unsigned int *)portalMmap(srcAlloc, alloc_sz);
  unsigned int ref_srcAlloc = dma->reference(srcAlloc);

  testRequest->startWrite(ref_srcAlloc);
  sem_wait(&test_sem);
  testRequest->startWrite(ref_srcAlloc);
  sem_wait(&test_sem);
  return 0;
}
