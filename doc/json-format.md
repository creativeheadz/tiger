# The Tigris JSON report

Every run writes its findings twice: as the text report people read, and
as JSON Lines for programs, in `log/security.report.HOST.DATE.jsonl`. This
page is the contract for the second one. The machine-readable form of it
is [tigris-report.schema.json](tigris-report.schema.json) (JSON Schema,
2020-12), and CI validates a real run against it on every push.

## Shape

One JSON object per line, UTF-8-safe plain ASCII, three kinds in this
order:

```
{"type":"run","schema":1,"id":"…","tool":"tigris","version":"3.2.4, 2026.10.04.15.40","host":"Hera","os":"Linux","release":"7.0.0-38-generic","arch":"x86_64","config":"./tigerrc","start":"2026-10-05T07:12:03Z"}
{"type":"finding","level":"WARN","id":"ssh008w","check":"check_ssh","message":"sshd: x11forwarding is yes: X11 is forwarded, which exposes the client's display to this server","category":"ssh"}
{"type":"finding","level":"WARN","id":"lin015w","check":"check_network_config","message":"The system has IP forwarding enabled","accepted":{"reason":"Docker needs IP forwarding","until":"-"},"category":"network"}
{"type":"summary","id":"…","end":"2026-10-05T07:14:01Z","counts":{"ALERT":0,"FAIL":12,"WARN":52,"INFO":132,"ERROR":0}}
```

### `run`

| field | meaning |
|---|---|
| `schema` | The version of this format. Currently `1`. |
| `id` | Unique to the run; the `summary` repeats it. |
| `tool`, `version` | `tigris` and the release that produced the file. |
| `host`, `os`, `release`, `arch` | What was audited. `release` is the kernel on Linux. |
| `config` | The `tigerrc` the run used, since that decides what was checked. |
| `profile` | Optional. The profile applied on top of it (`--profile`): `quick`, `server`, `desktop`, `container`, or a site's own. A diff between runs with different configs or profiles says `configs_differ`. |
| `filesystem_scan` | `false` when the filesystem scan was switched off (the quick profile). Such a run has no `fsys*` findings because it did not look for them, not because there are none. Absent in reports from before the field existed, which always scanned. |
| `start` | UTC, `YYYY-MM-DDTHH:MM:SSZ`. |

### `finding`

| field | meaning |
|---|---|
| `level` | `ALERT`, `FAIL`, `WARN`, `INFO` or `ERROR`. Most to least urgent, `ERROR` meaning the check could not run. |
| `id` | The message id, e.g. `lin016f`: three to seven lower-case letters, three digits, and a last letter that repeats the level. Stable: `tigris explain lin016f` explains it. |
| `check` | The script that reported it. |
| `message` | The text, on one line. |
| `detail` | Optional. Extra lines the check printed (for example a file listing), joined with `\n`. |
| `category` | The area the finding belongs to, from its metadata file `meta/ID`: `accounts`, `boot`, `containers`, `cron`, `filesystem`, `firewall`, `integrity`, `intrusion`, `kernel`, `logging`, `network`, `packages`, `services`, `ssh` or `tigris` ([metadata.md](metadata.md)). Absent in reports written before 3.4.0. |
| `accepted` | Optional. Present when the finding was accepted with `tigris-accept`: `reason`, and `until` as `YYYY-MM-DD` or `-` for no expiry. An accepted finding is **not** in the text report. A consumer that wants the same view as the text report skips findings that have `accepted`. |

`INFO` findings are always here, whatever the text report shows.

### `summary`

`end` (UTC) and `counts` per level. A report with no `summary` line was cut
short, and a consumer should treat it as incomplete.

### `diff`

`tigris-diff -j OLD NEW` prints one object: `from` and `to` (the two `run`
records), `new` and `resolved` (arrays of `finding` records) and
`unchanged` (a count). Two findings are the same when `level`, `id` and
`message` are all equal. A new finding that carries `accepted` is in `new`
like any other; the exit status (1 when something is new) does not count
it, and the text output marks it "(accepted)". `tigris --since RUN` runs
this comparison against the new report and takes its exit status from
the worst new finding that is not accepted.

When either run skipped the filesystem scan, all `fsys*` findings are
left out of both sides, so they show as neither new nor resolved, and the
object carries `"set_aside":["fsys"]`. When the two runs used different
`tigerrc` files it carries `"configs_differ":true`: a check switched on in
only one of them will show its findings as new or resolved, and a
consumer should say so rather than raise an alarm.

## Encoding

The file is plain ASCII. Quotes, backslashes and control characters are
escaped as JSON requires. Every byte above 127 is written as `\u00XX`, one
per **byte**, not per character, because Tigris does not know the encoding
of the file names it meets. A name that is UTF-8 on disk therefore arrives
as two escapes; to get the original text back, build the bytes
(`bytes(ord(c) for c in s)` in Python, `s.encode("latin-1")`) and decode
them as whatever the file system uses.

## Versioning

`schema` changes only when something is removed, renamed or changes
meaning. Adding a field to a record, a value to `level`'s neighbours, or a
whole new record type does not, so a consumer must:

- ignore fields it does not know,
- ignore records whose `type` it does not know,
- read the `run` record first and refuse a `schema` greater than the one
  it was written for.

## Validating

```
python3 -m jsonschema -i record.json doc/tigris-report.schema.json   # one record
tests/schema_check.sh log/security.report.HOST.DATE.jsonl            # a whole file
```

`tests/schema_check.sh` needs Python with the `jsonschema` package
(`apt install python3-jsonschema`); without it the test skips.
