# Tigris

[![CI](https://github.com/creativeheadz/tigris/actions/workflows/ci.yml/badge.svg)](https://github.com/creativeheadz/tigris/actions/workflows/ci.yml)
[![Licence: GPL-2.0-or-later](https://img.shields.io/badge/Licence-GPL--2.0--or--later-blue.svg)](COPYING)

<pre>
      ##    ##                               ##
     ##########                              ##
     ###########                             ##
  ###############                          ##
   ############################################
    ################# ##### ##### ###########
    #######################################
     ####################################
     ######   #####    ######  ########
     #####    #####    #####   #####
     #####    #####    #####   #####
     #####    #####    #####   #####
     ######   ######   ######  ######
 ______________________________________________
</pre>

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
In a hurry, run the quick profile instead: everything except the
filesystem scan, about a minute where the full run takes three:

    sudo ./tigris -c tigerrc-quick

Tigris needs no compiler. If you have one, `make && make -C c install`
builds a few small C helpers into `bin/`, which Tigris then prefers to
its shell equivalents.

To install system-wide instead:

    ./configure
    make install

Installed files are checked against the package manager on Debian and
Ubuntu (dpkg), Fedora, RHEL and its relatives, and openSUSE (rpm), Alpine
(apk) and Arch (pacman). A modified file, a missing one, a changed mode
and a stray file in a binary directory are reported with the same ids on
all of them.

On Debian and Ubuntu, `apt install tiger` gives the original TIGER from
the archive, not this fork.

## Machine-readable output

Every run also writes the findings as JSON Lines to
`log/security.report.HOST.DATE.jsonl`: a `run` record first (with an `id`
for the run, the host, OS and the `tigerrc` used), one
`finding` per message with `level`, `id`, `check`, `message` and an
optional `detail`, and a `summary` with counts last. INFO findings are
always included there, whatever the text report shows. Bytes above 127
in a message are written as `\u00XX`, one per byte, so file names in any
encoding survive and the file is plain ASCII. `Tiger_Output_JSON=N` in
`tigerrc` turns it off. The format is a documented contract with a version
field and a JSON Schema: [doc/json-format.md](doc/json-format.md).

`tigris-diff` compares two of those files and lists what is new and what
was resolved; with no arguments it takes the two most recent runs in
`log/`. It exits 1 when anything is new, so a cron job or a CI step can
act on it, and `-j` gives the same as one JSON object:

    ./tigris-diff                      # the last two runs
    ./tigris-diff old.jsonl new.jsonl  # any two

`tigris` itself does the same with `--since`: the run happens and is
recorded in full, and what is printed is only what changed. With `-q` it
prints nothing at all when nothing changed, so a nightly cron job needs
no wrapper and mails only when there is news:

    sudo ./tigris -q --since last

The exit status of `tigris` is the worst finding in the report (with
`--since`, the worst new one), for CI and monitoring: 0 nothing at WARN
or above, 2 a check could not run, 3 WARN, 4 FAIL, 5 ALERT, and 1 when
the audit did not run at all.

A finding you have looked at and decided to live with can be accepted,
with a reason and, if you want, an expiry date:

    ./tigris-accept lin015w -r "Docker needs IP forwarding" 
    ./tigris-accept sysd001w -m "docker.service*" -r "sandboxing tracked in #12" -u 2027-01-31
    ./tigris-accept -l

An accepted finding stays out of the text report (the run says how many
were left out) and stays in the JSON report marked `accepted` with the
reason and date. When the date passes it is reported again, with a
warning that the acceptance expired. The entries live in
`tigris.accepted` next to `tigerrc`.

## Where it is going

[ROADMAP.md](ROADMAP.md) has the decisions, the status, what has shipped
and what is next. Already here: package integrity on five package
managers, a versioned JSON report, drift between runs, and a quick
profile that skips the filesystem scan. Ahead: a free compliance
mapping, auditing a mounted image without booting it, and later a
PowerShell engine for Windows against the same spec. Every change is
measured for wall time, CPU and memory; it has to stay light enough for a
Raspberry Pi.

## Licence

GNU General Public License, version 2 or later; see [COPYING](COPYING).
`c/md5.c` (RSA Data Security) and `c/snefru.c` (Xerox) carry their own
notices.

## History

The 3.2.4 release here finished the release candidate TIGER left in 2018;
3.3.0 is the first release as Tigris. See [CHANGES](CHANGES). TIGER's configurations for AIX, HP-UX, IRIX,
NeXT, SunOS, Tru64, UNICOS and Mac OS X were retired after that release;
they are in the git history under the tag `attic/other-unix-2026-10`. [AUTHORS](AUTHORS) and [CREDITS](CREDITS) list
everyone who built TIGER. The original [README](README) and
[USING](USING) still describe the internals accurately.
