#!/bin/bash
#
# LEGACY - kept for history, superseded by the per-platform scripts in the parent directory.
#
# This script tried to cover Linux and macOS in one file. Two bugs in it are fixed here so it
# still runs, but new work should use install-linux.sh / install-macos.sh:
#   * the macOS archive name below was removed upstream and 404s
#   * downloads had no failure check, so a 404 was written to disk and only failed at unzip
# It also generates a server unit with no -w, which leaves the workspace inside the install
# prefix - see ../README.md for why that is worth avoiding.
#
# Also dropped: the -xv in the shebang, which traced the whole run to stderr.

BASE_URL="https://www.rocrail.online/rocrail-snapshot"

case "$(uname -s)" in
    Darwin)
        OS=macos
        ;;
    Linux)
        OS=linux
        ;;
    *)
        echo "ERROR: unsupported OS: $(uname -s)" >&2
        exit 1
        ;;
esac

ARCH=$(uname -m)

if [ "$OS" = macos ]; then
    DIR="macOS"
    DEST_DIR="$HOME/data/rocrail"
    case "$ARCH" in
        arm64)  FILE="Rocrail-macOS27.app.zip" ;;
        x86_64) FILE="Rocrail-sequoia-i64.app.zip" ;;
        *)
            echo "ERROR: unsupported architecture: $ARCH" >&2
            exit 1
            ;;
    esac
elif [ "$OS" = linux ]; then
    DEST_DIR="/opt/rocrail"
    DIR="Debian"
    case "$ARCH" in
        aarch64|arm64|armv8*)
            FILE="Rocrail-debian13-ARM64.zip"
            ;;
        x86_64)
            FILE="Rocrail-debian11-i64.zip"
            ;;
        *)
            echo "ERROR: unsupported architecture: $ARCH" >&2
            exit 1
            ;;
    esac

    if [ "$(id -u)" -ne 0 ]; then
        exec sudo "$0" "$@"
    fi
fi

URL="$BASE_URL/$DIR/$FILE"

mkdir -p "$DEST_DIR"
cd "$DEST_DIR"

if [ -f "$FILE" ]; then
    rm -f "$FILE"
fi

if command -v wget >/dev/null 2>&1; then
    wget -q --show-progress -O "$FILE" "$URL" || { echo "ERROR: download failed: $URL" >&2; exit 1; }
else
    curl -fL -o "$FILE" "$URL" || { echo "ERROR: download failed: $URL" >&2; exit 1; }
fi

if [ "$OS" = linux ]; then
    UNIT_FILE="/etc/systemd/system/rocrail.service"

    INSTALLED=false
    if systemctl is-active --quiet rocrail 2>/dev/null; then
        INSTALLED=true
        systemctl stop rocrail
    elif [ -f "$UNIT_FILE" ]; then
        INSTALLED=true
    fi

    unzip -o "$FILE"

    if ! $INSTALLED; then
        cat > "$UNIT_FILE" <<'UNITEOF'
[Unit]
Description=Rocrail server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

# --- adjust these to your setup ---
WorkingDirectory=/opt/rocrail
Environment=LD_LIBRARY_PATH=/opt/rocrail/bin
ExecStart=/opt/rocrail/bin/rocrail -l /opt/rocrail/bin

ExecStartPre=/usr/bin/mkdir -p /opt/rocrail/trace /opt/rocrail/issues

Restart=on-failure
RestartSec=3

User=root
Group=root

[Install]
WantedBy=multi-user.target
UNITEOF

        systemctl daemon-reload
        systemctl enable rocrail
    fi

    systemctl start rocrail
else
    unzip -o "$FILE"
fi

echo "Done: $FILE -> $DEST_DIR"
