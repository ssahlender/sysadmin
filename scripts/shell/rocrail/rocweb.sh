#!/usr/bin/env bash
#
# rocweb.sh - enable, disable or inspect the Rocweb browser client for a Rocrail workspace.
#
# Why this is a separate script and not a flag of install-linux.sh: Rocweb is a per-workspace
# setting that lives in the workspace's rocrail.ini, which the server does not create until its
# first start. A standalone helper works identically on the Raspberry Pi, on a container, and on
# any future server, and it can be re-run whenever a workspace is replaced.
#
# Verified 2026-10-03 against Rocrail revision 7454:
#   * a hand-inserted <http>/<webclient> element SURVIVES Rocrail's own ini rewrite at shutdown
#     (Rocrail keeps the previous file as rocrail.ini.bak), across repeated start/stop cycles;
#   * Rocweb then answers on its port while the Server-Monitor keeps answering on 8008.
#
# Rocweb is a supporter feature: the wiki documents 5 minutes of demo operation per server start
# without a valid support key (lic.dat in the server's working directory).

set -euo pipefail

UNIT_PATH="/etc/systemd/system/rocrail.service"
WORKSPACE=""
PORT="8088"
WEBPATH=""
SERVER_MONITOR_PORT="8008"
ACTION=""

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: rocweb.sh <enable|disable|status> [options]

  --workspace DIR        workspace directory (default: the -w path from the systemd unit)
  --port N               Rocweb port, must differ from the Server-Monitor port (default: 8088)
  --webpath DIR          Rocweb asset directory (default: <prefix>/web, derived from the unit)
  --unit-path FILE       systemd unit to read/restart (default: /etc/systemd/system/rocrail.service)
  --monitor-port N       Server-Monitor port to avoid (default: 8008)
  -h, --help             this help

Notes:
  * enable stops the service, edits rocrail.ini, starts it again and then verifies the port.
    Stopping first is deliberate: Rocrail writes its in-memory configuration back at shutdown,
    so an edit made while it runs can be overwritten.
  * Nothing is deleted. Each edit keeps a timestamped copy of the previous rocrail.ini.
  * disable sets the Rocweb port to 0, which is how the server means "off".
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    enable|disable|status) ACTION="$1"; shift ;;
    --workspace)     WORKSPACE="${2:-}"; shift 2 ;;
    --port)          PORT="${2:-}"; shift 2 ;;
    --webpath)       WEBPATH="${2:-}"; shift 2 ;;
    --unit-path)     UNIT_PATH="${2:-}"; shift 2 ;;
    --monitor-port)  SERVER_MONITOR_PORT="${2:-}"; shift 2 ;;
    -h|--help)       usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

[ -n "$ACTION" ] || { usage; exit 1; }
[ -f "$UNIT_PATH" ] || die "unit not found: $UNIT_PATH (is the server installed?)"

UNIT_NAME="$(basename "${UNIT_PATH%.service}")"

case "$PORT" in ''|*[!0-9]*) die "invalid --port: '$PORT'" ;; esac
[ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || die "port out of range: $PORT"
[ "$PORT" != "$SERVER_MONITOR_PORT" ] || die "Rocweb port $PORT collides with the Server-Monitor port"

# ---------------------------------------------------------------- derive from the unit
unit_execstart() { awk -F'ExecStart=' '/^ExecStart=/{ print $2; exit }' "$UNIT_PATH"; }
unit_arg() { # $1 = option letter, e.g. -w
  unit_execstart | tr ' ' '\n' | awk -v o="$1" '$0==o{getline; print; exit}'
}

if [ -z "$WORKSPACE" ]; then
  WORKSPACE="$(unit_arg -w)"
  [ -n "$WORKSPACE" ] || die "could not read -w from $UNIT_PATH; pass --workspace DIR"
  log "Workspace taken from ${UNIT_PATH}: ${WORKSPACE}"
fi
WORKSPACE="${WORKSPACE%/}"

LIBDIR="$(unit_arg -l)"
PREFIX=""
if [ -n "$LIBDIR" ]; then
  PREFIX="$(dirname "$LIBDIR")"
fi
if [ -z "$WEBPATH" ]; then
  [ -n "$PREFIX" ] || die "could not derive the prefix; pass --webpath DIR"
  WEBPATH="${PREFIX}/web"
fi

INI="${WORKSPACE}/rocrail.ini"

# ---------------------------------------------------------------- status
if [ "$ACTION" = "status" ]; then
  log "workspace      : $WORKSPACE"
  log "ini            : $INI"
  if [ ! -f "$INI" ]; then
    log "state          : no rocrail.ini (start the server once - it creates the workspace)"
    exit 2
  fi
  CUR="$(awk 'match($0, /<webclient[^>]*port="[0-9]+"/) { s=substr($0, RSTART, RLENGTH); sub(/.*port="/, "", s); sub(/".*/, "", s); print s; exit }' "$INI" 2>/dev/null || true)"
  log "rocweb port    : ${CUR:-<not configured>}"
  if [ -n "$CUR" ] && [ "$CUR" != "0" ]; then
    if command -v curl >/dev/null 2>&1; then
      HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
      CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:${CUR}/" 2>/dev/null || true)"
      log "listening      : ${CODE:-no answer}"
      [ -n "$HOST_IP" ] && log "url            : http://${HOST_IP}:${CUR}/"
      [ "$CODE" = "200" ] && exit 0
      exit 1
    fi
  fi
  [ -n "$CUR" ] && [ "$CUR" != "0" ] && exit 0
  exit 1
fi

# ---------------------------------------------------------------- root required
if [ "$(id -u)" -ne 0 ]; then
  log "Root is required to edit ${INI} and restart ${UNIT_NAME}; re-running with sudo."
  exec sudo "$0" "$@"
fi

[ -f "$INI" ] || die "no workspace ini at $INI - start the server once so Rocrail creates it"

TARGET_PORT="$PORT"
[ "$ACTION" = "disable" ] && TARGET_PORT="0"

WAS_ACTIVE=0
if systemctl is-active --quiet "$UNIT_NAME" 2>/dev/null; then
  WAS_ACTIVE=1
  log "Stopping ${UNIT_NAME} (Rocrail rewrites the ini at shutdown)."
  systemctl stop "$UNIT_NAME"
fi

BACKUP="${INI}.rocweb-$(date -u +%Y%m%dT%H%M%SZ)"
cp -p "$INI" "$BACKUP"
log "Previous ini kept as ${BACKUP}"

# ---------------------------------------------------------------- edit (XML-aware)
python3 - "$INI" "$TARGET_PORT" "$WEBPATH" <<'PY'
import re, sys
path, port, webpath = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path, encoding="utf-8").read()

ATTRS = ('imgpath="images" svgpath1="svg/themes/SpDrS60" svgpath2="svg/themes/Accessories" '
         'svgpath3="svg/themes/Roads" svgpath4="." svgpath5="." svgpath6="." svguserprops=""')

def set_attr(el, name, value):
    if re.search(rf'\b{name}="[^"]*"', el):
        return re.sub(rf'\b{name}="[^"]*"', f'{name}="{value}"', el, count=1)
    return el.replace("<webclient", f'<webclient {name}="{value}"', 1)

m = re.search(r'<webclient\b[^>]*>', s)
if m:
    el = m.group(0)
    el = set_attr(el, "port", port)
    el = set_attr(el, "webpath", webpath)
    s = s[:m.start()] + el + s[m.end():]
    print("updated existing <webclient>")
else:
    webel = f'<webclient port="{port}" webpath="{webpath}" {ATTRS}/>'
    mh = re.search(r'<http\b[^>]*>', s)
    if mh and mh.group(0).rstrip().endswith('/>'):
        # self-closing <http .../> cannot take a child: expand it into a container
        attrs = mh.group(0).rstrip()[:-2].strip()
        s = s[:mh.start()] + f'{attrs}>\n    {webel}\n  </http>' + s[mh.end():]
        print("expanded self-closing <http/> and inserted <webclient>")
    elif mh:
        s = s[:mh.end()] + f'\n    {webel}' + s[mh.end():]
        print("inserted <webclient> into existing <http>")
    else:
        block = f'  <http port="8008" shortids="false">\n    {webel}\n  </http>\n'
        if "</rocrail>" in s:
            s = s.replace("</rocrail>", block + "</rocrail>", 1)
        else:
            s = s + block
        print("inserted <http>/<webclient> block")

open(path, "w", encoding="utf-8").write(s)
PY

chown --reference="$BACKUP" "$INI" 2>/dev/null || true
chmod --reference="$BACKUP" "$INI" 2>/dev/null || true

# ---------------------------------------------------------------- restart + verify
if [ "$WAS_ACTIVE" -eq 1 ]; then
  log "Starting ${UNIT_NAME}."
  # The service was stopped before the edit, so it MUST come back. Fail loudly rather than
  # exiting on a raw systemd error with the server left down.
  if ! systemctl start "$UNIT_NAME"; then
    warn "COULD NOT RESTART ${UNIT_NAME} - it was stopped before the edit and is DOWN now."
    warn "The ini has been edited; the previous version is kept at ${BACKUP}."
    warn "Bring it back with: systemctl start ${UNIT_NAME}"
    exit 1
  fi
fi

HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"

if [ "$ACTION" = "disable" ]; then
  log "Rocweb disabled (port 0). Server-Monitor stays on ${SERVER_MONITOR_PORT}."
  exit 0
fi

# give the server a moment, then prove it really answers
for _ in 1 2 3 4 5 6 7 8 9 10; do
  CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:${PORT}/" 2>/dev/null || true)"
  [ "$CODE" = "200" ] && break
  sleep 1
done

log ""
if [ "$CODE" = "200" ]; then
  log "Rocweb is up:"
  log "  url        : http://${HOST_IP:-<this host>}:${PORT}/"
  log "  ini        : $INI"
  log "  backup     : $BACKUP"
  log "  monitor    : http://${HOST_IP:-<this host>}:${SERVER_MONITOR_PORT}/"
  log ""
  log "Note: this setting lives in rocrail.ini. If the workspace is synced (e.g. Resilio), the"
  log "enabled port travels with that file to every machine that syncs it."
else
  warn "Rocweb did not answer on port ${PORT} (last HTTP code: ${CODE:-none})."
  warn "The ini was still edited; previous version kept at ${BACKUP}."
  warn "Check: systemctl status ${UNIT_NAME}  /  journalctl -u ${UNIT_NAME} -n 50"
  exit 1
fi
