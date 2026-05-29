#!/bin/bash -xv

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
    FILE="Rocrail-tahoe-M.app.zip"
    DIR="macOS"
    DEST_DIR="$HOME/data/rocrail"
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
    wget "$URL"
else
    curl -L -o "$FILE" "$URL"
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
