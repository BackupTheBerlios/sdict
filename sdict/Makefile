VERSION=0.1
PREFIX=/usr/local
BINPATH=$(PREFIX)/bin
DATAPATH=$(PREFIX)/share
DOCPATH=$(PREFIX)/share/doc
APPNAME=sdict

############################################################
RM=rm
CP=cp
INSTALL=install

############################################################
dist:
	@(cd .. && tar -czf $(APPNAME)-$(VERSION).tar.gz sdict)

uninstall:
	$(RM) $(BINPATH)/$(APPNAME)
	$(RM) -r $(DATAPATH)/$(APPNAME)
	$(RM) -r $(DOCPATH)/$(APPNAME)-$(VERSION)
