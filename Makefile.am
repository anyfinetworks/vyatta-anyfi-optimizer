cfgdir = $(datadir)/vyatta-cfg/templates
opdir = $(datadir)/vyatta-op/templates
curverdir = $(sysconfdir)/config-migrate/current
bin_sudo_usersdir = $(bindir)/sudo-users

vprefix = /opt/vyatta
vsbindir = $(vprefix)/sbin

sbin_SCRIPTS = scripts/vyatta-anyfi-optimizer.pl

bin_sudo_users_SCRIPTS =

curver_DATA =

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
  cpio -0pd

install-exec-hook:
	-cd templates-cfg && \
		mkdir -p $(DESTDIR)$(cfgdir) && \
		$(cpiop) $(DESTDIR)$(cfgdir)
	-cd templates-op && \
		mkdir -p $(DESTDIR)$(opdir) && \
		$(cpiop) $(DESTDIR)$(opdir)
