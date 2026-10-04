# TIGER

TIGER is a set of shell scripts that audit a Unix system for security
problems: accounts and passwords, file permissions, network
configuration, cron, installed packages, signs of intrusion and more. It
started at Texas A&M University in 1993, written by Douglas Lee Schales,
David K. Hess and David R. Safford, in the same tradition as COPS. Javier
Fernández-Sanguino Peña maintained it on GNU Savannah from 2002, and it is
still packaged in Debian.

This repository continues TIGER from the Savannah history. Release 3.2.4
finishes the 3.2.4 release candidate from 2018. It adds the fixes Debian
carried as non-maintainer uploads and the patches waiting in Debian's bug
tracker, and makes the Debian checks work on merged-/usr systems. See
[CHANGES](CHANGES).

## Running it

From the source tree, as root. Tiger will not run check scripts owned by
another user, so the tree has to belong to root first:

    sudo chown -R root:root .
    sudo ./tiger

The report is written to `log/`. To look up what a message code in it
means, build the message index once with `util/genmsgidx doc/*.txt`,
then run, for example, `./tigexp lin005f`. Choose which checks run, and
how, in `tigerrc`.

Tiger needs no compiler. If you have one, `make && make -C c install`
builds a few small C helpers into `bin/`, which Tiger then prefers to
its shell equivalents.

To install system-wide instead:

    ./configure
    make install

On Debian and Ubuntu, `apt install tiger` gives the archive version.

## Licence

GNU General Public License, version 2 or later; see [COPYING](COPYING).
`c/md5.c` (RSA Data Security) and `c/snefru.c` (Xerox) carry their own
notices.

## History

The original project page is <https://www.nongnu.org/tiger/>, and the
Savannah repository is <https://git.savannah.nongnu.org/cgit/tiger.git>.
[AUTHORS](AUTHORS) and [CREDITS](CREDITS) list everyone who built it.
The original [README](README) and [USING](USING) cover the details.

Maintained by Andrei Trimbitas.
