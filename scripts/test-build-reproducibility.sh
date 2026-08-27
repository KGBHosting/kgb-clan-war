#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-reproducibility-test}"
AMXX_VERSION="${AMXX_VERSION:-1.8.2}"
TEST_ROOT="$(mktemp -d)"
SOURCE_LIST="$TEST_ROOT/source-files.txt"
SOURCE_ARCHIVE="$TEST_ROOT/source.tar"
trap 'rm -rf "$TEST_ROOT"' EXIT

hash_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	else
		shasum -a 256 "$1" | awk '{print $1}'
	fi
}

write_manifest() {
	local build_root="$1" scope="$2" output="$3"
	case "$scope" in
		source) find "$build_root/src" -type f -name '*.sma' -print ;;
		binary) find "$build_root/compiled" -type f \( -name '*.amxx' -o -name '*.amxx.sha256' \) -print ;;
		*) printf 'Unknown reproducibility manifest scope: %s\n' "$scope" >&2; exit 2 ;;
	esac | LC_ALL=C sort | while IFS= read -r path; do
		printf '%s  %s\n' "$(hash_file "$path")" "${path#"$build_root/"}"
	done > "$output"
}

# Copy only repository source inputs into two empty trees. This deliberately
# excludes ignored compiler caches, compiled artifacts, and dist output. The
# untracked list keeps this gate usable before a new test script is committed.
(
	cd "$ROOT_DIR"
	git ls-files --cached --others --exclude-standard | LC_ALL=C sort | while IFS= read -r path; do
		test -f "$path" && printf '%s\n' "$path"
	done > "$SOURCE_LIST"
	tar -cf "$SOURCE_ARCHIVE" -T "$SOURCE_LIST"
)

for build_name in build-one build-two; do
	build_root="$TEST_ROOT/$build_name"
	mkdir -p "$build_root"
	tar -xf "$SOURCE_ARCHIVE" -C "$build_root"
	AMXX_VERSION="$AMXX_VERSION" "$build_root/scripts/build.sh"
	"$build_root/scripts/package.sh" "$VERSION"
	write_manifest "$build_root" source "$TEST_ROOT/$build_name-source.sha256"
	write_manifest "$build_root" binary "$TEST_ROOT/$build_name-binary.sha256"
	test -s "$TEST_ROOT/$build_name-source.sha256"
	test -s "$TEST_ROOT/$build_name-binary.sha256"
done

cmp "$TEST_ROOT/build-one-source.sha256" "$TEST_ROOT/build-two-source.sha256"
cmp "$TEST_ROOT/build-one-binary.sha256" "$TEST_ROOT/build-two-binary.sha256"

FIRST_ROOT="$TEST_ROOT/build-one"
SECOND_ROOT="$TEST_ROOT/build-two"
FIRST_ARCHIVE="$FIRST_ROOT/dist/kgb-clan-war-$VERSION.zip"
SECOND_ARCHIVE="$SECOND_ROOT/dist/kgb-clan-war-$VERSION.zip"
FIRST_ZIP_HASH="$(hash_file "$FIRST_ARCHIVE")"
SECOND_ZIP_HASH="$(hash_file "$SECOND_ARCHIVE")"
if test "$FIRST_ZIP_HASH" != "$SECOND_ZIP_HASH"; then
	printf 'Independent release ZIP hashes differ: %s != %s\n' "$FIRST_ZIP_HASH" "$SECOND_ZIP_HASH" >&2
	exit 1
fi

# Promote exactly one of the two independently verified builds for the later
# installer/checksum/release-asset gates in this checkout.
mkdir -p "$ROOT_DIR/compiled" "$ROOT_DIR/dist"
for plugin in kgb_clan_war kgb_clan_war_hltv kgb_clan_war_sql; do
	cp "$FIRST_ROOT/compiled/$plugin.amxx" "$FIRST_ROOT/compiled/$plugin.amxx.sha256" "$ROOT_DIR/compiled/"
done
cp "$FIRST_ARCHIVE" "$FIRST_ARCHIVE.sha256" "$ROOT_DIR/dist/"

printf 'Independent source manifests match: %s\n' "$(hash_file "$TEST_ROOT/build-one-source.sha256")"
printf 'Independent binary manifests match: %s\n' "$(hash_file "$TEST_ROOT/build-one-binary.sha256")"
printf 'Independent release ZIP SHA-256: %s\n' "$FIRST_ZIP_HASH"
