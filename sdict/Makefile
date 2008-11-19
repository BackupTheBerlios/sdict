VERSION=0.1
APPNAME=sdict
PREFIX=/usr/local
BINPATH=$(PREFIX)/bin
LIBPATH=$(PREFIX)/lib/$(APPNAME)-$(VERSION)
PKGPATH=$(LIBPATH)/lib
DOCPATH=$(PREFIX)/share/doc/$(APPNAME)-$(VERSION)
DOCS=README sdictrc.sample stardict.html
TCLSH=tclsh

############################################################
RM		= rm -f
RMDIR		= rmdir
INSTALL		= /usr/bin/install
INSTALL_DATA	= $(INSTALL) -m 644
INSTALL_PRG	= $(INSTALL) -m 755

############################################################
install: check-tcl build install-bin install-doc
	
build:
	$(RM) $(APPNAME)
	@echo "#!/bin/sh" >> $(APPNAME)
	@echo "cd $(LIBPATH) && $(TCLSH) sdict.tcl $$@" >> $(APPNAME)
	@chmod 755 $(APPNAME)

check-tcl:
	@if ! `which $(TCLSH) >/dev/null 2>&1` ; then	\
		echo "$(TCLSH): not found";	\
		exit 1;				\
	fi

# Generate pkgIndex file and package doc in html format
tcl-pkg: check-tcl
	( cd lib && echo "pkg_mkIndex . stardict.tcl" | $(TCLSH) )
	dtplite -o doc html lib/stardict.man

install-bin:
	$(INSTALL) -d $(LIBPATH)/lib
	$(INSTALL_DATA) lib/pkgIndex.tcl $(PKGPATH)
	$(INSTALL_DATA) lib/stardict.tcl $(PKGPATH)
	$(INSTALL_DATA) sdict.tcl $(LIBPATH)
	$(INSTALL_PRG) -m 755 sdict $(BINPATH)

install-doc:
	$(INSTALL) -d $(DOCPATH)
	for n in $(DOCS); do $(INSTALL_DATA) $$n $(DOCPATH); done

clean:
	$(RM) $(APPNAME)

dist: clean
	@(cd .. && tar -czf $(APPNAME)-$(VERSION).tar.gz sdict)

uninstall:
	$(RM) $(BINPATH)/$(APPNAME)
	$(RM) $(PKGPATH)/pkgIndex.tcl
	$(RM) $(PKGPATH)/stardict.tcl
	$(RM) $(LIBPATH)/sdict.tcl
	for n in $(DOCS); do $(RM) $(DOCPATH)/$$n; done
	$(RMDIR) $(DOCPATH) $(PKGPATH) $(LIBPATH)
