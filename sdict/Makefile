VERSION=0.1
APPNAME=sdict
PREFIX=/usr/local
BINPATH=$(PREFIX)/bin
LIBPATH=$(PREFIX)/lib/$(APPNAME)-$(VERSION)
DOCPATH=$(PREFIX)/share/doc/$(APPNAME)-$(VERSION)
TCLSH=tclsh

############################################################
RM		= rm -f
INSTALL		= /usr/bin/install
INSTALL_DATA	= $(INSTALL) -m 644
INSTALL_PRG	= $(INSTALL) -m 755

############################################################
install: build install-bin install-doc
	
build:
	@if ! `which $(TCLSH) >/dev/null 2>&1` ; then 	\
		echo "$(TCLSH): not found";	\
		exit 1;				\
	fi
	$(RM) $(APPNAME)
	@echo "#!/bin/sh" >> $(APPNAME)
	@echo "cd $(LIBPATH) && $(TCLSH) sdict.tcl $$@" >> $(APPNAME)
	@chmod 755 $(APPNAME)

install-bin:
	$(INSTALL) -d $(LIBPATH)/lib
	$(INSTALL_DATA) lib/*.tcl $(LIBPATH)/lib
	$(INSTALL_DATA) sdict.tcl $(LIBPATH)
	$(INSTALL_PRG) -m 755 sdict $(BINPATH)

install-doc:
	$(INSTALL) -d $(DOCPATH)
	$(INSTALL_DATA) README $(DOCPATH)
	$(INSTALL_DATA) sdictrc.sample $(DOCPATH)

clean:
	$(RM) $(APPNAME)

dist: clean
	@(cd .. && tar -czf $(APPNAME)-$(VERSION).tar.gz sdict)

uninstall:
	$(RM) $(BINPATH)/$(APPNAME)
	$(RM) -r $(LIBPATH)
	$(RM) -r $(DOCPATH)
