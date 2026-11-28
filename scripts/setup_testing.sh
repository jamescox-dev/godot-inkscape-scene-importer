#!/usr/bin/env bash
# Installs the pinned GUT version needed by the test suite.
set -euo pipefail

GUT_VERSION="9.6.1"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$PROJECT_ROOT/addons/gut"

if [ -d "$TARGET_DIR" ]; then
	echo "GUT $GUT_VERSION appears to be installed at $TARGET_DIR."
	exit 0
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

curl -fsSL \
	"https://github.com/bitwes/Gut/archive/refs/tags/v${GUT_VERSION}.tar.gz" \
	-o "$WORK_DIR/gut.tar.gz"
tar -xzf "$WORK_DIR/gut.tar.gz" -C "$WORK_DIR"

mkdir -p "$PROJECT_ROOT/addons"
mv "$WORK_DIR/Gut-${GUT_VERSION}/addons/gut" "$TARGET_DIR"
echo "Installed GUT $GUT_VERSION into $TARGET_DIR."
