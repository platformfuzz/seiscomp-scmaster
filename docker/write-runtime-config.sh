#!/bin/bash
set -euo pipefail

export SEISCOMP_ROOT="${SEISCOMP_ROOT:-/home/sysop/seiscomp}"
DB_HOST="${DB_HOST:-mariadb}"
DB_USER="${DB_USER:-sysop}"
DB_PASSWORD="${DB_PASSWORD:-sysop}"
DB_NAME="${DB_NAME:-seiscomp}"
SEEDLINK_HOST="${SEEDLINK_HOST:-seedlink}"
SCMASTER_HOST="${SCMASTER_HOST:-scmaster}"
SDS_ROOT="${SDS_ROOT:-$SEISCOMP_ROOT/var/lib/archive}"

python3 - "$SEISCOMP_ROOT" "$DB_HOST" "$DB_USER" "$DB_PASSWORD" "$DB_NAME" \
  "$SEEDLINK_HOST" "$SCMASTER_HOST" "$SDS_ROOT" <<'PY'
import pathlib, sys
root, db_host, db_user, db_password, db_name, seedlink, scmaster, sds = sys.argv[1:]
dsn = f"mysql://{db_user}:{db_password}@{db_host}/{db_name}"
store = f"{db_user}:{db_password}@{db_host}/{db_name}"
g = pathlib.Path(root) / "etc" / "global.cfg"
text = g.read_text() if g.exists() else ""
keys = {
    "recordstream": f"slink://{seedlink}:18000",
    "connection.server": f"{scmaster}/production",
    "database": dsn,
}
seen = set()
lines = []
for line in text.splitlines():
    raw = line.strip()
    if not raw or raw.startswith("#") or "=" not in line:
        lines.append(line)
        continue
    key = line.split("=", 1)[0].strip()
    if key in keys:
        lines.append(f"{key} = {keys[key]}")
        seen.add(key)
    else:
        lines.append(line)
for key, val in keys.items():
    if key not in seen:
        lines.append(f"{key} = {val}")
g.parent.mkdir(parents=True, exist_ok=True)
g.write_text("\n".join(lines) + "\n")

s = pathlib.Path(root) / "etc" / "scmaster.cfg"
if s.exists() or True:
    stext = s.read_text() if s.exists() else ""
    skeys = {
        "interface.bind": "0.0.0.0:18180",
        "queues.production.processors.messages.dbstore.read": store,
        "queues.production.processors.messages.dbstore.write": store,
    }
    sseen = set()
    slines = []
    for line in stext.splitlines():
        raw = line.strip()
        if not raw or raw.startswith("#") or "=" not in line:
            slines.append(line)
            continue
        key = line.split("=", 1)[0].strip()
        if key in skeys:
            slines.append(f"{key} = {skeys[key]}")
            sseen.add(key)
        else:
            slines.append(line)
    for key, val in skeys.items():
        if key not in sseen:
            slines.append(f"{key} = {val}")
    s.write_text("\n".join(slines) + "\n")

f = pathlib.Path(root) / "etc" / "fdsnws.cfg"
if f.exists():
    ftext = f.read_text()
    fkeys = {
        "listenAddress": "0.0.0.0",
        "port": "8080",
        "recordstream": f"sdsarchive://{sds}",
    }
    fseen = set()
    flines = []
    for line in ftext.splitlines():
        raw = line.strip()
        if not raw or raw.startswith("#") or "=" not in line:
            flines.append(line)
            continue
        key = line.split("=", 1)[0].strip()
        if key in fkeys:
            flines.append(f"{key} = {fkeys[key]}")
            fseen.add(key)
        else:
            flines.append(line)
    for key, val in fkeys.items():
        if key not in fseen:
            flines.append(f"{key} = {val}")
    f.write_text("\n".join(flines) + "\n")
PY
