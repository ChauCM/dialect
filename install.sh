#!/usr/bin/env sh
#
# Dialect installer
# https://dialect.tools
#
# Downloads a pre-built `dialect` binary from the GitHub release matching
# the host OS/arch, verifies the SHA-256 checksum, and installs it to
# $DIALECT_INSTALL_DIR (default: ~/.local/bin).
#
# Usage:
#   curl -fsSL https://dialect.tools/install.sh | sh
#   DIALECT_VERSION=v1.0.0 curl -fsSL https://dialect.tools/install.sh | sh
#   DIALECT_INSTALL_DIR=/usr/local/bin curl -fsSL https://dialect.tools/install.sh | sudo sh
#
# Supported targets: macos-arm64, linux-x64.
# Intel-Mac, Linux-arm64, Windows users: see the README — build from source
# or grab the .exe / .tar.gz from the GitHub release page.

set -eu

REPO="ChauCM/dialect"
INSTALL_DIR="${DIALECT_INSTALL_DIR:-$HOME/.local/bin}"

# ---------------------------------------------------------------------------
# Detect target triple
# ---------------------------------------------------------------------------
uname_s="$(uname -s 2>/dev/null || echo unknown)"
uname_m="$(uname -m 2>/dev/null || echo unknown)"

case "$uname_s" in
  Darwin) os="macos" ;;
  Linux)  os="linux" ;;
  *)
    echo "dialect: unsupported OS: $uname_s" >&2
    echo "         Windows users: see https://github.com/$REPO#install" >&2
    exit 1
    ;;
esac

case "$uname_m" in
  x86_64|amd64) arch="x64" ;;
  arm64|aarch64) arch="arm64" ;;
  *)
    echo "dialect: unsupported architecture: $uname_m" >&2
    exit 1
    ;;
esac

target="${os}-${arch}"

# Only macos-arm64 and linux-x64 are published. Others build from source.
case "$target" in
  macos-arm64|linux-x64) ;;
  *)
    echo "dialect: no prebuilt binary published for $target." >&2
    echo "         Build from source:" >&2
    echo "           https://github.com/$REPO#build-from-source" >&2
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Resolve version
# ---------------------------------------------------------------------------
if [ -z "${DIALECT_VERSION:-}" ]; then
  # Latest release tag via the GitHub API. The 30s curl timeout keeps
  # CI from hanging on a flaky API.
  VERSION="$(curl -fsSL --max-time 30 \
    "https://api.github.com/repos/${REPO}/releases/latest" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)"
  if [ -z "$VERSION" ]; then
    echo "dialect: could not look up latest release tag." >&2
    echo "         Pin a version: DIALECT_VERSION=v1.0.0 ..." >&2
    exit 1
  fi
else
  VERSION="$DIALECT_VERSION"
fi

archive="dialect-${target}.tar.gz"
url="https://github.com/${REPO}/releases/download/${VERSION}/${archive}"
sums_url="https://github.com/${REPO}/releases/download/${VERSION}/SHA256SUMS"

echo "dialect: installing ${VERSION} (${target}) to ${INSTALL_DIR}"

# ---------------------------------------------------------------------------
# Download + verify
# ---------------------------------------------------------------------------
tmp="$(mktemp -d 2>/dev/null || mktemp -d -t dialect)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL --max-time 120 "$url" -o "$tmp/$archive" \
  || { echo "dialect: download failed: $url" >&2; exit 1; }

curl -fsSL --max-time 30 "$sums_url" -o "$tmp/SHA256SUMS" \
  || { echo "dialect: checksum file download failed: $sums_url" >&2; exit 1; }

expected="$(grep " $archive\$" "$tmp/SHA256SUMS" | awk '{print $1}')"
if [ -z "$expected" ]; then
  echo "dialect: SHA256SUMS missing entry for $archive" >&2
  exit 1
fi

if command -v shasum >/dev/null 2>&1; then
  actual="$(shasum -a 256 "$tmp/$archive" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "$tmp/$archive" | awk '{print $1}')"
else
  echo "dialect: neither shasum nor sha256sum found — cannot verify download." >&2
  exit 1
fi

if [ "$expected" != "$actual" ]; then
  echo "dialect: checksum mismatch for $archive" >&2
  echo "         expected: $expected" >&2
  echo "         actual:   $actual" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
mkdir -p "$INSTALL_DIR"
tar -xzf "$tmp/$archive" -C "$tmp"
mv "$tmp/dialect" "$INSTALL_DIR/dialect"
chmod +x "$INSTALL_DIR/dialect"

echo "dialect: installed $("$INSTALL_DIR/dialect" --version)"

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    echo
    echo "Add $INSTALL_DIR to your PATH:"
    echo "  echo 'export PATH=\"\$PATH:$INSTALL_DIR\"' >> ~/.profile"
    ;;
esac
