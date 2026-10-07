# Finding metadata

Every finding id a check can report has one file, `meta/<id>`: what the
finding means, how serious it is, what area it belongs to and which check
reports it. `tigris explain`, the `category` of each JSON finding and the
HTML reference are read from these files, and `tests/explain_check.sh`
fails the build when an id the code can emit has no file, or a file
describes an id nothing emits.

## Format

A header of `Key: value` lines, an empty line, then the explanation as
plain text, wrapped at about 72 columns. Lines indented in the text
(commands, configuration) are shown as they are.

    Id: lin039w
    Severity: WARN
    Category: packages
    Check: deb_statoverride
    References: dpkg-statoverride(1)

    A file's mode or owner differs from what dpkg-statoverride sets for it.
    ...

| Key          | Required | Value                                                                    |
|--------------|----------|--------------------------------------------------------------------------|
| `Id`         | yes      | The id, the same as the file name.                                       |
| `Severity`   | yes      | The levels it is reported at, most severe first: `ALERT`, `FAIL`, `WARN`, `INFO`, `ERROR`, `CONFIG`, separated by `, `. Usually one, and the id's last letter names it (`w` for WARN); some findings are reported at more than one level (lin002i is a WARN for a root process listening on every interface). |
| `Category`   | yes      | One of the categories below.                                             |
| `Check`      | yes      | The scripts that report it, separated by spaces, or `any` for the start-up messages every check carries (init002e). |
| `Fix`        | no       | One line: what to do about it, when that fits in a line.                |
| `References` | no       | Sources, separated by `; `: man pages, standards, books.                 |
| `Controls`   | no       | Compliance controls it maps to, separated by `; `, once the open mapping exists (ROADMAP, 4.0). |

Unknown keys are an error, so a typo does not go unnoticed.

## Categories

| Category     | What it covers                                                        |
|--------------|-----------------------------------------------------------------------|
| `accounts`   | Users, groups, passwords, root's environment and PATH, login banners  |
| `boot`       | Boot loader configuration and passwords, single-user mode             |
| `containers` | Docker and Podman: who may drive them, what their containers may do   |
| `cron`       | Cron tables and the files they run                                    |
| `filesystem` | Permissions, ownership, setuid and setgid files, devices, umask       |
| `firewall`   | The packet filter, and ports Docker publishes past it                 |
| `integrity`  | File integrity tools (AIDE, integrit, Tripwire) and signatures        |
| `intrusion`  | Signs of compromise: rootkits, known intruder files, promiscuous mode |
| `kernel`     | Kernel hardening: sysctl settings, lockdown, AppArmor and SELinux, CPU vulnerabilities |
| `logging`    | Log files and their permissions, auditd, logs kept across reboots     |
| `network`    | Network settings, listening processes, NFS                            |
| `packages`   | Installed files against the package manager, updates, OS version     |
| `services`   | Services and their configuration: mail, web, inetd, systemd units     |
| `ssh`        | The SSH server's configuration                                        |
| `tigris`     | Tigris itself: its configuration, a check that could not run          |

## Adding a finding

Write `meta/<id>` when adding the `message` call that reports it, and run
`sh tests/explain_check.sh`. Retiring a finding removes its file; the
explanations of ids retired before 3.4.0 are in the git history, under
`doc/*.txt` at the tag `version_3_3_0`.
