
CONNECTALDIR?=../..
MEMWRITEDIR=$(CONNECTALDIR)/examples/memwrite
INTERFACES = MemwriteRequest MemwriteIndication
BSVFILES = $(MEMWRITEDIR)/Memwrite.bsv $(MEMWRITEDIR)/Top.bsv
CPPFILES = $(MEMWRITEDIR)/testmemwrite.cpp
CONNECTALFLAGS += -D NumEngineServers=16
CONNECTALFLAGS += --bscflags " -show-schedule"
#CONNECTALFLAGS += --bscflags " -ddumpschedule"

include $(CONNECTALDIR)/Makefile.connectal
