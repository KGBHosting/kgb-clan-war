#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$ROOT_DIR/src/kgb_clan_war.sma"
HLTV="$ROOT_DIR/src/kgb_clan_war_hltv.sma"
SQL="$ROOT_DIR/src/kgb_clan_war_sql.sma"

require_string() {
	local file="$1"
	local expected="$2"
	if ! grep -Fq "$expected" "$file"; then
		printf 'Missing required capability in %s: %s\n' "${file#"$ROOT_DIR/"}" "$expected" >&2
		exit 1
	fi
}

for source in "$CORE" "$HLTV" "$SQL"; do
	test -s "$source" || {
		printf 'Missing required source: %s\n' "${source#"$ROOT_DIR/"}" >&2
		exit 1
	}
	require_string "$source" '#define PLUGIN_VERSION "0.1.0"'
	require_string "$source" 'SPDX-License-Identifier: GPL-3.0-or-later'
done

for command in \
	amx_cw_menu amx_cw_warmup amx_cw_knife amx_cw_live amx_cw_relo3 \
	amx_cw_swap amx_cw_restart_half amx_cw_restart_match amx_cw_pug_randomize \
	amx_cw_teams amx_cw_tags amx_cw_maps amx_cw_stop amx_cw_score amx_cw_status; do
	require_string "$CORE" "\"$command\""
done

for cvar in \
	kgb_cw_format kgb_cw_ready_mode kgb_cw_time_limit_minutes kgb_cw_playout \
	kgb_cw_overtime_max_cycles kgb_cw_team_a_name kgb_cw_team_b_name \
	kgb_cw_team_a_tag kgb_cw_team_b_tag kgb_cw_map_count kgb_cw_knife_vote \
	kgb_cw_pug_mode kgb_cw_set_hostname kgb_cw_set_password \
	kgb_cw_client_demos kgb_cw_screenshots kgb_cw_file_stats; do
	require_string "$CORE" "\"$cvar\""
done
require_string "$CORE" 'kgb_cw_event'
require_string "$CORE" 'addons/amxmodx/configs/kgb_clan_war.cfg'
require_string "$CORE" 'register_cvar("kgb_cw_password", "", FCVAR_PROTECTED)'
require_string "$CORE" '#define LI_TEAM_A_SIDE "_kgbcw_a_side"'
require_string "$CORE" 'set_localinfo(LI_TEAM_A_SIDE, value)'
require_string "$CORE" 'get_localinfo(LI_TEAM_A_SIDE, value, charsmax(value))'
require_string "$CORE" 'set_localinfo(LI_TEAM_A_SIDE, "")'
require_string "$CORE" 'if (!file_exists(path))'
require_string "$CORE" 'Required %s config file does not exist: %s'

require_string "$HLTV" '#include <sockets>'
require_string "$HLTV" '"kgb_cw_hltv_enabled", "0"'
require_string "$HLTV" '"kgb_cw_hltv_rcon_enabled", "0"'
require_string "$HLTV" 'kgb_clan_war_hltv_rcon.key'
require_string "$HLTV" 'addons/amxmodx/configs/kgb_clan_war_hltv.cfg'
require_string "$HLTV" 'kgb_cw_event'
require_string "$HLTV" 'equali(event, "half_start") && map_number == 2 && half == 1 && !g_Recording'

require_string "$SQL" '#include <sqlx>'
require_string "$SQL" '"kgb_cw_sql_enabled", "0"'
require_string "$SQL" 'SQL_MakeStdTuple'
require_string "$SQL" 'SQL_ThreadQuery'
require_string "$SQL" 'addons/amxmodx/configs/kgb_clan_war_sql.cfg'
require_string "$SQL" 'kgb_cw_event'
require_string "$SQL" '#define LI_SQL_MATCH_UID "_kgbcw_sql_match_uid"'
require_string "$SQL" 'set_localinfo(LI_SQL_MATCH_UID, g_MatchUid)'
require_string "$SQL" 'restore_crossmap_match_uid()'
require_string "$SQL" 'confirm_crossmap_resume()'
require_string "$SQL" 'set_localinfo(LI_SQL_MATCH_UID, "")'

if grep -Eq 'register_cvar\("[^\"]*(sql_password|rcon_password|db_password)' "$HLTV" "$SQL"; then
	printf 'Credential-bearing CVAR detected in optional integration source.\n' >&2
	exit 1
fi

if test -n "${VERSION_TAG:-}"; then
	expected_version="${VERSION_TAG#v}"
	if test "$expected_version" = "$VERSION_TAG"; then
		printf 'VERSION_TAG must start with v: %s\n' "$VERSION_TAG" >&2
		exit 1
	fi
	for source in "$CORE" "$HLTV" "$SQL"; do
		require_string "$source" "#define PLUGIN_VERSION \"$expected_version\""
	done
fi

printf 'Source capability and version checks passed.\n'
