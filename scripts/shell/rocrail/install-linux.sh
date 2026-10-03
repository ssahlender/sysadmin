#!/usr/bin/env bash
#
# install-linux.sh - install or update the Rocrail SERVER on Linux.
#
# Role split: Linux is the server; Windows and macOS are clients (install-windows.ps1,
# install-macos.sh). The snapshot ships native executables - no Java runtime is installed
# or required by any of the three builds.
#
# This script downloads the build matching the machine's architecture, installs it into a
# prefix, generates a systemd unit FROM THE PARAMETERS YOU PASS (workspace and port are not
# hardcoded), creates the workspace, and starts the service.
#
# Re-running it is the supported update path: the service is stopped, the build is replaced
# atomically, the previous build is kept as <prefix>.prev, and the unit is regenerated.
#
# Verified against Rocrail revision 7454 (2026-10-03). See REVIEW.md for what was verified
# and what was not.
#
# Exit codes for --check: 0 = up to date, 1 = update available, 2 = not installed.

set -euo pipefail

# --------------------------------------------------------------------- download matrix
# Single source of truth for this script. Linux builds live under Debian/; the name encodes
# the distribution the build was COMPILED on, not the one it must run on.
SNAPSHOT_BASE="https://www.rocrail.online/rocrail-snapshot"
REVISION_URL="${SNAPSHOT_BASE}/log.txt"   # newest-first revision list, first line = newest

# --------------------------------------------------------------------- defaults
PREFIX="/opt/rocrail"
WORKSPACE_NAME="rocrail"
WORKSPACE_DIR="/var/lib/rocrail"
SERVICE_PORT="8051"
SERVICE_USER="rocrail"
SERVICE_GROUP=""
VARIANT="auto"          # auto | debian11 | ubuntu24   (x86_64 only)
UNIT_PATH="/etc/systemd/system/rocrail.service"
CONSOLE_MODE=0
DRY_RUN=0
MODE="install"          # install | check | rollback

# --------------------------------------------------------------------- helpers
log()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: install-linux.sh [options]

  --workspace NAME       workspace name                     (default: rocrail)
  --workspace-dir DIR    parent directory for workspaces     (default: /var/lib/rocrail)
  --port N               client service port for Rocview     (default: 8051)
  --prefix DIR           install prefix                      (default: /opt/rocrail)
  --user NAME            service account, created if missing (default: rocrail)
  --group NAME           service group                       (default: same as --user)
  --variant V            x86_64 build: auto|debian11|ubuntu24 (default: auto)
  --unit-path FILE       systemd unit file to write          (default: /etc/systemd/system/rocrail.service)
  --console              start with -console (clients cannot shut the server down)
  --check                report installed vs available and exit (no changes)
  --rollback             restore <prefix>.prev
  --dry-run              show what would be done, change nothing
  -h, --help             this help

Notes:
  * The Rocrail Server-Monitor always listens on port 8008 by default; Rocweb (the browser
    client) is per-workspace, ships disabled, and is enabled with the separate rocweb.sh.
  * A workspace is created by the server on first start (rocrail.ini, plan.xml, occ.xml,
    trace/, issues/). This script only makes the directory and hands it to the service user.
EOF
}

# --------------------------------------------------------------------- arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --workspace)      WORKSPACE_NAME="${2:-}"; shift 2 ;;
    --workspace-dir)  WORKSPACE_DIR="${2:-}";  shift 2 ;;
    --port)           SERVICE_PORT="${2:-}";   shift 2 ;;
    --prefix)         PREFIX="${2:-}";         shift 2 ;;
    --user)           SERVICE_USER="${2:-}";   shift 2 ;;
    --group)          SERVICE_GROUP="${2:-}";  shift 2 ;;
    --variant)        VARIANT="${2:-}";        shift 2 ;;
    --unit-path)      UNIT_PATH="${2:-}";      shift 2 ;;
    --console)        CONSOLE_MODE=1;          shift ;;
    --check)          MODE="check";            shift ;;
    --rollback)       MODE="rollback";         shift ;;
    --dry-run)        DRY_RUN=1;               shift ;;
    -h|--help)        usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

[ -n "$SERVICE_GROUP" ] || SERVICE_GROUP="$SERVICE_USER"

case "$WORKSPACE_NAME" in
  */*|.|..|"") die "invalid workspace name: '$WORKSPACE_NAME'" ;;
esac
case "$SERVICE_PORT" in
  ''|*[!0-9]*) die "invalid port: '$SERVICE_PORT'" ;;
esac
[ "$SERVICE_PORT" -ge 1 ] && [ "$SERVICE_PORT" -le 65535 ] || die "port out of range: $SERVICE_PORT"

PREFIX="${PREFIX%/}"
WORKSPACE_DIR="${WORKSPACE_DIR%/}"
WORKSPACE_PATH="${WORKSPACE_DIR}/${WORKSPACE_NAME}"

# --------------------------------------------------------------------- architecture
ARCH="$(uname -m)"
case "$ARCH" in
  aarch64|arm64|armv8*)
    FILENAME="Rocrail-debian13-ARM64.zip"
    ;;
  x86_64)
    case "$VARIANT" in
      auto|debian11) FILENAME="Rocrail-debian11-i64.zip" ;;
      ubuntu24)      FILENAME="Rocrail-ubuntu24-i64.zip" ;;
      *) die "unknown --variant '$VARIANT' (auto|debian11|ubuntu24)" ;;
    esac
    ;;
  *)
    die "unsupported architecture: $ARCH (supported: aarch64/arm64, x86_64)"
    ;;
esac
DOWNLOAD_URL="${SNAPSHOT_BASE}/Debian/${FILENAME}"

# --------------------------------------------------------------------- read-only helpers
# Every read-only probe below reads its input to EOF on purpose. Closing a pipe early (head)
# makes the producer exit non-zero, and with "set -o pipefail" that would abort the script -
# which is exactly how --check died silently the first time it was run.
advertised_revision() {
  # Newest revision in the snapshot list. Empty on any failure - never fatal.
  curl -fsSL --max-time 20 "$REVISION_URL" 2>/dev/null \
    | awk 'NR==1 { first=$1 } END { if (first != "") print first }' || true
}

remote_last_modified() {
  # HTTP Last-Modified of this platform's archive: the precise "available" signal.
  local lm
  lm="$(curl -fsSIL --max-time 20 -o /dev/null -w '%{header_json}' "$DOWNLOAD_URL" 2>/dev/null \
        | tr -d '\n' | sed -n 's/.*"last-modified":\["\([^"]*\)".*/\1/p')" || true
  if [ -z "$lm" ]; then
    lm="$(curl -fsSIL --max-time 20 "$DOWNLOAD_URL" 2>/dev/null \
          | awk 'tolower($1)=="last-modified:"{ if (lm=="") lm=substr($0, index($0," ")+1) } \
                 END { if (lm != "") print lm }')" || true
  fi
  printf '%s' "$lm"
}

installed_revision() {
  # "Revision: 7454 (i64, debian11)" -> "7454"
  [ -f "${PREFIX}/revision.info" ] || return 0
  awk '/^Revision:/{ print $2; exit }' "${PREFIX}/revision.info" 2>/dev/null || true
}

installed_build() {
  [ -f "${PREFIX}/revision.info" ] || return 0
  awk '/^Revision:/{ if (match($0, /\([^)]*\)/)) print substr($0, RSTART+1, RLENGTH-2); exit }' \
      "${PREFIX}/revision.info" 2>/dev/null || true
}

recorded_install() {
  [ -f "${PREFIX}/install-record.json" ] || return 0
  cat "${PREFIX}/install-record.json"
}

primary_ip() {
  hostname -I 2>/dev/null | awk '{print $1}'
}

# --------------------------------------------------------------------- check mode
if [ "$MODE" = "check" ]; then
  rev_inst="$(installed_revision)"
  rev_adv="$(advertised_revision)"
  lmod="$(remote_last_modified)"
  ip="$(primary_ip)"

  log "platform        : $ARCH   build: $FILENAME"
  log "prefix          : $PREFIX"
  log "workspace       : $WORKSPACE_PATH"
  log "url             : $DOWNLOAD_URL"
  log "installed       : ${rev_inst:-<not installed>}${rev_inst:+ $(installed_build)}"
  log "available (log) : ${rev_adv:-<unavailable>}"
  log "available (file): ${lmod:-<unavailable>}"
  if [ -n "$(recorded_install)" ]; then
    log "last installed  : $(recorded_install | tr -d '\n')"
  fi

  if [ -z "$rev_inst" ]; then
    log "verdict         : NOT INSTALLED"
    exit 2
  fi
  if [ -n "$rev_adv" ] && [ "$rev_inst" = "$rev_adv" ]; then
    log "verdict         : up to date"
    exit 0
  fi
  log "verdict         : UPDATE AVAILABLE (installed ${rev_inst}, newest ${rev_adv:-unknown})"
  if [ -n "$ip" ]; then
    log "note            : re-run without --check to update"
  fi
  exit 1
fi

# --------------------------------------------------------------------- rollback mode
if [ "$MODE" = "rollback" ]; then
  [ -d "${PREFIX}.prev" ] || die "no previous build at ${PREFIX}.prev"
  [ "$(id -u)" -eq 0 ] || exec sudo "$0" --rollback \
      --prefix "$PREFIX" --workspace "$WORKSPACE_NAME" --workspace-dir "$WORKSPACE_DIR" \
      --unit-path "$UNIT_PATH" --user "$SERVICE_USER" --group "$SERVICE_GROUP"
  log "Rolling back ${PREFIX} <- ${PREFIX}.prev"
  systemctl stop "$(basename "${UNIT_PATH%.service}")" 2>/dev/null || true
  rm -rf "${PREFIX}.rolledback"
  mv "$PREFIX" "${PREFIX}.rolledback"
  mv "${PREFIX}.prev" "$PREFIX"
  systemctl start "$(basename "${UNIT_PATH%.service}")" 2>/dev/null || true
  log "Rollback done. The replaced build is kept at ${PREFIX}.rolledback"
  exit 0
fi

# --------------------------------------------------------------------- preview (no root needed)
UNIT_NAME="$(basename "${UNIT_PATH%.service}")"
CONSOLE_ARG=""
[ "$CONSOLE_MODE" -eq 1 ] && CONSOLE_ARG=" -console"

render_unit() {
  cat <<EOF
[Unit]
Description=Rocrail server (workspace: ${WORKSPACE_NAME})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${WORKSPACE_PATH}
Environment=LD_LIBRARY_PATH=${PREFIX}/bin
ExecStart=${PREFIX}/bin/rocrail -w ${WORKSPACE_PATH} -l ${PREFIX}/bin -p ${SERVICE_PORT}${CONSOLE_ARG}
ExecStartPre=/usr/bin/mkdir -p ${WORKSPACE_PATH}/trace ${WORKSPACE_PATH}/issues
Restart=on-failure
RestartSec=3
# A client-issued shutdown exits with 70. Treat it as a clean stop so the shutdown is
# honoured instead of being restarted 3 seconds later. Real failures (signals, other
# exit codes) still restart. Use --console to stop clients issuing it at all.
SuccessExitStatus=70
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
# StandardInput is null by default under systemd, which is what -console is tested against.

# Hardening left off by default, as in the reference install. Enable once the layout runs.
#NoNewPrivileges=yes
#ProtectSystem=full
#ReadWritePaths=${WORKSPACE_PATH}
#LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
}

if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY RUN - nothing will be changed."
  log ""
  log "build      : $FILENAME"
  log "url        : $DOWNLOAD_URL"
  log "prefix     : $PREFIX     (previous kept as ${PREFIX}.prev)"
  log "workspace  : $WORKSPACE_PATH"
  log "service    : ${UNIT_NAME}  user=${SERVICE_USER} group=${SERVICE_GROUP} port=${SERVICE_PORT}"
  log "unit file  : $UNIT_PATH"
  log ""
  log "----- ${UNIT_PATH} -----"
  render_unit
  log "------------------------"
  exit 0
fi

# --------------------------------------------------------------------- root required
if [ "$(id -u)" -ne 0 ]; then
  log "Root is required to write ${PREFIX} and ${UNIT_PATH}; re-running with sudo."
  exec sudo "$0" "$@" 2>/dev/null || exec sudo -E "$0" "$@"
fi

# --------------------------------------------------------------------- prerequisites
for tool in curl unzip systemctl; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool not found: $tool"
done

# --------------------------------------------------------------------- service account
if getent passwd "$SERVICE_USER" >/dev/null 2>&1; then
  log "Service account ${SERVICE_USER} already exists."
else
  command -v useradd >/dev/null 2>&1 || die "useradd not found; create ${SERVICE_USER} yourself"
  log "Creating system account ${SERVICE_USER}."
  useradd --system --no-create-home --home-dir "$WORKSPACE_DIR" \
          --shell "$(command -v nologin || echo /usr/sbin/nologin)" "$SERVICE_USER"
fi

# --------------------------------------------------------------------- download + verify
PREFIX_PARENT="$(dirname "$PREFIX")"
if [ -d "$PREFIX_PARENT" ]; then
  TMP_ZIP="$(mktemp "${PREFIX_PARENT}/.rocrail-dl.XXXXXX")"
else
  TMP_ZIP="$(mktemp /tmp/.rocrail-dl.XXXXXX)"
fi
cleanup() { rm -f "$TMP_ZIP"; }
trap cleanup EXIT

log "Downloading ${FILENAME}"
curl -fL --retry 3 --retry-delay 2 -o "$TMP_ZIP" "$DOWNLOAD_URL" \
  || die "download failed: $DOWNLOAD_URL"

unzip -tq "$TMP_ZIP" >/dev/null 2>&1 || die "downloaded file is not a valid zip: $DOWNLOAD_URL"

ZIP_REV="$(unzip -p "$TMP_ZIP" revision.info 2>/dev/null \
  | awk '/^Revision:/{ if (r == "") r=$2 } END { if (r != "") print r }' || true)"
ZIP_BUILD="$(unzip -p "$TMP_ZIP" revision.info 2>/dev/null \
  | awk '/^Revision:/{ if (match($0, /\([^)]*\)/)) b=substr($0, RSTART+1, RLENGTH-2) } END { if (b != "") print b }' || true)"
ADV_REV="$(advertised_revision)"
log "Downloaded build: revision ${ZIP_REV:-unknown} ${ZIP_BUILD:+(${ZIP_BUILD})}"

if [ -n "$ADV_REV" ] && [ -n "$ZIP_REV" ] && [ "$ZIP_REV" != "$ADV_REV" ]; then
  warn "the downloaded build (rev ${ZIP_REV}) is not the newest advertised (rev ${ADV_REV}) -"
  warn "platforms are published at different times. Continuing with what was published for this platform."
fi

# --------------------------------------------------------------------- atomic install
if systemctl is-active --quiet "$UNIT_NAME" 2>/dev/null; then
  log "Stopping ${UNIT_NAME}."
  systemctl stop "$UNIT_NAME"
fi

STAGE="${PREFIX}.new"
rm -rf "$STAGE"
log "Extracting to ${STAGE}"
mkdir -p "$STAGE"
unzip -q -o "$TMP_ZIP" -d "$STAGE" || die "extraction failed"

# --------------------------------------------------------------------- carry user files
# The vendor build never ships a licence. The official documentation puts lic.dat in the
# server's WORKING DIRECTORY - that is the workspace, which this script keeps outside the
# prefix and never touches (the -lic option can also point at an explicit path). A copy may
# nevertheless sit in the prefix, so carry it over rather than dropping it. Anything else that
# exists here but is not part of the new build is reported, never silently discarded.
USER_FILES="lic.dat"
CARRIED=""
for f in $USER_FILES; do
  if [ -f "${PREFIX}/${f}" ]; then
    cp -p "${PREFIX}/${f}" "${STAGE}/${f}"
    CARRIED="${CARRIED} ${f}"
  fi
done
if [ -n "$CARRIED" ]; then
  log "Carried over into the new build:${CARRIED}"
fi

if [ -d "$PREFIX" ]; then
  EXTRA=""
  for f in $(ls -A "$PREFIX" 2>/dev/null || true); do
    case " $USER_FILES " in *" $f "*) continue ;; esac
    [ -e "${STAGE}/${f}" ] || EXTRA="${EXTRA} ${f}"
  done
  if [ -n "$EXTRA" ]; then
    warn "files present in ${PREFIX} that are not part of the new build:${EXTRA}"
    warn "they are still in ${PREFIX}.prev - copy over anything you still need."
    warn "a licence kept in the WORKSPACE (not here) is untouched either way."
  fi

  rm -rf "${PREFIX}.prev"
  mv "$PREFIX" "${PREFIX}.prev"
  log "Previous build kept at ${PREFIX}.prev"
fi
mv "$STAGE" "$PREFIX"

# Keep the downloaded archive inside the prefix (matches the reference install, and gives
# --check something to compare the remote Last-Modified against).
cp -f "$TMP_ZIP" "${PREFIX}/${FILENAME}"

# Record what was installed here, so "installed" is not inferred from a timestamp.
cat > "${PREFIX}/install-record.json" <<EOF
{"revision":"${ZIP_REV:-unknown}","build":"${ZIP_BUILD:-unknown}","file":"${FILENAME}","url":"${DOWNLOAD_URL}","sha256":"$(sha256sum "$TMP_ZIP" | awk '{print $1}')","installed":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","installed_by":"install-linux.sh"}
EOF

# --------------------------------------------------------------------- workspace
log "Preparing workspace ${WORKSPACE_PATH}"
mkdir -p "${WORKSPACE_PATH}/trace" "${WORKSPACE_PATH}/issues"
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "$WORKSPACE_PATH"
chown -R root:root "$PREFIX" 2>/dev/null || true
# The workspace is outside the prefix on purpose: replacing the build never touches a plan.

# --------------------------------------------------------------------- unit
log "Writing ${UNIT_PATH}"
render_unit > "$UNIT_PATH"
chmod 644 "$UNIT_PATH"
systemctl daemon-reload
systemctl enable "$UNIT_NAME" >/dev/null 2>&1 || true
systemctl restart "$UNIT_NAME"

# --------------------------------------------------------------------- report
IP="$(primary_ip)"
log ""
log "Rocrail server installed."
log "  build      : revision ${ZIP_REV:-unknown} ${ZIP_BUILD:+(${ZIP_BUILD})}"
log "  prefix     : ${PREFIX}"
log "  workspace  : ${WORKSPACE_PATH}"
log "  unit       : ${UNIT_PATH}  ($(systemctl is-active "$UNIT_NAME" 2>/dev/null || echo unknown))"
log "  Rocview    : point clients at ${IP:-<this host>}:${SERVICE_PORT}"
log "  Monitor    : http://${IP:-<this host>}:8008/    (server status panel, always on)"
log "  Rocweb     : per-workspace and disabled by default - enable with rocweb.sh enable"
log ""
log "Updating later: re-run this script. Rolling back: re-run with --rollback"
log "Do NOT use the Server-Monitor's Update / OS Update buttons: they write into a root-owned"
log "prefix and will fail. This script is the supported update path."
