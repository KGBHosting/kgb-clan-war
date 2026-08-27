#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

command -v cc >/dev/null 2>&1 || {
	printf 'A C compiler is required for the POSIX rename regression.\n' >&2
	exit 1
}

HLDS_ROOT="$TEST_ROOT/hlds"
MOD_ROOT="$HLDS_ROOT/cstrike"
CONFIG_DIR="$MOD_ROOT/addons/amxmodx/configs"
FIXTURE="$TEST_ROOT/posix-rename"
mkdir -p "$CONFIG_DIR"
cc -std=c99 -Wall -Wextra -Werror "$ROOT_DIR/tests/posix_rename_fixture.c" -o "$FIXTURE"

# AMX Mod X's relative=0 base is documented as undefined (usually the HLDS
# process cwd). Prove that an AMXX mod-relative path is not valid from there.
printf 'first snapshot\n' > "$CONFIG_DIR/kgb_clan_war_saved.cfg.tmp"
(
	cd "$HLDS_ROOT"
	if "$FIXTURE" \
		"addons/amxmodx/configs/kgb_clan_war_saved.cfg.tmp" \
		"addons/amxmodx/configs/kgb_clan_war_saved.cfg" >/dev/null 2>&1; then
		printf 'Unexpectedly resolved a mod-relative snapshot from the HLDS cwd.\n' >&2
		exit 1
	fi

	# This is the effective path after rename_file(..., relative=1) applies the
	# cstrike mod-directory base. It must work for the first save.
	"$FIXTURE" \
		"cstrike/addons/amxmodx/configs/kgb_clan_war_saved.cfg.tmp" \
		"cstrike/addons/amxmodx/configs/kgb_clan_war_saved.cfg"
)
grep -Fqx 'first snapshot' "$CONFIG_DIR/kgb_clan_war_saved.cfg"
! test -e "$CONFIG_DIR/kgb_clan_war_saved.cfg.tmp"

# POSIX rename must atomically replace the existing snapshot without a delete
# gap. The plugin deliberately relies on this behavior only on POSIX servers.
printf 'replacement snapshot\n' > "$CONFIG_DIR/kgb_clan_war_saved.cfg.tmp"
(
	cd "$HLDS_ROOT"
	"$FIXTURE" \
		"cstrike/addons/amxmodx/configs/kgb_clan_war_saved.cfg.tmp" \
		"cstrike/addons/amxmodx/configs/kgb_clan_war_saved.cfg"
)
grep -Fqx 'replacement snapshot' "$CONFIG_DIR/kgb_clan_war_saved.cfg"
! test -e "$CONFIG_DIR/kgb_clan_war_saved.cfg.tmp"

printf 'HLDS-cwd mod-base and POSIX first/replacement snapshot checks passed.\n'
