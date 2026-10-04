# Roadmap

The goal: make Tigris the Linux security auditor people pick on purpose,
at least as good as Lynis and better where it counts. Lynis is the
reference point because it is the tool people compare against.

## Where things stand

|                       | Tigris 3.2.4                              | Lynis 3.1.7 (June 2026)                    |
|-----------------------|------------------------------------------|--------------------------------------------|
| Language              | POSIX shell                              | POSIX shell                                |
| Licence               | GPL-2.0-or-later                         | GPL-3.0                                    |
| Checks                | ~50 check groups, 261 finding IDs        | ~470 test IDs in 42 categories             |
| Platforms             | Linux in practice; half the tree is AIX, IRIX, NeXT, SunOS, UNICOS... | Linux, macOS, BSD, Solaris, AIX |
| Machine output        | Text report only                         | `report.dat` (key=value)                   |
| Finding explanations  | `tigexp`, written in the 1990s and 2000s | Suggestions linked to the CISOfy website   |
| Compliance mapping    | None                                     | Enterprise (paid) edition only             |
| Change over time      | `tigercron` mails only new findings      | Mostly point-in-time                       |
| Package integrity     | dpkg only                                | Limited                                    |
| Test suite            | None                                     | None in the repository                     |

Lynis is broad, maintained and popular (16k GitHub stars). Tigris can't
out-grow that by copying it test for test. It can win on depth, output
that other tools can use, honest evidence, and quality engineering.

## Principles

1. **POSIX shell, no dependencies.** It runs as root, so the people who
   run it should be able to read it. It must also run on minimal
   containers and rescue systems. No rewrite in another language.
2. **Every finding is complete.** It has a stable ID, a severity, a title,
   why it matters, how to fix it (commands, not just advice), references,
   and the compliance controls it maps to.
3. **Machine-readable output from the start.** JSON comes out of the same
   code path as the text report, never bolted on later.
4. **Read-only and offline by default.** Tiger never changes the system and
   never touches the network unless asked.
5. **Linux first, done properly.** Debian, Ubuntu, RHEL-likes, Fedora,
   SUSE, Alpine and Arch. Other Unixes come back only with a maintainer
   and a CI runner. Windows gets its own engine against the same spec
   once that spec exists (see below).
6. **No check ships without a test.** Each check must catch a planted
   problem and stay quiet on a clean system, as the 3.2.4 container
   tests did.
7. **Lean.** Tiger must run well on a Raspberry Pi or a 512 MB VPS, not
   just a workstation. Every release records the wall time, CPU time and
   peak memory of a full run on a reference machine, and a change that
   makes those worse needs a reason. No check spawns a process per file
   when one pass will do, and the file system scan stays the only thing
   allowed to take minutes.

## 3.2.x: maintenance (small)

- [ ] Replace `egrep` with `grep -E`. GNU grep warns on every call.
- [ ] Replace `tempfile` with `mktemp` in `safe_temp`. Remove the remaining
      `which` calls, for example in `gen_mounts`.
- [ ] CI on GitHub Actions: build, Debian package, and a smoke run in
      `debian:stable`, `debian:sid` and `ubuntu:24.04` containers.
- [ ] Run ShellCheck over `scripts/` and `systems/Linux/` and fix real
      bugs. Don't chase every style warning yet.
- [ ] Add `SECURITY.md`, issue templates and a contributing guide.

## 3.3: modern Linux baseline (large)

What the system looks like in 2026, not 2003.

**Clear out the old**
- [x] Move the dead platforms (AIX, HP-UX, IRIX, NeXT, SunOS, Tru64,
      UNICOS, Mac OS X) to an `attic` tag: `attic/other-unix-2026-10`,
      364 files.
- [ ] Turn off by default, or retire, checks for things that are gone:
      inetd/xinetd, rhosts, anonymous FTP, printcap, OmniBack, NIS+, LILO,
      and the static Debian advisory list from the early 2000s.

**Package integrity on every package manager.** This is Tiger's
traditional strength.
- [ ] rpm (`rpm -Va`), apk (`apk audit`) and pacman (`pacman -Qkk`),
      alongside dpkg.
- [ ] Compare every SUID/SGID binary, and every file in system directories,
      against what the package manager says should be there.

**New checks**
- [ ] SSH: read the effective configuration from `sshd -T`, not just the
      config file.
- [ ] sudo and sudoers.d, PAM (password quality, faillock), and accounts
      without passwords.
- [ ] systemd: enabled services, timers next to cron, and unit hardening
      (`systemd-analyze security`).
- [ ] Firewall: nftables, iptables, ufw or firewalld present, with a
      default-deny policy.
- [ ] Kernel: sysctl hardening, lockdown, Secure Boot, and CPU
      vulnerability mitigations (`/sys/devices/system/cpu/vulnerabilities`).
- [ ] AppArmor or SELinux enforcing, auditd, and journald persistence.
- [ ] Time sync (chrony, timesyncd) instead of the NTP-only check.
- [ ] Updates: automatic security updates configured, pending security
      updates, and a reboot required.
- [ ] Storage: LUKS, mount options (`/tmp`, `/dev/shm`), core dumps, and
      USB storage.
- [ ] Containers: Docker or Podman socket permissions, rootless mode, and
      privileged containers.

## 4.0: where Tiger beats Lynis (large)

- [ ] **JSON report** with a versioned schema, written next to the text
      report. Exit codes that CI and automation can act on.
- [ ] **One metadata file per check**: ID, severity, category, controls,
      fix and references. The docs, `tiger explain <ID>` (replacing
      `tigexp`) and the JSON are all generated from it.
- [ ] **Open compliance mapping**, free: CIS Controls v8, ISO 27001:2022
      Annex A, NIST 800-53 and UK Cyber Essentials, kept as data files.
      Lynis only offers this in its paid edition.
- [ ] **Drift as a first-class feature**: `tiger diff` between runs, and
      `tiger accept <ID>` to acknowledge a finding with a reason and an
      expiry date. This builds on what `tigercron` already does.
- [ ] **Offline audit**: `tiger --root /mnt/image` audits a mounted disk,
      a container image's root filesystem or a VM snapshot without booting
      it. Lynis can't do this.
- [ ] **Transparent summary**: counts by severity and category, and any
      score shows its formula.
- [ ] **Profiles** (server, desktop, container) and a non-root mode that
      reports "skipped: needs root" instead of guessing.

## Engineering, ongoing

- **Tests:** a container fixture per check, with one known-bad and one
  known-good case, run by bats or shellspec in CI across Debian, Ubuntu,
  Fedora, Rocky, openSUSE, Alpine and Arch.
- **Safety:** no `eval` of data read from the system, `mktemp` for every
  temporary file, everything quoted. Tiger runs as root, so its own code
  has to be beyond reproach.
- **Speed:** independent checks run in parallel, and a full run on a
  typical server finishes in minutes. First target: `util/flogit`, which
  runs `ls | awk` for every file the filesystem scan finds, so a root
  disk with 500k files costs about a million processes. `find` can
  classify ownership and permissions itself in one pass.
- **Packaging:** a Debian upload through Javier or our own APT repository,
  Fedora COPR, the AUR, Alpine, and a container image to scan a host or
  image.
- **Docs:** man pages, plus a GitHub Pages site generated from the check
  metadata.

## Windows (after 4.0)

Windows has nothing like Lynis or Tiger in the open: HardeningKitty
checks settings against CIS and Microsoft baselines, and the rest is
commercial. Tiger's shell code can't run on a Windows host, but after 4.0
the parts that matter are language-neutral: the finding IDs and
metadata, the JSON schema, the compliance mapping and the explanations.
A `tiger.ps1` engine implements the same spec in PowerShell, using WMI
and CIM, the registry, the event log, `Get-Hotfix`, `auditpol`,
`secedit` and Defender's APIs, and emits the same JSON. One report
format, one set of IDs, one `tiger explain`, two engines. It starts once
the 4.0 schema is stable, so it's built against a fixed contract.

## Not planned

- A GUI or a resident daemon. Tiger stays a command-line tool; dashboards
  belong to whatever reads its JSON.
- Automatic remediation. Tiger shows the fix and the admin runs it.
