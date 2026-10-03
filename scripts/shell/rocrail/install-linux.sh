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
# Re-running it is the supported update path. The archive is validated and extracted into a
# staging directory BEFORE the running service is touched; the previous build is kept as
# <prefix>.prev; options of an existing install are adopted so a plain re-run reproduces the
# installed configuration instead of reverting to defaults; and a build that fails to start is
# rolled back automatically. No separate updater script is needed.
#
# Verified against Rocrail revision 7454 (2026-10-03). See REVIEW.md for what was verified
# and what was not.
#
# Exit codes for --check: 0 up to date, 1 update available, 2 not installed,
#                          3 unknown (the archive could not be reached, nothing compared).

set -euo pipefail

# Keep the arguments as they were given. The parse loop below consumes "$@", and the sudo
# re-exec further down must re-run this script with the SAME options - passing "$@" there
# would re-run with an empty argument list and silently install the defaults.
ORIG_ARGS=("$@")

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
FORCE=0
MODE="install"          # install | check | rollback

# Which options were given explicitly. Options NOT given are adopted from an existing install
# (see "adopt recorded options"), so re-running never silently reverts a setting.
WS_SET=0; WSDIR_SET=0; PORT_SET=0; USER_SET=0; GROUP_SET=0; VARIANT_SET=0
CONSOLE_SET=0; UNIT_SET=0

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
  --force                act even if nothing changed, or if --prefix does not look like
                         a Rocrail install
  -h, --help             this help

On re-run, options you do NOT pass are adopted from the existing install, so a plain re-run
keeps the installed workspace, port and account instead of reverting to the defaults.

--check exits 0 (up to date), 1 (update available), 2 (not installed) or 3 (the archive
could not be reached, so nothing was compared).

Notes:
  * The Rocrail Server-Monitor always listens on port 8008 by default; Rocweb (the browser
    client) is per-workspace, ships disabled, and is enabled with the separate rocweb.sh.
  * A workspace is created by the server on first start (rocrail.ini, plan.xml, occ.xml,
    trace/, issues/). This script only makes the directory and hands it to the service user.
  * Only the vendor archive is verified (TLS + zip CRC): the vendor publishes no checksum or
    signature, so there is no trusted digest to compare against.
EOF
}

# --------------------------------------------------------------------- arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --workspace)      WORKSPACE_NAME="${2:-}"; WS_SET=1;      shift 2 ;;
    --workspace-dir)  WORKSPACE_DIR="${2:-}";  WSDIR_SET=1;   shift 2 ;;
    --port)           SERVICE_PORT="${2:-}";   PORT_SET=1;    shift 2 ;;
    --prefix)         PREFIX="${2:-}";         shift 2 ;;
    --user)           SERVICE_USER="${2:-}";   USER_SET=1;    shift 2 ;;
    --group)          SERVICE_GROUP="${2:-}";  GROUP_SET=1;   shift 2 ;;
    --variant)        VARIANT="${2:-}";        VARIANT_SET=1; shift 2 ;;
    --unit-path)      UNIT_PATH="${2:-}";      UNIT_SET=1;    shift 2 ;;
    --console)        CONSOLE_MODE=1;          CONSOLE_SET=1; shift ;;
    --check)          MODE="check";            shift ;;
    --rollback)       MODE="rollback";         shift ;;
    --dry-run)        DRY_RUN=1;               shift ;;
    --force)          FORCE=1;                 shift ;;
    -h|--help)        usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

[ -n "$SERVICE_GROUP" ] || SERVICE_GROUP="$SERVICE_USER"
PREFIX="${PREFIX%/}"
WORKSPACE_DIR="${WORKSPACE_DIR%/}"
WORKSPACE_PATH="${WORKSPACE_DIR}/${WORKSPACE_NAME}"

# --------------------------------------------------------------------- validation
# Every value below ends up in a systemd unit or a shell command, so it is validated rather
# than trusted: a newline in a name would inject unit directives.
no_control_chars() { # $1 = value, $2 = option name
  case "$1" in
    *[![:print:]]*) die "$2 must not contain control characters or newlines" ;;
  esac
}

no_control_chars "$WORKSPACE_NAME" "workspace name"
no_control_chars "$WORKSPACE_DIR"  "workspace directory"
no_control_chars "$PREFIX"         "prefix"
no_control_chars "$UNIT_PATH"      "unit path"
no_control_chars "$SERVICE_USER"   "user"
no_control_chars "$SERVICE_GROUP"  "group"

case "$WORKSPACE_NAME" in
  .*|*/*|"") die "invalid workspace name: '$WORKSPACE_NAME' (no slashes, must not start with a dot)" ;;
esac
case "$WORKSPACE_NAME" in
  *[!A-Za-z0-9._-]*) die "invalid workspace name: '$WORKSPACE_NAME' (letters, digits, dot, underscore, hyphen)" ;;
esac
case "$SERVICE_USER" in
  [a-z_]*) ;;
  *) die "invalid user name: '$SERVICE_USER' (must start with a lower-case letter or underscore)" ;;
esac
case "$SERVICE_USER$SERVICE_GROUP" in
  *[!a-z0-9_-]*) die "invalid user/group name (lower-case letters, digits, underscore, hyphen)" ;;
esac
# Each path is checked separately. Concatenating them into one case pattern would pass as
# soon as the FIRST component was absolute, hiding a relative prefix.
# systemd expands "%" specifiers and "$" variables in unit files, so neither may appear in
# anything that ends up in the generated unit.
case "$WORKSPACE_NAME$WORKSPACE_DIR${PREFIX}${UNIT_PATH}" in
  *%*) die "paths and names must not contain '%' (systemd expands it in unit files)" ;;
  *'$'*) die "paths and names must not contain '\$' (systemd expands it in unit files)" ;;
esac

# A prefix is about to be moved aside and later replaced. Refuse the obvious disasters.
for bad in / /usr /usr/local /opt /etc /var /var/lib /home /root /srv; do
  if [ "$PREFIX" = "$bad" ]; then
    [ "$FORCE" -eq 1 ] || die "refusing to use '$PREFIX' as the install prefix (use --force to override)"
  fi
done

case "$WORKSPACE_DIR" in /*) ;; *) die "workspace directory must be an absolute path: '$WORKSPACE_DIR'" ;; esac
case "$PREFIX"        in /*) ;; *) die "prefix must be an absolute path: '$PREFIX'" ;; esac
case "$UNIT_PATH"     in /*) ;; *) die "unit path must be an absolute path: '$UNIT_PATH'" ;; esac
case "$SERVICE_PORT" in
  ''|*[!0-9]*) die "invalid port: '$SERVICE_PORT'" ;;
esac
[ "$SERVICE_PORT" -ge 1 ] && [ "$SERVICE_PORT" -le 65535 ] || die "port out of range: $SERVICE_PORT"

# --------------------------------------------------------------------- adopt recorded options
# An existing install records its effective options. Anything not passed on this run is taken
# from there, so `install-linux.sh` alone updates in place instead of resetting the workspace,
# port or account to the defaults.
opt_from_record() { # $1 = key
  [ -f "${PREFIX}/install-options.conf" ] || return 0
  awk -F= -v k="$1" '$1 == k { print substr($0, index($0, "=") + 1); exit }' \
      "${PREFIX}/install-options.conf" 2>/dev/null || true
}

adopt() { # $1=key  $2=current value  $3=1 if explicitly set on this run
  if [ "$3" -eq 1 ]; then
    printf '%s' "$2"
    return
  fi
  local recorded
  recorded="$(opt_from_record "$1")"
  if [ -n "$recorded" ]; then printf '%s' "$recorded"; else printf '%s' "$2"; fi
}

if [ -f "${PREFIX}/install-options.conf" ]; then
  ADOPTED=""
  old="$WORKSPACE_NAME";  new="$(adopt WORKSPACE_NAME "$WORKSPACE_NAME" "$WS_SET")";    [ "$old" = "$new" ] || ADOPTED=1; WORKSPACE_NAME="$new"
  old="$WORKSPACE_DIR";   new="$(adopt WORKSPACE_DIR  "$WORKSPACE_DIR"  "$WSDIR_SET")";  [ "$old" = "$new" ] || ADOPTED=1; WORKSPACE_DIR="$new"
  old="$SERVICE_PORT";    new="$(adopt SERVICE_PORT   "$SERVICE_PORT"   "$PORT_SET")";    [ "$old" = "$new" ] || ADOPTED=1; SERVICE_PORT="$new"
  old="$SERVICE_USER";    new="$(adopt SERVICE_USER   "$SERVICE_USER"   "$USER_SET")";    [ "$old" = "$new" ] || ADOPTED=1; SERVICE_USER="$new"
  old="$SERVICE_GROUP";   new="$(adopt SERVICE_GROUP  "$SERVICE_GROUP"  "$GROUP_SET")";   [ "$old" = "$new" ] || ADOPTED=1; SERVICE_GROUP="$new"
  old="$VARIANT";         new="$(adopt VARIANT        "$VARIANT"        "$VARIANT_SET")"; [ "$old" = "$new" ] || ADOPTED=1; VARIANT="$new"
  old="$CONSOLE_MODE";    new="$(adopt CONSOLE_MODE   "$CONSOLE_MODE"   "$CONSOLE_SET")"; [ "$old" = "$new" ] || ADOPTED=1; CONSOLE_MODE="$new"
  old="$UNIT_PATH";       new="$(adopt UNIT_PATH      "$UNIT_PATH"      "$UNIT_SET")";    [ "$old" = "$new" ] || ADOPTED=1; UNIT_PATH="$new"
  WORKSPACE_PATH="${WORKSPACE_DIR}/${WORKSPACE_NAME}"
  if [ -n "$ADOPTED" ]; then
    log "Adopted the existing install's options from ${PREFIX}/install-options.conf"
    log "  workspace ${WORKSPACE_PATH}  port ${SERVICE_PORT}  user ${SERVICE_USER}  console ${CONSOLE_MODE}"
  fi
fi

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
  # Newest revision in the snapshot list - newest for ANY platform. Informational only:
  # platforms are published at different times, so this is not this platform's version.
  curl -fsSL --proto-redir =https --max-time 20 "$REVISION_URL" 2>/dev/null \
    | awk 'NR==1 { first=$1 } END { if (first != "") print first }' || true
}

remote_last_modified() {
  # HTTP Last-Modified of THIS platform's archive: the precise "available" signal.
  local lm
  lm="$(curl -fsSIL --proto-redir =https --max-time 20 -o /dev/null -w '%{header_json}' "$DOWNLOAD_URL" 2>/dev/null \
        | tr -d '\n' | sed -n 's/.*"last-modified":\["\([^"]*\)".*/\1/p')" || true
  if [ -z "$lm" ]; then
    lm="$(curl -fsSIL --proto-redir =https --max-time 20 "$DOWNLOAD_URL" 2>/dev/null \
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

primary_ip() {
  # Best effort: hostname -I fails on some minimal systems, and under pipefail that must not
  # abort a report or --check.
  hostname -I 2>/dev/null | awk '{print $1}' || true
}

# --------------------------------------------------------------------- check mode
if [ "$MODE" = "check" ]; then
  rev_inst="$(installed_revision)"
  rev_newest="$(advertised_revision)"
  lmod="$(remote_last_modified)"
  recorded_lm="$(opt_from_record ARCHIVE_LAST_MODIFIED)"
  ip="$(primary_ip)"

  log "platform        : $ARCH   build: $FILENAME"
  log "prefix          : $PREFIX"
  log "workspace       : $WORKSPACE_PATH"
  log "url             : $DOWNLOAD_URL"
  log "installed       : ${rev_inst:-<not installed>}${rev_inst:+ $(installed_build)}"
  log "installed from  : ${recorded_lm:-<not recorded>}   (this archive's Last-Modified at install time)"
  log "available (file): ${lmod:-<unavailable>}   (this archive, now)"
  log "newest overall  : ${rev_newest:-<unavailable>}   (any platform, informational)"
  if [ -f "${PREFIX}/install-record.json" ]; then
    log "last installed  : $(tr -d '\n' < "${PREFIX}/install-record.json")"
  fi

  if [ -z "$rev_inst" ]; then
    log "verdict         : NOT INSTALLED"
    exit 2
  fi
  if [ -z "$lmod" ]; then
    log "verdict         : UNKNOWN - could not reach the archive, nothing was compared"
    exit 3
  fi
  if [ -n "$recorded_lm" ] && [ "$recorded_lm" = "$lmod" ]; then
    log "verdict         : up to date (this platform's archive is unchanged)"
    exit 0
  fi
  log "verdict         : UPDATE AVAILABLE (this platform's archive changed since install)"
  if [ -n "$ip" ]; then
    log "note            : re-run without --check to update"
  fi
  exit 1
fi

# --------------------------------------------------------------------- rollback mode
if [ "$MODE" = "rollback" ]; then
  [ -d "${PREFIX}.prev" ] || die "no previous build at ${PREFIX}.prev"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY RUN - would restore ${PREFIX}.prev over ${PREFIX} and restart the service."
    exit 0
  fi
  [ "$(id -u)" -eq 0 ] || exec sudo "$0" "${ORIG_ARGS[@]}"
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
# The leading '-' makes systemd tolerate a missing directory instead of failing before any
# command runs: without it the unit dies on chdir and ExecStartPre never gets the chance to
# repair it (measured). WorkingDirectory is also where Rocrail looks for lic.dat.
WorkingDirectory=-${WORKSPACE_PATH}
Environment=LD_LIBRARY_PATH=${PREFIX}/bin
ExecStart=${PREFIX}/bin/rocrail -w ${WORKSPACE_PATH} -l ${PREFIX}/bin -p ${SERVICE_PORT}${CONSOLE_ARG}
ExecStartPre=/usr/bin/mkdir -p ${WORKSPACE_PATH}/trace ${WORKSPACE_PATH}/issues
Restart=on-failure
RestartSec=3
# A client-issued shutdown exits with 70. Treat it as a clean stop so the shutdown is honoured
# instead of being restarted 3 seconds later. Real failures (signals, other exit codes) still
# restart. This assumes exit 70 is reserved for an intentional shutdown; --console stops
# clients issuing it at all.
SuccessExitStatus=70
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
# StandardInput is null by default under systemd, which is what -console is tested against.

# Hardening left off by default, as in the reference install. Enable once the layout runs.
#NoNewPrivileges=yes
#ProtectSystem=full
#ReadWritePaths=${WORKSPACE_PATH}
# resource limit rather than hardening; uncomment if you need many concurrent connections
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

# --------------------------------------------------------------------- nothing to do?
# Idempotent no-op. If this platform's archive is unchanged AND the unit on disk already
# matches what would be rendered, there is nothing to install - and rotating <prefix>.prev a
# second time would make --rollback restore the build that is already running. Runs before the
# root check on purpose: a plain re-run on an up-to-date host does not even prompt for sudo.
if [ "$FORCE" -eq 0 ] && [ -n "$(installed_revision)" ] && [ -f "$UNIT_PATH" ]; then
  rec_lm="$(opt_from_record ARCHIVE_LAST_MODIFIED)"
  cur_lm="$(remote_last_modified)"
  if [ -n "$rec_lm" ] && [ -n "$cur_lm" ] && [ "$rec_lm" = "$cur_lm" ] \
     && diff -q <(render_unit) "$UNIT_PATH" >/dev/null 2>&1; then
    log "Already up to date: revision $(installed_revision), this platform's archive is unchanged"
    log "and ${UNIT_PATH} already matches the requested configuration."
    log "Nothing to do. Use --force to reinstall anyway."
    exit 0
  fi
fi

# --------------------------------------------------------------------- root required
if [ "$(id -u)" -ne 0 ]; then
  log "Root is required to write ${PREFIX} and ${UNIT_PATH}; re-running with sudo."
  # ORIG_ARGS, not "$@": the parse loop above has already consumed "$@".
  exec sudo "$0" "${ORIG_ARGS[@]}"
fi

# File and directory modes must not depend on root's umask: with umask 027/077 the prefix
# would end up mode 750/700 and the service user could not traverse it (systemd reports 203/EXEC).
umask 022

# --------------------------------------------------------------------- prerequisites
for tool in curl unzip systemctl; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool not found: $tool"
done

PREFIX_PARENT="$(dirname "$PREFIX")"

# A prefix whose parent the service account (or anyone else) can write to would let that
# account replace the build it is served from.
if [ -d "$PREFIX_PARENT" ]; then
  mode="$(stat -c '%a' "$PREFIX_PARENT" 2>/dev/null || echo '')"
  case "$mode" in
    ?????) case "$mode" in *[2367][2367]) die "${PREFIX_PARENT} is group/other writable (mode ${mode}); use a root-owned prefix parent" ;; esac ;;
  esac
fi

# A symlinked prefix would be destroyed by the swap, leaving the link pointing nowhere.
if [ -L "$PREFIX" ]; then
  die "${PREFIX} is a symlink; the atomic swap needs a real directory"
fi

# The swap moves the whole existing prefix aside and later replaces it. Refuse to do that to
# a directory that is not a Rocrail install unless the operator insists.
if [ -d "$PREFIX" ] && [ "$FORCE" -eq 0 ]; then
  if [ ! -f "${PREFIX}/revision.info" ] && [ ! -f "${PREFIX}/install-record.json" ]; then
    die "${PREFIX} does not look like a Rocrail install (no revision.info, no install-record.json).
Refusing to move it aside. Check --prefix, or pass --force if that is really intended."
  fi
fi

# --------------------------------------------------------------------- exclusive lock
# Two concurrent runs would otherwise share the staging and backup directories and could
# delete each other's work mid-swap.
LOCK="${PREFIX}.lock"
exec 9>"$LOCK" 2>/dev/null || die "cannot open lock file ${LOCK}"
if command -v flock >/dev/null 2>&1; then
  flock -n 9 || die "another run is already in progress (lock: ${LOCK})"
else
  warn "flock not found; concurrent runs are not prevented"
fi

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
if [ -d "$PREFIX_PARENT" ]; then
  TMP_ZIP="$(mktemp "${PREFIX_PARENT}/.rocrail-dl.XXXXXX")"
else
  TMP_ZIP="$(mktemp /tmp/.rocrail-dl.XXXXXX)"
fi
STAGE="${PREFIX}.new.$$"
cleanup() { rm -f "$TMP_ZIP"; rm -rf "$STAGE"; }
trap cleanup EXIT

log "Downloading ${FILENAME}"
# --proto-redir: the snapshot host redirects to a different host name; keep that hop on https.
curl -fL --proto-redir =https --retry 3 --retry-delay 2 -o "$TMP_ZIP" "$DOWNLOAD_URL" \
  || die "download failed: $DOWNLOAD_URL"

# Integrity is TLS plus the zip CRC: the vendor publishes no checksum or signature to compare
# against (verified - .sha256, .md5 and sha256sum.txt on the snapshot host are all 404).
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

# --------------------------------------------------------------------- stage + validate FIRST
# Everything that can fail happens before the running service is stopped, so a failed download
# or a bad archive leaves a working install untouched.
log "Extracting to ${STAGE}"
mkdir -p "$STAGE"
unzip -q -o "$TMP_ZIP" -d "$STAGE" || die "extraction failed; the running install is untouched"

[ -x "${STAGE}/bin/rocrail" ] || die "the archive has no executable bin/rocrail; refusing to swap"
[ -f "${STAGE}/revision.info" ] || warn "the archive has no revision.info (revision will show as unknown)"

# --------------------------------------------------------------------- carry user files
# The vendor build never ships a licence. The official documentation puts lic.dat in the
# server's WORKING DIRECTORY - the workspace, which this script keeps outside the prefix and
# never touches (the -lic option can point at an explicit path instead). Anything else living
# in the prefix that is not part of the vendor build is carried over as well, rather than
# warned about and then destroyed by the next run's cleanup of <prefix>.prev.
CARRIED=""
if [ -d "$PREFIX" ]; then
  # find -printf, not $(ls): a filename may contain spaces or newlines.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in
      *.prev|*.new.*|*.lock|*.rolledback|*.failed) continue ;;
      install-options.conf|install-record.json) continue ;;
      Rocrail-*.zip) continue ;;            # the vendor archive is re-copied below anyway
    esac
    if [ -e "${STAGE}/${f}" ]; then continue; fi
    if cp -a "${PREFIX}/${f}" "${STAGE}/${f}"; then
      CARRIED="${CARRIED} ${f}"
    else
      warn "could not carry over ${f}"
    fi
  done < <(find "$PREFIX" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null || true)
fi
if [ -n "$CARRIED" ]; then
  log "Carried over into the new build:${CARRIED}"
fi

# --------------------------------------------------------------------- stop + swap
if systemctl is-active --quiet "$UNIT_NAME" 2>/dev/null; then
  log "Stopping ${UNIT_NAME}."
  systemctl stop "$UNIT_NAME"
fi

if [ -d "$PREFIX" ]; then
  rm -rf "${PREFIX}.prev"
  mv "$PREFIX" "${PREFIX}.prev"
  log "Previous build kept at ${PREFIX}.prev"
fi
mv "$STAGE" "$PREFIX"

# Keep the downloaded archive inside the prefix (matches the reference install).
cp -f "$TMP_ZIP" "${PREFIX}/${FILENAME}"

# Record what was installed, and with which options: "installed" is then never inferred from
# a timestamp, and a re-run reproduces the same configuration.
ARCHIVE_LM="$(remote_last_modified)"
ZIP_SHA="$(sha256sum "$TMP_ZIP" | awk '{print $1}')"
cat > "${PREFIX}/install-record.json" <<EOF
{"revision":"${ZIP_REV:-unknown}","build":"${ZIP_BUILD:-unknown}","file":"${FILENAME}","url":"${DOWNLOAD_URL}","sha256":"${ZIP_SHA}","archive_last_modified":"${ARCHIVE_LM}","installed":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","installed_by":"install-linux.sh"}
EOF

cat > "${PREFIX}/install-options.conf" <<EOF
WORKSPACE_NAME=${WORKSPACE_NAME}
WORKSPACE_DIR=${WORKSPACE_DIR}
SERVICE_PORT=${SERVICE_PORT}
SERVICE_USER=${SERVICE_USER}
SERVICE_GROUP=${SERVICE_GROUP}
VARIANT=${VARIANT}
CONSOLE_MODE=${CONSOLE_MODE}
UNIT_PATH=${UNIT_PATH}
ARCHIVE_LAST_MODIFIED=${ARCHIVE_LM}
SHA256=${ZIP_SHA}
EOF
chmod 644 "${PREFIX}/install-options.conf" "${PREFIX}/install-record.json"

# --------------------------------------------------------------------- workspace
log "Preparing workspace ${WORKSPACE_PATH}"
mkdir -p "${WORKSPACE_PATH}/trace" "${WORKSPACE_PATH}/issues"
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "$WORKSPACE_PATH"
chown -R root:root "$PREFIX" 2>/dev/null || true
# The workspace is outside the prefix on purpose: replacing the build never touches a plan.

# --------------------------------------------------------------------- unit
if [ -f "$UNIT_PATH" ]; then
  cp -p "$UNIT_PATH" "${UNIT_PATH}.previous" 2>/dev/null || true
fi
log "Writing ${UNIT_PATH}"
render_unit > "$UNIT_PATH"
chmod 644 "$UNIT_PATH"
systemctl daemon-reload
if ! systemctl enable "$UNIT_NAME" >/dev/null 2>&1; then
  warn "could not enable ${UNIT_NAME} at boot; it will still be started now"
fi

# --------------------------------------------------------------------- start + health check
roll_back_failed_update() {
  warn "rolling back to the previous build."
  rm -rf "${PREFIX}.failed"
  if [ -d "$PREFIX" ]; then
    mv "$PREFIX" "${PREFIX}.failed"
  fi
  if [ -d "${PREFIX}.prev" ]; then
    mv "${PREFIX}.prev" "$PREFIX"
    log "Previous build restored to ${PREFIX}"
  fi
  if [ -f "${UNIT_PATH}.previous" ]; then
    cp -p "${UNIT_PATH}.previous" "$UNIT_PATH"
    systemctl daemon-reload
  fi
  systemctl restart "$UNIT_NAME" 2>/dev/null || warn "the previous build also failed to start"
}

# A zero exit from restart only means the process was forked: Type=simple reports success even
# if the binary dies immediately. Require it to still be running before declaring success.
service_healthy() {
  local _
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if systemctl is-active --quiet "$UNIT_NAME" 2>/dev/null; then
      sleep 2
      if systemctl is-active --quiet "$UNIT_NAME" 2>/dev/null; then
        return 0
      fi
    fi
    sleep 1
  done
  return 1
}

if ! systemctl restart "$UNIT_NAME"; then
  roll_back_failed_update
  die "update failed and was rolled back; the failed build is kept at ${PREFIX}.failed"
fi
if ! service_healthy; then
  warn "the new build did not stay running. Recent log:"
  journalctl -u "$UNIT_NAME" -n 6 --no-pager 2>/dev/null | sed 's/^/    /' || true
  roll_back_failed_update
  die "the new build did not stay running; rolled back. The failed build is kept at ${PREFIX}.failed"
fi

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
log "Updating later: re-run this script (options are adopted from the existing install)."
log "Rolling back:  re-run with --rollback"
log "Do NOT use the Server-Monitor's Update / OS Update buttons: they write into a root-owned"
log "prefix and will fail. This script is the supported update path."
