
all:
	@echo ""
	@echo " rsbak3 is a shell script. there is nothing to build."
	@echo ""
	@echo " $(MAKE) doc .......... create documentation (needs docbook)"
	@echo " $(MAKE) install ...... install rsbak3"
	@echo ""

doc:
	docbook2man rsbak3.sgml
	docbook2pdf rsbak3.sgml
	docbook2txt rsbak3.sgml
	mv rsbak3.txt README
	rm -f manpage.*

install:
	install -m 755 rsbak3.sh  /usr/local/sbin/rsbak3
	install -m 755 rsb3swr.sh /usr/local/sbin/rsb3swr
	install -m 755 rsbak3diff.sh  /usr/local/sbin/rsbak3diff
	-install -m 644 rsbak3.man /usr/local/man/man8/rsbak3.8

clean:
	rm -f manpage.* *~ core

realclean: clean
	rm -f rsbak3.8 rsbak3.pdf rsbak3.txt README

