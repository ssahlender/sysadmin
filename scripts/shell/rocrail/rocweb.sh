#!/usr/bin/env bash
#
# rocweb.sh - enable, disable or inspect the Rocweb browser client for a Rocrail workspace.
#
# Why this is a separate script and not a flag of install-linux.sh: Rocweb is a per-workspace
# setting that lives in the workspace's rocrail.ini, which the server does not create until its
# first start. A standalone helper works identically on the Raspberry Pi, on a container, and on
# any future server, and it can be re-run whenever a workspace is replaced.
#
# Verified 2026-10-03 against the Rocrail build published that day (see REVIEW.md for the
# per-platform revisions; none is pinned here because they change with every snapshot):
#   * a hand-inserted <http>/<webclient> element SURVIVES Rocrail's own ini rewrite at shutdown
#     (Rocrail keeps the previous file as rocrail.ini.bak), across repeated start/stop cycles;
#   * Rocweb then answers on its port while the Server-Monitor keeps answering on 8008.
#
# Rocweb is a supporter feature: the wiki documents 5 minutes of demo operation per server start
# without a valid support key (lic.dat in the server's working directory).

set -euo pipefail

# The parse loop consumes "$@"; the sudo re-exec below must see the ORIGINAL arguments.
ORIG_ARGS=("$@")

UNIT_PATH="/etc/systemd/system/rocrail.service"
WORKSPACE=""
PORT="8088"
WEBPATH=""
SERVER_MONITOR_PORT="8008"
ACTION=""
WS_SET=0

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: rocweb.sh <enable|disable|status> [options]

  --workspace DIR        workspace directory (default: read from the install record, then the
                         -w path in the systemd unit)
  --port N               Rocweb port, must differ from the Server-Monitor port (default: 8088)
  --webpath DIR          Rocweb asset directory (default: <prefix>/web)
  --unit-path FILE       systemd unit to read/restart (default: /etc/systemd/system/rocrail.service)
  --monitor-port N       Server-Monitor port to avoid (default: 8008)
  -h, --help             this help

Notes:
  * enable stops the service, edits rocrail.ini, starts it again and then verifies the port.
    Stopping first is deliberate: Rocrail writes its in-memory configuration back at shutdown,
    so an edit made while it runs can be overwritten.
  * The edit is XML-validated and written atomically. Nothing is deleted: each edit keeps a
    timestamped copy of the previous rocrail.ini.
  * disable sets the Rocweb port to 0, which is how the server means "off".
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    enable|disable|status) ACTION="$1"; shift ;;
    --workspace)     WORKSPACE="${2:-}"; WS_SET=1; shift 2 ;;
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

if [ -n "$WORKSPACE" ]; then
  case "$WORKSPACE" in
    *[![:print:]]*) die "--workspace must not contain control characters" ;;
    /*) ;;
    *) die "--workspace must be an absolute path: '$WORKSPACE'" ;;
  esac
fi

# ---------------------------------------------------------------- install record (preferred)
# install-linux.sh writes the effective options next to the build. Reading that is more robust
# than re-parsing a unit file whose quoting and argument order are not ours to control.
unit_execstart() { awk -F'ExecStart=' '/^ExecStart=/{ print $2; exit }' "$UNIT_PATH"; }

unit_arg() { # $1 = option letter, e.g. -w ; handles "-w value", "-wvalue" and quoted values
  unit_execstart | tr ' ' '\n' | awk -v o="$1" '
    $0 == o { getline; gsub(/^["'\'']|["'\'']$/, ""); print; exit }
    index($0, o "=") == 1 { v = substr($0, length(o) + 2); gsub(/^["'\'']|["'\'']$/, "", v); print v; exit }
    index($0, o) == 1 && length($0) > length(o) { v = substr($0, length(o) + 1); gsub(/^["'\'']|["'\'']$/, "", v); print v; exit }
  '
}

LIBDIR="$(unit_arg -l)"
PREFIX=""
[ -n "$LIBDIR" ] && PREFIX="$(dirname "$LIBDIR")"

opt_from_record() { # $1 = key, read from the install record in the derived prefix
  [ -n "$PREFIX" ] || return 0
  [ -f "${PREFIX}/install-options.conf" ] || return 0
  awk -F= -v k="$1" '$1 == k { print substr($0, index($0, "=") + 1); exit }' \
      "${PREFIX}/install-options.conf" 2>/dev/null | tr -d '\r' || true
}

if [ "$WS_SET" -eq 0 ]; then
  rec_wsdir="$(opt_from_record WORKSPACE_DIR)"
  rec_wsname="$(opt_from_record WORKSPACE_NAME)"
  if [ -n "$rec_wsdir" ] && [ -n "$rec_wsname" ]; then
    WORKSPACE="${rec_wsdir}/${rec_wsname}"
    log "Workspace from the install record: ${WORKSPACE}"
  else
    WORKSPACE="$(unit_arg -w)"
    [ -n "$WORKSPACE" ] || die "could not determine the workspace; pass --workspace DIR"
    log "Workspace taken from ${UNIT_PATH}: ${WORKSPACE}"
  fi
fi
WORKSPACE="${WORKSPACE%/}"
case "$WORKSPACE" in
  /*) ;;
  *) die "the resolved workspace is not an absolute path: '$WORKSPACE' (pass --workspace DIR)" ;;
esac
# The install record and the unit can disagree: --rollback restores the older sidecar while the
# unit keeps the newer options, and an update can write one without the other. Enabling Rocweb in
# the wrong workspace looks like success and does nothing, so refuse rather than pick one.
u_ws="$(unit_arg -w)"
u_ws="${u_ws%/}"
if [ -n "$u_ws" ] && [ "$u_ws" != "$WORKSPACE" ]; then
  if [ "$WS_SET" -eq 1 ]; then
    warn "you asked for workspace ${WORKSPACE}, but ${UNIT_PATH} runs with -w ${u_ws}."
    warn "Editing the one you named; the running server will not pick the change up."
  else
    die "the workspace to edit is ambiguous:
  the install record says   ${WORKSPACE}
  ${UNIT_PATH} runs with -w ${u_ws}
Refusing to edit a workspace the server does not use. Pass --workspace DIR to choose one
deliberately, or fix whichever of the two is wrong."
  fi
fi

if [ ! -d "$WORKSPACE" ]; then
  warn "the workspace directory does not exist yet: $WORKSPACE"
fi

if [ -z "$WEBPATH" ]; then
  [ -n "$PREFIX" ] || die "could not derive the prefix; pass --webpath DIR"
  WEBPATH="${PREFIX}/web"
fi

INI="${WORKSPACE}/rocrail.ini"

# The ini, not the command line, is the truth about what is configured - so it is read back
# rather than assumed, in both the status output and the collision checks below.
ini_webclient_port() { # the <webclient port="N"> of this workspace
  [ -f "$INI" ] || return 0
  awk 'match($0, /<webclient[^>]*port="[0-9]+"/) {
         s = substr($0, RSTART, RLENGTH); sub(/.*port="/, "", s); sub(/".*/, "", s); print s; exit
       }' "$INI" 2>/dev/null || true
}

ini_http_port() { # the <http port="N"> = the Server-Monitor's port
  [ -f "$INI" ] || return 0
  awk 'match($0, /<http[^>]*port="[0-9]+"/) {
         s = substr($0, RSTART, RLENGTH); sub(/.*port="/, "", s); sub(/".*/, "", s); print s; exit
       }' "$INI" 2>/dev/null || true
}

# ---------------------------------------------------------------- status
if [ "$ACTION" = "status" ]; then
  log "workspace      : $WORKSPACE"
  log "ini            : $INI"
  if [ ! -f "$INI" ]; then
    log "state          : no rocrail.ini (start the server once - it creates the workspace)"
    exit 2
  fi
  CUR="$(ini_webclient_port)"
  log "rocweb port    : ${CUR:-<not configured>}"
  if [ -n "$CUR" ] && [ "$CUR" != "0" ]; then
    if command -v curl >/dev/null 2>&1; then
      HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
      CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:${CUR}/" 2>/dev/null || true)"
      # curl prints 000 when it could not connect at all; report that as "no answer", not as a code
      case "$CODE" in 000) CODE="" ;; esac
      log "listening      : ${CODE:-no answer}"
      if [ -n "$HOST_IP" ]; then log "url            : http://${HOST_IP}:${CUR}/"; fi
      if [ "$CODE" = "200" ]; then exit 0; fi
      exit 1
    fi
  fi
  if [ -n "$CUR" ] && [ "$CUR" != "0" ]; then exit 0; fi
  exit 1
fi

# ---------------------------------------------------------------- root required
if [ "$(id -u)" -ne 0 ]; then
  log "Root is required to edit ${INI} and restart ${UNIT_NAME}; re-running with sudo."
  # ORIG_ARGS, not "$@": the parse loop above has already consumed "$@".
  exec sudo "$0" "${ORIG_ARGS[@]}"
fi

[ -f "$INI" ] || die "no workspace ini at $INI - start the server once so Rocrail creates it"
[ -L "$INI" ] && die "$INI is a symlink; refusing to write through it"
[ -w "$INI" ] || die "$INI is not writable"
# Check everything that can fail BEFORE stopping the service, so a missing tool cannot leave
# the server down.
command -v python3 >/dev/null 2>&1 || die "python3 is required to edit the ini safely"

# One editor at a time: a concurrent run could rewrite the ini under this one.
LOCK="${WORKSPACE}/.rocweb.lock"
# NOT `exec 9>"$LOCK" 2>/dev/null`: redirections on a bare `exec` are permanent, so that
# would send every die/warn for the rest of this run to /dev/null - including the python
# refusals. See the same note in install-linux.sh.
exec 9>"$LOCK" || die "cannot open lock file ${LOCK}"
if command -v flock >/dev/null 2>&1; then
  flock -n 9 || die "another rocweb.sh run is already editing ${INI}"
fi

TARGET_PORT="$PORT"
[ "$ACTION" = "disable" ] && TARGET_PORT="0"

# Everything that can fail happens before the service is stopped: a port that is already taken
# would otherwise leave the server DOWN as well as Rocweb unconfigured.
if [ "$TARGET_PORT" != "0" ]; then
  UNIT_PORT="$(unit_arg -p)"
  if [ -n "$UNIT_PORT" ] && [ "$TARGET_PORT" = "$UNIT_PORT" ]; then
    die "Rocweb port ${TARGET_PORT} is the port the server itself serves clients on (-p ${UNIT_PORT})"
  fi
  # --monitor-port is only an input; if the ini already pins the Server-Monitor port, say that
  # this run changes it rather than silently moving the monitor.
  EX_HTTP="$(ini_http_port)"
  if [ -n "$EX_HTTP" ] && [ "$EX_HTTP" != "$SERVER_MONITOR_PORT" ]; then
    warn "${INI} already serves the Server-Monitor on ${EX_HTTP}; this run changes that to ${SERVER_MONITOR_PORT}."
  fi
  # Listening already? Ignore this workspace's own Rocweb, which is about to be restarted.
  if [ "$(ini_webclient_port)" != "$TARGET_PORT" ] && command -v ss >/dev/null 2>&1; then
    if ss -ltn "sport = :${TARGET_PORT}" 2>/dev/null | grep -q LISTEN; then
      warn "port ${TARGET_PORT} is already in use:"
      ss -ltnp "sport = :${TARGET_PORT}" 2>/dev/null | sed 's/^/    /' || true
      die "refusing to configure Rocweb on port ${TARGET_PORT}"
    fi
  fi
fi

WAS_ACTIVE=0
# is-activating matters as much as is-active here: a crash-looping unit sits in
# "activating (auto-restart)", so testing only is-active would edit the ini underneath a live
# process that rewrites it at shutdown.
if systemctl is-active --quiet "$UNIT_NAME" 2>/dev/null \
   || systemctl is-activating --quiet "$UNIT_NAME" 2>/dev/null; then
  WAS_ACTIVE=1
  log "Stopping ${UNIT_NAME} (Rocrail rewrites the ini at shutdown)."
  systemctl stop "$UNIT_NAME"
  # Wait for it to actually go inactive before touching the file.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    systemctl is-active --quiet "$UNIT_NAME" 2>/dev/null \
      || systemctl is-activating --quiet "$UNIT_NAME" 2>/dev/null || break
    sleep 1
  done
  if systemctl is-active --quiet "$UNIT_NAME" 2>/dev/null \
     || systemctl is-activating --quiet "$UNIT_NAME" 2>/dev/null; then
    die "${UNIT_NAME} did not stop; not editing the ini"
  fi
fi

# From here on the service is down. Whatever happens next - a python failure, a full disk, a
# signal - the server must come back up.
if [ "$WAS_ACTIVE" -eq 1 ]; then
  trap 'systemctl start "$UNIT_NAME" >/dev/null 2>&1 || true' EXIT
fi

BACKUP="${INI}.rocweb-$(date -u +%Y%m%dT%H%M%S)-$$"
if [ -e "$BACKUP" ]; then
  die "backup path already exists: $BACKUP"
fi
cp -p "$INI" "$BACKUP"
log "Previous ini kept as ${BACKUP}"

# ---------------------------------------------------------------- edit (XML-aware, atomic)
python3 - "$INI" "$TARGET_PORT" "$WEBPATH" "$SERVER_MONITOR_PORT" <<'PY'
import os, re, sys
import xml.etree.ElementTree as ET

path, port, webpath, monitor = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

if os.path.islink(path):
    sys.exit(f"refusing to edit a symlink: {path}")

def esc(v):
    # attribute-value escaping: the value goes into the document as XML
    return (v.replace("&", "&amp;").replace("<", "&lt;")
             .replace(">", "&gt;").replace('"', "&quot;"))

try:
    with open(path, encoding="utf-8", newline="") as fh:
        s = fh.read()
except UnicodeDecodeError as exc:
    sys.exit(f"{path} is not valid UTF-8 ({exc}); refusing to edit it")

# Did the ORIGINAL parse? If Rocrail wrote something ElementTree cannot read, do not turn
# that into a failure - only require that we do not make it worse.
original_ok = True
try:
    ET.fromstring(s)
except Exception:
    original_ok = False

elements = list(re.finditer(r'<webclient\b[^>]*>', s))
if len(elements) > 1:
    sys.exit("there is more than one <webclient> element in the file; refusing to guess which "
             "one is the live one - fix the ini by hand")

ATTRS = ('imgpath="images" svgpath1="svg/themes/SpDrS60" svgpath2="svg/themes/Accessories" '
         'svgpath3="svg/themes/Roads" svgpath4="." svgpath5="." svgpath6="." svguserprops=""')

def set_attr(el, name, value):
    # A lambda replacement, not a template string: a backslash or \g<...> in the value would
    # otherwise be interpreted by re.sub's template expansion.
    if re.search(rf'\b{name}="[^"]*"', el):
        return re.sub(rf'\b{name}="[^"]*"', lambda _m: f'{name}="{esc(value)}"', el, count=1)
    return el.replace("<webclient", f'<webclient {name}="{esc(value)}"', 1)

note = ""
if elements:
    el = elements[0].group(0)
    el = set_attr(el, "port", port)
    el = set_attr(el, "webpath", webpath)
    s = s[:elements[0].start()] + el + s[elements[0].end():]
    note = "updated the existing <webclient>"
else:
    webel = f'<webclient port="{esc(port)}" webpath="{esc(webpath)}" {ATTRS}/>'
    mh = re.search(r'<http\b[^>]*>', s)
    if mh and mh.group(0).rstrip().endswith('/>'):
        # a self-closing <http .../> cannot take a child: expand it into a container
        attrs = mh.group(0).rstrip()[:-2].strip()
        s = s[:mh.start()] + f'{attrs}>\n    {webel}\n  </http>' + s[mh.end():]
        note = "expanded a self-closing <http/> and inserted <webclient>"
    elif mh:
        s = s[:mh.end()] + f'\n    {webel}' + s[mh.end():]
        note = "inserted <webclient> into the existing <http>"
    else:
        if "</rocrail>" not in s:
            sys.exit("no </rocrail> closing tag found; the file is malformed, not editing it")
        block = f'  <http port="{esc(monitor)}" shortids="false">\n    {webel}\n  </http>\n'
        s = s.replace("</rocrail>", block + "</rocrail>", 1)
        note = "inserted an <http>/<webclient> block"

if original_ok:
    try:
        ET.fromstring(s)
    except Exception as exc:
        sys.exit(f"the edited document is not well-formed XML: {exc}")

# Atomic replace, preserving owner and mode. A write failure must not truncate the live file.
st = os.stat(path)
tmp = f"{path}.rocweb-tmp-{os.getpid()}"
with open(tmp, "w", encoding="utf-8", newline="") as fh:
    fh.write(s)
try:
    os.chmod(tmp, st.st_mode & 0o7777)
    os.chown(tmp, st.st_uid, st.st_gid)
except OSError as exc:
    os.unlink(tmp)
    sys.exit(f"could not preserve ownership/mode on the edited file: {exc}")
os.replace(tmp, path)
print(note)
PY

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

# The server was not running when we started, so there is nothing to start and nothing to
# probe. Starting it here would override a deliberate stop. The edit is still correct.
if [ "$WAS_ACTIVE" -eq 0 ]; then
  log ""
  log "Rocweb is enabled in ${INI}."
  log "  ini     : $INI"
  log "  backup  : $BACKUP"
  log "  note    : ${UNIT_NAME} was not running, so it was left stopped. The setting applies"
  log "            the next time it starts (systemctl start ${UNIT_NAME})."
  exit 0
fi

# Give it time: a Pi with a large plan can take a while to open the port, and the old 10 s window
# could report failure for a correct edit. Then require the page to look like Rocweb - a foreign
# service answering 200 on that port would otherwise pass for success.
CODE=""
for _ in $(seq 1 30); do
  RESP="$(curl -sS -w '\n%{http_code}' --max-time 2 "http://127.0.0.1:${PORT}/" 2>/dev/null || true)"
  CODE="${RESP##*$'\n'}"
  BODY="${RESP%$'\n'*}"
  if [ "$CODE" = "200" ] && printf '%s' "$BODY" | grep -qi 'rocrail'; then
    break
  fi
  if [ "$CODE" = "200" ]; then
    warn "port ${PORT} answers 200 but the page does not look like Rocrail - still waiting"
  fi
  sleep 2
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
