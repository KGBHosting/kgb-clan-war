#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT_ONE="$(mktemp -d)"
TEST_ROOT_TWO="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT_ONE" "$TEST_ROOT_TWO"' EXIT

hash_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	else
		shasum -a 256 "$1" | awk '{print $1}'
	fi
}

for plugin in kgb_clan_war kgb_clan_war_hltv kgb_clan_war_sql; do
	test -s "$ROOT_DIR/compiled/$plugin.amxx"
done

# Existing configuration and deliberately disabled entries must survive.
mkdir -p "$TEST_ROOT_ONE/addons/amxmodx/configs"
printf '; operator-owned core config\nkgb_cw_enabled 0\n' > \
	"$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war.cfg"
printf '; operator-owned hltv config\nkgb_cw_hltv_enabled 0\n' > \
	"$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_hltv.cfg"
printf '; operator-owned sql config\nkgb_cw_sql_enabled 0\n' > \
	"$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_sql.cfg"
printf '; existing entries\n; kgb_clan_war_hltv.amxx\n' > \
	"$TEST_ROOT_ONE/addons/amxmodx/configs/plugins.ini"
printf '// operator-owned phase config\nmp_freezetime 9\n' > \
	"$TEST_ROOT_ONE/kgb_gamemode.cfg"
mkdir -p "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war/presets" \
	"$TEST_ROOT_ONE/addons/amxmodx/data/lang"
printf 'house|Operator League\n' > \
	"$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_presets.ini"
printf 'de_dust2|Operator Dust II\n' > \
	"$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_maps.ini"
printf 'kgb_cw_half_rounds 9\n' > \
	"$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war/presets/competitive.cfg"
printf '[en]\nCW_MENU_WARMUP = Operator warmup\n' > \
	"$TEST_ROOT_ONE/addons/amxmodx/data/lang/kgb_clan_war.txt"

CORE_HASH="$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war.cfg")"
HLTV_HASH="$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_hltv.cfg")"
SQL_HASH="$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_sql.cfg")"
PHASE_HASH="$(hash_file "$TEST_ROOT_ONE/kgb_gamemode.cfg")"
PRESET_CATALOG_HASH="$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_presets.ini")"
MAP_CATALOG_HASH="$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_maps.ini")"
PRESET_HASH="$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war/presets/competitive.cfg")"
LANG_HASH="$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/data/lang/kgb_clan_war.txt")"

"$ROOT_DIR/scripts/install.sh" --all "$TEST_ROOT_ONE"
"$ROOT_DIR/scripts/install.sh" --all "$TEST_ROOT_ONE"

test "$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war.cfg")" = "$CORE_HASH"
test "$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_hltv.cfg")" = "$HLTV_HASH"
test "$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_sql.cfg")" = "$SQL_HASH"
test "$(hash_file "$TEST_ROOT_ONE/kgb_gamemode.cfg")" = "$PHASE_HASH"
test "$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_presets.ini")" = "$PRESET_CATALOG_HASH"
test "$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_maps.ini")" = "$MAP_CATALOG_HASH"
test "$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war/presets/competitive.cfg")" = "$PRESET_HASH"
test "$(hash_file "$TEST_ROOT_ONE/addons/amxmodx/data/lang/kgb_clan_war.txt")" = "$LANG_HASH"
test "$(grep -Fxc 'kgb_clan_war.amxx' "$TEST_ROOT_ONE/addons/amxmodx/configs/plugins.ini")" -eq 1
test "$(grep -Fxc 'kgb_clan_war_sql.amxx' "$TEST_ROOT_ONE/addons/amxmodx/configs/plugins.ini")" -eq 1
test "$(grep -Fxc '; kgb_clan_war_hltv.amxx' "$TEST_ROOT_ONE/addons/amxmodx/configs/plugins.ini")" -eq 1
! grep -Fqx 'kgb_clan_war_hltv.amxx' "$TEST_ROOT_ONE/addons/amxmodx/configs/plugins.ini"
! test -e "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_hltv_rcon.key"
! test -e "$TEST_ROOT_ONE/addons/amxmodx/configs/sql.cfg"
test -s "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_presets.ini"
test -s "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war_maps.ini"
test -s "$TEST_ROOT_ONE/addons/amxmodx/configs/kgb_clan_war/presets/competitive.cfg"
test -s "$TEST_ROOT_ONE/addons/amxmodx/data/lang/kgb_clan_war.txt"

# A fresh installation creates each safe example once and remains idempotent.
"$ROOT_DIR/scripts/install.sh" --all "$TEST_ROOT_TWO"
"$ROOT_DIR/scripts/install.sh" --all "$TEST_ROOT_TWO"
for plugin in kgb_clan_war kgb_clan_war_hltv kgb_clan_war_sql; do
	test -s "$TEST_ROOT_TWO/addons/amxmodx/plugins/$plugin.amxx"
	test "$(grep -Fxc "$plugin.amxx" "$TEST_ROOT_TWO/addons/amxmodx/configs/plugins.ini")" -eq 1
done
grep -Fqx 'kgb_cw_hltv_enabled 0' \
	"$TEST_ROOT_TWO/addons/amxmodx/configs/kgb_clan_war_hltv.cfg"
grep -Fqx 'kgb_cw_hltv_rcon_enabled 0' \
	"$TEST_ROOT_TWO/addons/amxmodx/configs/kgb_clan_war_hltv.cfg"
grep -Fqx 'kgb_cw_sql_enabled 0' \
	"$TEST_ROOT_TWO/addons/amxmodx/configs/kgb_clan_war_sql.cfg"
grep -Fqx 'kgb_cw_display_name "KGB Clan War"' \
	"$TEST_ROOT_TWO/addons/amxmodx/configs/kgb_clan_war.cfg"
grep -Fqx 'kgb_cw_chat_prefix "[KGB CW]"' \
	"$TEST_ROOT_TWO/addons/amxmodx/configs/kgb_clan_war.cfg"
grep -Fqx 'kgb_cw_overtime_vote 0' \
	"$TEST_ROOT_TWO/addons/amxmodx/configs/kgb_clan_war.cfg"
grep -Fqx 'kgb_cw_allow_menu_save 0' \
	"$TEST_ROOT_TWO/addons/amxmodx/configs/kgb_clan_war.cfg"
grep -Fqx 'competitive|Competitive MR15' \
	"$TEST_ROOT_TWO/addons/amxmodx/configs/kgb_clan_war_presets.ini"
grep -Fqx '[de]' "$TEST_ROOT_TWO/addons/amxmodx/data/lang/kgb_clan_war.txt"
grep -Fqx 'mp_roundtime 1.75' "$TEST_ROOT_TWO/kgb_gamemode.cfg"
grep -Fqx 'mp_friendlyfire 1' "$TEST_ROOT_TWO/kgb_gamemode.cfg"
grep -Fqx 'mp_autoteambalance 0' "$TEST_ROOT_TWO/kgb_gamemode.cfg"
! test -e "$TEST_ROOT_TWO/addons/amxmodx/configs/kgb_clan_war_hltv_rcon.key"
! test -e "$TEST_ROOT_TWO/addons/amxmodx/configs/sql.cfg"

printf 'Installer preservation, idempotency, and safe-default checks passed.\n'
