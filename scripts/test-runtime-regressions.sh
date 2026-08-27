#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$ROOT_DIR/src/kgb_clan_war.sma"
HLTV="$ROOT_DIR/src/kgb_clan_war_hltv.sma"
SQL="$ROOT_DIR/src/kgb_clan_war_sql.sma"
MIGRATION="$ROOT_DIR/sql/migrate-v0.2.0-to-v0.3.0.sql"
V020_SCHEMA="$ROOT_DIR/tests/sql/v0.2.0-player-schema.sql"

require_string() {
	local file="$1" expected="$2"
	grep -Fq "$expected" "$file" || {
		printf 'Missing regression guard in %s: %s\n' "${file#"$ROOT_DIR/"}" "$expected" >&2
		exit 1
	}
}

hash_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	else
		shasum -a 256 "$1" | awk '{print $1}'
	fi
}

# Series topology and match policy are captured once, committed last, restored
# only after every entry validates, and invalidated before individual keys are
# cleared. This guards against a partially written or partially restored map 2.
require_string "$CORE" 'stock bool:capture_series_manifest()'
require_string "$CORE" 'stock bool:persist_series_manifest()'
require_string "$CORE" 'stock bool:restore_series_manifest()'
require_string "$CORE" 'set_localinfo(LI_MANIFEST_ACTIVE, "1")'
require_string "$CORE" 'set_localinfo(LI_MANIFEST_ACTIVE, "")'
require_string "$CORE" 'if (!restarting) { restore_legacy_record_mode(); discard_series_manifest(); }'
for setting in \
	kgb_cw_team_a_name kgb_cw_team_b_name kgb_cw_team_a_tag kgb_cw_team_b_tag \
	kgb_cw_format kgb_cw_half_rounds kgb_cw_win_rounds kgb_cw_time_limit_minutes \
	kgb_cw_ready_mode kgb_cw_swap_policy kgb_cw_overtime kgb_cw_playout \
	kgb_cw_screenshots kgb_cw_warmup_config kgb_cw_match_config \
	kgb_cw_overtime_config kgb_cw_default_config kgb_cw_map1 kgb_cw_map2 \
	kgb_cw_map_count kgb_cw_client_demos kgb_cw_hltv_enabled kgb_cw_hltv_auto_record; do
	require_string "$CORE" "\"$setting\""
done

# Exercise the vote rule independently of player slots: disconnect retracts
# exactly one choice, reconnect starts empty, and a new vote counts once.
connected=(0 1 1 1)
choice=(0 1 2 1)
recompute_knife_votes() {
	stay=0 swap=0
	for id in 1 2 3; do
		if test "${connected[$id]}" -ne 1; then
			choice[$id]=0
		elif test "${choice[$id]}" -eq 1; then
			stay=$((stay + 1))
		elif test "${choice[$id]}" -eq 2; then
			swap=$((swap + 1))
		fi
	done
}
recompute_knife_votes
test "$stay" -eq 2 && test "$swap" -eq 1
connected[2]=0
recompute_knife_votes
test "$stay" -eq 2 && test "$swap" -eq 0 && test "${choice[2]}" -eq 0
connected[2]=1
recompute_knife_votes
test "$stay" -eq 2 && test "$swap" -eq 0
choice[2]=1
recompute_knife_votes
test "$stay" -eq 3 && test "$swap" -eq 0
require_string "$CORE" 'recompute_knife_votes()'
require_string "$CORE" 'recompute_overtime_votes()'
require_string "$CORE" 'recompute_playout_votes()'
require_string "$CORE" 'g_KnifeVoteChoice[id] = 0'
require_string "$CORE" 'g_OvertimeVoteChoice[id] = 0'
require_string "$CORE" 'g_PlayoutVoteChoice[id] = 0'

# Model the serialized restart transitions used by the HLTV plugin. A failed
# start may be retried for a requested restart; a failed stop must never start
# a second recording; disabling auto-record cancels all replacement work.
enabled=1 recording=0 start_pending=1 stop_pending=0 restart_pending=1 starts=0
drive_restart() {
	if test "$restart_pending" -ne 1; then return; fi
	if test "$enabled" -ne 1; then restart_pending=0; return; fi
	if test "$start_pending" -eq 1 || test "$stop_pending" -eq 1; then return; fi
	if test "$recording" -eq 1; then stop_pending=1; return; fi
	restart_pending=0
	starts=$((starts + 1))
}
start_pending=0
drive_restart
test "$starts" -eq 1 && test "$restart_pending" -eq 0

recording=1; stop_pending=0; restart_pending=1; starts=0
drive_restart
test "$stop_pending" -eq 1 && test "$starts" -eq 0
stop_pending=0; recording=0
drive_restart
test "$starts" -eq 1 && test "$restart_pending" -eq 0

recording=1; stop_pending=1; restart_pending=1; starts=0
# This mirrors finish_rcon_request(false) for RCON_STOP_RECORDING.
stop_pending=0; restart_pending=0
drive_restart
test "$recording" -eq 1 && test "$starts" -eq 0

enabled=0; recording=0; start_pending=0; stop_pending=0; restart_pending=1; starts=0
drive_restart
test "$restart_pending" -eq 0 && test "$starts" -eq 0
require_string "$HLTV" 'if (g_RecordStartPending)'
require_string "$HLTV" 'g_RecordRestartPending = false'
require_string "$HLTV" 'if (operation == RCON_STOP_RECORDING)'
require_string "$HLTV" 'Stop request failed; recording state remains active/unknown and a replacement recording will not start.'
require_string "$HLTV" 'stop_recording_on_unload()'

# A re-LO3 during the original TL LO3 must preserve the pending timer reset.
require_string "$CORE" 'new bool:resetTimerAfterLo3 = resetTlTimer || g_ResetTlTimerAfterLo3'
require_string "$CORE" 'if (g_ResetTlTimerAfterLo3 && g_Format == FORMAT_TL && !g_InOvertime) schedule_time_limit_half()'

# The SQL accumulator stores only new deltas. Repeating a persist is a no-op,
# while a reconnect under the same SteamID adds a fresh session to the row.
db_kills=0 db_deaths=0 db_headshots=0
persisted_kills=0 persisted_deaths=0 persisted_headshots=0
session_kills=7 session_deaths=2 session_headshots=1
persist_delta() {
	db_kills=$((db_kills + session_kills - persisted_kills))
	db_deaths=$((db_deaths + session_deaths - persisted_deaths))
	db_headshots=$((db_headshots + session_headshots - persisted_headshots))
	persisted_kills=$session_kills
	persisted_deaths=$session_deaths
	persisted_headshots=$session_headshots
}
persist_delta
persist_delta
test "$db_kills" -eq 7 && test "$db_deaths" -eq 2 && test "$db_headshots" -eq 1
persisted_kills=0; persisted_deaths=0; persisted_headshots=0
session_kills=3; session_deaths=4; session_headshots=0
persist_delta
test "$db_kills" -eq 10 && test "$db_deaths" -eq 6 && test "$db_headshots" -eq 1
require_string "$SQL" 'PRIMARY KEY (match_uid,map_number,auth_id)'
require_string "$SQL" 'ON DUPLICATE KEY UPDATE'
require_string "$SQL" 'kills=kills+VALUES(kills)'
require_string "$SQL" 'equal(columns, "match_uid,map_number,auth_id")'
require_string "$SQL" 'g_PlayerPersistedKills[id] = g_PlayerKills[id]'
test "$(hash_file "$V020_SCHEMA")" = '68a5ea318fa75a8031386d62725648fe871d5cee9fc24ac90d5ae2feefb3006e'
require_string "$V020_SCHEMA" 'PRIMARY KEY (match_uid, auth_id)'
if grep -Fq 'map_number' "$V020_SCHEMA"; then
	printf 'The public v0.2.0 regression fixture must remain pre-map-scoping.\n' >&2
	exit 1
fi
require_string "$MIGRATION" 'ADD COLUMN map_number INTEGER NOT NULL DEFAULT 1 AFTER match_uid;'
require_string "$MIGRATION" 'ADD PRIMARY KEY (match_uid, map_number, auth_id);'
if grep -Fq 'REPLACE INTO kgb_cw_players' "$SQL"; then
	printf 'Player persistence must not replace accumulated map rows.\n' >&2
	exit 1
fi

# Persistent PUG progression must use the validated server mapcycle and a
# cross-changelevel resume marker, not just swap one configured pair forever.
require_string "$CORE" 'get_cvar_string("mapcyclefile", filename, charsmax(filename))'
require_string "$CORE" 'stock bool:next_mapcycle_pair('
require_string "$CORE" 'set_localinfo(LI_PUG_RESUME, "1")'
require_string "$CORE" 'server_cmd("changelevel %s", nextMap)'
if grep -Fq 'alternate_configured_pug_maps()' "$CORE"; then
	printf 'Found obsolete two-map alternation instead of persistent mapcycle advancement.\n' >&2
	exit 1
fi

# Explicit legacy record overrides are restored on every terminal lifecycle.
require_string "$CORE" 'stock restore_legacy_record_mode()'
require_string "$CORE" 'audit_event("legacy_record_mode_restored")'
require_string "$CORE" 'restore_legacy_record_mode(); clear_crossmap_state(); discard_series_manifest()'

"$ROOT_DIR/scripts/test-filesystem-semantics.sh"
printf 'Runtime state-model and source regression checks passed.\n'
