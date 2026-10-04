# Tigris

Tigris is a security auditor for Linux: a set of shell scripts that check
accounts and passwords, file permissions, network configuration, cron,
installed packages against the package manager, signs of intrusion and
more, and report only what changed since the last run when scheduled.

It is descended from **TIGER**, written at Texas A&M University in 1993 by
Douglas Lee Schales, David K. Hess and David R. Safford, and maintained
on GNU Savannah from 2001 to 2019 by Javier Fernández-Sanguino Peña.
Tigris is an independent fork of that code, started in October 2026 from
the Savannah history and maintained by Andrei Trimbitas. The official
TIGER remains at <https://savannah.nongnu.org/projects/tiger/>; fixes
made here that apply to it are offered back there and to the Debian bug
tracker.

The name is the Latin for tiger, and the root of the Icelandic
*tígrisdýr*; there was never a Norse word for an animal no Norseman saw.

## Running it

From your own checkout:

    sudo ./tigris

(`./tiger` still works and does the same.) Tigris will not run check
scripts owned by someone other than the user running it, with one
exception: a tree owned by the person who ran `sudo` is theirs to run.
A copy that cron runs, or an installed one, must belong to root. The
report is written to
`log/`. To look up what a message code in it means, build the message
index once with `util/genmsgidx doc/*.txt`, then run, for example,
`./tigexp lin005f`. Choose which checks run, and how, in `tigerrc`.

Tigris needs no compiler. If you have one, `make && make -C c install`
builds a few small C helpers into `bin/`, which Tigris then prefers to
its shell equivalents.

To install system-wide instead:

    ./configure
    make install

On Debian and Ubuntu, `apt install tiger` gives the original TIGER from
the archive, not this fork.

## Where it is going

[ROADMAP.md](ROADMAP.md): a modern Linux baseline, JSON output, a free
compliance mapping, drift between runs, auditing a mounted image without
booting it, and later a PowerShell engine for Windows against the same
spec. Every change is measured for wall time, CPU and memory; it has to
stay light enough for a Raspberry Pi.

## Licence

GNU General Public License, version 2 or later; see [COPYING](COPYING).
`c/md5.c` (RSA Data Security) and `c/snefru.c` (Xerox) carry their own
notices.

## History

The 3.2.4 release here finished the release candidate TIGER left in 2018;
see [CHANGES](CHANGES). [AUTHORS](AUTHORS) and [CREDITS](CREDITS) list
everyone who built TIGER. The original [README](README) and
[USING](USING) still describe the internals accurately.
