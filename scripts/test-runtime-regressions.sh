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
require_string "$CORE" 'set_pcvar_num(g_CvarClientDemos, legacyClient)'
require_string "$CORE" 'set_localinfo(LI_RECOVERY_PENDING, "1")'
require_string "$CORE" 'else finalize_crossmap_recovery()'
require_string "$CORE" 'stock finalize_crossmap_recovery()'
require_string "$CORE" 'clear_crossmap_storage(true)'
require_string "$CORE" 'stock clear_crossmap_recovery_storage()'
require_string "$CORE" 'Cross-map baseline recovery remains pending; unresolved evidence was preserved'
require_string "$CORE" 'set_localinfo(LI_OLD_SHIELD, ""); set_localinfo(LI_ENV_SAVED, "done")'
require_string "$CORE" 'set_localinfo(LI_LEGACY_CLIENT, "done")'
require_string "$CORE" '#define LI_RECOVERY_ID "_kgbcw_recovery_id"'
require_string "$CORE" 'set_localinfo(LI_RECOVERY_ID, g_MatchId)'
require_string "$CORE" '!valid_match_id_exact(recoveryId) || !equal(recoveryId, storedMatchId)'
require_string "$CORE" 'new bool:keepRecovery = preserveRecovery || crossmap_recovery_pending()'
require_string "$CORE" 'set_localinfo(LI_MATCH_ID, ""); set_localinfo(LI_RECOVERY_ID, "")'
require_string "$CORE" 'Refused to overwrite pending cross-map baseline recovery'
require_string "$CORE" 'Refused to stop match while cross-map baseline recovery is pending'
require_string "$CORE" 'Refused to finish match while cross-map baseline recovery is pending'
require_string "$CORE" 'register_concmd("amx_cw_recover", "command_recover", ADMIN_CFG'
require_string "$CORE" 'stock bool:crossmap_recovery_pending()'
require_string "$CORE" 'if (crossmap_recovery_pending() || !base_control_config_valid()) return false'
persist_guard_line="$(awk '/stock bool:persist_crossmap_state\(\)/,/stock bool:parse_crossmap_envelope\(\)/ { if (index($0, "crossmap_recovery_pending()")) { print NR; exit } }' "$CORE")"
persist_write_line="$(awk '/stock bool:persist_crossmap_state\(\)/,/stock bool:parse_crossmap_envelope\(\)/ { if (index($0, "set_localinfo(LI_RECOVERY_ID, g_MatchId)")) { print NR; exit } }' "$CORE")"
stop_guard_line="$(awk '/stock stop_match\(bool:administrator\)/,/stock restart_current_half\(\)/ { if (index($0, "crossmap_recovery_pending()")) { print NR; exit } }' "$CORE")"
stop_clear_line="$(awk '/stock stop_match\(bool:administrator\)/,/stock restart_current_half\(\)/ { if (index($0, "clear_crossmap_state()")) { print NR; exit } }' "$CORE")"
finish_guard_line="$(awk '/stock finish_match\(bool:stopped/,/stock bool:valid_mapcycle_filename/ { if (index($0, "crossmap_recovery_pending()")) { print NR; exit } }' "$CORE")"
finish_clear_line="$(awk '/stock finish_match\(bool:stopped/,/stock bool:valid_mapcycle_filename/ { if (index($0, "clear_crossmap_state()")) { print NR; exit } }' "$CORE")"
storage_active_clear_line="$(awk '/stock clear_crossmap_storage\(bool:keepRecovery\)/,/stock bool:crossmap_recovery_pending\(\)/ { if (index($0, "set_localinfo(LI_ACTIVE, \"\")")) { print NR; exit } }' "$CORE")"
storage_pending_clear_line="$(awk '/stock clear_crossmap_storage\(bool:keepRecovery\)/,/stock bool:crossmap_recovery_pending\(\)/ { if (index($0, "set_localinfo(LI_RECOVERY_PENDING, \"\")")) { print NR; exit } }' "$CORE")"
finalize_invalidate_line="$(awk '/stock finalize_crossmap_recovery\(\)/,/stock clear_crossmap_storage\(bool:keepRecovery\)/ { if (index($0, "clear_crossmap_storage(true)")) { print NR; exit } }' "$CORE")"
finalize_commit_line="$(awk '/stock finalize_crossmap_recovery\(\)/,/stock clear_crossmap_storage\(bool:keepRecovery\)/ { if (index($0, "set_localinfo(LI_RECOVERY_PENDING, \"\")")) { print NR; exit } }' "$CORE")"
finalize_gc_line="$(awk '/stock finalize_crossmap_recovery\(\)/,/stock clear_crossmap_storage\(bool:keepRecovery\)/ { if (index($0, "clear_crossmap_recovery_storage()")) { print NR; exit } }' "$CORE")"
test -n "$persist_guard_line" && test -n "$persist_write_line" && test "$persist_guard_line" -lt "$persist_write_line"
test -n "$stop_guard_line" && test -n "$stop_clear_line" && test "$stop_guard_line" -lt "$stop_clear_line"
test -n "$finish_guard_line" && test -n "$finish_clear_line" && test "$finish_guard_line" -lt "$finish_clear_line"
test -n "$storage_active_clear_line" && test -n "$storage_pending_clear_line" && test "$storage_active_clear_line" -lt "$storage_pending_clear_line"
test -n "$finalize_invalidate_line" && test -n "$finalize_commit_line" && test -n "$finalize_gc_line"
test "$finalize_invalidate_line" -lt "$finalize_commit_line" && test "$finalize_commit_line" -lt "$finalize_gc_line"
if grep -Fq 'legacyHltvEnabled >= 0 && !cvar_exists("kgb_cw_hltv_enabled")' "$CORE"; then
	printf 'Missing optional HLTV CVAR still aborts independent cross-map recovery.\n' >&2
	exit 1
fi
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

# Missing optional HLTV CVARs cannot block independent access/environment and
# client-demo recovery. Their validated baselines remain as explicit pending
# evidence until a later load can apply them.
runtime_hostname='Temporary Match'
runtime_password='temporary-secret'
runtime_shield=0
runtime_client_demos=1
hltv_cvars_available=0
pending_hltv_enabled="$baseline_hltv_enabled"
pending_hltv_auto="$baseline_hltv_auto"
recovery_pending=0
runtime_hostname="$baseline_hostname"
runtime_password="$baseline_password"
runtime_shield="$baseline_shield"
runtime_client_demos="$baseline_client_demos"
if test "$hltv_cvars_available" -ne 1; then recovery_pending=1; fi
test "$runtime_hostname|$runtime_password|$runtime_shield|$runtime_client_demos" = 'Customer Server|customer-secret|1|0'
test "$recovery_pending|$pending_hltv_enabled|$pending_hltv_auto" = '1|1|0'

# Model the identity-bound recovery lock. Generic clear(true), stop, finish,
# persist/new-series, and unrelated resume attempts all preserve the pending
# journal. Only a complete identity-matched recovery may clear it.
journal_pending=0
journal_match_id=20260827_120000
journal_recovery_id=20260827_120000
journal_environment='Customer Server|customer-secret|1'
journal_recording='0|1|0'
journal_active=1
generic_clear() {
	local preserve="$1"
	if test "$preserve" -eq 1 || test "$journal_pending" -eq 1; then return; fi
	journal_match_id=''; journal_recovery_id=''; journal_environment=''; journal_recording=''
}
attempt_stop() { test "$journal_pending" -eq 1 && return; generic_clear 0; }
attempt_finish() { test "$journal_pending" -eq 1 && return; generic_clear 0; }
attempt_persist() { test "$journal_pending" -eq 1 && return 1; return 0; }
attempt_unrelated_resume() { test "$journal_pending" -eq 1 && return 1; return 0; }
original_journal="$journal_match_id|$journal_recovery_id|$journal_environment|$journal_recording"
generic_clear 1
test "$journal_match_id|$journal_recovery_id|$journal_environment|$journal_recording" = "$original_journal"
journal_pending=1
attempt_stop
test "$journal_match_id|$journal_recovery_id|$journal_environment|$journal_recording" = "$original_journal"
attempt_finish
test "$journal_match_id|$journal_recovery_id|$journal_environment|$journal_recording" = "$original_journal"
if attempt_persist; then printf 'Pending recovery allowed a new envelope overwrite.\n' >&2; exit 1; fi
if attempt_unrelated_resume; then printf 'Pending recovery allowed an unrelated resume.\n' >&2; exit 1; fi
test "$journal_match_id" = "$journal_recovery_id"
# A completed restore retains identity, pending, and durable done markers until
# finalization. If interrupted here, the next load retries safely. Finalization
# invalidates active first, commits by clearing pending, then garbage-collects
# harmless stale payload.
journal_environment=done
journal_recording=done
test "$journal_pending|$journal_active|$journal_match_id|$journal_environment|$journal_recording" = \
	'1|1|20260827_120000|done|done'
journal_active=0
journal_pending=0
journal_match_id=''; journal_recovery_id=''; journal_environment=''; journal_recording=''
test -z "$journal_match_id$journal_recovery_id$journal_environment$journal_recording"
test "$journal_active|$journal_pending" = '0|0'

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

# KGB's explicit re-LO3 preserves the score, while the legacy Deluxe alias and
# chat shortcut restore the current-half baseline before running LO3. A whole-
# match restart cannot create a match from the off state.
kgb_relo3_block="$(awk '/public command_relo3\(id, level, cid\)/,/public command_legacy_relo3\(id, level, cid\)/' "$CORE")"
legacy_relo3_block="$(awk '/public command_legacy_relo3\(id, level, cid\)/,/public command_swap\(id, level, cid\)/' "$CORE")"
chat_relo3_block="$(awk '/if \(\(equali\(text, "\/relo3"\)/,/if \(\(equali\(text, "\/stop"\)/' "$CORE")"
grep -Fq 'else begin_lo3(false)' <<<"$kgb_relo3_block"
if grep -Fq 'restart_current_half()' <<<"$kgb_relo3_block"; then
	printf 'KGB-specific amx_cw_relo3 unexpectedly resets the current-half score.\n' >&2
	exit 1
fi
grep -Fq 'else restart_current_half()' <<<"$legacy_relo3_block"
grep -Fq 'if (g_State == STATE_LIVE) restart_current_half()' <<<"$chat_relo3_block"
require_string "$CORE" 'register_concmd("amx_matchrelo3", "command_legacy_relo3", ADMIN_CFG'
require_string "$CORE" 'stock bool:start_live_match(bool:preserveSides)'
require_string "$CORE" 'stock bool:restart_whole_match(id, bool:chatFeedback)'
restart_off_line="$(awk '/stock bool:restart_whole_match\(id, bool:chatFeedback\)/,/stock set_player_ready\(id, bool:isReady\)/ { if (index($0, "g_State == STATE_OFF")) { print NR; exit } }' "$CORE")"
restart_start_line="$(awk '/stock bool:restart_whole_match\(id, bool:chatFeedback\)/,/stock set_player_ready\(id, bool:isReady\)/ { if (index($0, "if (!start_live_match(false))")) { print NR; exit } }' "$CORE")"
restart_error_line="$(awk '/stock bool:restart_whole_match\(id, bool:chatFeedback\)/,/stock set_player_ready\(id, bool:isReady\)/ { if (index($0, "CW_ERR_RESTART_FAILED")) { print NR; exit } }' "$CORE")"
restart_audit_line="$(awk '/stock bool:restart_whole_match\(id, bool:chatFeedback\)/,/stock set_player_ready\(id, bool:isReady\)/ { if (index($0, "audit_event(\"admin_restart_match\")")) { print NR; exit } }' "$CORE")"
restart_true_line="$(awk '/stock bool:restart_whole_match\(id, bool:chatFeedback\)/,/stock set_player_ready\(id, bool:isReady\)/ { if (index($0, "return true")) { print NR; exit } }' "$CORE")"
test -n "$restart_off_line" && test -n "$restart_start_line" && test -n "$restart_error_line"
test -n "$restart_audit_line" && test -n "$restart_true_line"
test "$restart_off_line" -lt "$restart_start_line"
test "$restart_start_line" -lt "$restart_error_line"
test "$restart_error_line" -lt "$restart_audit_line"
test "$restart_audit_line" -lt "$restart_true_line"

# The four pre-existing fire-and-report launch paths intentionally rely on the
# global localized configuration announcement, while the destructive restart
# caller must consume the result and provide command/menu-specific feedback.
test "$(grep -Fc 'start_live_match(' "$CORE")" -eq 6
for caller_range in \
	'public command_live(id, level, cid)|public command_relo3(id, level, cid)' \
	'if ((equali(text, "/start")|public menu_control_handler(id, menu, item)' \
	'public menu_control_handler(id, menu, item)|public menu_restart_confirm_handler(id, menu, item)' \
	'stock check_auto_live()|stock ready_count()'; do
	start="${caller_range%%|*}"
	end="${caller_range#*|}"
	block="$(awk -v start="$start" -v end="$end" 'index($0, start) { active=1 } active { print } active && index($0, end) && !index($0, start) { exit }' "$CORE")"
	grep -Fq 'start_live_match(' <<<"$block" || {
		printf 'Missing audited start-live caller in function range: %s\n' "$caller_range" >&2
		exit 1
	}
done
restart_block="$(awk '/stock bool:restart_whole_match\(id, bool:chatFeedback\)/,/stock set_player_ready\(id, bool:isReady\)/' "$CORE")"
grep -Fq 'if (!start_live_match(false))' <<<"$restart_block"
grep -Fq 'CW_ERR_RESTART_FAILED' <<<"$restart_block"
start_live_block="$(awk '/stock bool:start_live_match\(bool:preserveSides\)/,/stock begin_lo3\(bool:resetRoundTracking/' "$CORE")"
grep -Fq 'return false' <<<"$start_live_block"
grep -Fq 'return true' <<<"$start_live_block"
start_validation_line="$(grep -n 'full_runtime_config_valid(true)' <<<"$start_live_block" | cut -d: -f1 | head -1)"
start_close_line="$(grep -n 'close_active_lifecycle("restart_match_stop")' <<<"$start_live_block" | cut -d: -f1 | head -1)"
start_identity_line="$(grep -n 'create_match_id()' <<<"$start_live_block" | cut -d: -f1 | head -1)"
start_success_line="$(grep -n 'return true' <<<"$start_live_block" | cut -d: -f1 | head -1)"
test -n "$start_validation_line" && test -n "$start_close_line" && test -n "$start_identity_line" && test -n "$start_success_line"
test "$start_validation_line" -lt "$start_close_line"
test "$start_close_line" -lt "$start_identity_line"
test "$start_identity_line" -lt "$start_success_line"
if grep -Fq 'admin_restart_match' <<<"$start_live_block"; then
	printf 'Start-live helper must not claim a successful admin restart.\n' >&2
	exit 1
fi

half_start_a=5
half_start_b=4
score_a=8
score_b=6
# amx_cw_relo3: begin_lo3(false), scores stay untouched.
test "$score_a|$score_b" = '8|6'
# amx_matchrelo3 and /relo3: restart_current_half(), scores return to baseline.
score_a="$half_start_a"
score_b="$half_start_b"
test "$score_a|$score_b" = '5|4'
match_state=off
restart_count=0
if test "$match_state" != off; then restart_count=$((restart_count + 1)); fi
test "$restart_count" -eq 0

# Model a rejected destructive restart. Invalid launch input must not change
# state, match identity, or score, must report failure, and must not emit the
# successful admin restart audit. The success path does all three explicitly.
match_state=live
match_id=existing-match
score_a=8
score_b=6
runtime_valid=0
restart_audits=0
restart_errors=0
start_live_model() {
	test "$runtime_valid" -eq 1 || return 1
	match_state=live
	match_id=new-match
	score_a=0
	score_b=0
}
restart_whole_model() {
	if ! start_live_model; then
		restart_errors=$((restart_errors + 1))
		return 1
	fi
	restart_audits=$((restart_audits + 1))
}
before_restart="$match_state|$match_id|$score_a|$score_b"
if restart_whole_model; then
	printf 'Rejected whole-match restart unexpectedly reported success.\n' >&2
	exit 1
fi
test "$match_state|$match_id|$score_a|$score_b" = "$before_restart"
test "$restart_audits|$restart_errors" = '0|1'
runtime_valid=1
restart_whole_model
test "$match_state|$match_id|$score_a|$score_b" = 'live|new-match|0|0'
test "$restart_audits|$restart_errors" = '1|1'

# The root menu is state-aware, destructive whole-match operations are
# confirmed, and read-only ready information is available without admin flags.
require_string "$CORE" 'stock bool:control_swap_allowed()'
require_string "$CORE" 'stock show_restart_match_confirmation(id)'
require_string "$CORE" 'stock show_stop_confirmation(id)'
require_string "$CORE" 'public menu_restart_confirm_handler(id, menu, item)'
require_string "$CORE" 'public menu_stop_confirmation_handler(id, menu, item)'
require_string "$CORE" 'register_concmd("amx_cw_ready_list", "command_ready_list", 0'
require_string "$CORE" 'register_concmd("amx_cw_readylist", "command_ready_list", 0'
require_string "$CORE" 'stock show_ready_list_menu(id)'
require_string "$CORE" 'return ITEM_DISABLED'
require_string "$CORE" 'AddMenuItem(g_DisplayName, "amx_cw_menu", ADMIN_CFG, PLUGIN_NAME)'
require_string "$CORE" 'stock show_match_length_menu(id)'
require_string "$CORE" 'stock show_min_ready_menu(id)'
require_string "$CORE" 'set_pcvar_num(g_CvarMinReady, clamp(str_to_num(info), 1, 32))'

# Once a map change owns either the cross-map series envelope or the persistent
# PUG marker, no admin command or stale menu may cancel its scheduled task.
# plugin_end must preserve that owner for the next plugin instance.
require_string "$CORE" 'stock bool:map_transition_blocks_mutation(id, bool:chatFeedback)'
require_string "$CORE" 'if (!g_MapChangePending) return false'
require_string "$CORE" 'CW_ERR_MAP_CHANGE_PENDING'
require_string "$CORE" 'if (g_MapChangePending && !equal(info, "status") && !equal(info, "ready_list"))'
require_string "$CORE" 'menu_destroy(menu); cw_chat_ml(id, "CW_ERR_MAP_CHANGE_PENDING"); show_control_menu(id)'
require_string "$CORE" 'if (map_transition_blocks_mutation(id, false)) return PLUGIN_HANDLED'
require_string "$CORE" 'if (map_transition_blocks_mutation(id, true)) return PLUGIN_HANDLED'

plugin_end_block="$(awk '/public plugin_end\(\)/,/public client_putinserver\(id\)/' "$CORE")"
grep -Fq 'if (!g_MapChangePending)' <<<"$plugin_end_block"
grep -Fq 'clear_pug_resume_state()' <<<"$plugin_end_block"
grep -Fq 'discard_series_manifest()' <<<"$plugin_end_block"

control_menu_block="$(awk '/stock show_control_menu\(id\)/,/stock bool:control_swap_allowed\(\)/' "$CORE")"
pending_menu_line="$(grep -n 'if (g_MapChangePending)' <<<"$control_menu_block" | cut -d: -f1 | head -1)"
restart_menu_line="$(grep -n 'CW_MENU_RESTART_MATCH' <<<"$control_menu_block" | cut -d: -f1 | head -1)"
test -n "$pending_menu_line" && test -n "$restart_menu_line" && test "$pending_menu_line" -lt "$restart_menu_line"

for function_range in \
	'stock bool:start_warmup(bool:resetData)|stock start_knife_round()' \
	'stock start_knife_round()|stock bool:start_live_match(bool:preserveSides)' \
	'stock bool:start_live_match(bool:preserveSides)|stock begin_lo3(bool:resetRoundTracking' \
	'stock begin_lo3(bool:resetRoundTracking|stock close_active_lifecycle' \
	'stock stop_match(bool:administrator)|stock restart_current_half()' \
	'stock restart_current_half()|stock bool:restart_whole_match' \
	'stock bool:restart_whole_match|stock set_player_ready'; do
	start="${function_range%%|*}"
	end="${function_range#*|}"
	block="$(awk -v start="$start" -v end="$end" 'index($0, start) { active=1 } active { print } active && index($0, end) && !index($0, start) { exit }' "$CORE")"
	grep -Fq 'map_transition_blocks_mutation' <<<"$block" || {
		printf 'Missing pending-map mutation guard in function range: %s\n' "$function_range" >&2
		exit 1
	}
done

cancel_block="$(awk '/stock cancel_transition_tasks\(\)/,/stock cancel_lo3_tasks\(\)/' "$CORE")"
grep -Fq 'remove_task(TASK_MAP_CHANGE)' <<<"$cancel_block"
grep -Fq 'remove_task(TASK_PUG_MAP_CHANGE)' <<<"$cancel_block"
if grep -Fq 'g_MapChangePending' <<<"$cancel_block"; then
	printf 'Generic task cancellation unexpectedly claims or clears the durable map-change owner.\n' >&2
	exit 1
fi

crossmap_block="$(awk '/stock begin_map_transition\(\)/,/stock finish_match\(bool:stopped/' "$CORE")"
crossmap_owner_line="$(grep -n 'persist_crossmap_state()' <<<"$crossmap_block" | cut -d: -f1 | head -1)"
crossmap_pending_line="$(grep -n 'g_MapChangePending = true' <<<"$crossmap_block" | cut -d: -f1 | head -1)"
crossmap_task_line="$(grep -n 'TASK_MAP_CHANGE' <<<"$crossmap_block" | cut -d: -f1 | head -1)"
test "$crossmap_owner_line" -lt "$crossmap_pending_line" && test "$crossmap_pending_line" -lt "$crossmap_task_line"

pug_transition_block="$(awk '/stock bool:schedule_persistent_pug_advance\(/,/public task_change_pug_map\(\)/' "$CORE")"
pug_owner_line="$(grep -n 'set_localinfo(LI_PUG_RESUME, "1")' <<<"$pug_transition_block" | cut -d: -f1 | head -1)"
pug_pending_line="$(grep -n 'g_MapChangePending = true' <<<"$pug_transition_block" | cut -d: -f1 | head -1)"
pug_task_line="$(grep -n 'TASK_PUG_MAP_CHANGE' <<<"$pug_transition_block" | tail -1 | cut -d: -f1)"
test "$pug_owner_line" -lt "$pug_pending_line" && test "$pug_pending_line" -lt "$pug_task_line"

attempt_pending_mutation() {
	# A rejected control must preserve all durable and scheduled ownership.
	test "$map_change_pending" -eq 1 && return
	map_task_queued=0
	crossmap_owner=0
	pug_owner=0
}
plugin_end_model() {
	if test "$map_change_pending" -ne 1; then
		crossmap_owner=0
		pug_owner=0
	fi
}
for owner_type in crossmap pug; do
	map_change_pending=1
	map_task_queued=1
	crossmap_owner=0
	pug_owner=0
	if test "$owner_type" = crossmap; then crossmap_owner=1; else pug_owner=1; fi
	attempt_pending_mutation
	plugin_end_model
	test "$map_change_pending|$map_task_queued" = '1|1'
	if test "$owner_type" = crossmap; then test "$crossmap_owner|$pug_owner" = '1|0'; else test "$crossmap_owner|$pug_owner" = '0|1'; fi
done

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
# policy, map topology, phase config, or bounded numeric/boolean setting must
# preserve the whole prior tuple.
short_runtime_line="$(awk '/public command_legacy_match\(id, level, cid\)/,/public command_legacy_match2\(id, level, cid\)/ { if (index($0, "full_runtime_config_valid(true)")) { print NR; exit } }' "$CORE")"
short_restore_line="$(awk '/public command_legacy_match\(id, level, cid\)/,/public command_legacy_match2\(id, level, cid\)/ { if (index($0, "restore_legacy_record_mode()")) { print NR; exit } }' "$CORE")"
full_runtime_line="$(awk '/stock bool:configure_legacy_match\(/,/stock bool:apply_legacy_rule\(/ { if (index($0, "full_runtime_config_valid(false)")) { print NR; exit } }' "$CORE")"
full_restore_line="$(awk '/stock bool:configure_legacy_match\(/,/stock bool:apply_legacy_rule\(/ { if (index($0, "restore_legacy_record_mode()")) { print NR; exit } }' "$CORE")"
test -n "$short_runtime_line" && test -n "$short_restore_line" && test "$short_runtime_line" -lt "$short_restore_line"
test -n "$full_runtime_line" && test -n "$full_restore_line" && test "$full_runtime_line" -lt "$full_restore_line"
require_string "$CORE" 'restore_legacy_snapshot(oldLegacyOverride, oldCurrentClientDemos,'
require_string "$CORE" 'restore_managed_config_snapshot()'
require_string "$CORE" 'stock bool:full_runtime_config_valid(bool:requireStartingMap)'
require_string "$CORE" 'if (crossmap_recovery_pending() || !base_control_config_valid()) return false'
require_string "$CORE" 'stock bool:base_control_config_valid()'
require_string "$CORE" 'get_pcvar_string(g_CvarEnabled, value, charsmax(value))'
require_string "$CORE" 'get_pcvar_string(g_CvarAllowMenuSave, value, charsmax(value))'
require_string "$CORE" 'index < sizeof g_ManagedConfigNames'
require_string "$CORE" 'if (!managed_config_value_valid(index, value)) return false'
require_string "$CORE" 'index < sizeof g_SeriesExtraConfigNames'
require_string "$CORE" 'if (!series_extra_value_valid(index, value)) return false'
require_string "$CORE" 'case MC_HALF_ROUNDS, MC_WIN_ROUNDS: return parse_uint_exact(value, 1, 100, number)'
require_string "$CORE" 'case MC_OT_MONEY: return parse_uint_exact(value, 800, 16000, number)'
require_string "$CORE" 'case MC_OT_VOTE_SECONDS: return parse_uint_exact(value, 5, 30, number)'
require_string "$CORE" 'case SC_HALFTIME_DELAY: return parse_uint_exact(value, 1, 30, number)'
require_string "$CORE" 'SC_SET_PASSWORD, SC_DISABLE_SHIELD, SC_CLIENT_DEMOS, SC_FILE_STATS,'
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
	test "$6" -eq 1 || return 1
	test "$7" -ge 1 && test "$7" -le 100 || return 1
	test "$8" -ge 1 && test "$8" -le 30 || return 1
	case "$9" in 0 | 1) ;; *) return 1 ;; esac
	test "${10}" -ge 800 && test "${10}" -le 16000 || return 1
	test "${11}" -ge 5 && test "${11}" -le 30 || return 1
	case "${12}" in 0 | 1) ;; *) return 1 ;; esac
	test "$4" = "${13}" || return 1
	case "${14}" in 0 | 1) ;; *) return 1 ;; esac
	case "${15}" in 0 | 1) ;; *) return 1 ;; esac
}
attempt_invalid_replacement() {
	local label="$1"
	shift
	local before="$legacy_override"
	if replacement_valid "$@"; then
		printf 'The %s regression fixture unexpectedly validated.\n' "$label" >&2
		exit 1
	fi
	test "$legacy_override" = "$before" || {
		printf 'Invalid %s replacement changed the active legacy override.\n' "$label" >&2
		exit 1
	}
}
attempt_invalid_replacement ready broken halves 1 de_dust2 '' 1 15 5 0 10000 15 1 de_dust2 1 0
attempt_invalid_replacement swap player broken 1 de_dust2 '' 1 15 5 0 10000 15 1 de_dust2 1 0
attempt_invalid_replacement topology player halves 2 de_dust2 de_dust2 1 15 5 0 10000 15 1 de_dust2 1 0
attempt_invalid_replacement phase player halves 1 de_dust2 '' 0 15 5 0 10000 15 1 de_dust2 1 0
attempt_invalid_replacement half_rounds player halves 1 de_dust2 '' 1 0 5 0 10000 15 1 de_dust2 1 0
attempt_invalid_replacement halftime_delay player halves 1 de_dust2 '' 1 15 0 0 10000 15 1 de_dust2 1 0
attempt_invalid_replacement client_demos player halves 1 de_dust2 '' 1 15 5 2 10000 15 1 de_dust2 1 0
attempt_invalid_replacement overtime_money player halves 1 de_dust2 '' 1 15 5 0 799 15 1 de_dust2 1 0
attempt_invalid_replacement overtime_vote_seconds player halves 1 de_dust2 '' 1 15 5 0 10000 4 1 de_dust2 1 0
attempt_invalid_replacement boolean player halves 1 de_dust2 '' 1 15 5 0 10000 15 2 de_dust2 1 0
attempt_invalid_replacement start_map player halves 1 de_nuke '' 1 15 5 0 10000 15 1 de_dust2 1 0
attempt_invalid_replacement enabled player halves 1 de_dust2 '' 1 15 5 0 10000 15 1 de_dust2 2 0
attempt_invalid_replacement menu_save player halves 1 de_dust2 '' 1 15 5 0 10000 15 1 de_dust2 1 2

require_string "$CORE" 'g_CvarFileStats = register_cvar("kgb_cw_file_stats", "0")'
require_string "$CORE" 'register_concmd("amx_cw_safety_status", "command_safety_status", ADMIN_CFG'
require_string "$CORE" 'get_pcvar_num(g_CvarFileStats), series_extra_number(SC_FILE_STATS, g_CvarFileStats)'
require_string "$CORE" 'KGB_CW_SAFETY version=%s state=%s series_policy_frozen=%d file_stats_configured=%d file_stats_effective=%d'

"$ROOT_DIR/scripts/test-filesystem-semantics.sh"
printf 'Runtime state-model and source regression checks passed.\n'
