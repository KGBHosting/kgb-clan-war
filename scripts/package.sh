#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-dev}"
case "$VERSION" in
	'' | *[!A-Za-z0-9._-]*)
		printf 'Version may contain only letters, numbers, dot, underscore, and dash: %s\n' "$VERSION" >&2
		exit 2
		;;
esac
PACKAGE_NAME="kgb-clan-war-$VERSION"
STAGE_DIR="$ROOT_DIR/dist/$PACKAGE_NAME"
ARCHIVE="$ROOT_DIR/dist/$PACKAGE_NAME.zip"

command -v zip >/dev/null 2>&1 || {
	printf 'zip is required to create a release bundle.\n' >&2
	exit 1
}

verify_amxx_magic() {
	local artifact="$1"
	local magic
	magic="$(LC_ALL=C od -An -tx1 -N4 "$artifact" | tr -d '[:space:]')"
	test "$magic" = "58584d41"
}

hash_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	else
		shasum -a 256 "$1" | awk '{print $1}'
	fi
}

verify_artifact_checksum() {
	local artifact="$1"
	local checksum="$artifact.sha256"
	local expected_hash expected_name
	expected_hash="$(awk 'NR == 1 { print $1 }' "$checksum")"
	expected_name="$(awk 'NR == 1 { print $2 }' "$checksum")"
	test "$expected_name" = "${artifact##*/}" \
		&& test "$expected_hash" = "$(hash_file "$artifact")"
}

for plugin in kgb_clan_war kgb_clan_war_hltv kgb_clan_war_sql; do
	test -s "$ROOT_DIR/compiled/$plugin.amxx" || {
		printf 'Missing compiled artifact: compiled/%s.amxx\n' "$plugin" >&2
		exit 1
	}
	verify_amxx_magic "$ROOT_DIR/compiled/$plugin.amxx" || {
		printf 'Invalid AMXX magic in compiled/%s.amxx\n' "$plugin" >&2
		exit 1
	}
	verify_artifact_checksum "$ROOT_DIR/compiled/$plugin.amxx" || {
		printf 'Invalid checksum for compiled/%s.amxx\n' "$plugin" >&2
		exit 1
	}
	test -s "$ROOT_DIR/compiled/$plugin.amxx.sha256" || {
		printf 'Missing checksum: compiled/%s.amxx.sha256\n' "$plugin" >&2
		exit 1
	}
done

rm -rf "$STAGE_DIR"
rm -f "$ARCHIVE" "$ARCHIVE.sha256"
mkdir -p "$STAGE_DIR/addons/amxmodx/plugins" "$STAGE_DIR/addons/amxmodx/configs" \
	"$STAGE_DIR/addons/amxmodx/configs/kgb_clan_war/presets" "$STAGE_DIR/addons/amxmodx/data/lang" \
	"$STAGE_DIR/compiled" "$STAGE_DIR/configs/presets" "$STAGE_DIR/data/lang" "$STAGE_DIR/docs" "$STAGE_DIR/src" "$STAGE_DIR/scripts" \
	"$STAGE_DIR/tests/sql"
for plugin in kgb_clan_war kgb_clan_war_hltv kgb_clan_war_sql; do
	cp "$ROOT_DIR/compiled/$plugin.amxx" "$ROOT_DIR/compiled/$plugin.amxx.sha256" \
		"$STAGE_DIR/addons/amxmodx/plugins/"
	cp "$ROOT_DIR/compiled/$plugin.amxx" "$ROOT_DIR/compiled/$plugin.amxx.sha256" \
		"$STAGE_DIR/compiled/"
done
for config in kgb_clan_war kgb_clan_war_hltv kgb_clan_war_sql; do
	cp "$ROOT_DIR/configs/$config.cfg.example" "$STAGE_DIR/addons/amxmodx/configs/"
done
cp "$ROOT_DIR"/configs/*.cfg.example "$STAGE_DIR/configs/"
cp "$ROOT_DIR"/configs/*.ini.example "$STAGE_DIR/configs/"
cp "$ROOT_DIR"/configs/presets/*.cfg "$STAGE_DIR/configs/presets/"
cp "$ROOT_DIR"/configs/presets/*.cfg "$STAGE_DIR/addons/amxmodx/configs/kgb_clan_war/presets/"
cp "$ROOT_DIR/data/lang/kgb_clan_war.txt" "$STAGE_DIR/data/lang/"
cp "$ROOT_DIR/data/lang/kgb_clan_war.txt" "$STAGE_DIR/addons/amxmodx/data/lang/"
cp "$ROOT_DIR/configs/kgb_clan_war_presets.ini.example" "$STAGE_DIR/addons/amxmodx/configs/kgb_clan_war_presets.ini"
cp "$ROOT_DIR/configs/kgb_clan_war_maps.ini.example" "$STAGE_DIR/addons/amxmodx/configs/kgb_clan_war_maps.ini"
cp "$ROOT_DIR/configs/kgb_gamemode.cfg.example" "$STAGE_DIR/"
cp "$ROOT_DIR"/src/*.sma "$STAGE_DIR/src/"
mkdir -p "$STAGE_DIR/sql"
cp "$ROOT_DIR"/sql/*.sql "$STAGE_DIR/sql/"
cp "$ROOT_DIR"/scripts/*.sh "$STAGE_DIR/scripts/"
cp "$ROOT_DIR/tests/posix_rename_fixture.c" "$STAGE_DIR/tests/"
cp "$ROOT_DIR/tests/sql"/*.sql "$STAGE_DIR/tests/sql/"
cp "$ROOT_DIR"/docs/*.md "$STAGE_DIR/docs/"
cp "$ROOT_DIR/README.md" "$ROOT_DIR/LICENSE" "$ROOT_DIR/SECURITY.md" "$STAGE_DIR/"

(
	cd "$ROOT_DIR/dist"
	zip -q -r "$PACKAGE_NAME.zip" "$PACKAGE_NAME"
)

if command -v sha256sum >/dev/null 2>&1; then
	(
		cd "$ROOT_DIR/dist"
		sha256sum "$PACKAGE_NAME.zip" > "$PACKAGE_NAME.zip.sha256"
	)
else
	(
		cd "$ROOT_DIR/dist"
		shasum -a 256 "$PACKAGE_NAME.zip" > "$PACKAGE_NAME.zip.sha256"
	)
fi

printf 'Created %s\n' "$ARCHIVE"
