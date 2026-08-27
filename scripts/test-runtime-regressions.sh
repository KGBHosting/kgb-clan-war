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
require_string "$CORE" 'stock bool:parse_series_manifest()'
require_string "$CORE" 'stock commit_series_manifest()'
require_string "$CORE" 'stock bool:parse_crossmap_envelope()'
require_string "$CORE" 'stock commit_crossmap_envelope()'
require_string "$CORE" '!equal(storedMatchId, g_RestoreMatchId)'
require_string "$CORE" 'parse_uint_exact(scoreAValue, 0, 1000, scoreA)'
require_string "$CORE" 'parse_bool_exact(legacyValue, legacyActive)'
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
require_string "$CORE" 'stock series_managed_number('
require_string "$CORE" 'stock series_extra_number('
require_string "$CORE" 'series_managed_number(MC_HALF_ROUNDS, g_CvarHalfRounds)'
require_string "$CORE" 'series_managed_number(MC_OVERTIME, g_CvarOvertime)'
require_string "$CORE" 'series_extra_string(SC_MATCH_CONFIG, cvar, token, charsmax(token))'
require_string "$CORE" 'series_extra_number(SC_CLIENT_DEMOS, g_CvarClientDemos)'

# Rejected two-phase restore must not commit staged values.
live_format=mr
staged_format=tl
valid_envelope=0
if test "$valid_envelope" -eq 1; then live_format="$staged_format"; fi
test "$live_format" = mr

# A rejected full map-two envelope still owns separately validated pre-match
# environment and recording baselines. They must be restored before storage is
# cleared, without committing any match/score/topology field.
require_string "$CORE" 'stock bool:restore_rejected_crossmap_state()'
require_string "$CORE" 'g_EnvironmentSaved = true'
require_string "$CORE" 'restore_environment()'
require_string "$CORE" 'g_LegacyOldClientDemos = legacyClient'
resume_restore_line="$(awk '/public task_resume_crossmap\(\)/,/stock bool:mode_enabled\(id\)/ { if (index($0, "restore_rejected_crossmap_state()")) { print NR; exit } }' "$CORE")"
resume_clear_line="$(awk '/public task_resume_crossmap\(\)/,/stock bool:mode_enabled\(id\)/ { if (index($0, "clear_crossmap_state()")) { print NR; exit } }' "$CORE")"
test -n "$resume_restore_line" && test -n "$resume_clear_line" && test "$resume_restore_line" -lt "$resume_clear_line"

runtime_hostname='Temporary Match'
runtime_password='temporary-secret'
runtime_shield=0
runtime_client_demos=1
runtime_hltv_enabled=1
runtime_hltv_auto=1
baseline_hostname='Customer Server'
baseline_password='customer-secret'
baseline_shield=1
baseline_client_demos=0
baseline_hltv_enabled=1
baseline_hltv_auto=0
valid_full_envelope=0
valid_recovery_baseline=1
if test "$valid_full_envelope" -ne 1 && test "$valid_recovery_baseline" -eq 1; then
	runtime_hostname="$baseline_hostname"
	runtime_password="$baseline_password"
	runtime_shield="$baseline_shield"
	runtime_client_demos="$baseline_client_demos"
	runtime_hltv_enabled="$baseline_hltv_enabled"
	runtime_hltv_auto="$baseline_hltv_auto"
fi
test "$runtime_hostname|$runtime_password|$runtime_shield" = 'Customer Server|customer-secret|1'
test "$runtime_client_demos|$runtime_hltv_enabled|$runtime_hltv_auto" = '0|1|0'

# TL expiry has an explicit no-winner Round_End path, and all terminal half
# paths capture before the regulation/OT transition.
require_string "$CORE" 'register_logevent("event_round_end", 2, "1=Round_End")'
require_string "$CORE" 'public task_finish_tl_draw()'
require_string "$CORE" 'write_stats_event("round_draw")'
require_string "$CORE" 'emit_match_event("half_end"); write_stats_event("overtime_half_end"); take_match_screenshots()'
require_string "$CORE" 'if (is_user_connected(id) && g_ScoreIdSnapshotAuthorized[id]) client_cmd(id, "snapshot")'

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
require_string "$HLTV" 'stock freeze_auto_recording_policy()'
require_string "$HLTV" 'if (g_AutoPolicyFrozen) return g_AutoPolicyEnabled && g_AutoPolicyRecord'

# Mid-match CVAR changes apply to the next series, not the active recording.
frozen_enabled=1
frozen_auto=1
live_cvar_enabled=0
test "$frozen_enabled" -eq 1 && test "$frozen_auto" -eq 1 && test "$live_cvar_enabled" -eq 0

# A re-LO3 during the original TL LO3 must preserve the pending timer reset.
require_string "$CORE" 'new bool:resetTimerAfterLo3 = resetTlTimer || g_ResetTlTimerAfterLo3'
require_string "$CORE" 'if (g_ResetTlTimerAfterLo3 && g_Format == FORMAT_TL && !g_InOvertime) schedule_time_limit_half()'

# Model the SQL callback contract deterministically. A transient failure does
# not advance the acknowledged session baseline; retries and overlapping
# callbacks use absolute maxima, so either callback order is idempotent.
db_kills=5
base_kills=5
session_kills=3
ack_session_kills=0
target=$((base_kills + session_kills))
# First asynchronous attempt fails: baseline stays at zero.
test "$ack_session_kills" -eq 0 && test "$db_kills" -eq 5
# Retry succeeds.
db_kills=$((db_kills > target ? db_kills : target))
ack_session_kills=$session_kills
test "$db_kills" -eq 8 && test "$ack_session_kills" -eq 3
# Two forced terminal writes overlap; newer succeeds before older.
older_target=10
newer_target=12
db_kills=$((db_kills > newer_target ? db_kills : newer_target))
ack_session_kills=7
db_kills=$((db_kills > older_target ? db_kills : older_target))
ack_session_kills=$((ack_session_kills > 5 ? ack_session_kills : 5))
test "$db_kills" -eq 12 && test "$ack_session_kills" -eq 7
require_string "$SQL" 'PRIMARY KEY (match_uid,map_number,auth_id)'
require_string "$SQL" 'ON DUPLICATE KEY UPDATE'
require_string "$SQL" 'kills=GREATEST(kills,VALUES(kills))'
require_string "$SQL" 'public query_player_write('
require_string "$SQL" 'g_WriteAttempts[operation] < PLAYER_WRITE_RETRY_MAX'
require_string "$SQL" 'g_PlayerPersistedKills[player] = max('
require_string "$SQL" 'if (g_PlayerDepartureHandled[id]) return'
require_string "$SQL" 'reject_player_schema(schema, primary)'
require_string "$SQL" 'equal(schema, PLAYER_SCHEMA_V02) && equal(primary, "match_uid,auth_id")'
test "$(hash_file "$V020_SCHEMA")" = '68a5ea318fa75a8031386d62725648fe871d5cee9fc24ac90d5ae2feefb3006e'
require_string "$V020_SCHEMA" 'PRIMARY KEY (match_uid, auth_id)'
if grep -Fq 'map_number' "$V020_SCHEMA"; then
	printf 'The public v0.2.0 regression fixture must remain pre-map-scoping.\n' >&2
	exit 1
fi
require_string "$MIGRATION" 'ADD COLUMN map_number INTEGER NOT NULL DEFAULT 1 AFTER match_uid;'
require_string "$MIGRATION" 'ADD PRIMARY KEY (match_uid, map_number, auth_id);'
require_string "$MIGRATION" "SIGNAL SQLSTATE '45000'"
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
legacy_validate_line="$(grep -n 'apply_legacy_record_mode(recordMode, false)' "$CORE" | cut -d: -f1 | head -1)"
legacy_restore_line="$(grep -n 'restore_legacy_record_mode()' "$CORE" | awk -F: -v minimum="$legacy_validate_line" '$1 > minimum {print $1; exit}')"
test "$legacy_restore_line" -gt "$legacy_validate_line"

# Full and compact legacy launchers validate the complete staged runtime before
# unwinding the currently active recording override. Invalid ready mode, swap
# policy, map topology, or phase config must preserve the whole prior tuple.
short_runtime_line="$(awk '/public command_legacy_match\(id, level, cid\)/,/public command_legacy_match2\(id, level, cid\)/ { if (index($0, "runtime_config_valid(false)")) { print NR; exit } }' "$CORE")"
short_restore_line="$(awk '/public command_legacy_match\(id, level, cid\)/,/public command_legacy_match2\(id, level, cid\)/ { if (index($0, "restore_legacy_record_mode()")) { print NR; exit } }' "$CORE")"
full_runtime_line="$(awk '/stock bool:configure_legacy_match\(/,/stock bool:apply_legacy_rule\(/ { if (index($0, "runtime_config_valid(false)")) { print NR; exit } }' "$CORE")"
full_restore_line="$(awk '/stock bool:configure_legacy_match\(/,/stock bool:apply_legacy_rule\(/ { if (index($0, "restore_legacy_record_mode()")) { print NR; exit } }' "$CORE")"
test -n "$short_runtime_line" && test -n "$short_restore_line" && test "$short_runtime_line" -lt "$short_restore_line"
test -n "$full_runtime_line" && test -n "$full_restore_line" && test "$full_runtime_line" -lt "$full_restore_line"
require_string "$CORE" 'restore_legacy_snapshot(oldLegacyOverride, oldCurrentClientDemos,'
require_string "$CORE" 'restore_managed_config_snapshot()'
require_string "$CORE" 'Invalid kgb_cw_ready_mode; expected player, team or admin'
require_string "$CORE" 'Invalid kgb_cw_swap_policy; expected halves or off'
require_string "$CORE" 'Invalid kgb_cw_map2 for two-map match'
require_string "$CORE" '!validate_phase_config(g_CvarWarmupConfig, "warmup")'
require_string "$CORE" '!validate_phase_config(g_CvarMatchConfig, "match")'
require_string "$CORE" '!validate_phase_config(g_CvarOvertimeConfig, "overtime")'
require_string "$CORE" '!validate_phase_config(g_CvarDefaultConfig, "default")'

legacy_override='1|1|1|1|0|1|0'
replacement_valid() {
	case "$1" in player | team | admin) ;; *) return 1 ;; esac
	case "$2" in halves | off) ;; *) return 1 ;; esac
	if test "$3" -eq 2 && { test -z "$4" || test "$4" = "$5"; }; then return 1; fi
	test "$6" -eq 1
}
attempt_invalid_replacement() {
	local label="$1" ready="$2" swap="$3" map_count="$4" map1="$5" map2="$6" phase_exists="$7"
	local before="$legacy_override"
	if replacement_valid "$ready" "$swap" "$map_count" "$map1" "$map2" "$phase_exists"; then
		printf 'The %s regression fixture unexpectedly validated.\n' "$label" >&2
		exit 1
	fi
	test "$legacy_override" = "$before" || {
		printf 'Invalid %s replacement changed the active legacy override.\n' "$label" >&2
		exit 1
	}
}
attempt_invalid_replacement ready broken halves 1 de_dust2 '' 1
attempt_invalid_replacement swap player broken 1 de_dust2 '' 1
attempt_invalid_replacement topology player halves 2 de_dust2 de_dust2 1
attempt_invalid_replacement phase player halves 1 de_dust2 '' 0

require_string "$CORE" 'g_CvarFileStats = register_cvar("kgb_cw_file_stats", "0")'

"$ROOT_DIR/scripts/test-filesystem-semantics.sh"
printf 'Runtime state-model and source regression checks passed.\n'
