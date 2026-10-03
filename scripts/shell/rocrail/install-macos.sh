#!/usr/bin/env bash
#
# install-macos.sh - install or update the Rocrail CLIENT on macOS.
#
# Role split: macOS is a client (Rocview, the GUI). No service, no server, no workspace is
# created here - Rocview attaches to a Rocrail server, either the Raspberry Pi or the
# balcony server, via  Datei/File -> "Verbinden mit..." (or -h <host> -p 8051).
#
# The snapshot ships native executables; no Java runtime is installed or required.
#
# The app is not notarised, so a downloaded bundle is quarantined and macOS refuses the first
# normal double-click. This script clears the quarantine attribute, which is what makes the
# first launch work; if macOS still objects, the vendor's documented fallback is a one-time
# right-click -> Open.
#
# Verified against the macOS build published on 2026-10-03. Note: the macOS .app.zip carries
# NO revision.info inside it (verified), so unlike the Linux and Windows installers this script
# can neither report nor compare a revision - the number exists only in the feed's history
# filenames. See REVIEW.md.

set -euo pipefail

SNAPSHOT_BASE="https://www.rocrail.online/rocrail-snapshot"
REVISION_URL="${SNAPSHOT_BASE}/log.txt"

DESTINATION="/Applications"
PORTABLE_DIR=""
DRY_RUN=0
MODE="install"

STATE_DIR="${HOME}/Library/Application Support/rocrail"
APP_NAME="Rocrail.app"
BUNDLE_ID="net.rocrail.Rocrail"

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: install-macos.sh [options]

  --check                report installed vs available and exit (no changes)
  --user-apps            install to ~/Applications instead of /Applications (vendor's
                         recommended location; needs no administrator rights)
  --portable DIR         extract into DIR instead of installing an app bundle
  --destination DIR      app directory to install into   (default: /Applications)
  --uninstall            remove the installed app bundle
  --dry-run              show what would be done, change nothing
  -h, --help             this help

Client use:
  Rocview attaches to a server - no local server is set up by this script.
    File -> "Verbinden mit..."           enter the server address and port 8051
    ./Rocrail.app/Contents/MacOS/rocview -h HOST -p 8051   pre-pointed launch (verified on the Linux
                                                 build; the documented flags on macOS)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check)        MODE="check";    shift ;;
    --uninstall)    MODE="uninstall"; shift ;;
    --user-apps)    DESTINATION="${HOME}/Applications"; shift ;;
    --portable)     PORTABLE_DIR="${2:-}"; shift 2 ;;
    --destination)  DESTINATION="${2:-}"; shift 2 ;;
    --dry-run)      DRY_RUN=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || die "this script is for macOS only (uname -s = $(uname -s))"

# --------------------------------------------------------------------- build matrix
ARCH="$(uname -m)"
case "$ARCH" in
  arm64)
    FILENAME="Rocrail-macOS27.app.zip"
    ;;
  x86_64)
    FILENAME="Rocrail-sequoia-i64.app.zip"
    ;;
  *)
    die "unsupported architecture: $ARCH (supported: arm64, x86_64)"
    ;;
esac
DOWNLOAD_URL="${SNAPSHOT_BASE}/macOS/${FILENAME}"

if [ -n "$PORTABLE_DIR" ]; then
  APP_PATH="${PORTABLE_DIR%/}/${APP_NAME}"
else
  APP_PATH="${DESTINATION%/}/${APP_NAME}"
fi

# --------------------------------------------------------------------- read-only helpers
# Read to EOF: closing a pipe early (head) makes the producer exit non-zero and would abort
# the script under "set -o pipefail".
advertised_revision() {
  curl -fsSL --max-time 20 "$REVISION_URL" 2>/dev/null \
    | awk 'NR==1 { first=$1 } END { if (first != "") print first }' || true
}

remote_last_modified() {
  curl -fsSIL --max-time 20 "$DOWNLOAD_URL" 2>/dev/null \
    | awk 'tolower($1)=="last-modified:" { if (lm=="") lm=substr($0, index($0," ")+1) } END { if (lm!="") print lm }' || true
}

installed_version() {
  [ -d "$APP_PATH" ] || return 0
  local plist="${APP_PATH}/Contents/Info.plist"
  [ -f "$plist" ] || return 0
  if [ -x /usr/libexec/PlistBuddy ]; then
    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist" 2>/dev/null || true
  else
    awk '/CFBundleShortVersionString/{ getline; gsub(/[[:space:]]*<[^>]*>[[:space:]]*/, ""); print; exit }' "$plist" || true
  fi
}

app_is_running() {
  pgrep -x rocview >/dev/null 2>&1 || pgrep -f "${APP_PATH}/Contents/MacOS" >/dev/null 2>&1
}

# --------------------------------------------------------------------- check
if [ "$MODE" = "check" ]; then
  log "platform        : macOS ${ARCH}   build: ${FILENAME}"
  log "app             : ${APP_PATH}"
  log "url             : ${DOWNLOAD_URL}"
  log "installed       : $(installed_version || true)"
  log "available (log) : $(advertised_revision || true)"
  log "available (file): $(remote_last_modified || true)"
  if [ -n "$(installed_version || true)" ]; then
    log "note            : macos builds carry no revision.info; the version is read from Info.plist"
    log "verdict         : installed - compare the two 'available' lines above"
    exit 0
  fi
  log "verdict         : NOT INSTALLED"
  exit 2
fi

# --------------------------------------------------------------------- uninstall
if [ "$MODE" = "uninstall" ]; then
  [ -d "$APP_PATH" ] || die "not installed: $APP_PATH"
  [ -f "${APP_PATH}/Contents/Info.plist" ] || die "${APP_PATH} is not a Rocrail app bundle; refusing to remove it"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY RUN - would remove ${APP_PATH} (workspaces, plans and settings are never touched)."
    exit 0
  fi
  if app_is_running; then
    log "Quitting Rocview first."
    osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
    sleep 2
  fi
  log "Removing ${APP_PATH}"
  rm -rf "$APP_PATH"
  log "Removed. Workspaces, plans and Rocview settings were not touched."
  exit 0
fi

# --------------------------------------------------------------------- preview
if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY RUN - nothing will be changed."
  log "  build      : $FILENAME"
  log "  url        : $DOWNLOAD_URL"
  log "  app path   : $APP_PATH"
  log "  action     : extract with ditto -x -k, clear com.apple.quarantine, verify signature"
  exit 0
fi

# --------------------------------------------------------------------- prerequisites
for tool in curl ditto xattr; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool not found: $tool"
done

# --------------------------------------------------------------------- stop the running app
if app_is_running; then
  log "Rocview is running; asking it to quit."
  osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
  sleep 2
  app_is_running && die "Rocview is still running - quit it and re-run."
fi

# --------------------------------------------------------------------- download
mkdir -p "$STATE_DIR"
TMP_ZIP="${STATE_DIR}/${FILENAME}"
log "Downloading ${FILENAME}"
curl -fL --retry 3 --retry-delay 2 -o "${TMP_ZIP}.part" "$DOWNLOAD_URL" || die "download failed"
mv -f "${TMP_ZIP}.part" "$TMP_ZIP"

# --------------------------------------------------------------------- install
# Install into a staging directory first and only then touch the live bundle, so there is no
# moment where the app is absent. The previous bundle is MOVED to a backup rather than deleted,
# and restored if the new one cannot be put in place.
if [ -n "$PORTABLE_DIR" ]; then
  DEST="${PORTABLE_DIR%/}"
  mkdir -p "$DEST"
else
  DEST="${DESTINATION%/}"
  [ -d "$DEST" ] || die "destination does not exist: $DEST"
  [ -w "$DEST" ] || die "$DEST is not writable by $(id -un); use --user-apps or sudo"
fi

STAGE="$(mktemp -d "${DEST}/.rocrail-stage.XXXXXX")"
BACKUP_DIR="${DEST}/.rocrail-previous"
trap 'rm -rf "$STAGE"' EXIT

log "Extracting into ${STAGE}"
# ditto, not unzip: unzip can break the code signature of an app bundle
ditto -x -k "$TMP_ZIP" "$STAGE" || die "extraction failed; the installed app is untouched"
[ -d "${STAGE}/${APP_NAME}" ] || die "the archive did not contain ${APP_NAME}; not installing"

if [ -d "$APP_PATH" ]; then
  mkdir -p "$BACKUP_DIR"
  rm -rf "${BACKUP_DIR:?}/${APP_NAME}"
  log "Moving the previous bundle aside to ${BACKUP_DIR}/${APP_NAME}"
  mv "$APP_PATH" "${BACKUP_DIR}/${APP_NAME}" || die "could not move the previous bundle aside"
fi

log "Installing to ${APP_PATH}"
if ! mv "${STAGE}/${APP_NAME}" "$APP_PATH"; then
  warn "could not install to ${APP_PATH}"
  if [ -d "${BACKUP_DIR}/${APP_NAME}" ]; then
    mv "${BACKUP_DIR}/${APP_NAME}" "$APP_PATH" && log "previous bundle restored"
  fi
  die "installation failed"
fi
TARGET="$APP_PATH"

# --------------------------------------------------------------------- quarantine
log "Clearing the quarantine attribute on ${TARGET}"
xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || warn "could not clear the quarantine attribute"

# --------------------------------------------------------------------- verify (reported, never fatal)
if command -v codesign >/dev/null 2>&1; then
  if codesign --verify --deep --strict "$TARGET" >/dev/null 2>&1; then
    log "codesign --verify : ok"
  else
    warn "codesign --verify failed - macOS may still ask you to confirm the first launch"
  fi
fi
if command -v spctl >/dev/null 2>&1; then
  if spctl -a -t exec "$TARGET" >/dev/null 2>&1; then
    log "spctl            : accepted"
  else
    warn "spctl does not accept the bundle (expected for a non-notarised build)."
    warn "Fallback, once: open ${APP_PATH} in Finder, right-click -> Open -> Open."
  fi
fi

# --------------------------------------------------------------------- record
VERSION="$(installed_version || true)"
cat > "${STATE_DIR}/install-record.json" <<EOF
{"version":"${VERSION:-unknown}","file":"${FILENAME}","url":"${DOWNLOAD_URL}","sha256":"$(shasum -a 256 "$TMP_ZIP" | awk '{print $1}')","installed":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","installed_by":"install-macos.sh"}
EOF

log ""
log "Rocrail client installed."
log "  version   : ${VERSION:-unknown}"
log "  app       : ${APP_PATH}"
log "  cached zip: ${TMP_ZIP}"
log ""
log "This is a CLIENT. To attach to a server:"
log "  open -a ${APP_PATH}"
log "  then  File -> \"Verbinden mit...\"  and enter the server address, port 8051"
