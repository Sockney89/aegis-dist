#!/usr/bin/env sh
# Aegis toolchain installer (Linux x86_64).
#
#   curl -fsSL https://raw.githubusercontent.com/Sockney89/aegis-dist/main/install.sh | sh
#
# Env / flags:
#   VERSION=0.2.0        install a specific release (default: latest)
#   AEGIS_DIR=~/.aegis   install directory
#   --version <v>  --dir <path>  --base-url <url>
#
# The download is verified against the release's aegis-checksums.txt before it
# is unpacked. Building a standalone executable still needs a clang-compatible C
# compiler at runtime (AEGIS_CC), which this installer detects and reports.
set -eu

OWNER="Sockney89"
REPO="aegis-dist"

VERSION="${VERSION:-}"
DIR="${AEGIS_DIR:-$HOME/.aegis}"
BASE_URL="${BASE_URL:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --dir)     DIR="$2"; shift 2 ;;
    --base-url) BASE_URL="$2"; shift 2 ;;
    -h|--help) echo "usage: install.sh [--version V] [--dir DIR] [--base-url URL]"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "$(uname -s)" in
  Linux) ;;
  *) echo "install.sh supports Linux; on Windows use install.ps1" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) TRIPLE="x86_64-unknown-linux-gnu" ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

ASSET="aegis-$TRIPLE.tar.gz"
SUMS="aegis-checksums.txt"

if [ -n "$BASE_URL" ]; then
  BASE="$BASE_URL"
elif [ -n "$VERSION" ]; then
  BASE="https://github.com/$OWNER/$REPO/releases/download/v$VERSION"
else
  BASE="https://github.com/$OWNER/$REPO/releases/latest/download"
fi

echo "Aegis installer: $ASSET from $BASE"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }; }
need curl
need tar
if command -v sha256sum >/dev/null 2>&1; then
  sum() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
  sum() { shasum -a 256 "$1" | awk '{print $1}'; }
else
  echo "missing sha256 tool (need sha256sum or shasum)" >&2; exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -fsSL "$BASE/$ASSET" -o "$TMP/$ASSET"
curl -fsSL "$BASE/$SUMS"  -o "$TMP/$SUMS"

EXPECTED="$(grep -E "[[:space:]]\*?$ASSET\$" "$TMP/$SUMS" | head -n1 | awk '{print $1}')"
[ -n "$EXPECTED" ] || { echo "no checksum for $ASSET in $SUMS" >&2; exit 1; }
ACTUAL="$(sum "$TMP/$ASSET")"
[ "$EXPECTED" = "$ACTUAL" ] || { echo "checksum mismatch: expected $EXPECTED got $ACTUAL" >&2; exit 1; }
echo "checksum ok: $ACTUAL"

rm -rf "$DIR"
mkdir -p "$DIR"
tar -xzf "$TMP/$ASSET" -C "$DIR"

BIN="$DIR/bin"
[ -x "$BIN/compiler" ] || { echo "unexpected layout: $BIN/compiler missing" >&2; exit 1; }

LOCALBIN="$HOME/.local/bin"
if [ -d "$LOCALBIN" ]; then
  for b in aegis compiler aegis-daemon aegis-ws aegis-mcp; do
    [ -e "$BIN/$b" ] && ln -sf "$BIN/$b" "$LOCALBIN/$b"
  done
  echo "linked binaries into $LOCALBIN"
else
  echo "add to PATH:  export PATH=\"$BIN:\$PATH\""
fi

echo ""
echo "Aegis installed to $DIR"
echo "  run:  $BIN/compiler --help"
if command -v clang >/dev/null 2>&1 || command -v cc >/dev/null 2>&1; then
  echo "  note: set AEGIS_CC to your clang path if it is not on PATH."
else
  echo "  note: building an executable needs a clang-compatible C compiler (AEGIS_CC)."
fi
