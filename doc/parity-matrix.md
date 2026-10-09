# Lynis parity matrix

Where Tigris stands against Lynis, group by group, so the roadmap's
parity target is a checklist instead of a slogan. Lynis is reference
only: no Lynis code is copied here or into the checks (GPL-3.0;
Tigris stays GPL-2.0-or-later). Statuses: covered, strong (minor
gaps), partial, gap, N/A (template or platform-only).

Inventoried from Lynis 3.1.8-dev (`include/tests_*`, 43 files, 480
registrations, 477 real tests) against Tigris on master. Refresh by
re-running the inventory and updating the counts below.

## Covered (6 groups)

| Lynis group | Tests | Tigris cover |
|---|---|---|
| banners | 5 | check_issue |
| dns | 1 | check_dns |
| file_permissions | 1 | check_perms |
| homedirs | 6 | check_accounts, check_path |
| kernel_hardening | 1 | check_sysctl |
| ssh | 5 | check_ssh (sshd -T) |

## Strong (10 groups, minor gaps)

| Lynis group | Tests | Tigris cover | Remaining |
|---|---|---|---|
| authentication | 36 | accounts, passwd, group, pam, sudo, neverlogin, umask | doas (macOS/BSD phase); LDAP-in-PAM (see ldap) |
| boot_services | 27 | check_lilo (GRUB 2), check_single, check_secureboot, systemd units | verify GRUB password check; other bootloaders ride the platform phases |
| containers | 7 | check_containers (10 ids) | zones/Xen ride the platform phases; verify Docker file-permission depth |
| filesystems | 23 | fstab/crypttab, mount options, scan, check_storage | DONE 2026-10-09: LVM layout (stor011i), ACL extras (stor012w), locate db (stor013w) |
| firewalls | 17 | check_firewall (nft/iptables/ufw/firewalld, Docker ports) | verify firewall logging; pf/ipfw ride the platform phases |
| logging | 23 | check_logfiles, check_remotelog, journald persistence | metalog, RFC 3195, newsyslog (platform); wazuh-agent (see tooling) |
| networking | 16 | check_network, check_listeningprocs (ss/lsof/netstat//proc) | verify promiscuous-mode check |
| ports_packages | 43 | pkg_integrity (dpkg/rpm/apk/pacman), check_updates, check_patches | verify unpurged packages, YUM GPG signing; non-Linux managers ride platforms |
| time | 17 | check_ntp, check_timesync | NTP protocol depth (stratum, falsetickers) |
| webservers | 18 | check_apache, check_nginx, check_certs | verify Apache module-inventory depth |

## Partial (15 groups)

| Lynis group | Tests | Tigris cover | Missing |
|---|---|---|---|
| accounting | 17 | check_audit (auditd) | sysstat, snoopy; Solaris/BSD daemons ride platforms |
| crypto | 8 | check_certs (expiry), check_storage (LUKS, swap) | DONE 2026-10-09: check_crypto (cry001w/002w/003i; rngd source, key perms, pool level). FileVault rides macOS |
| databases | 16 | check_databases (MySQL/MariaDB, PostgreSQL, Redis) | DONE 2026-10-09: MongoDB (dbs011f/012w/013w/014f), Oracle sqlnet.ora (dbs015w/016w). DB2 not coverable offline (binary dbm config) |
| file_integrity | 18 | aide/tripwire runners | DONE 2026-10-09: check_integrity (int001w/002w/003i; AIDE/AFICK databases, watcher inventory; OSSEC stays in check_ids) |
| insecure_services | 21 | legacy services retired deliberately | verify client-side tools (telnet/rsh/TFTP clients) |
| kernel | 13 | check_sysctl, core dumps, pending-reboot | I/O scheduler and module detail (mostly informational) |
| mac_frameworks | 8 | check_mac (AppArmor, SELinux) | DONE 2026-10-09: TOMOYO (mac007w/008i), PaX softmode (mac005w/006i) |
| mail_messaging | 11 | check_sendmail | DONE 2026-10-09: check_mail (mail001w/002w/003i; Exim, Postfix, Dovecot). Qmail/OpenSMTPD depth open |
| malware | 11 | check_rootkit | antivirus presence depth (ClamAV and friends) |
| memory_processes | 5 | check_runprocs, check_finddeleted | prelink handled (Oct 2026: no longer called for checksums, no longer shipped); zombie/heavy-IO are informational |
| nameservices | 27 | check_dns (resolvers, unbound, BIND) | PowerDNS; verify hosts duplicates; NIS retired deliberately |
| scheduling | 5 | check_crontabs, check_cron | verify `at` jobs coverage |
| shells | 4 | login shells, umask in shell configs | console TTYs (verify), idle-session killing |
| storage_nfs | 8 | check_exports | DONE 2026-10-09: check_nfsd (nfs015w/016i; daemon consistency) |
| usb | 3 | check_storage (USB storage) | authorization detail |

## Gap (10 groups)

| Lynis group | Tests | Target |
|---|---|---|
| hardening | 4 | DONE 2026-10-09: check_compilers (cmp001i/002w/003w; C toolchains and scanner presence) |
| kerberos | 6 | DONE 2026-10-09, client side: check_kerberos (krb001w/002i/003w; weak crypto, keytab). KDC server-side out of scope |
| ldap | 2 | DONE 2026-10-09: check_ldap (ldap001w/002w; client bindpw and server rootpw readability, server TLS) |
| php | 9 | DONE 2026-10-09: check_php (php001w/002i/003i; allow_url_include, expose_php, display_errors, all SAPIs) |
| printers_spoolers | 9 | DONE 2026-10-09: check_printers (print001w/002w/003w; browsing, listen, URI creds; printcap stays retired) |
| snmp | 3 | DONE 2026-10-09: check_snmp (snmp001w/002i/003i; write communities, defaults) |
| squid | 11 | DONE 2026-10-09: check_squid (squid001w/002w/003w; open proxy, port lock, secrets) |
| storage | 1 | DONE 2026-10-09: stor010w folded into check_storage (Tiger_Storage_NoFireWire) |
| tooling | 9 | DONE 2026-10-09: check_ids (ids001w/002w/003i; blind watchers, inventory) |
| virtualization | 1 | DONE 2026-10-09: osv003i in check_release (live-only guest detection) |

## N/A (2 files)

| Lynis file | Tests | Note |
|---|---|---|
| custom.template | 3 | template for custom tests, not real coverage |
| system_integrity | 1 | SINT-7010, macOS SIP status; rides the macOS phase |

## Deliberate exceptions (parity does not override these)

- No live probing: NIS zone transfers and anything needing crafted
  packets stay out (read-only and offline by default).
- Retired legacy: NIS/NIS+, printcap, inetd-era services stay retired;
  their Lynis counterparts count as intentionally uncovered.
- No copied code: every port is written from the upstream documentation
  of the thing being checked.

## Counts

Covered 6, strong 10, partial 15, gap 10, N/A 2: 43 files, 477
real tests. Phase A finished 2026-10-09: first-phase checks for
the ten gap groups (Kerberos, LDAP, PHP, SNMP, Squid, CUPS, IDS
presence, compilers, FireWire, guest detection), second phases
for databases, mail, MAC frameworks, crypto, file integrity, and
filesystems, and the verify-marked items above. What remains is
Phase B and beyond.
