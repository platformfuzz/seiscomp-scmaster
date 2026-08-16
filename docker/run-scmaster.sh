#!/bin/bash
set -euo pipefail
export SEISCOMP_ROOT="${SEISCOMP_ROOT:-/home/sysop/seiscomp}"
export PATH="$SEISCOMP_ROOT/bin:$PATH"

mkdir -p "$SEISCOMP_ROOT/var/run" "$SEISCOMP_ROOT/var/log"

DB_HOST="${DB_HOST:-mariadb}"
DB_USER="${DB_USER:-sysop}"
DB_PASSWORD="${DB_PASSWORD:-sysop}"
DB_NAME="${DB_NAME:-seiscomp}"

station_count() {
  mariadb --skip-ssl -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -N \
    -e "SELECT COUNT(*) FROM Station" "$DB_NAME" 2>/dev/null || echo 0
}

inv="$SEISCOMP_ROOT/etc/inventory/ge-lab.xml"
if [ -f "$inv" ]; then
  echo "importing baked inventory..."
  seiscomp exec import_inv fdsnxml "$inv" || true
fi

echo "syncing inventory to database..."
ok_cfg=0
for _ in $(seq 1 15); do
  if seiscomp update-config inventory; then
    ok_cfg=1
    break
  fi
  sleep 4
done
if [ "$ok_cfg" != "1" ]; then
  echo "seiscomp update-config inventory failed" >&2
  exit 1
fi

ok=0
for _ in $(seq 1 60); do
  n=$(station_count)
  n=${n//[^0-9]/}
  echo "Station rows: ${n:-0}"
  if [ "${n:-0}" -ge 4 ]; then
    ok=1
    break
  fi
  sleep 2
done
if [ "$ok" != "1" ]; then
  echo "inventory did not appear in MariaDB (need 4 stations)" >&2
  exit 1
fi

# trunk.py always talks to localhost:18180. Wait for the kernel scmaster
# started by update-config inventory, then push station bindings into the
# catalog so processors (scautopick, …) are not empty.
echo "waiting for local scmaster on 18180..."
ok_ms=0
for _ in $(seq 1 30); do
  if python3 -c 'import socket; socket.create_connection(("127.0.0.1",18180),2).close()' 2>/dev/null; then
    ok_ms=1
    break
  fi
  sleep 2
done
if [ "$ok_ms" != "1" ]; then
  echo "scmaster not listening on 18180 after inventory sync" >&2
  exit 1
fi

echo "syncing trunk bindings to catalog..."
if ! seiscomp update-config trunk; then
  echo "seiscomp update-config trunk failed" >&2
  exit 1
fi

seiscomp enable scmaster >/dev/null || true
echo "starting scmaster on 18180"
if python3 -c 'import socket; socket.create_connection(("127.0.0.1",18180),1).close()' 2>/dev/null; then
  echo "scmaster already listening on 18180"
  while python3 -c 'import socket; socket.create_connection(("127.0.0.1",18180),2).close()' 2>/dev/null; do
    sleep 5
  done
  echo "scmaster stopped listening" >&2
  exit 1
fi
exec seiscomp exec scmaster --console 1
