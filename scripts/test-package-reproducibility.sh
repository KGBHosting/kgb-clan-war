#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-reproducibility-test}"
ARCHIVE="$ROOT_DIR/dist/kgb-clan-war-$VERSION.zip"

hash_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	else
		shasum -a 256 "$1" | awk '{print $1}'
	fi
}

"$ROOT_DIR/scripts/package.sh" "$VERSION"
first_hash="$(hash_file "$ARCHIVE")"
# Unnormalized ZIP creation timestamps have two-second granularity. Cross that
# boundary so this test fails reliably if metadata normalization is removed.
sleep 2
"$ROOT_DIR/scripts/package.sh" "$VERSION"
second_hash="$(hash_file "$ARCHIVE")"

if test "$first_hash" != "$second_hash"; then
	printf 'Release archive is not reproducible: %s != %s\n' "$first_hash" "$second_hash" >&2
	exit 1
fi
printf 'Reproducible release archive SHA-256: %s\n' "$second_hash"
