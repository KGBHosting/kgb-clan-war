#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$ROOT_DIR/src/kgb_clan_war.sma"
HLTV="$ROOT_DIR/src/kgb_clan_war_hltv.sma"
SQL="$ROOT_DIR/src/kgb_clan_war_sql.sma"
SQL_SCHEMA="$ROOT_DIR/sql/schema.sql"
CORE_CONFIG="$ROOT_DIR/configs/kgb_clan_war.cfg.example"
PRESET_CATALOG="$ROOT_DIR/configs/kgb_clan_war_presets.ini.example"
MAP_CATALOG="$ROOT_DIR/configs/kgb_clan_war_maps.ini.example"
LANG_CATALOG="$ROOT_DIR/data/lang/kgb_clan_war.txt"
README="$ROOT_DIR/README.md"

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
	require_string "$source" '#define PLUGIN_VERSION "0.3.0"'
	require_string "$source" 'SPDX-License-Identifier: GPL-3.0-or-later'
done

for command in \
	amx_cw_menu amx_cw_warmup amx_cw_knife amx_cw_live amx_cw_relo3 \
	amx_cw_swap amx_cw_restart_half amx_cw_restart_match amx_cw_pug_randomize \
	amx_cw_pug_start amx_cw_pug_assign amx_cw_pug_stop amx_cw_config_menu \
	amx_cw_setup amx_cw_settings amx_match amx_match2 amx_match3 amx_match4 \
	amx_matchrestart amx_matchstop amx_matchstart amx_matchrelo3 amx_swapteams amx_randomizeteams \
	amx_cw_presets amx_cw_preset amx_cw_map_menu amx_cw_save_config amx_cw_load_saved \
	amx_cw_teams amx_cw_tags amx_cw_maps amx_cw_stop amx_cw_score amx_cw_scoreids \
	amx_cw_scoreids_snapshot amx_cw_status; do
	require_string "$CORE" "\"$command\""
done

for cvar in \
	kgb_cw_format kgb_cw_ready_mode kgb_cw_time_limit_minutes kgb_cw_playout \
	kgb_cw_playout_vote_default kgb_cw_time_limit_finish_round \
	kgb_cw_overtime_max_cycles kgb_cw_team_a_name kgb_cw_team_b_name \
	kgb_cw_team_a_tag kgb_cw_team_b_tag kgb_cw_map_count kgb_cw_knife_vote \
	kgb_cw_pug_mode kgb_cw_set_hostname kgb_cw_set_password \
	kgb_cw_client_demos kgb_cw_screenshots kgb_cw_file_stats \
	kgb_cw_overtime_vote kgb_cw_overtime_vote_seconds kgb_cw_overtime_vote_default \
	kgb_cw_pug_style kgb_cw_pug_persist kgb_cw_allow_menu_save kgb_cw_second_half_ready \
	kgb_cw_swap_policy kgb_cw_hud_interval kgb_cw_scoreid_screenshots kgb_cw_screenshot_on_stop \
	kgb_cw_display_name kgb_cw_chat_prefix; do
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
require_string "$CORE" 'g_State != STATE_KNIFE_VOTE || g_KnifeDecisionMade'
require_string "$CORE" 'reset_ready_players(); g_KnifeDecisionMade = false'
require_string "$CORE" '#define DEFAULT_DISPLAY_NAME "KGB Clan War"'
require_string "$CORE" '#define DEFAULT_CHAT_PREFIX "[KGB CW]"'
require_string "$CORE" 'valid_display_token(value, MAX_DISPLAY_NAME)'
require_string "$CORE" 'valid_display_token(value, MAX_CHAT_PREFIX)'
require_string "$CORE" 'copy(g_DisplayName, charsmax(g_DisplayName), DEFAULT_DISPLAY_NAME)'
require_string "$CORE" 'copy(g_ChatPrefix, charsmax(g_ChatPrefix), DEFAULT_CHAT_PREFIX)'
require_string "$CORE" 'new menu = menu_create(g_DisplayName, "menu_control_handler")'
require_string "$CORE" 'formatex(title, charsmax(title), "%s: %L", g_DisplayName, id, "CW_KNIFE_TITLE")'
require_string "$CORE" 'new menu = menu_create(title, "menu_knife_vote_handler")'
require_string "$CORE" 'register_dictionary("kgb_clan_war.txt")'
require_string "$CORE" '"%s/kgb_clan_war/presets/%s.cfg", configsDir, preset'
require_string "$CORE" '"%s/kgb_clan_war_saved.cfg", configsDir'
require_string "$CORE" 'STATE_OVERTIME_VOTE'
require_string "$CORE" 'menu_overtime_vote_handler'
require_string "$CORE" 'show_hudmessage(id, "%s %s", g_ChatPrefix, message)'
require_string "$CORE" 'public client_disconnect(id)'
require_string "$CORE" 'public client_disconnected(id)'
require_string "$CORE" 'STATE_HALF_READY'
require_string "$CORE" 'register_touch("weaponbox", "player", "touch_knife_weapon")'
require_string "$CORE" 'register_event("TeamInfo", "event_team_info", "a")'
require_string "$CORE" 'capture_half_player_baseline()'
require_string "$CORE" 'if (g_CaptureHalfBaselineAfterLo3)'
require_string "$CORE" 'kind=player'
require_string "$CORE" 'g_MapMenuSecond'
require_string "$CORE" 'if (!start_warmup(true)) return PLUGIN_HANDLED'
require_string "$CORE" 'if (g_Half == 2 && get_pcvar_num(g_CvarSecondHalfReady))'
require_string "$CORE" 'if (team == CS_TEAM_CT || team == CS_TEAM_T) players[activeCount++] = players[i]'
require_string "$CORE" 'recompute_overtime_votes()'
require_string "$CORE" 'recompute_knife_votes()'
require_string "$CORE" 'g_KnifeVoteChoice[id]'
require_string "$CORE" 'STATE_PLAYOUT_VOTE'
require_string "$CORE" 'begin_playout_vote()'
require_string "$CORE" 'if (g_Format == FORMAT_TL && g_TimeLimitExpired) complete_time_limit_half()'
require_string "$CORE" 'if (g_ResetTlTimerAfterLo3 && g_Format == FORMAT_TL && !g_InOvertime) schedule_time_limit_half()'
require_string "$CORE" 'if (!safe_configuration_state(id)) return PLUGIN_HANDLED'
require_string "$CORE" 'g_MapNumber = oldMapNumber; g_MapCount = oldMapCount'
require_string "$CORE" 'managed_config_file_valid(path, true)'
require_string "$CORE" 'rename_file(temporaryPath, path)'
require_string "$CORE" 'if (!runtime_config_valid(false) || !start_warmup(true))'
require_string "$CORE" 'set_pcvar_string(g_CvarFormat, oldFormat)'
require_string "$CORE" 'alternate_configured_pug_maps()'
require_string "$CORE" '#define LI_PUG_ACTIVE "_kgbcw_pug_active"'
require_string "$CORE" 'cw_console_ml(id, "CW_SCORE_MAP", g_MapNumber, labelA, g_TeamAScore, g_TeamBScore, labelB)'
require_string "$CORE_CONFIG" 'kgb_cw_display_name "KGB Clan War"'
require_string "$CORE_CONFIG" 'kgb_cw_chat_prefix "[KGB CW]"'
require_string "$CORE_CONFIG" 'kgb_cw_playout_vote_default 1'
require_string "$CORE_CONFIG" 'kgb_cw_time_limit_finish_round 1'
require_string "$CORE_CONFIG" 'kgb_cw_screenshot_on_stop 0'
require_string "$README" '`v0.3.0` is the next qualification candidate.'
require_string "$README" 'KGB Hosting may install, run, modify, and redistribute it'
require_string "$README" 'does not grant trademark rights'

if grep -Eq 'client_print.*"\[KGB CW\]|console_print.*"\[KGB CW\]|menu_create\("' "$CORE"; then
	printf 'Hardcoded customer-visible core branding bypasses the validated CVARs.\n' >&2
	exit 1
fi

if grep -Fq 'show_hudmessage(0, "%s", message)' "$CORE"; then
	printf 'HUD announcements bypass the validated branding CVARs.\n' >&2
	exit 1
fi

if grep -Eq '(^|[[:space:]])(announce|cw_chat|cw_console)\(' "$CORE"; then
	printf 'Untranslated customer-visible core output bypasses the fresh language catalog.\n' >&2
	exit 1
fi

for key in $(grep -Eho '"CW_[A-Z0-9_]+"' "$CORE" "$HLTV" | tr -d '"' | sort -u); do
	if test "$(grep -Ec "^${key}[[:space:]]*=" "$LANG_CATALOG")" -ne 2; then
		printf 'Language key must exist exactly once in English and German: %s\n' "$key" >&2
		exit 1
	fi
done

require_string "$HLTV" '#include <sockets>'
require_string "$HLTV" '"kgb_cw_hltv_enabled", "0"'
require_string "$HLTV" '"kgb_cw_hltv_rcon_enabled", "0"'
require_string "$HLTV" 'kgb_clan_war_hltv_rcon.key'
require_string "$HLTV" 'addons/amxmodx/configs/kgb_clan_war_hltv.cfg'
require_string "$HLTV" 'kgb_cw_event'
require_string "$HLTV" 'equali(event, "half_start") && map_number == 2 && half == 1 && !g_Recording'
require_string "$HLTV" '"amx_cw_hltv_menu"'
require_string "$HLTV" '"amx_cw_hltv_delay"'
require_string "$HLTV" '"kgb_cw_hltv_proxy_delay", "30"'
require_string "$HLTV" 'delay %d;record %s'
require_string "$HLTV" 'g_RecordStartPending'
require_string "$HLTV" 'g_RecordStopPending'
require_string "$HLTV" 'RCON operation rejected because another request is pending.'
require_string "$HLTV" 'enforce_disabled_recording_stop()'
require_string "$HLTV" 'finish_rcon_request(sent)'
require_string "$HLTV" 'if (operation == RCON_START_RECORDING)'
require_string "$HLTV" 'if (g_Recording || g_RecordStartPending) task_stop_recording()'
require_string "$HLTV" 'g_RecordRestartPending = true'
require_string "$HLTV" 'stop_recording_on_unload()'
require_string "$HLTV" 'socket_is_readable(g_RconSocket, 100000)'
require_string "$HLTV" 'socket_change(g_RconSocket, 100000)'
require_string "$HLTV" 'get_cvar_pointer("kgb_cw_chat_prefix")'
require_string "$HLTV" 'get_hltv_prefix(prefix, charsmax(prefix))'

require_string "$PRESET_CATALOG" 'competitive|Competitive MR15'
require_string "$MAP_CATALOG" 'de_dust2|Dust II'
require_string "$LANG_CATALOG" '[en]'
require_string "$LANG_CATALOG" '[de]'
require_string "$LANG_CATALOG" 'CW_OVERTIME_TITLE'
require_string "$LANG_CATALOG" 'CW_PLAYOUT_TITLE'
require_string "$LANG_CATALOG" 'CW_TL_FINISH_ROUND'

if grep -ERiq '(password|hostname|rcon|sql_|exec[[:space:]])' "$ROOT_DIR/configs/presets"; then
	printf 'A clean-room preset contains a credential, external integration, or nested exec directive.\n' >&2
	exit 1
fi
if grep -ERv '^[[:space:]]*(//|$|kgb_cw_(format|half_rounds|playout|playout_vote_default|time_limit_finish_round|overtime|overtime_vote|overtime_half_rounds|overtime_money|ready_mode|min_ready|pug_mode|pug_style|pug_persist|second_half_ready|swap_policy)[[:space:]])' \
	"$ROOT_DIR/configs/presets"/*.cfg; then
	printf 'A clean-room preset contains a CVAR outside the release allowlist.\n' >&2
	exit 1
fi

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
require_string "$SQL" 'REPLACE INTO kgb_cw_players (match_uid,map_number,auth_id'
require_string "$SQL" 'g_CurrentMapNumber = 2'
require_string "$SQL" 'capture_connected_players()'
require_string "$SQL_SCHEMA" 'PRIMARY KEY (match_uid, map_number, auth_id)'

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
