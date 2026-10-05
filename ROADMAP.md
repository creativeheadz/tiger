# Roadmap

Tigris is a security auditor for Linux, descended from TIGER (Texas A&M,
1993). The goal is to make it the auditor people pick on purpose: at
least as good as Lynis, and better where it counts. Lynis is the
reference point because it is the tool people compare against.

*Last updated 5 October 2026.* `[x]` done, `[ ]` to do, `[~]` started.
Everything marked done is on `master`; "released" means tagged (the last
tag is `version_3_2_4`).

## Contents

1. [Ground rules and decisions](#ground-rules-and-decisions)
2. [Where things stand](#where-things-stand)
3. [Principles](#principles)
4. [What has shipped](#what-has-shipped)
5. [3.2.x: maintenance](#32x-maintenance)
6. [3.3: modern Linux baseline](#33-modern-linux-baseline)
7. [4.0: where Tigris beats Lynis](#40-where-tigris-beats-lynis)
8. [Ideas parked for later](#ideas-parked-for-later)
9. [Windows (after 4.0)](#windows-after-40)
10. [Engineering, ongoing](#engineering-ongoing)
11. [Not planned](#not-planned)

## Ground rules and decisions

Settled, so they do not have to be argued again:

- **Tigris is an independent fork.** The official TIGER stays on GNU
  Savannah, maintained by Javier Fernández-Sanguino Peña, who also
  maintains the Debian package. Fixes here that apply to TIGER are
  offered back as patches (to Savannah and the Debian bug tracker);
  three went to the BTS on 4 October 2026 (#1111306, #505906, #610785).
  A Savannah membership is pending.
- **The history stays whole.** The full TIGER history is kept, with its
  authors, and the copyright notices stay on the files. Tigris adds to
  that line; it does not rewrite it.
- **Licence: GPL-2.0-or-later**, as TIGER. `c/md5.c` (RSA) and
  `c/snefru.c` (Xerox) carry their own notices.
- **Lynis is a list of ideas, not a source of code.** Lynis is GPL-3.0;
  copying from it would force Tigris to GPL-3.0 and take away the
  "or later" that keeps it the more permissive of the two. Checks are
  written from the documentation of the thing being checked.
- **Linux first.** The other Unixes (AIX, HP-UX, IRIX, NeXT, SunOS,
  Tru64, UNICOS, Mac OS X) are in the `attic/other-unix-2026-10` tag and
  come back only with a maintainer and a CI runner for them.
- **Internal names stay for now.** `tigerrc`, the `Tiger_*` settings, the
  `tiger` command and `/etc/tiger` keep working. They change at 4.0, with
  compatibility shims, in one go. `./tigris` is the entry point today.

## Where things stand

|                      | Tigris (master, October 2026)                                   | Lynis 3.1.7 (June 2026)                  |
|----------------------|-----------------------------------------------------------------|------------------------------------------|
| Language             | POSIX shell, no dependencies                                    | POSIX shell                              |
| Licence              | GPL-2.0-or-later                                                | GPL-3.0                                  |
| Checks               | 46 check scripts, 308 finding ids, every one explained          | ~470 test ids in 42 categories           |
| Platforms            | Linux: Debian/Ubuntu, Fedora/RHEL/SUSE, Alpine, Arch            | Linux, macOS, BSD, Solaris, AIX          |
| Machine output       | JSON Lines with a versioned schema, next to the text report     | `report.dat` (key=value)                 |
| Explanations         | `tigexp ID` (all 308 written, most predate 2008; 22 this week)  | Suggestions linked to the CISOfy website |
| Compliance mapping   | None yet                                                        | Enterprise (paid) edition only           |
| Change over time     | `tigris-diff` and `tigris-accept`; `tigercron`                  | Mostly point-in-time                     |
| Package integrity    | dpkg, rpm, apk, pacman, one finding id per kind of problem      | Limited                                  |
| Tests                | 12 fixture suites, 11 CI jobs on every push                     | No per-check suite found in the repository |

Lynis is broad, maintained and popular (16k GitHub stars). Tigris cannot
out-grow it by copying it test for test. It can win on depth, on output
other tools can use, on honest evidence, and on engineering quality.

**Measured** on the reference machine (Linux Mint 22.3 desktop, 1.8 TB
root disk plus a 1.9 TB data disk, 2.4k packages), full run as root:

| | 3.2.4 as released | master, 5 Oct 2026 |
|---|---|---|
| Report | 49,651 lines; 24 checks refused to run | 222 lines, the false positives found so far removed |
| Wall time | 7:16 | 1:55 to 3:21, depending on disk load |
| Peak memory | 159 MB | 34 MB |

Everything except the filesystem scan finishes in about a minute; the
scan is bound by how fast the disks can be walked (a bare `find` over the
same disks takes 146 s on a busy day). A **quick profile** that leaves the
big data disks out is therefore the biggest remaining win (see 3.3).

## Principles

1. **POSIX shell, no dependencies.** It runs as root, so the people who
   run it should be able to read it. It must also run on minimal
   containers and rescue systems. No rewrite in another language.
2. **Every finding is complete.** A stable id, a severity, a message,
   why it matters, how to fix it (commands, not just advice), references,
   and the compliance controls it maps to.
3. **One id means one thing everywhere.** `lin005f` is "an installed file
   differs from its package" whether the package is a `.deb`, an RPM, an
   apk or a pacman package, so a program reading the report needs no
   per-distribution knowledge.
4. **Machine-readable output from the start.** JSON comes out of the same
   code path as the text report, never bolted on.
5. **Read-only and offline by default.** Tigris never changes the system
   and never touches the network unless asked.
6. **No check ships without a test.** Each check must catch a planted
   problem and stay quiet on a clean system, in a real container where
   the check depends on a real package manager.
7. **Lean.** It must run well on a Raspberry Pi or a 512 MB VPS, not just
   a workstation. Every release records wall time, CPU and peak memory on
   the reference machine; a change that makes them worse needs a reason.
   No check spawns a process per file when one pass will do, and the file
   system scan stays the only thing allowed to take minutes.
8. **Honest evidence.** A finding says what was found and where. A check
   that cannot run says so, and does not guess. Noise is a bug: a report
   with 16,000 lines of dangling symlinks hides the few that matter.

## What has shipped

**Released: 3.2.4 (4 October 2026).** Finishes the 3.2.4 release candidate
TIGER left in 2018 and folds in the five Debian non-maintainer uploads
that never reached the repository. Debian bugs #1111306 (merged-/usr),
#505906 (prelink, md5sum parsing), #610785 (`Tiger_FSScan_PruneDirs`),
#1105709 (parallel install), #1033743 (Romanian translation).

**On master since 3.2.4 (unreleased):**

*Runs properly on a modern Linux.*
- [x] `sudo ./tigris` works from a checkout; the tree-ownership guard
  explains itself (`init010e`) and accepts the sudo user's own checkout.
- [x] `config` falls back to the generic Linux checks correctly on a
  kernel newer than the version symlinks. Before, every Linux-specific
  check silently did not run on kernel 7.
- [x] The filesystem scan is one `find` with `-fprintf`, not an `ls | awk`
  per file (about a million processes before); the old path stays for
  busybox.
- [x] Dangling symlinks and unusual file names are listed one by one only
  under system directories (`Tiger_FSScan_DetailDirs`); elsewhere one line
  per directory. Image stores (Flatpak, Docker, containerd, snap) are
  pruned by default (`Tiger_FSScan_PruneDirs`).
- [x] Checks taught the modern world: PAM-era PATH and umask, systemd,
  merged-/usr, `nologin` service accounts, `/var/log/syslog` and the
  journal, `/dev` as udev builds it, `su` and `passwd` being setuid.
- [x] `egrep`, `tempfile` and `which` are gone; `util/realpath` replaces
  the C helper when it is not built; distribution detection reads
  `/etc/os-release`.
- [x] The dead-service checks retired and deleted: inetd, xinetd and
  tcpd, rhosts and `.netrc`, anonymous FTP and ftpusers, printcap,
  OmniBack, NIS+, inittab and the static Debian advisory list
  (17 files). The boot check stays: despite its name it covers GRUB 2.
  So does `check_known`'s inetd backdoor test, which costs nothing when
  there is no inetd.
- [x] `tigerrc-quick`: everything except the filesystem scan, about a
  minute where the full run takes three (62 s on Hera, 175 lines).

*New checks.*
- [x] `check_sysctl`: kernel pointer and log restriction, Yama, ASLR,
  SysRq, BPF, perf, `fs.protected_*`, IPv6 redirects and source routing,
  and the kernel's own verdict on CPU speculation flaws.
- [x] `check_ssh` reads the effective configuration with `sshd -T`: 15
  directives and the cipher, MAC and key-exchange lists.
- [x] `check_systemd`: sandboxing of network-facing services, scored by
  `systemd-analyze security`, naming the three protections that would
  help most.
- [x] `pkg_integrity`: package integrity for rpm, apk and pacman, with
  the finding ids the dpkg checks use, plus `lin038w` (mode or owner
  differs from the package). Honours pacman's `NoExtract` and
  `NoUpgrade`. Verified on Fedora, Rocky 9, openSUSE, Alpine and Arch.
- [x] The dpkg checks: merged-/usr aware, deleted files reported again,
  one `grep` for diversions instead of a `dpkg -S` each (130 MB to 11 MB).

*Output and drift.*
- [x] JSON Lines report from `message()` itself: run record, one record
  per finding, summary with counts. A `schema: 1` version, a JSON Schema
  (`doc/tigris-report.schema.json`), the contract in `doc/json-format.md`,
  and CI validating a real run against it.
- [x] `tigris-diff`: new, resolved and unchanged between two runs, exit 1
  on anything new, `-j` for JSON. When either run skipped the filesystem
  scan (the quick profile) its `fsys*` findings are set aside on both
  sides instead of showing as resolved, and different `tigerrc` files are
  noted; the run record carries `filesystem_scan` for this.
- [x] `tigris-accept`: acknowledge a finding with a reason and an expiry;
  out of the text report, marked in the JSON, back when it expires.
- [x] Every message id on a live Linux path is well-formed and
  explained: 308 emitted, 308 with entries, the count complete for the
  first time. 22 explanations written this week (apache, aide, NTP,
  permissions, root, rootkit, suid/sgid, crack, PATH); three
  placeholder ids replaced with real ones (`tigxxxx` to `tig001e`,
  `suidxxx` to `suid002`, `miscxxxx` to `pass022w`); the NIS+ check
  that held the last four malformed ids retired. `tigexp` serves them
  all and `tests/explain_check.sh` fails CI on any gap.

*Engineering.*
- [x] 12 fixture suites and a CI pipeline of 11 jobs: syntax and
  ShellCheck, a full run on Ubuntu, the dpkg checks on Debian stable,
  sid and Ubuntu 24.04, and the package checks on five other
  distributions.
- [x] The other Unixes moved to the attic tag (364 files).
- [x] `SECURITY.md`, issue templates and a contributing guide, with
  GitHub's private vulnerability reporting switched on so the route the
  policy names actually works.

## 3.2.x: maintenance

- [x] Replace `egrep`, `tempfile` and `which`.
- [x] CI on GitHub Actions.
- [~] ShellCheck over `scripts/` and `systems/Linux/`. It runs in CI but
  is advisory: Tiger's `[ $TESTEXEC file ]` idiom, where the test
  operator is a variable, cannot be parsed. Fix the real bugs it finds
  and make it blocking.
- [x] `SECURITY.md`, issue templates and a contributing guide.
- [x] **Every finding id has an explanation, enforced.** The earlier
  count of 18 was a lower bound from a plain grep. The complete
  enumeration (literals, `pathmsg` arguments, the `file_access_list`
  and `signatures` data, `check_embed`'s suffix) found 25 gaps on
  master: 20 are now written, and five went away with the retired
  checks (tcpd's three, `xnet002f`, `bcm203x`). Two more entries cover
  new ids for placeholder findings the old grep could not see
  (`tig001e`, `pass022w`), and `apa003w` from the old list was never
  emitted by anything. `tests/explain_check.sh` fails CI on any id
  with no entry, and on any malformed id.
- [ ] **Survive a dead network mount.** On 5 October the NAS mount was
  down (`df: /mnt/nas: Host is down`). Anything that asks about every
  mount can stall on it. Audit every call that touches mounts (`df`,
  `mount`, `lsof`, `stat`) and use local-only forms or a timeout.
- [x] `tests/explain_check.sh` covers the id families built from data
  (`perm…`, `embed…`) but not a *new* id built from a variable: a
  mutation test confirmed `message WARN yyy$x"w"` passes unnoticed.
  Closed from the other side: the smoke test now checks that every id
  in a real run's JSON has an explanation (28 ids on Hera).
- [x] Two runs in the same minute overwrite each other's report: the
  file names carried the time only to the minute. They now carry
  seconds (`security.report.HOST.YYMMDD-HH:MM:SS`); the byte sort in
  `tigris-diff` still orders a mix of old and new names by time, and
  `tigercron` was never affected (it rotates numbered `.1`/`.2` files).
- [x] `tigerrc-quick` is a full copy of `tigerrc` with one line changed,
  because an unset `Tiger_Check_*` means "run". Until profiles can be
  short overlays, `tests/profile_check.sh` fails unless the two differ
  only in that line.
- [x] The legacy variants `tigerrc-all` and `tigerrc-dist` carried
  the switches of the retired checks; dropped, since nothing installs,
  reads or documents them (the only generator was the dead manual
  `make distribution` target, whose recipe went with them).

## 3.3: modern Linux baseline

What the system looks like in 2026, not 2003. **Release gate for 3.3.0:**
profiles (at least `quick`), the dead-service checks retired, every id
explained and tested, `SECURITY.md`. Everything above under "shipped" is
already in; the gate is what is left.

**Clear out the old**
- [x] Other Unixes to the attic.
- [x] Retire the checks for things that are gone from a current Linux:
  inetd, xinetd and tcpd, rhosts and `.netrc`, anonymous FTP and
  ftpusers, printcap, OmniBack, NIS+, inittab and the static Debian
  advisory list from the early 2000s. Two corrections to the plan:
  tcpd went with inetd (it cannot run without it, and FAILs noise on
  any system without tcpwrappers), and the "LILO" check stayed because
  it is the GRUB 2 boot check.

**Profiles** (also the answer to "lean")
- [x] `quick`: leaves the filesystem scan out. 62 s on Hera, where the
  full run takes about three minutes on a busy disk.
- [ ] `server`, `desktop` and `container`, each a short tigerrc selecting
  the checks and the prune list that make sense for that kind of machine.
- [ ] A non-root mode that reports "skipped: needs root" for the checks
  that need it, instead of guessing.

**Package integrity**
- [x] rpm, apk and pacman alongside dpkg.
- [ ] Setuid and setgid files compared with what the package manager says
  should be setuid, not only with Tigris's own lists.
- [ ] `lin038w`-style mode and owner comparison for dpkg systems
  (`dpkg --verify`); today the dpkg checks compare content only.

**New checks**
- [x] SSH from `sshd -T`.
- [x] systemd unit hardening of network-facing services.
- [x] Kernel and file-system sysctl hardening; CPU vulnerability status.
- [ ] sudo and `sudoers.d`, PAM (password quality, `faillock`), and
  accounts without passwords.
- [ ] systemd: enabled services and timers next to cron.
- [ ] Firewall: nftables, iptables, ufw or firewalld present, with a
  default-deny policy.
- [ ] Kernel lockdown and Secure Boot.
- [ ] AppArmor or SELinux enforcing, auditd, journald persistence.
- [ ] Time sync (chrony, timesyncd) instead of the NTP-only check.
- [ ] Updates: automatic security updates configured, pending security
  updates, reboot required. The existing `check_patches` is apt-only and
  off by default.
- [ ] Storage: LUKS, mount options (`/tmp`, `/dev/shm`), core dumps, USB
  storage.
- [ ] Containers: Docker or Podman socket permissions, rootless mode,
  privileged containers.

## 4.0: where Tigris beats Lynis

- [~] **A report other tools can rely on.** Done: JSON Lines, a schema
  version, a JSON Schema, a documented contract. To do: **exit codes** CI
  and cron can act on (`tigris` exits 0 whatever it finds today; only
  `tigris-diff` has a meaningful status), and a `diff`-aware mode of the
  main command.
- [ ] **One metadata file per check**: id, severity, category, controls,
  fix, references. The docs, `tigris explain ID` (replacing `tigexp`) and
  the JSON are generated from it, and the rule that every id has an
  explanation is true by construction.
- [ ] **Open compliance mapping**, free: CIS Controls v8, ISO 27001:2022
  Annex A, NIST 800-53 and UK Cyber Essentials, kept as data files and
  carried in the JSON. Lynis offers this only in its paid edition.
- [x] **Drift**: `tigris-diff` and `tigris-accept`. Still to do: the
  main command takes `--since RUN` and reports only what is new, so cron
  needs no wrapper.
- [ ] **Offline audit**: `tigris --root /mnt/image` audits a mounted disk,
  a container image's root filesystem or a VM snapshot without booting
  it. Lynis cannot do this.
- [ ] **A transparent summary**: counts by severity and category, and any
  score shows its formula.
- [ ] **Rename the internals** in one release, with shims for old
  configurations: `tigerrc` to `tigris.conf`, `Tiger_*` to `Tigris_*`,
  `/etc/tiger` to `/etc/tigris`, `tigexp` to `tigris explain`.
- [ ] A JSON schema 2 only if something has to be removed or renamed.

## Ideas parked for later

Not commitments. Written down so they are not lost.

- **Scan identities**: a name for a kind of scan (`--identity nightly`,
  `--identity pre-deploy`) carried in the run record, so a consumer can
  keep the series apart and `tigris-diff` compares like with like.
- **Notification**: a webhook that receives the summary, or the diff,
  when a run ends. Off unless configured, in keeping with offline by
  default.
- **More output formats** generated from the JSON rather than written
  into the checks: SARIF (for code-scanning dashboards), XML, CSV.
- **Wegweiser**: the Linux agent runs Tigris on each endpoint next to
  Lynis and ships the JSON; the schema and the `accepted` block are
  designed for that. First real consumer of the contract.
- **A fast path for large data disks**: let the scan skip filesystems by
  type or mount point from the profile, not just by directory.

## Windows (after 4.0)

Windows has nothing like Lynis or TIGER in the open: HardeningKitty checks
settings against CIS and Microsoft baselines, and the rest is commercial.
Tigris's shell code cannot run on a Windows host, but after 4.0 the parts
that matter are language-neutral: the finding ids and metadata, the JSON
schema, the compliance mapping and the explanations. A `tigris.ps1`
engine implements the same spec in PowerShell, using WMI and CIM, the
registry, the event log, `Get-Hotfix`, `auditpol`, `secedit` and
Defender's APIs, and emits the same JSON: one report format, one set of
ids, one `tigris explain`, two engines. It starts once the 4.0 schema is
stable, so it is built against a fixed contract.

## Engineering, ongoing

- **Tests:** plain `sh` fixtures with no framework. Checks that read
  `/proc`, `sshd -T`, `ss` or `systemd-analyze` take the command or the
  tree as a setting (`Tiger_Sysctl_Root`, `Tiger_SSHD_Cmd`,
  `Tiger_SS_Cmd`), so a test can feed them a fixture. Checks that depend
  on a package manager run in a real container: each plants a modified
  file, a deleted one, a changed mode and a stray, and requires exactly
  those four new findings on top of the image's own baseline. Test
  awk-dependent code under both mawk and gawk.
- **Safety:** no `eval` of data read from the system, `mktemp` for every
  temporary file, everything quoted. Files such as `/etc/os-release` and
  `/etc/pacman.conf` are read as text, never sourced. Tigris runs as
  root, so its own code has to be beyond reproach.
- **Speed and memory:** independent checks run in parallel. The two
  biggest wins so far were `util/flogit` (an `ls | awk` per file) and
  `deb_checkmd5sums` (a `dpkg -S` per diversion at 130 MB each). The
  next is the profiles above.
- **Packaging:** `.deb`, `.rpm` and apk built in CI, under the name
  `tigris` and separate from Debian's `tiger`; an AUR package; a COPR; a
  container image that scans a host or an image. Debian packaging of the
  fork is for later and would be its own package.
- **Docs:** man pages, `doc/json-format.md` (done), and a GitHub Pages
  site generated from the check metadata once it exists.

## Not planned

- A GUI or a resident daemon. Tigris stays a command-line tool;
  dashboards belong to whatever reads its JSON.
- Automatic remediation. Tigris shows the fix and the administrator runs
  it.
- Copying code from other auditors.
