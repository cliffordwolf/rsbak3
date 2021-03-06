
PREFIX=/usr/local

all:
	@echo ""
	@echo " rsbak3 is a shell script. there is nothing to build."
	@echo ""
	@echo " $(MAKE) doc .......... create documentation (needs docbook)"
	@echo " $(MAKE) install ...... install rsbak3 and additional tools"
	@echo ""

doc:
	docbook2man rsbak3.sgml
	docbook2pdf rsbak3.sgml
	docbook2txt rsbak3.sgml
	rm -f manpage.*

install:
	mkdir -p $(PREFIX)/sbin
	mkdir -p $(PREFIX)/man/man8
	install -m 755 rsbak3.sh $(PREFIX)/sbin/rsbak3
	install -m 755 rsb3swr.sh $(PREFIX)/sbin/rsb3swr
	install -m 755 rsbak3diff.sh $(PREFIX)/sbin/rsbak3diff
	install -m 755 rsbak3dump.sh $(PREFIX)/sbin/rsbak3dump
	install -m 755 rsbak3logsum.pl $(PREFIX)/sbin/rsbak3logsum.pl
	install -m 644 rsbak3.man $(PREFIX)/man/man8/rsbak3.8

clean:
	rm -f manpage.* *~ core

realclean: clean
	rm -f rsbak3.8 rsbak3.pdf rsbak3.txt README

