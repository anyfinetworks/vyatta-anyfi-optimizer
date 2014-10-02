cfgdir = $(datadir)/vyatta-cfg/templates
opdir = $(datadir)/vyatta-op/templates

vprefix = /opt/vyatta
vsbindir = $(vprefix)/sbin

sbin_SCRIPTS = scripts/vyatta-anyfi-optimizer.pl

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
  cpio -0pd

install-exec-hook:
	-cd templates-cfg && \
		mkdir -p $(DESTDIR)$(cfgdir) && \
		$(cpiop) $(DESTDIR)$(cfgdir)
	-cd templates-op && \
		mkdir -p $(DESTDIR)$(opdir) && \
		$(cpiop) $(DESTDIR)$(opdir)
