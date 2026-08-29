/* SPDX-License-Identifier: GPL-3.0-or-later */

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <file>
#include <fun>

#define PLUGIN_NAME "KGB Clan War"
#define PLUGIN_VERSION "0.4.0"
#define PLUGIN_AUTHOR "KGB Hosting"

#define DEFAULT_DISPLAY_NAME "KGB Clan War"
#define DEFAULT_CHAT_PREFIX "[KGB CW]"

#define MAX_PLAYERS 32
#define MAX_TEAM_NAME 31
#define MAX_TEAM_TAG 15
#define MAX_TEAM_LABEL 51
#define MAX_MAP_TOKEN 31
#define MAX_CONFIG_TOKEN 31
#define MAX_MATCH_ID 31
#define MAX_DISPLAY_NAME 47
#define MAX_CHAT_PREFIX 23
#define MAX_BRANDED_MESSAGE 165
#define MAX_PRESET_TOKEN 31
#define MAX_CATALOG_LABEL 63
#define SERIES_MANIFEST_MAX 64
#define SERIES_MANIFEST_VALUE_MAX 127
#define SERIES_MANIFEST_VERSION "1"
#define MAX_MAPCYCLE_MAPS 128

#define TASK_LO3_1 73101
#define TASK_LO3_2 73102
#define TASK_LO3_3 73103
#define TASK_LO3_DONE 73104
#define TASK_HALFTIME 73105
#define TASK_WARMUP 73106
#define TASK_KNIFE_VOTE 73107
#define TASK_TIME_LIMIT 73108
#define TASK_MAP_CHANGE 73109
#define TASK_RESUME_MAP 73110
#define TASK_OVERTIME_VOTE 73111
#define TASK_STATUS_HUD 73112
#define TASK_SCOREID_SNAPSHOT 73113
#define TASK_PLAYOUT_VOTE 73114
#define TASK_PUG_MAP_CHANGE 73115
#define TASK_TL_ROUND_END 73116
#define TASK_KNIFE_EQUIP 73200

#define LI_ACTIVE "_kgbcw_active"
#define LI_MAP "_kgbcw_map"
#define LI_SCORE_A "_kgbcw_score_a"
#define LI_SCORE_B "_kgbcw_score_b"
#define LI_MATCH_ID "_kgbcw_match_id"
#define LI_OLD_HOST "_kgbcw_old_host"
#define LI_OLD_PASS "_kgbcw_old_pass"
#define LI_OLD_SHIELD "_kgbcw_old_shield"
#define LI_ENV_SAVED "_kgbcw_env_saved"
#define LI_TEAM_A_SIDE "_kgbcw_a_side"
#define LI_PUG_ACTIVE "_kgbcw_pug_active"
#define LI_PUG_STYLE "_kgbcw_pug_style"
#define LI_MANIFEST_ACTIVE "_kgbcw_manifest"
#define LI_MANIFEST_VERSION "_kgbcw_manifest_v"
#define LI_MANIFEST_COUNT "_kgbcw_manifest_n"
#define LI_MANIFEST_ID "_kgbcw_manifest_id"
#define LI_LEGACY_RECORD "_kgbcw_legacy_rec"
#define LI_LEGACY_CLIENT "_kgbcw_legacy_client"
#define LI_LEGACY_HLTV_ENABLED "_kgbcw_legacy_he"
#define LI_LEGACY_HLTV_AUTO "_kgbcw_legacy_ha"
#define LI_RECOVERY_PENDING "_kgbcw_recovery"
#define LI_RECOVERY_ID "_kgbcw_recovery_id"
#define LI_PUG_RESUME "_kgbcw_pug_resume"
#define LI_PUG_NEXT "_kgbcw_pug_next"
#define LI_PUG_FOLLOWING "_kgbcw_pug_follow"
#define LI_PUG_RESUME_STYLE "_kgbcw_pug_rstyle"

enum MatchState { STATE_OFF = 0, STATE_WARMUP, STATE_KNIFE, STATE_KNIFE_VOTE, STATE_LIVE, STATE_HALFTIME, STATE_HALF_READY, STATE_OVERTIME_VOTE, STATE_PLAYOUT_VOTE, STATE_FINISHED }
enum MatchFormat { FORMAT_MR = 0, FORMAT_TL, FORMAT_WL }
enum ReadyMode { READY_PLAYER = 0, READY_TEAM, READY_ADMIN }

new MatchState:g_State = STATE_OFF
new MatchFormat:g_Format = FORMAT_MR
new ReadyMode:g_ReadyMode = READY_PLAYER
new CsTeams:g_TeamASide = CS_TEAM_CT

new g_TeamAScore, g_TeamBScore, g_PreviousMapScoreA, g_PreviousMapScoreB
new g_HalfStartA, g_HalfStartB
new g_Half = 1, g_RoundsThisHalf, g_OvertimeCycle
new bool:g_InOvertime, bool:g_RoundResolved, bool:g_Lo3Running
new bool:g_Ready[MAX_PLAYERS + 1], bool:g_TeamReady[2]
new bool:g_DemoStarted[MAX_PLAYERS + 1]
new bool:g_ScoreIdSnapshotAuthorized[MAX_PLAYERS + 1]
new bool:g_EnvironmentSaved, bool:g_MapChangePending, bool:g_KnifeDecisionMade
new bool:g_ShieldRestricted
new bool:g_OvertimeVoted[MAX_PLAYERS + 1], bool:g_PugActive
new bool:g_PlayoutVoted[MAX_PLAYERS + 1]
new bool:g_CaptureHalfBaselineAfterLo3
new g_OvertimeVoteChoice[MAX_PLAYERS + 1]
new g_PlayoutVoteChoice[MAX_PLAYERS + 1]
new g_HalfKillsStart[MAX_PLAYERS + 1], g_HalfDeathsStart[MAX_PLAYERS + 1]
new g_OvertimeYesVotes, g_OvertimeNoVotes
new g_PlayoutYesVotes, g_PlayoutNoVotes
new bool:g_PlayoutDecisionMade, bool:g_TimeLimitExpired, bool:g_ResetTlTimerAfterLo3
new bool:g_SeriesManifestCaptured
new g_SeriesManifestValues[SERIES_MANIFEST_MAX][SERIES_MANIFEST_VALUE_MAX + 1]
new g_SeriesRestoreValues[SERIES_MANIFEST_MAX][SERIES_MANIFEST_VALUE_MAX + 1]
new g_RestoreMatchId[MAX_MATCH_ID + 1]
new g_RestoreOldHostname[128], g_RestoreOldPassword[64], g_RestoreOldShield[8]
new g_RestoreScoreA, g_RestoreScoreB, CsTeams:g_RestoreTeamASide
new bool:g_RestorePugActive, g_RestorePugStyle[16]
new bool:g_RestoreLegacyRecord
new g_RestoreLegacyClient, g_RestoreLegacyHltvEnabled, g_RestoreLegacyHltvAuto
new bool:g_LegacyRecordOverride
new g_LegacyOldClientDemos, g_LegacyOldHltvEnabled = -1, g_LegacyOldHltvAuto = -1
new g_KnifeVoteChoice[MAX_PLAYERS + 1]
new bool:g_MapMenuSecond[MAX_PLAYERS + 1]
new g_MapMenuFirst[MAX_PLAYERS + 1][MAX_MAP_TOKEN + 1]
new g_MapcycleMaps[MAX_MAPCYCLE_MAPS][MAX_MAP_TOKEN + 1]

new const g_MrLengthChoices[] = {3, 6, 9, 12, 15}
new const g_WlLengthChoices[] = {4, 8, 10, 13, 16}
new const g_TlLengthChoices[] = {5, 10, 15, 20, 30, 45}
new const g_MinReadyChoices[] = {1, 2, 4, 6, 8, 10, 12, 16, 24, 32}

new g_MapNumber = 1, g_MapCount = 1
new g_Map1[MAX_MAP_TOKEN + 1], g_Map2[MAX_MAP_TOKEN + 1]
new g_TeamAName[MAX_TEAM_NAME + 1] = "Team A"
new g_TeamBName[MAX_TEAM_NAME + 1] = "Team B"
new g_TeamATag[MAX_TEAM_TAG + 1], g_TeamBTag[MAX_TEAM_TAG + 1]
new g_MatchId[MAX_MATCH_ID + 1]
new g_DisplayName[MAX_DISPLAY_NAME + 1] = DEFAULT_DISPLAY_NAME
new g_ChatPrefix[MAX_CHAT_PREFIX + 1] = DEFAULT_CHAT_PREFIX
new g_OldHostname[128], g_OldPassword[64], g_OldShield[8]

new CsTeams:g_KnifeWinningSide
new g_KnifeStayVotes, g_KnifeSwapVotes
new bool:g_KnifeVoted[MAX_PLAYERS + 1]
new g_ForwardEvent

new g_CvarEnabled, g_CvarMinReady, g_CvarReadyMode, g_CvarAutoLive
new g_CvarDisplayName, g_CvarChatPrefix
new g_CvarFormat, g_CvarHalfRounds, g_CvarWinRounds, g_CvarTimeLimitMinutes, g_CvarPlayout, g_CvarPlayoutVoteDefault
new g_CvarTimeLimitFinishRound
new g_CvarOvertime, g_CvarOvertimeMaxCycles, g_CvarOvertimeHalfRounds, g_CvarOvertimeMoney
new g_CvarHudAnnouncements, g_CvarState
new g_CvarTeamAName, g_CvarTeamBName, g_CvarTeamATag, g_CvarTeamBTag
new g_CvarMap1, g_CvarMap2, g_CvarMapCount
new g_CvarWarmupConfig, g_CvarMatchConfig, g_CvarOvertimeConfig, g_CvarDefaultConfig
new g_CvarHalftimeDelay, g_CvarKnifeVote, g_CvarKnifeVoteSeconds, g_CvarPugMode
new g_CvarOvertimeVote, g_CvarOvertimeVoteSeconds, g_CvarOvertimeVoteDefault
new g_CvarPugStyle, g_CvarAllowMenuSave
new g_CvarSecondHalfReady, g_CvarSwapPolicy, g_CvarHudInterval
new g_CvarPugPersist, g_CvarScoreIdScreenshots
new g_CvarScreenshotOnStop
new g_CvarSetHostname, g_CvarHostname, g_CvarSetPassword, g_CvarPassword, g_CvarDisableShield
new g_CvarClientDemos, g_CvarScreenshots, g_CvarFileStats

enum ManagedConfigIndex
{
    MC_DISPLAY_NAME = 0, MC_CHAT_PREFIX, MC_FORMAT, MC_HALF_ROUNDS, MC_WIN_ROUNDS, MC_TIME_LIMIT,
    MC_PLAYOUT, MC_PLAYOUT_DEFAULT, MC_TL_FINISH_ROUND, MC_OVERTIME, MC_OT_MAX, MC_OT_VOTE,
    MC_OT_HALF_ROUNDS, MC_OT_MONEY, MC_OT_VOTE_SECONDS, MC_OT_VOTE_DEFAULT, MC_READY_MODE,
    MC_MIN_READY, MC_TEAM_A_NAME, MC_TEAM_B_NAME, MC_TEAM_A_TAG, MC_TEAM_B_TAG, MC_MAP1, MC_MAP2,
    MC_MAP_COUNT, MC_SECOND_READY, MC_SWAP_POLICY, MC_HUD_INTERVAL, MC_PUG_MODE, MC_PUG_STYLE,
    MC_PUG_PERSIST, MC_SCREENSHOTS, MC_SCOREID_SCREENSHOTS, MC_SCREENSHOT_ON_STOP
}

new const g_ManagedConfigNames[][] = {
    "kgb_cw_display_name", "kgb_cw_chat_prefix", "kgb_cw_format", "kgb_cw_half_rounds", "kgb_cw_win_rounds", "kgb_cw_time_limit_minutes",
    "kgb_cw_playout", "kgb_cw_playout_vote_default", "kgb_cw_time_limit_finish_round", "kgb_cw_overtime", "kgb_cw_overtime_max_cycles", "kgb_cw_overtime_vote",
    "kgb_cw_overtime_half_rounds", "kgb_cw_overtime_money", "kgb_cw_overtime_vote_seconds", "kgb_cw_overtime_vote_default", "kgb_cw_ready_mode",
    "kgb_cw_min_ready", "kgb_cw_team_a_name", "kgb_cw_team_b_name", "kgb_cw_team_a_tag", "kgb_cw_team_b_tag", "kgb_cw_map1", "kgb_cw_map2",
    "kgb_cw_map_count", "kgb_cw_second_half_ready", "kgb_cw_swap_policy", "kgb_cw_hud_interval", "kgb_cw_pug_mode", "kgb_cw_pug_style",
    "kgb_cw_pug_persist", "kgb_cw_screenshots", "kgb_cw_scoreid_screenshots", "kgb_cw_screenshot_on_stop"
}
new g_ConfigRollbackValues[sizeof g_ManagedConfigNames][128]

enum SeriesExtraConfigIndex
{
    SC_AUTO_LIVE = 0, SC_HUD_ANNOUNCEMENTS, SC_WARMUP_CONFIG, SC_MATCH_CONFIG,
    SC_OVERTIME_CONFIG, SC_DEFAULT_CONFIG, SC_HALFTIME_DELAY, SC_KNIFE_VOTE,
    SC_KNIFE_VOTE_SECONDS, SC_SET_HOSTNAME, SC_HOSTNAME, SC_SET_PASSWORD,
    SC_PASSWORD, SC_DISABLE_SHIELD, SC_CLIENT_DEMOS, SC_FILE_STATS,
    SC_HLTV_ENABLED, SC_HLTV_AUTO_RECORD
}

new const g_SeriesExtraConfigNames[][] = {
    "kgb_cw_auto_live", "kgb_cw_hud_announcements", "kgb_cw_warmup_config", "kgb_cw_match_config",
    "kgb_cw_overtime_config", "kgb_cw_default_config", "kgb_cw_halftime_delay", "kgb_cw_knife_vote",
    "kgb_cw_knife_vote_seconds", "kgb_cw_set_hostname", "kgb_cw_hostname", "kgb_cw_set_password",
    "kgb_cw_password", "kgb_cw_disable_shield", "kgb_cw_client_demos", "kgb_cw_file_stats",
    "kgb_cw_hltv_enabled", "kgb_cw_hltv_auto_record"
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_dictionary("kgb_clan_war.txt")
    register_cvar("kgb_cw_version", PLUGIN_VERSION, FCVAR_SERVER | FCVAR_SPONLY)

    g_CvarEnabled = register_cvar("kgb_cw_enabled", "1")
    g_CvarDisplayName = register_cvar("kgb_cw_display_name", DEFAULT_DISPLAY_NAME)
    g_CvarChatPrefix = register_cvar("kgb_cw_chat_prefix", DEFAULT_CHAT_PREFIX)
    g_CvarMinReady = register_cvar("kgb_cw_min_ready", "10")
    g_CvarReadyMode = register_cvar("kgb_cw_ready_mode", "player")
    g_CvarAutoLive = register_cvar("kgb_cw_auto_live", "0")
    g_CvarFormat = register_cvar("kgb_cw_format", "mr")
    g_CvarHalfRounds = register_cvar("kgb_cw_half_rounds", "15")
    g_CvarWinRounds = register_cvar("kgb_cw_win_rounds", "16")
    g_CvarTimeLimitMinutes = register_cvar("kgb_cw_time_limit_minutes", "20")
    g_CvarPlayout = register_cvar("kgb_cw_playout", "0")
    g_CvarPlayoutVoteDefault = register_cvar("kgb_cw_playout_vote_default", "1")
    g_CvarTimeLimitFinishRound = register_cvar("kgb_cw_time_limit_finish_round", "1")
    g_CvarOvertime = register_cvar("kgb_cw_overtime", "1")
    g_CvarOvertimeMaxCycles = register_cvar("kgb_cw_overtime_max_cycles", "3")
    g_CvarOvertimeHalfRounds = register_cvar("kgb_cw_overtime_half_rounds", "3")
    g_CvarOvertimeMoney = register_cvar("kgb_cw_overtime_money", "10000")
    g_CvarOvertimeVote = register_cvar("kgb_cw_overtime_vote", "0")
    g_CvarOvertimeVoteSeconds = register_cvar("kgb_cw_overtime_vote_seconds", "15")
    g_CvarOvertimeVoteDefault = register_cvar("kgb_cw_overtime_vote_default", "1")
    g_CvarHudAnnouncements = register_cvar("kgb_cw_hud_announcements", "1")
    g_CvarState = register_cvar("kgb_cw_state", "off", FCVAR_SERVER)

    g_CvarTeamAName = register_cvar("kgb_cw_team_a_name", "Team A")
    g_CvarTeamBName = register_cvar("kgb_cw_team_b_name", "Team B")
    g_CvarTeamATag = register_cvar("kgb_cw_team_a_tag", "")
    g_CvarTeamBTag = register_cvar("kgb_cw_team_b_tag", "")
    g_CvarMap1 = register_cvar("kgb_cw_map1", "")
    g_CvarMap2 = register_cvar("kgb_cw_map2", "")
    g_CvarMapCount = register_cvar("kgb_cw_map_count", "1")

    g_CvarWarmupConfig = register_cvar("kgb_cw_warmup_config", "kgb_gamemode")
    g_CvarMatchConfig = register_cvar("kgb_cw_match_config", "kgb_gamemode")
    g_CvarOvertimeConfig = register_cvar("kgb_cw_overtime_config", "kgb_gamemode")
    g_CvarDefaultConfig = register_cvar("kgb_cw_default_config", "kgb_gamemode")
    g_CvarHalftimeDelay = register_cvar("kgb_cw_halftime_delay", "5")
    g_CvarKnifeVote = register_cvar("kgb_cw_knife_vote", "1")
    g_CvarKnifeVoteSeconds = register_cvar("kgb_cw_knife_vote_seconds", "15")
    g_CvarPugMode = register_cvar("kgb_cw_pug_mode", "0")
    g_CvarPugStyle = register_cvar("kgb_cw_pug_style", "random")
    g_CvarAllowMenuSave = register_cvar("kgb_cw_allow_menu_save", "0")
    g_CvarSecondHalfReady = register_cvar("kgb_cw_second_half_ready", "0")
    g_CvarSwapPolicy = register_cvar("kgb_cw_swap_policy", "halves")
    g_CvarHudInterval = register_cvar("kgb_cw_hud_interval", "10")
    g_CvarPugPersist = register_cvar("kgb_cw_pug_persist", "1")
    g_CvarScoreIdScreenshots = register_cvar("kgb_cw_scoreid_screenshots", "0")
    g_CvarScreenshotOnStop = register_cvar("kgb_cw_screenshot_on_stop", "0")

    /* Risky or client-affecting behavior is opt-in. */
    g_CvarSetHostname = register_cvar("kgb_cw_set_hostname", "0")
    g_CvarHostname = register_cvar("kgb_cw_hostname", "")
    g_CvarSetPassword = register_cvar("kgb_cw_set_password", "0")
    g_CvarPassword = register_cvar("kgb_cw_password", "", FCVAR_PROTECTED)
    g_CvarDisableShield = register_cvar("kgb_cw_disable_shield", "0")
    g_CvarClientDemos = register_cvar("kgb_cw_client_demos", "0")
    g_CvarScreenshots = register_cvar("kgb_cw_screenshots", "0")
    g_CvarFileStats = register_cvar("kgb_cw_file_stats", "0")

    register_concmd("amx_cw_menu", "command_menu", ADMIN_CFG, "- open match controls")
    register_concmd("amx_cw_warmup", "command_warmup", ADMIN_CFG, "- start warmup")
    register_concmd("amx_cw_knife", "command_knife", ADMIN_CFG, "- start knife round")
    register_concmd("amx_cw_live", "command_live", ADMIN_CFG, "- start a match with LO3")
    register_concmd("amx_cw_relo3", "command_relo3", ADMIN_CFG, "- repeat LO3 without resetting score")
    register_concmd("amx_cw_swap", "command_swap", ADMIN_CFG, "- swap T and CT")
    register_concmd("amx_cw_restart_half", "command_restart_half", ADMIN_CFG, "- reset the current half")
    register_concmd("amx_cw_restart_match", "command_restart_match", ADMIN_CFG, "- reset the whole match")
    register_concmd("amx_cw_ready_list", "command_ready_list", 0, "- show the current ready list")
    register_concmd("amx_cw_readylist", "command_ready_list", 0, "- compatibility alias")
    register_concmd("amx_cw_pug_randomize", "command_pug_randomize", ADMIN_CFG, "- randomly balance warmup players")
    register_concmd("amx_cw_pug_start", "command_pug_start", ADMIN_CFG, "[random|manual]")
    register_concmd("amx_cw_pug_assign", "command_pug_assign", ADMIN_CFG, "<player> <a|b>")
    register_concmd("amx_cw_pug_stop", "command_pug_stop", ADMIN_CFG, "- stop the active PUG")
    register_concmd("amx_cw_config_menu", "command_config_menu", ADMIN_CFG, "- open preset/map/save controls")
    register_concmd("amx_cw_setup", "command_settings_menu", ADMIN_CFG, "- complete interactive match setup")
    register_concmd("amx_cw_settings", "command_settings_menu", ADMIN_CFG, "- edit match settings")
    register_concmd("amx_cw_presets", "command_preset_menu", ADMIN_CFG, "- choose an installed league preset")
    register_concmd("amx_cw_preset", "command_preset", ADMIN_CFG, "<preset>")
    register_concmd("amx_cw_map_menu", "command_map_menu", ADMIN_CFG, "- choose default maps")
    register_concmd("amx_cw_save_config", "command_save_config", ADMIN_CFG, "- save an allowlisted menu snapshot")
    register_concmd("amx_cw_load_saved", "command_load_saved", ADMIN_CFG, "- load the saved menu snapshot")
    register_concmd("amx_cw_teams", "command_teams", ADMIN_CFG, "<team-a> <team-b>")
    register_concmd("amx_cw_tags", "command_tags", ADMIN_CFG, "<tag-a> <tag-b>")
    register_concmd("amx_cw_maps", "command_maps", ADMIN_CFG, "<map1> [map2]")
    register_concmd("amx_cw_stop", "command_stop", ADMIN_CFG, "- stop and restore server")
    register_concmd("amx_cw_recover", "command_recover", ADMIN_CFG, "- safely retry pending cross-map baseline recovery")
    register_concmd("amx_cw_score", "command_score", 0, "- show score")
    register_concmd("amx_cw_scoreids", "command_scoreids", ADMIN_CFG, "- show score and player SteamIDs in the admin console")
    register_concmd("amx_cw_scoreids_snapshot", "command_scoreids_snapshot", ADMIN_CFG, "- show score/SteamIDs and request an admin screenshot")
    register_concmd("amx_match", "command_legacy_match", ADMIN_CFG, "<team-a> <team-b> [mrXX|tlXX|wlXX config [record-mode]]")
    register_concmd("amx_match2", "command_legacy_match2", ADMIN_CFG, "<mrXX|tlXX|wlXX> <config> [record-mode]")
    register_concmd("amx_match3", "command_legacy_match3", ADMIN_CFG, "<team-a> <team-b> <mrXX|tlXX|wlXX> <config> <second-map> [record-mode]")
    register_concmd("amx_match4", "command_legacy_match4", ADMIN_CFG, "<mrXX|tlXX|wlXX> <config> <second-map> [record-mode]")
    register_concmd("amx_match_stop", "command_stop", ADMIN_CFG, "- compatibility alias")
    register_concmd("amx_match_start", "command_live", ADMIN_CFG, "- compatibility alias")
    register_concmd("amx_matchrestart", "command_restart_match", ADMIN_CFG, "- compatibility alias")
    register_concmd("amx_matchstop", "command_stop", ADMIN_CFG, "- compatibility alias")
    register_concmd("amx_matchstart", "command_live", ADMIN_CFG, "- compatibility alias")
    register_concmd("amx_matchrelo3", "command_legacy_relo3", ADMIN_CFG, "- reset the current half with LO3")
    register_concmd("amx_swapteams", "command_swap", ADMIN_CFG, "- compatibility alias")
    register_concmd("amx_randomizeteams", "command_pug_randomize", ADMIN_CFG, "- compatibility alias")
    register_concmd("amx_cw_safety_status", "command_safety_status", ADMIN_CFG, "- show non-secret safety status")
    register_concmd("amx_cw_status", "command_status", 0, "- show detailed status")
    register_clcmd("say", "command_say")
    register_clcmd("say_team", "command_say")
    register_clcmd("shield", "command_shield_purchase")
    register_clcmd("shieldgun", "command_shield_purchase")

    register_event("HLTV", "event_new_round", "a", "1=0", "2=0")
    register_event("ResetHUD", "event_player_spawn", "be")
    register_event("SendAudio", "event_ct_win", "a", "2=%!MRAD_ctwin")
    register_event("SendAudio", "event_t_win", "a", "2=%!MRAD_terwin")
    register_logevent("event_round_end", 2, "1=Round_End")
    register_event("CurWeapon", "event_current_weapon", "be", "1=1")
    register_event("TeamInfo", "event_team_info", "a")
    register_touch("weaponbox", "player", "touch_knife_weapon")
    register_touch("armoury_entity", "player", "touch_knife_weapon")

    g_ForwardEvent = CreateMultiForward("kgb_cw_event", ET_IGNORE, FP_STRING, FP_STRING, FP_STRING, FP_CELL, FP_CELL, FP_CELL, FP_CELL)
}

public plugin_cfg()
{
    /* This is a fixed package-owned path, not user input. */
    server_cmd("exec addons/amxmodx/configs/kgb_clan_war.cfg")
    server_exec()
    refresh_branding(true)
    AddMenuItem(g_DisplayName, "amx_cw_menu", ADMIN_CFG, PLUGIN_NAME)
    set_cw_state(STATE_OFF)
    set_task(1.0, "task_resume_crossmap", TASK_RESUME_MAP)
    schedule_status_hud()
}

public plugin_end()
{
    if (!g_MapChangePending)
    {
        stop_client_demos()
        restore_environment()
        restore_legacy_record_mode()
        clear_pug_resume_state()
        discard_series_manifest()
    }
    if (g_ForwardEvent >= 0) DestroyForward(g_ForwardEvent)
}

public client_putinserver(id)
{
    clear_client_state(id)
    g_HalfKillsStart[id] = get_user_frags(id); g_HalfDeathsStart[id] = cs_get_user_deaths(id)
    if (g_State == STATE_LIVE && series_extra_number(SC_CLIENT_DEMOS, g_CvarClientDemos)) start_client_demo(id)
}
public client_disconnect(id) { handle_client_departure(id); }
public client_disconnected(id) { handle_client_departure(id); }

stock handle_client_departure(id)
{
    remove_task(TASK_SCOREID_SNAPSHOT + id)
    g_ScoreIdSnapshotAuthorized[id] = false
    if (g_State == STATE_KNIFE_VOTE && g_KnifeVoted[id])
    {
        if (g_KnifeVoteChoice[id] == 1 && g_KnifeStayVotes > 0) g_KnifeStayVotes--
        else if (g_KnifeVoteChoice[id] == 2 && g_KnifeSwapVotes > 0) g_KnifeSwapVotes--
    }
    if (g_State == STATE_OVERTIME_VOTE && g_OvertimeVoted[id])
    {
        if (g_OvertimeVoteChoice[id] == 1 && g_OvertimeYesVotes > 0) g_OvertimeYesVotes--
        else if (g_OvertimeVoteChoice[id] == 2 && g_OvertimeNoVotes > 0) g_OvertimeNoVotes--
    }
    if (g_State == STATE_PLAYOUT_VOTE && g_PlayoutVoted[id])
    {
        if (g_PlayoutVoteChoice[id] == 1 && g_PlayoutYesVotes > 0) g_PlayoutYesVotes--
        else if (g_PlayoutVoteChoice[id] == 2 && g_PlayoutNoVotes > 0) g_PlayoutNoVotes--
    }
    clear_client_state(id)
    if (g_State == STATE_KNIFE_VOTE && knife_vote_count() >= knife_eligible_count(id)) finish_knife_vote()
    if (g_State == STATE_OVERTIME_VOTE && overtime_vote_count() >= overtime_eligible_count(id)) finish_overtime_vote()
    if (g_State == STATE_PLAYOUT_VOTE && playout_vote_count() >= playout_eligible_count(id)) finish_playout_vote()
}

stock clear_client_state(id)
{
    g_Ready[id] = false
    g_DemoStarted[id] = false
    g_ScoreIdSnapshotAuthorized[id] = false
    g_KnifeVoted[id] = false
    g_KnifeVoteChoice[id] = 0
    g_OvertimeVoted[id] = false
    g_OvertimeVoteChoice[id] = 0
    g_PlayoutVoted[id] = false
    g_PlayoutVoteChoice[id] = 0
    g_MapMenuSecond[id] = false
    g_MapMenuFirst[id][0] = 0
    g_HalfKillsStart[id] = 0
    g_HalfDeathsStart[id] = 0
}

public command_menu(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id)) show_control_menu(id)
    return PLUGIN_HANDLED
}

public command_warmup(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id) && !map_transition_blocks_mutation(id, false)) start_warmup(true)
    return PLUGIN_HANDLED
}

public command_knife(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id) && !map_transition_blocks_mutation(id, false)) start_knife_round()
    return PLUGIN_HANDLED
}

public command_live(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id))
    {
        if (map_transition_blocks_mutation(id, false)) return PLUGIN_HANDLED
        if (g_State == STATE_HALF_READY) resume_ready_half()
        else start_live_match(g_State == STATE_WARMUP && g_KnifeDecisionMade)
    }
    return PLUGIN_HANDLED
}

public command_relo3(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (map_transition_blocks_mutation(id, false)) return PLUGIN_HANDLED
    if (g_State != STATE_LIVE) cw_console_ml(id, "CW_ERR_NOT_LIVE")
    else begin_lo3(false)
    return PLUGIN_HANDLED
}

public command_legacy_relo3(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (map_transition_blocks_mutation(id, false)) return PLUGIN_HANDLED
    if (g_State != STATE_LIVE) cw_console_ml(id, "CW_ERR_NOT_LIVE")
    else restart_current_half()
    return PLUGIN_HANDLED
}

public command_swap(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (map_transition_blocks_mutation(id, false)) return PLUGIN_HANDLED
    if (g_Lo3Running || g_State == STATE_HALFTIME || g_State == STATE_HALF_READY || g_State == STATE_OVERTIME_VOTE || g_State == STATE_PLAYOUT_VOTE) cw_console_ml(id, "CW_ERR_TRANSITION")
    else
    {
        swap_players()
        toggle_team_a_side()
        announce_ml("CW_ADMIN_SWAPPED")
        audit_event("admin_swap")
    }
    return PLUGIN_HANDLED
}

public command_restart_half(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (map_transition_blocks_mutation(id, false)) return PLUGIN_HANDLED
    if (g_State != STATE_LIVE) cw_console_ml(id, "CW_ERR_NOT_LIVE")
    else restart_current_half()
    return PLUGIN_HANDLED
}

public command_restart_match(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id))
    {
        if (map_transition_blocks_mutation(id, false)) return PLUGIN_HANDLED
        restart_whole_match(id, false)
    }
    return PLUGIN_HANDLED
}

public command_ready_list(id, level, cid)
{
    if (id <= 0 || !is_user_connected(id))
    {
        cw_console_ml(id, "CW_ERR_READY_LIST_PLAYER")
        return PLUGIN_HANDLED
    }
    if (!get_pcvar_num(g_CvarEnabled)) cw_console_ml(id, "CW_ERR_DISABLED")
    else show_ready_list_menu(id)
    return PLUGIN_HANDLED
}

public command_pug_randomize(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (map_transition_blocks_mutation(id, false)) return PLUGIN_HANDLED
    if (!get_pcvar_num(g_CvarPugMode)) cw_console_ml(id, "CW_ERR_PUG_DISABLED")
    else if (g_State != STATE_OFF && g_State != STATE_WARMUP) cw_console_ml(id, "CW_ERR_PUG_STATE")
    else randomize_pug_teams()
    return PLUGIN_HANDLED
}

public command_pug_start(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (map_transition_blocks_mutation(id, false)) return PLUGIN_HANDLED
    if (!get_pcvar_num(g_CvarPugMode))
    {
        cw_console_ml(id, "CW_ERR_PUG_DISABLED")
        return PLUGIN_HANDLED
    }
    if (g_State != STATE_OFF && g_State != STATE_WARMUP)
    {
        cw_console_ml(id, "CW_ERR_PUG_START_STATE")
        return PLUGIN_HANDLED
    }

    new style[16]
    if (read_argc() > 1) read_argv(1, style, charsmax(style))
    else get_pcvar_string(g_CvarPugStyle, style, charsmax(style))
    strtolower(style)
    if (!equal(style, "random") && !equal(style, "manual"))
    {
        cw_console_ml(id, "CW_ERR_PUG_STYLE")
        return PLUGIN_HANDLED
    }

    if (!start_warmup(true)) return PLUGIN_HANDLED
    set_pcvar_string(g_CvarPugStyle, style)
    g_PugActive = true
    if (equal(style, "random")) randomize_pug_teams()
    else announce_ml("CW_PUG_MANUAL_STARTED")
    audit_event("pug_start")
    return PLUGIN_HANDLED
}

public command_pug_assign(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (map_transition_blocks_mutation(id, false)) return PLUGIN_HANDLED
    if (!get_pcvar_num(g_CvarPugMode) || !g_PugActive || g_State != STATE_WARMUP)
    {
        cw_console_ml(id, "CW_ERR_PUG_ASSIGN_STATE")
        return PLUGIN_HANDLED
    }

    new playerArg[32], teamArg[8]
    read_argv(1, playerArg, charsmax(playerArg)); read_argv(2, teamArg, charsmax(teamArg)); strtolower(teamArg)
    new target = cmd_target(id, playerArg, CMDTARGET_NO_BOTS)
    if (!target || (!equal(teamArg, "a") && !equal(teamArg, "b")))
    {
        cw_console_ml(id, "CW_USAGE_PUG_ASSIGN")
        return PLUGIN_HANDLED
    }

    new CsTeams:destination = equal(teamArg, "a") ? g_TeamASide : (g_TeamASide == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT)
    if (is_user_alive(target)) user_silentkill(target)
    cs_set_user_team(target, destination)
    reset_ready_players()
    new name[32]
    get_user_name(target, name, charsmax(name))
    announce_ml("CW_PUG_ASSIGNED", name, equal(teamArg, "a") ? g_TeamAName : g_TeamBName)
    audit_event("pug_assign")
    return PLUGIN_HANDLED
}

public command_pug_stop(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    if (crossmap_recovery_pending())
    {
        cw_console_ml(id, "CW_ERR_RECOVERY_PENDING")
        return PLUGIN_HANDLED
    }
    if (map_transition_blocks_mutation(id, false)) return PLUGIN_HANDLED
    if (!g_PugActive) cw_console_ml(id, "CW_ERR_NO_PUG")
    else
    {
        g_PugActive = false
        stop_match(true)
        audit_event("pug_stop")
    }
    return PLUGIN_HANDLED
}

public command_config_menu(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id) && safe_configuration_state(id)) show_config_menu(id)
    return PLUGIN_HANDLED
}

public command_settings_menu(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id) && safe_configuration_state(id)) show_settings_menu(id)
    return PLUGIN_HANDLED
}

public command_preset_menu(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id) && safe_configuration_state(id)) show_preset_menu(id)
    return PLUGIN_HANDLED
}

public command_preset(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2) || !mode_enabled(id)) return PLUGIN_HANDLED
    new preset[MAX_PRESET_TOKEN + 1]
    read_argv(1, preset, charsmax(preset)); strtolower(preset)
    apply_preset(id, preset)
    return PLUGIN_HANDLED
}

public command_map_menu(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !mode_enabled(id) || !safe_configuration_state(id)) return PLUGIN_HANDLED
    g_MapMenuSecond[id] = false; g_MapMenuFirst[id][0] = 0
    show_map_menu(id)
    return PLUGIN_HANDLED
}

public command_save_config(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id)) save_menu_config(id)
    return PLUGIN_HANDLED
}

public command_load_saved(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !mode_enabled(id)) return PLUGIN_HANDLED
    load_saved_config(id)
    return PLUGIN_HANDLED
}

stock load_saved_config(id)
{
    if (!safe_configuration_state(id)) return
    new configsDir[128], path[192]
    get_configsdir(configsDir, charsmax(configsDir))
    formatex(path, charsmax(path), "%s/kgb_clan_war_saved.cfg", configsDir)
    if (!file_exists(path)) cw_console_ml(id, "CW_ERR_NO_SAVED_CONFIG")
    else if (!managed_config_file_valid(path, false)) cw_console_ml(id, "CW_ERR_SAVED_INVALID")
    else
    {
        if (apply_managed_config_file(path, false))
        {
            cw_console_ml(id, "CW_SAVED_LOADED")
        }
        else cw_console_ml(id, "CW_ERR_SAVED_INVALID")
    }
}

public command_teams(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3) || !mode_enabled(id) || !safe_configuration_state(id)) return PLUGIN_HANDLED
    new a[MAX_TEAM_NAME + 1], b[MAX_TEAM_NAME + 1]
    read_argv(1, a, charsmax(a)); read_argv(2, b, charsmax(b)); trim(a); trim(b)
    if (!valid_display_token(a, MAX_TEAM_NAME) || !valid_display_token(b, MAX_TEAM_NAME))
    {
        cw_console_ml(id, "CW_ERR_TEAM_NAMES", MAX_TEAM_NAME)
        return PLUGIN_HANDLED
    }
    set_pcvar_string(g_CvarTeamAName, a); set_pcvar_string(g_CvarTeamBName, b)
    copy(g_TeamAName, charsmax(g_TeamAName), a); copy(g_TeamBName, charsmax(g_TeamBName), b)
    announce_ml("CW_TEAMS_CONFIGURED", a, b)
    audit_event("teams_configured")
    return PLUGIN_HANDLED
}

public command_tags(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3) || !mode_enabled(id) || !safe_configuration_state(id)) return PLUGIN_HANDLED
    new a[MAX_TEAM_TAG + 1], b[MAX_TEAM_TAG + 1]
    read_argv(1, a, charsmax(a)); read_argv(2, b, charsmax(b)); trim(a); trim(b)
    if ((a[0] && !valid_display_token(a, MAX_TEAM_TAG)) || (b[0] && !valid_display_token(b, MAX_TEAM_TAG)))
    {
        cw_console_ml(id, "CW_ERR_TEAM_TAGS", MAX_TEAM_TAG)
        return PLUGIN_HANDLED
    }
    set_pcvar_string(g_CvarTeamATag, a); set_pcvar_string(g_CvarTeamBTag, b)
    copy(g_TeamATag, charsmax(g_TeamATag), a); copy(g_TeamBTag, charsmax(g_TeamBTag), b)
    announce_ml("CW_TAGS_CONFIGURED", g_TeamAName, g_TeamBName)
    audit_event("tags_configured")
    return PLUGIN_HANDLED
}

public command_maps(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2) || !mode_enabled(id) || !safe_configuration_state(id)) return PLUGIN_HANDLED
    new map1[MAX_MAP_TOKEN + 1], map2[MAX_MAP_TOKEN + 1]
    read_argv(1, map1, charsmax(map1)); read_argv(2, map2, charsmax(map2))
    strtolower(map1); strtolower(map2)
    if (!valid_map_token(map1) || (map2[0] && (!valid_map_token(map2) || equali(map1, map2))))
    {
        cw_console_ml(id, "CW_ERR_MAP_ARGS")
        return PLUGIN_HANDLED
    }
    set_pcvar_string(g_CvarMap1, map1); set_pcvar_string(g_CvarMap2, map2)
    set_pcvar_num(g_CvarMapCount, map2[0] ? 2 : 1)
    load_runtime_settings(false)
    cw_console_ml(id, "CW_MAPS_CONFIGURED", map1, map2[0] ? ", " : "", map2)
    return PLUGIN_HANDLED
}

public command_stop(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    if (crossmap_recovery_pending())
    {
        cw_console_ml(id, "CW_ERR_RECOVERY_PENDING")
        return PLUGIN_HANDLED
    }
    if (map_transition_blocks_mutation(id, false)) return PLUGIN_HANDLED
    stop_match(true)
    return PLUGIN_HANDLED
}

public command_recover(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    if (!crossmap_recovery_pending())
    {
        cw_console_ml(id, "CW_RECOVERY_NONE")
        return PLUGIN_HANDLED
    }
    if (!restore_rejected_crossmap_state())
    {
        cw_console_ml(id, "CW_ERR_RECOVERY_PENDING")
        return PLUGIN_HANDLED
    }
    finalize_crossmap_recovery()
    cw_console_ml(id, "CW_RECOVERY_COMPLETE")
    return PLUGIN_HANDLED
}

public command_score(id) { print_score(id, false); return PLUGIN_HANDLED; }
public command_status(id) { print_score(id, true); return PLUGIN_HANDLED; }

public command_safety_status(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    new stateText[24]
    state_name(stateText, charsmax(stateText))
    console_print(id, "KGB_CW_SAFETY version=%s state=%s series_policy_frozen=%d file_stats_configured=%d file_stats_effective=%d", PLUGIN_VERSION, stateText, g_SeriesManifestCaptured ? 1 : 0, get_pcvar_num(g_CvarFileStats), series_extra_number(SC_FILE_STATS, g_CvarFileStats))
    return PLUGIN_HANDLED
}

public command_scoreids(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    cw_console_ml(id, "CW_SCORE_MAP", g_MapNumber, labelA, g_TeamAScore, g_TeamBScore, labelB)
    if (g_MapCount == 2) cw_console_ml(id, "CW_SCORE_SERIES", labelA, total_score_a(), total_score_b(), labelB)
    cw_console_ml(id, "CW_SCOREID_HEADER")
    new players[32], count
    get_players(players, count, "ch")
    for (new i = 0; i < count; i++)
    {
        new player = players[i], name[32], authid[36], side[24]
        get_user_name(player, name, charsmax(name)); get_user_authid(player, authid, charsmax(authid))
        get_side_name(cs_get_user_team(player), side, charsmax(side))
        cw_console_ml(id, "CW_SCOREID_ROW", get_user_userid(player), name, authid, side, get_user_frags(player), cs_get_user_deaths(player))
    }
    return PLUGIN_HANDLED
}

public command_scoreids_snapshot(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    if (!series_managed_number(MC_SCOREID_SCREENSHOTS, g_CvarScoreIdScreenshots))
    {
        cw_console_ml(id, "CW_ERR_SCOREID_SCREENSHOT_DISABLED")
        return PLUGIN_HANDLED
    }
    command_scoreids(id, level, cid)
    show_identity_motd(id)
    remove_task(TASK_SCOREID_SNAPSHOT + id)
    g_ScoreIdSnapshotAuthorized[id] = true
    set_task(0.8, "task_scoreid_snapshot", TASK_SCOREID_SNAPSHOT + id)
    return PLUGIN_HANDLED
}

public command_legacy_match(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (map_transition_blocks_mutation(id, false)) return PLUGIN_HANDLED
    if (!safe_configuration_state(id)) return PLUGIN_HANDLED
    if (read_argc() >= 5)
    {
        new teamA[MAX_TEAM_NAME + 1], teamB[MAX_TEAM_NAME + 1], rule[16], config[MAX_CONFIG_TOKEN + 1], recordMode[16]
        read_argv(1, teamA, charsmax(teamA)); read_argv(2, teamB, charsmax(teamB)); read_argv(3, rule, charsmax(rule))
        read_argv(4, config, charsmax(config)); read_argv(5, recordMode, charsmax(recordMode))
        configure_legacy_match(id, teamA, teamB, rule, config, "", recordMode)
        return PLUGIN_HANDLED
    }
    new teamA[MAX_TEAM_NAME + 1], teamB[MAX_TEAM_NAME + 1], preset[MAX_PRESET_TOKEN + 1]
    read_argv(1, teamA, charsmax(teamA)); read_argv(2, teamB, charsmax(teamB)); read_argv(3, preset, charsmax(preset))
    trim(teamA); trim(teamB); strtolower(preset)
    if (!valid_display_token(teamA, MAX_TEAM_NAME) || !valid_display_token(teamB, MAX_TEAM_NAME))
    {
        cw_console_ml(id, "CW_USAGE_LEGACY_MATCH")
        return PLUGIN_HANDLED
    }
    if (preset[0] && !preset_config_valid(preset))
    {
        cw_console_ml(id, "CW_ERR_PRESET_INVALID")
        return PLUGIN_HANDLED
    }

    /* Stage the complete replacement while the current recording override is
     * still intact. A syntactically valid preset can still be incompatible
     * with current map topology, phase configs, or other runtime settings. */
    snapshot_managed_config()
    if (preset[0])
    {
        new configsDir[128], presetPath[224]
        get_configsdir(configsDir, charsmax(configsDir))
        formatex(presetPath, charsmax(presetPath), "%s/kgb_clan_war/presets/%s.cfg", configsDir, preset)
        if (!apply_managed_config_file(presetPath, true))
        {
            cw_console_ml(id, "CW_ERR_PRESET_INVALID")
            return PLUGIN_HANDLED
        }
    }
    set_pcvar_string(g_CvarTeamAName, teamA); set_pcvar_string(g_CvarTeamBName, teamB)
    if (!full_runtime_config_valid(true))
    {
        restore_managed_config_snapshot()
        cw_console_ml(id, "CW_ERR_LEGACY_START")
        return PLUGIN_HANDLED
    }

    new bool:oldLegacyOverride = g_LegacyRecordOverride
    new oldCurrentClientDemos = get_pcvar_num(g_CvarClientDemos)
    new bool:oldHasHltvEnabled = bool:cvar_exists("kgb_cw_hltv_enabled")
    new bool:oldHasHltvAuto = bool:cvar_exists("kgb_cw_hltv_auto_record")
    new oldCurrentHltvEnabled = oldHasHltvEnabled ? get_cvar_num("kgb_cw_hltv_enabled") : 0
    new oldCurrentHltvAuto = oldHasHltvAuto ? get_cvar_num("kgb_cw_hltv_auto_record") : 0
    new oldLegacyClientDemos = g_LegacyOldClientDemos
    new oldLegacyHltvEnabled = g_LegacyOldHltvEnabled, oldLegacyHltvAuto = g_LegacyOldHltvAuto
    restore_legacy_record_mode()
    if (!start_warmup(true))
    {
        restore_managed_config_snapshot()
        restore_legacy_snapshot(oldLegacyOverride, oldCurrentClientDemos,
            oldHasHltvEnabled, oldCurrentHltvEnabled, oldHasHltvAuto, oldCurrentHltvAuto,
            oldLegacyClientDemos, oldLegacyHltvEnabled, oldLegacyHltvAuto)
        cw_console_ml(id, "CW_ERR_LEGACY_START")
        return PLUGIN_HANDLED
    }
    if (preset[0])
    {
        cw_console_ml(id, "CW_PRESET_APPLIED", preset)
        audit_event("preset_applied")
    }
    announce_ml("CW_LEGACY_STARTED", teamA, teamB)
    return PLUGIN_HANDLED
}

public command_legacy_match2(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (map_transition_blocks_mutation(id, false) || !safe_configuration_state(id)) return PLUGIN_HANDLED
    new teamA[MAX_TEAM_NAME + 1], teamB[MAX_TEAM_NAME + 1], rule[16], config[MAX_CONFIG_TOKEN + 1], recordMode[16]
    get_pcvar_string(g_CvarTeamAName, teamA, charsmax(teamA)); get_pcvar_string(g_CvarTeamBName, teamB, charsmax(teamB))
    read_argv(1, rule, charsmax(rule)); read_argv(2, config, charsmax(config)); read_argv(3, recordMode, charsmax(recordMode))
    configure_legacy_match(id, teamA, teamB, rule, config, "", recordMode)
    return PLUGIN_HANDLED
}

public command_legacy_match3(id, level, cid)
{
    if (!cmd_access(id, level, cid, 6) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (map_transition_blocks_mutation(id, false) || !safe_configuration_state(id)) return PLUGIN_HANDLED
    new teamA[MAX_TEAM_NAME + 1], teamB[MAX_TEAM_NAME + 1], rule[16], config[MAX_CONFIG_TOKEN + 1], map2[MAX_MAP_TOKEN + 1], recordMode[16]
    read_argv(1, teamA, charsmax(teamA)); read_argv(2, teamB, charsmax(teamB)); read_argv(3, rule, charsmax(rule))
    read_argv(4, config, charsmax(config)); read_argv(5, map2, charsmax(map2)); read_argv(6, recordMode, charsmax(recordMode))
    configure_legacy_match(id, teamA, teamB, rule, config, map2, recordMode)
    return PLUGIN_HANDLED
}

public command_legacy_match4(id, level, cid)
{
    if (!cmd_access(id, level, cid, 4) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (map_transition_blocks_mutation(id, false) || !safe_configuration_state(id)) return PLUGIN_HANDLED
    new teamA[MAX_TEAM_NAME + 1], teamB[MAX_TEAM_NAME + 1], rule[16], config[MAX_CONFIG_TOKEN + 1], map2[MAX_MAP_TOKEN + 1], recordMode[16]
    get_pcvar_string(g_CvarTeamAName, teamA, charsmax(teamA)); get_pcvar_string(g_CvarTeamBName, teamB, charsmax(teamB))
    read_argv(1, rule, charsmax(rule)); read_argv(2, config, charsmax(config)); read_argv(3, map2, charsmax(map2)); read_argv(4, recordMode, charsmax(recordMode))
    configure_legacy_match(id, teamA, teamB, rule, config, map2, recordMode)
    return PLUGIN_HANDLED
}

stock bool:configure_legacy_match(id, const teamAInput[], const teamBInput[], const ruleInput[], const configInput[], const secondMapInput[], const recordModeInput[])
{
    new teamA[MAX_TEAM_NAME + 1], teamB[MAX_TEAM_NAME + 1], rule[16], config[MAX_CONFIG_TOKEN + 1]
    new secondMap[MAX_MAP_TOKEN + 1], recordMode[16], configPath[MAX_CONFIG_TOKEN + 5], currentMap[MAX_MAP_TOKEN + 1]
    copy(teamA, charsmax(teamA), teamAInput); copy(teamB, charsmax(teamB), teamBInput); trim(teamA); trim(teamB)
    copy(rule, charsmax(rule), ruleInput); copy(config, charsmax(config), configInput); copy(secondMap, charsmax(secondMap), secondMapInput); copy(recordMode, charsmax(recordMode), recordModeInput)
    strtolower(rule); strtolower(config); strtolower(secondMap); strtolower(recordMode)
    if (!valid_display_token(teamA, MAX_TEAM_NAME) || !valid_display_token(teamB, MAX_TEAM_NAME) || !apply_legacy_rule(rule, false))
    {
        cw_console_ml(id, "CW_USAGE_LEGACY_FULL")
        return false
    }
    if (!valid_simple_token(config, MAX_CONFIG_TOKEN))
    {
        cw_console_ml(id, "CW_ERR_LEGACY_CONFIG")
        return false
    }
    formatex(configPath, charsmax(configPath), "%s.cfg", config)
    if (!file_exists(configPath))
    {
        cw_console_ml(id, "CW_ERR_LEGACY_CONFIG")
        return false
    }
    get_mapname(currentMap, charsmax(currentMap))
    if (secondMap[0] && (!valid_map_token(secondMap) || equali(currentMap, secondMap)))
    {
        cw_console_ml(id, "CW_ERR_MAP_ARGS")
        return false
    }
    if (!apply_legacy_record_mode(recordMode, false))
    {
        cw_console_ml(id, "CW_ERR_LEGACY_RECORD")
        return false
    }

    /* Validate the full staged replacement before unwinding the active
     * override. This includes ready/swap policy, map relationships, and all
     * phase files, not just the command's direct arguments. */
    snapshot_managed_config()
    new oldConfig[MAX_CONFIG_TOKEN + 1]
    get_pcvar_string(g_CvarMatchConfig, oldConfig, charsmax(oldConfig))
    apply_legacy_rule(rule, true)
    set_pcvar_string(g_CvarTeamAName, teamA); set_pcvar_string(g_CvarTeamBName, teamB)
    set_pcvar_string(g_CvarTeamATag, ""); set_pcvar_string(g_CvarTeamBTag, "")
    set_pcvar_string(g_CvarMatchConfig, config)
    set_pcvar_string(g_CvarMap1, currentMap); set_pcvar_string(g_CvarMap2, secondMap)
    set_pcvar_num(g_CvarMapCount, secondMap[0] ? 2 : 1)
    if (!full_runtime_config_valid(false))
    {
        restore_managed_config_snapshot()
        set_pcvar_string(g_CvarMatchConfig, oldConfig)
        cw_console_ml(id, "CW_ERR_LEGACY_START")
        return false
    }

    new bool:oldLegacyOverride = g_LegacyRecordOverride
    new oldCurrentClientDemos = get_pcvar_num(g_CvarClientDemos)
    new bool:oldHasHltvEnabled = bool:cvar_exists("kgb_cw_hltv_enabled")
    new bool:oldHasHltvAuto = bool:cvar_exists("kgb_cw_hltv_auto_record")
    new oldCurrentHltvEnabled = oldHasHltvEnabled ? get_cvar_num("kgb_cw_hltv_enabled") : 0
    new oldCurrentHltvAuto = oldHasHltvAuto ? get_cvar_num("kgb_cw_hltv_auto_record") : 0
    new oldLegacyClientDemos = g_LegacyOldClientDemos
    new oldLegacyHltvEnabled = g_LegacyOldHltvEnabled, oldLegacyHltvAuto = g_LegacyOldHltvAuto

    restore_legacy_record_mode()
    new replacementOldClientDemos = get_pcvar_num(g_CvarClientDemos)
    new replacementOldHltvEnabled = oldHasHltvEnabled ? get_cvar_num("kgb_cw_hltv_enabled") : -1
    new replacementOldHltvAuto = oldHasHltvAuto ? get_cvar_num("kgb_cw_hltv_auto_record") : -1
    apply_legacy_record_mode(recordMode, true)
    if (!start_warmup(true))
    {
        restore_managed_config_snapshot()
        set_pcvar_string(g_CvarMatchConfig, oldConfig)
        restore_legacy_snapshot(oldLegacyOverride, oldCurrentClientDemos,
            oldHasHltvEnabled, oldCurrentHltvEnabled, oldHasHltvAuto, oldCurrentHltvAuto,
            oldLegacyClientDemos, oldLegacyHltvEnabled, oldLegacyHltvAuto)
        cw_console_ml(id, "CW_ERR_LEGACY_START")
        return false
    }
    if (recordMode[0])
    {
        g_LegacyRecordOverride = true
        g_LegacyOldClientDemos = replacementOldClientDemos
        g_LegacyOldHltvEnabled = replacementOldHltvEnabled
        g_LegacyOldHltvAuto = replacementOldHltvAuto
    }
    announce_ml("CW_LEGACY_STARTED", teamA, teamB)
    return true
}

stock bool:apply_legacy_rule(const rule[], bool:apply)
{
    if (strlen(rule) < 3) return false
    new numberText[12]
    copy(numberText, charsmax(numberText), rule[2])
    if (!is_decimal_number(numberText)) return false
    new value = str_to_num(numberText)
    if (rule[0] == 'm' && rule[1] == 'r')
    {
        if (value < 1 || value > 100) return false
        if (apply) { set_pcvar_string(g_CvarFormat, "mr"); set_pcvar_num(g_CvarHalfRounds, value); }
        return true
    }
    if (rule[0] == 't' && rule[1] == 'l')
    {
        if (value < 1 || value > 180) return false
        if (apply) { set_pcvar_string(g_CvarFormat, "tl"); set_pcvar_num(g_CvarTimeLimitMinutes, value); }
        return true
    }
    if (rule[0] == 'w' && rule[1] == 'l')
    {
        if (value < 1 || value > 100) return false
        if (apply) { set_pcvar_string(g_CvarFormat, "wl"); set_pcvar_num(g_CvarWinRounds, value); }
        return true
    }
    return false
}

stock bool:apply_legacy_record_mode(const mode[], bool:apply)
{
    if (!mode[0]) return true
    if (!equal(mode, "recdemo") && !equal(mode, "rechltv") && !equal(mode, "recboth")) return false
    if ((equal(mode, "rechltv") || equal(mode, "recboth")) &&
        (!cvar_exists("kgb_cw_hltv_enabled") || !cvar_exists("kgb_cw_hltv_auto_record"))) return false
    if (!apply) return true
    set_pcvar_num(g_CvarClientDemos, equal(mode, "recdemo") || equal(mode, "recboth"))
    if (cvar_exists("kgb_cw_hltv_auto_record"))
        set_cvar_num("kgb_cw_hltv_auto_record", equal(mode, "rechltv") || equal(mode, "recboth"))
    if (equal(mode, "rechltv") || equal(mode, "recboth"))
    {
        if (cvar_exists("kgb_cw_hltv_enabled")) set_cvar_num("kgb_cw_hltv_enabled", 1)
    }
    return true
}

stock restore_legacy_record_mode()
{
    if (!g_LegacyRecordOverride) return
    set_pcvar_num(g_CvarClientDemos, g_LegacyOldClientDemos)
    if (g_LegacyOldHltvEnabled >= 0 && cvar_exists("kgb_cw_hltv_enabled")) set_cvar_num("kgb_cw_hltv_enabled", g_LegacyOldHltvEnabled)
    if (g_LegacyOldHltvAuto >= 0 && cvar_exists("kgb_cw_hltv_auto_record")) set_cvar_num("kgb_cw_hltv_auto_record", g_LegacyOldHltvAuto)
    g_LegacyRecordOverride = false
    g_LegacyOldClientDemos = 0; g_LegacyOldHltvEnabled = -1; g_LegacyOldHltvAuto = -1
    audit_event("legacy_record_mode_restored")
}

stock restore_legacy_snapshot(bool:wasActive, clientDemos,
    bool:hadHltvEnabled, hltvEnabled, bool:hadHltvAuto, hltvAuto,
    oldClientDemos, oldHltvEnabled, oldHltvAuto)
{
    set_pcvar_num(g_CvarClientDemos, clientDemos)
    if (hadHltvEnabled && cvar_exists("kgb_cw_hltv_enabled")) set_cvar_num("kgb_cw_hltv_enabled", hltvEnabled)
    if (hadHltvAuto && cvar_exists("kgb_cw_hltv_auto_record")) set_cvar_num("kgb_cw_hltv_auto_record", hltvAuto)
    g_LegacyRecordOverride = wasActive
    g_LegacyOldClientDemos = oldClientDemos
    g_LegacyOldHltvEnabled = oldHltvEnabled
    g_LegacyOldHltvAuto = oldHltvAuto
}

stock show_identity_motd(id)
{
    new report[2048], length, labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1], safeLabelA[96], safeLabelB[96]
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    sanitize_html(labelA, safeLabelA, charsmax(safeLabelA)); sanitize_html(labelB, safeLabelB, charsmax(safeLabelB))
    length = formatex(report, charsmax(report), "<html><body><pre>%L^n", id, "CW_SCORE_MAP", g_MapNumber, safeLabelA, g_TeamAScore, g_TeamBScore, safeLabelB)
    if (g_MapCount == 2) length += formatex(report[length], charsmax(report) - length, "%L^n", id, "CW_SCORE_SERIES", safeLabelA, total_score_a(), total_score_b(), safeLabelB)
    length += formatex(report[length], charsmax(report) - length, "^n%L^n", id, "CW_SCOREID_MOTD_HEADER")
    new players[32], count
    get_players(players, count, "ch")
    for (new i = 0; i < count && length < charsmax(report) - 128; i++)
    {
        new player = players[i], name[32], safeName[96], authid[36], side[24]
        get_user_name(player, name, charsmax(name)); sanitize_html(name, safeName, charsmax(safeName))
        get_user_authid(player, authid, charsmax(authid)); get_side_name(cs_get_user_team(player), side, charsmax(side))
        length += formatex(report[length], charsmax(report) - length, "%s / %s / %s / %d-%d^n", safeName, authid, side, get_user_frags(player), cs_get_user_deaths(player))
    }
    add(report, charsmax(report), "</pre></body></html>")
    new title[64]
    ml_text(id, "CW_SCOREID_MOTD_TITLE", title, charsmax(title)); show_motd(id, report, title)
}

stock sanitize_html(const input[], output[], length)
{
    new position
    for (new i = 0; input[i] && position < length; i++)
    {
        new c = input[i]
        if (c == '<' || c == '>' || c == '&' || c == '^"') c = '_'
        if (c < 32 || c > 126) c = '_'
        output[position++] = c
    }
    output[position] = 0
}

stock sanitize_menu_text(const input[], output[], length)
{
    new position
    for (new i = 0; input[i] && position < length; i++)
    {
        new c = input[i]
        if (c < 32 || c > 126 || c == 92 || c == '%' || c == 94) c = '_'
        output[position++] = c
    }
    output[position] = 0
}

public command_shield_purchase(id)
{
    if (!g_ShieldRestricted) return PLUGIN_CONTINUE
    cw_chat_ml(id, "CW_SHIELD_RESTRICTED")
    return PLUGIN_HANDLED
}

public command_say(id)
{
    if (!get_pcvar_num(g_CvarEnabled)) return PLUGIN_CONTINUE
    new text[64]
    read_args(text, charsmax(text)); remove_quotes(text); trim(text)
    if (equali(text, "ready") || equali(text, "/ready") || equali(text, "!ready")) { set_player_ready(id, true); return PLUGIN_HANDLED; }
    if (equali(text, "notready") || equali(text, "/notready") || equali(text, "!notready")) { set_player_ready(id, false); return PLUGIN_HANDLED; }
    if (equali(text, "teamready") || equali(text, "/teamready") || equali(text, "!teamready")) { set_team_ready(id, true); return PLUGIN_HANDLED; }
    if (equali(text, "teamnotready") || equali(text, "/teamnotready") || equali(text, "!teamnotready")) { set_team_ready(id, false); return PLUGIN_HANDLED; }
    if (equali(text, "/readylist") || equali(text, "!readylist")) { show_ready_list_menu(id); return PLUGIN_HANDLED; }
    if (equali(text, "/score") || equali(text, "!score")) { print_score(id, false); return PLUGIN_HANDLED; }
    if ((equali(text, "/relo3") || equali(text, "!relo3")) && (get_user_flags(id) & ADMIN_CFG))
    {
        if (!mode_enabled(id)) return PLUGIN_HANDLED
        if (map_transition_blocks_mutation(id, true)) return PLUGIN_HANDLED
        if (g_State == STATE_LIVE) restart_current_half()
        else cw_chat_ml(id, "CW_ERR_NOT_LIVE")
        return PLUGIN_HANDLED
    }
    if ((equali(text, "/stop") || equali(text, "!stop")) && (get_user_flags(id) & ADMIN_CFG))
    {
        if (map_transition_blocks_mutation(id, true)) return PLUGIN_HANDLED
        if (crossmap_recovery_pending())
        {
            cw_console_ml(id, "CW_ERR_RECOVERY_PENDING")
            return PLUGIN_HANDLED
        }
        stop_match(true)
        return PLUGIN_HANDLED
    }
    if ((equali(text, "/restart") || equali(text, "!restart")) && (get_user_flags(id) & ADMIN_CFG))
    {
        if (mode_enabled(id))
        {
            if (map_transition_blocks_mutation(id, true)) return PLUGIN_HANDLED
            restart_whole_match(id, true)
        }
        return PLUGIN_HANDLED
    }
    if (equali(text, "/cw") || equali(text, "!cw"))
    {
        if (get_user_flags(id) & ADMIN_CFG)
        {
            if (mode_enabled(id)) show_control_menu(id)
        }
        else print_score(id, false)
        return PLUGIN_HANDLED
    }
    if ((equali(text, "/start") || equali(text, "!start")) && (get_user_flags(id) & ADMIN_CFG))
    {
        if (mode_enabled(id))
        {
            if (map_transition_blocks_mutation(id, true)) return PLUGIN_HANDLED
            if (g_State == STATE_HALF_READY) resume_ready_half()
            else start_live_match(g_State == STATE_WARMUP && g_KnifeDecisionMade)
        }
        return PLUGIN_HANDLED
    }
    return PLUGIN_CONTINUE
}

public menu_control_handler(id, menu, item)
{
    if (item == MENU_EXIT || !(get_user_flags(id) & ADMIN_CFG) || !get_pcvar_num(g_CvarEnabled) || crossmap_recovery_pending())
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new access, info[24], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    menu_destroy(menu)

    if (g_MapChangePending && !equal(info, "status") && !equal(info, "ready_list"))
    {
        cw_chat_ml(id, "CW_ERR_MAP_CHANGE_PENDING")
        return PLUGIN_HANDLED
    }

    if (equal(info, "warmup") && (g_State == STATE_OFF || g_State == STATE_WARMUP || g_State == STATE_KNIFE || g_State == STATE_KNIFE_VOTE)) start_warmup(true)
    else if (equal(info, "knife") && (g_State == STATE_OFF || g_State == STATE_WARMUP)) start_knife_round()
    else if (equal(info, "live") && (g_State == STATE_OFF || g_State == STATE_WARMUP || g_State == STATE_KNIFE || g_State == STATE_KNIFE_VOTE)) start_live_match(g_State == STATE_WARMUP && g_KnifeDecisionMade)
    else if (equal(info, "resume") && g_State == STATE_HALF_READY) resume_ready_half()
    else if (equal(info, "relo3") && g_State == STATE_LIVE && !g_Lo3Running) begin_lo3(false)
    else if (equal(info, "restart_half") && g_State == STATE_LIVE) restart_current_half()
    else if (equal(info, "restart_match") && g_State != STATE_OFF) show_restart_match_confirmation(id)
    else if (equal(info, "status")) print_score(id, true)
    else if (equal(info, "ready_list")) show_ready_list_menu(id)
    else if (equal(info, "swap") && control_swap_allowed())
    {
        swap_players(); toggle_team_a_side(); announce_ml("CW_TEAMS_SWAPPED"); audit_event("menu_swap")
    }
    else if (equal(info, "pug") && get_pcvar_num(g_CvarPugMode) && (g_State == STATE_OFF || g_State == STATE_WARMUP)) randomize_pug_teams()
    else if (equal(info, "config") && (g_State == STATE_OFF || g_State == STATE_WARMUP)) show_config_menu(id)
    else if (equal(info, "stop") && g_State != STATE_OFF) show_stop_confirmation(id)
    return PLUGIN_HANDLED
}

public menu_restart_confirm_handler(id, menu, item)
{
    if (item == MENU_EXIT || !(get_user_flags(id) & ADMIN_CFG) || !get_pcvar_num(g_CvarEnabled) || crossmap_recovery_pending())
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    if (g_MapChangePending)
    {
        menu_destroy(menu); cw_chat_ml(id, "CW_ERR_MAP_CHANGE_PENDING"); show_control_menu(id)
        return PLUGIN_HANDLED
    }
    new access, info[8], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    menu_destroy(menu)
    if (equal(info, "yes")) restart_whole_match(id, true)
    else show_control_menu(id)
    return PLUGIN_HANDLED
}

public menu_stop_confirmation_handler(id, menu, item)
{
    if (item == MENU_EXIT || !(get_user_flags(id) & ADMIN_CFG) || !get_pcvar_num(g_CvarEnabled) || crossmap_recovery_pending())
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    if (g_MapChangePending)
    {
        menu_destroy(menu); cw_chat_ml(id, "CW_ERR_MAP_CHANGE_PENDING"); show_control_menu(id)
        return PLUGIN_HANDLED
    }
    new access, info[8], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    menu_destroy(menu)
    if (equal(info, "yes") && g_State != STATE_OFF) stop_match(true)
    else show_control_menu(id)
    return PLUGIN_HANDLED
}

public menu_ready_list_handler(id, menu, item)
{
    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menu_ready_list_item_callback(id, menu, item)
{
    return ITEM_DISABLED
}

public menu_config_handler(id, menu, item)
{
    if (item == MENU_EXIT || !(get_user_flags(id) & ADMIN_CFG) || !get_pcvar_num(g_CvarEnabled) || !safe_configuration_state(id))
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new access, info[8], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    switch (str_to_num(info))
    {
        case 1: show_preset_menu(id)
        case 2: { g_MapMenuSecond[id] = false; g_MapMenuFirst[id][0] = 0; show_map_menu(id); }
        case 3: save_menu_config(id)
        case 4: load_saved_config(id)
        case 5: show_settings_menu(id)
    }
    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menu_settings_handler(id, menu, item)
{
    if (item == MENU_EXIT || !(get_user_flags(id) & ADMIN_CFG) || !safe_configuration_state(id))
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new access, info[8], label[96], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    switch (str_to_num(info))
    {
        case 1: cycle_format_setting()
        case 2: { menu_destroy(menu); load_runtime_settings(false); show_match_length_menu(id); return PLUGIN_HANDLED; }
        case 3: cycle_ready_setting()
        case 4: { menu_destroy(menu); load_runtime_settings(false); show_min_ready_menu(id); return PLUGIN_HANDLED; }
        case 5: cycle_swap_setting()
        case 6: set_pcvar_num(g_CvarSecondHalfReady, !get_pcvar_num(g_CvarSecondHalfReady))
        case 7: set_pcvar_num(g_CvarPlayout, (get_pcvar_num(g_CvarPlayout) + 1) % 3)
        case 8: set_pcvar_num(g_CvarOvertime, !get_pcvar_num(g_CvarOvertime))
        case 9: set_pcvar_num(g_CvarOvertimeVote, !get_pcvar_num(g_CvarOvertimeVote))
        case 10: cycle_pug_style_setting()
        case 11: set_pcvar_num(g_CvarPugPersist, !get_pcvar_num(g_CvarPugPersist))
        case 12: set_pcvar_num(g_CvarScreenshots, !get_pcvar_num(g_CvarScreenshots))
        case 13: set_pcvar_num(g_CvarScoreIdScreenshots, !get_pcvar_num(g_CvarScoreIdScreenshots))
        case 14: set_pcvar_num(g_CvarScreenshotOnStop, !get_pcvar_num(g_CvarScreenshotOnStop))
        case 15: set_pcvar_num(g_CvarTimeLimitFinishRound, !get_pcvar_num(g_CvarTimeLimitFinishRound))
        case 16: set_pcvar_num(g_CvarPlayoutVoteDefault, !get_pcvar_num(g_CvarPlayoutVoteDefault))
        case 17: cycle_hud_interval_setting()
        case 18: { menu_destroy(menu); client_cmd(id, "messagemode amx_cw_teams"); return PLUGIN_HANDLED; }
        case 19: { menu_destroy(menu); client_cmd(id, "messagemode amx_cw_tags"); return PLUGIN_HANDLED; }
        case 20: { menu_destroy(menu); show_preset_menu(id); return PLUGIN_HANDLED; }
        case 21: { menu_destroy(menu); g_MapMenuSecond[id] = false; g_MapMenuFirst[id][0] = 0; show_map_menu(id); return PLUGIN_HANDLED; }
        case 22: { menu_destroy(menu); save_menu_config(id); return PLUGIN_HANDLED; }
    }
    menu_destroy(menu)
    load_runtime_settings(false)
    show_settings_menu(id)
    return PLUGIN_HANDLED
}

public menu_match_length_handler(id, menu, item)
{
    if (item == MENU_EXIT || !(get_user_flags(id) & ADMIN_CFG) || !safe_configuration_state(id))
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new access, info[8], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    menu_destroy(menu)
    new format[8]
    get_pcvar_string(g_CvarFormat, format, charsmax(format)); strtolower(format)
    if (!equal(info, format, 2))
    {
        load_runtime_settings(false); show_settings_menu(id)
        return PLUGIN_HANDLED
    }
    new value = str_to_num(info[2])
    if (equal(format, "mr")) set_pcvar_num(g_CvarHalfRounds, clamp(value, 1, 100))
    else if (equal(format, "wl")) set_pcvar_num(g_CvarWinRounds, clamp(value, 1, 100))
    else set_pcvar_num(g_CvarTimeLimitMinutes, clamp(value, 1, 180))
    load_runtime_settings(false)
    show_settings_menu(id)
    return PLUGIN_HANDLED
}

public menu_min_ready_handler(id, menu, item)
{
    if (item == MENU_EXIT || !(get_user_flags(id) & ADMIN_CFG) || !safe_configuration_state(id))
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new access, info[8], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    menu_destroy(menu)
    set_pcvar_num(g_CvarMinReady, clamp(str_to_num(info), 1, 32))
    load_runtime_settings(false)
    show_settings_menu(id)
    return PLUGIN_HANDLED
}

public menu_preset_handler(id, menu, item)
{
    if (item == MENU_EXIT || !(get_user_flags(id) & ADMIN_CFG) || !safe_configuration_state(id))
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new access, preset[MAX_PRESET_TOKEN + 1], label[MAX_CATALOG_LABEL + 1], callback
    menu_item_getinfo(menu, item, access, preset, charsmax(preset), label, charsmax(label), callback)
    apply_preset(id, preset)
    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menu_map_handler(id, menu, item)
{
    if (item == MENU_EXIT || !(get_user_flags(id) & ADMIN_CFG) || !safe_configuration_state(id))
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new access, map[MAX_MAP_TOKEN + 1], label[MAX_CATALOG_LABEL + 1], callback
    menu_item_getinfo(menu, item, access, map, charsmax(map), label, charsmax(label), callback)
    menu_destroy(menu)

    if (g_MapMenuSecond[id] && equal(map, "single"))
    {
        commit_menu_maps(id, g_MapMenuFirst[id], "")
        return PLUGIN_HANDLED
    }
    if (!valid_map_token(map))
    {
        cw_console_ml(id, "CW_ERR_CATALOG_MAP")
        return PLUGIN_HANDLED
    }
    if (!g_MapMenuSecond[id])
    {
        copy(g_MapMenuFirst[id], charsmax(g_MapMenuFirst[]), map)
        g_MapMenuSecond[id] = true
        show_map_menu(id)
    }
    else if (equali(map, g_MapMenuFirst[id]))
    {
        cw_console_ml(id, "CW_ERR_MAP_DUPLICATE")
        show_map_menu(id)
    }
    else commit_menu_maps(id, g_MapMenuFirst[id], map)
    return PLUGIN_HANDLED
}

public menu_overtime_vote_handler(id, menu, item)
{
    if (item == MENU_EXIT || g_State != STATE_OVERTIME_VOTE || g_OvertimeVoted[id])
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new identity = identity_for_side(cs_get_user_team(id))
    if (identity < 0)
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new access, info[8], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    g_OvertimeVoted[id] = true
    g_OvertimeVoteChoice[id] = str_to_num(info) == 1 ? 1 : 2
    if (g_OvertimeVoteChoice[id] == 1) g_OvertimeYesVotes++; else g_OvertimeNoVotes++
    cw_chat_ml(id, "CW_VOTE_RECORDED")
    menu_destroy(menu)
    if (overtime_vote_count() >= overtime_eligible_count()) finish_overtime_vote()
    return PLUGIN_HANDLED
}

public menu_playout_vote_handler(id, menu, item)
{
    if (item == MENU_EXIT || g_State != STATE_PLAYOUT_VOTE || g_PlayoutVoted[id])
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    if (identity_for_side(cs_get_user_team(id)) < 0)
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new access, info[8], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    g_PlayoutVoted[id] = true
    g_PlayoutVoteChoice[id] = str_to_num(info) == 1 ? 1 : 2
    if (g_PlayoutVoteChoice[id] == 1) g_PlayoutYesVotes++; else g_PlayoutNoVotes++
    cw_chat_ml(id, "CW_VOTE_RECORDED")
    menu_destroy(menu)
    if (playout_vote_count() >= playout_eligible_count()) finish_playout_vote()
    return PLUGIN_HANDLED
}

public menu_knife_vote_handler(id, menu, item)
{
    if (item == MENU_EXIT || g_State != STATE_KNIFE_VOTE || g_KnifeDecisionMade || g_KnifeVoted[id] || cs_get_user_team(id) != g_KnifeWinningSide)
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new access, info[8], label[32], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    g_KnifeVoted[id] = true
    g_KnifeVoteChoice[id] = str_to_num(info) == 2 ? 2 : 1
    if (g_KnifeVoteChoice[id] == 2) g_KnifeSwapVotes++; else g_KnifeStayVotes++
    cw_chat_ml(id, "CW_VOTE_RECORDED")
    menu_destroy(menu)
    if (knife_vote_count() >= knife_eligible_count()) finish_knife_vote()
    return PLUGIN_HANDLED
}

public event_new_round() { g_RoundResolved = false; }
public event_ct_win() { handle_round_winner(CS_TEAM_CT); }
public event_t_win() { handle_round_winner(CS_TEAM_T); }
public event_round_end()
{
    /* SendAudio normally resolves a winning round before Round_End. Defer the
     * no-winner path so TL still advances when the clock expires on a draw. */
    if (g_State == STATE_LIVE && g_Format == FORMAT_TL && g_TimeLimitExpired && !g_RoundResolved)
    {
        remove_task(TASK_TL_ROUND_END)
        set_task(0.1, "task_finish_tl_draw", TASK_TL_ROUND_END)
    }
}

public task_finish_tl_draw()
{
    if (g_State != STATE_LIVE || g_Format != FORMAT_TL || !g_TimeLimitExpired || g_RoundResolved) return
    g_RoundResolved = true
    write_stats_event("round_draw")
    complete_time_limit_half()
}

public event_player_spawn(id)
{
    if (g_State == STATE_KNIFE && is_user_alive(id)) set_task(0.2, "task_equip_knife", TASK_KNIFE_EQUIP + id)
}

public event_current_weapon(id)
{
    if (g_State != STATE_KNIFE || !is_user_alive(id) || read_data(2) == CSW_KNIFE) return
    strip_user_weapons(id); give_item(id, "weapon_knife"); engclient_cmd(id, "weapon_knife")
}

public touch_knife_weapon(entity, id)
{
    if (g_State == STATE_KNIFE && is_user_alive(id)) return PLUGIN_HANDLED
    return PLUGIN_CONTINUE
}

public event_team_info()
{
    new id = read_data(1)
    if (g_State == STATE_KNIFE_VOTE)
    {
        recompute_knife_votes()
        if (id > 0 && is_user_connected(id) && !is_user_bot(id) && !is_user_hltv(id) && cs_get_user_team(id) == g_KnifeWinningSide && !g_KnifeVoted[id]) show_knife_vote_menu(id)
        new eligible = knife_eligible_count()
        if (!eligible || knife_vote_count() >= eligible) finish_knife_vote()
    }
    else if (g_State == STATE_OVERTIME_VOTE)
    {
        recompute_overtime_votes()
        if (id > 0 && is_user_connected(id) && identity_for_side(cs_get_user_team(id)) >= 0 && !g_OvertimeVoted[id]) show_overtime_vote_menu(id)
        new eligible = overtime_eligible_count()
        if (!eligible || overtime_vote_count() >= eligible) finish_overtime_vote()
    }
    else if (g_State == STATE_PLAYOUT_VOTE)
    {
        recompute_playout_votes()
        if (id > 0 && is_user_connected(id) && identity_for_side(cs_get_user_team(id)) >= 0 && !g_PlayoutVoted[id]) show_playout_vote_menu(id)
        new eligible = playout_eligible_count()
        if (!eligible || playout_vote_count() >= eligible) finish_playout_vote()
    }
}

public task_equip_knife(taskId)
{
    new id = taskId - TASK_KNIFE_EQUIP
    if (g_State != STATE_KNIFE || !is_user_alive(id)) return
    strip_user_weapons(id); give_item(id, "weapon_knife"); engclient_cmd(id, "weapon_knife")
}

public task_restart_first() { server_cmd("sv_restart 1"); announce_ml("CW_LO3_RESTART", 1); }
public task_restart_second() { server_cmd("sv_restart 1"); announce_ml("CW_LO3_RESTART", 2); }
public task_restart_third() { server_cmd("sv_restart 1"); announce_ml("CW_LO3_RESTART", 3); }

public task_finish_lo3()
{
    g_Lo3Running = false
    if (g_CaptureHalfBaselineAfterLo3)
    {
        capture_half_player_baseline()
        g_CaptureHalfBaselineAfterLo3 = false
    }
    if (g_ResetTlTimerAfterLo3 && g_Format == FORMAT_TL && !g_InOvertime) schedule_time_limit_half()
    g_ResetTlTimerAfterLo3 = false
    g_RoundResolved = false; set_cw_state(STATE_LIVE)
    announce_ml("CW_MATCH_LIVE")
    audit_event("lo3_complete")
}

public task_begin_next_half()
{
    if (g_State != STATE_HALFTIME) return
    if (automatic_swaps_enabled()) { swap_players(); toggle_team_a_side(); }
    g_RoundsThisHalf = 0
    g_HalfStartA = g_TeamAScore; g_HalfStartB = g_TeamBScore
    execute_phase_config(g_InOvertime ? g_CvarOvertimeConfig : g_CvarMatchConfig, g_InOvertime ? "overtime" : "match")
    if (g_InOvertime) set_cvar_num("mp_startmoney", clamp(series_managed_number(MC_OT_MONEY, g_CvarOvertimeMoney), 800, 16000))
    set_scoreboard_team_score("CT", 0); set_scoreboard_team_score("TERRORIST", 0)
    if (g_Half == 2 && series_managed_number(MC_SECOND_READY, g_CvarSecondHalfReady))
    {
        reset_ready_players(); set_cw_state(STATE_HALF_READY)
        announce_ml("CW_SECOND_READY_GATE")
        return
    }
    start_configured_half()
}

stock start_configured_half()
{
    emit_match_event("half_start"); g_CaptureHalfBaselineAfterLo3 = true; begin_lo3(false, true)
    new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    announce_ml("CW_HALF_START", g_Half, labelA, total_score_a(), total_score_b(), labelB)
}

stock resume_ready_half()
{
    if (g_State != STATE_HALF_READY) return
    start_configured_half()
    audit_event("second_half_ready")
}

public task_return_to_warmup() { start_warmup(false); }
public task_finish_knife_vote() { finish_knife_vote(); }
public task_finish_overtime_vote() { finish_overtime_vote(); }
public task_finish_playout_vote() { finish_playout_vote(); }

public task_status_hud()
{
    refresh_branding(false)
    if (series_extra_number(SC_HUD_ANNOUNCEMENTS, g_CvarHudAnnouncements))
    {
        new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
        get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
        set_hudmessage(0, 180, 255, -1.0, 0.10, 0, 0.0, 3.0, 0.1, 0.2, -1)
        for (new id = 1; id <= MAX_PLAYERS; id++)
        {
            if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id)) continue
            if (g_State == STATE_WARMUP || g_State == STATE_HALF_READY)
                show_hudmessage(id, "%s %L", g_ChatPrefix, id, "CW_HUD_READY", ready_count(), required_ready_count())
            else if (g_State == STATE_LIVE || g_State == STATE_HALFTIME || g_State == STATE_OVERTIME_VOTE || g_State == STATE_PLAYOUT_VOTE)
                show_hudmessage(id, "%s %L", g_ChatPrefix, id, "CW_HUD_SCORE", g_MapNumber, labelA, g_TeamAScore, g_TeamBScore, labelB)
        }
    }
    schedule_status_hud()
}

public task_scoreid_snapshot(taskId)
{
    new id = taskId - TASK_SCOREID_SNAPSHOT
    if (is_user_connected(id) && g_ScoreIdSnapshotAuthorized[id]) client_cmd(id, "snapshot")
    g_ScoreIdSnapshotAuthorized[id] = false
}

public task_time_limit_half()
{
    if (g_State != STATE_LIVE || g_Format != FORMAT_TL) return
    if (series_managed_number(MC_TL_FINISH_ROUND, g_CvarTimeLimitFinishRound))
    {
        g_TimeLimitExpired = true
        announce_ml("CW_TL_FINISH_ROUND")
        return
    }
    complete_time_limit_half()
}

stock complete_time_limit_half()
{
    if (g_State != STATE_LIVE || g_Format != FORMAT_TL) return
    g_TimeLimitExpired = false
    emit_match_event("half_end"); write_stats_event("half_end")
    if (g_Half == 1) { take_match_screenshots(); g_Half = 2; begin_halftime(); }
    else complete_regulation_map(true)
}

public task_change_map()
{
    if (!g_MapChangePending || !valid_map_token(g_Map2))
    {
        announce_ml("CW_ERR_MAP_TRANSITION")
        g_MapChangePending = false; clear_crossmap_state(); finish_match(false); return
    }
    /* g_Map2 was strictly tokenized and verified with is_map_valid. */
    server_cmd("changelevel %s", g_Map2)
}

public task_resume_crossmap()
{
    new active[4], recoveryPending[4]
    get_localinfo(LI_RECOVERY_PENDING, recoveryPending, charsmax(recoveryPending))
    if (equal(recoveryPending, "1"))
    {
        if (!restore_rejected_crossmap_state())
            log_amx("Cross-map baseline recovery remains pending; unresolved evidence was preserved")
        else
        {
            finalize_crossmap_recovery()
            log_amx("Completed pending cross-map baseline recovery; stale match state was discarded")
        }
        return
    }

    get_localinfo(LI_ACTIVE, active, charsmax(active))
    if (!equal(active, "1"))
    {
        if (!resume_persistent_pug()) clear_series_manifest_storage()
        return
    }

    if (!parse_crossmap_envelope())
    {
        log_amx("Rejected stale or invalid cross-map match state")
        new bool:recoveryComplete = restore_rejected_crossmap_state()
        if (!recoveryComplete)
        {
            log_amx("Cross-map baseline recovery is incomplete; unresolved evidence was preserved")
            clear_crossmap_state(true)
        }
        else finalize_crossmap_recovery()
        return
    }
    commit_crossmap_envelope()
    clear_crossmap_state()
    apply_environment(false); execute_phase_config(g_CvarMatchConfig, "match")
    set_cw_state(STATE_LIVE); emit_match_event("half_start"); write_stats_event("map_resume")
    g_CaptureHalfBaselineAfterLo3 = true
    start_client_demos(); begin_lo3(true, true)
    announce_ml("CW_MAP_RESUMED", g_MatchId, g_Map2)
}

stock bool:mode_enabled(id)
{
    if (crossmap_recovery_pending())
    {
        cw_console_ml(id, "CW_ERR_RECOVERY_PENDING")
        return false
    }
    if (get_pcvar_num(g_CvarEnabled)) return true
    cw_console_ml(id, "CW_ERR_DISABLED")
    return false
}

stock bool:map_transition_blocks_mutation(id, bool:chatFeedback)
{
    if (!g_MapChangePending) return false
    if (chatFeedback && id > 0) cw_chat_ml(id, "CW_ERR_MAP_CHANGE_PENDING")
    else cw_console_ml(id, "CW_ERR_MAP_CHANGE_PENDING")
    return true
}

stock show_control_menu(id)
{
    refresh_branding(false)
    new menu = menu_create(g_DisplayName, "menu_control_handler"), label[64]
    if (g_MapChangePending)
    {
        ml_text(id, "CW_MENU_STATUS", label, charsmax(label)); menu_additem(menu, label, "status")
        ml_text(id, "CW_MENU_READY_LIST", label, charsmax(label)); menu_additem(menu, label, "ready_list")
        menu_setprop(menu, MPROP_EXIT, MEXIT_ALL); menu_display(id, menu)
        return
    }
    if (g_State == STATE_OFF || g_State == STATE_WARMUP || g_State == STATE_KNIFE || g_State == STATE_KNIFE_VOTE)
    {
        ml_text(id, "CW_MENU_WARMUP", label, charsmax(label)); menu_additem(menu, label, "warmup")
        if (g_State == STATE_OFF || g_State == STATE_WARMUP)
        {
            ml_text(id, "CW_MENU_KNIFE", label, charsmax(label)); menu_additem(menu, label, "knife")
        }
        ml_text(id, "CW_MENU_LIVE", label, charsmax(label)); menu_additem(menu, label, "live")
    }
    else if (g_State == STATE_HALF_READY)
    {
        ml_text(id, "CW_MENU_RESUME", label, charsmax(label)); menu_additem(menu, label, "resume")
    }

    if (g_State == STATE_LIVE)
    {
        if (!g_Lo3Running)
        {
            ml_text(id, "CW_MENU_RELO3", label, charsmax(label)); menu_additem(menu, label, "relo3")
        }
        ml_text(id, "CW_MENU_RESTART_HALF", label, charsmax(label)); menu_additem(menu, label, "restart_half")
    }
    if (g_State != STATE_OFF)
    {
        ml_text(id, "CW_MENU_RESTART_MATCH", label, charsmax(label)); menu_additem(menu, label, "restart_match")
    }
    ml_text(id, "CW_MENU_STATUS", label, charsmax(label)); menu_additem(menu, label, "status")
    ml_text(id, "CW_MENU_READY_LIST", label, charsmax(label)); menu_additem(menu, label, "ready_list")
    if (control_swap_allowed())
    {
        ml_text(id, "CW_MENU_SWAP", label, charsmax(label)); menu_additem(menu, label, "swap")
    }
    if (get_pcvar_num(g_CvarPugMode) && (g_State == STATE_OFF || g_State == STATE_WARMUP))
    {
        ml_text(id, "CW_MENU_PUG", label, charsmax(label)); menu_additem(menu, label, "pug")
    }
    if (g_State == STATE_OFF || g_State == STATE_WARMUP)
    {
        ml_text(id, "CW_MENU_CONFIG", label, charsmax(label)); menu_additem(menu, label, "config")
    }
    if (g_State != STATE_OFF)
    {
        ml_text(id, "CW_MENU_STOP", label, charsmax(label)); menu_additem(menu, label, "stop")
    }
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
    menu_display(id, menu)
}

stock bool:control_swap_allowed()
{
    if (g_Lo3Running) return false
    return g_State == STATE_WARMUP || g_State == STATE_KNIFE || g_State == STATE_LIVE
}

stock show_restart_match_confirmation(id)
{
    if (g_State == STATE_OFF)
    {
        cw_chat_ml(id, "CW_ERR_RESTART_OFF")
        return
    }
    new title[96], label[64]
    formatex(title, charsmax(title), "%L", id, "CW_CONFIRM_RESTART_MATCH")
    new menu = menu_create(title, "menu_restart_confirm_handler")
    ml_text(id, "CW_CONFIRM_YES", label, charsmax(label)); menu_additem(menu, label, "yes")
    ml_text(id, "CW_CONFIRM_NO", label, charsmax(label)); menu_additem(menu, label, "no")
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL); menu_display(id, menu)
}

stock show_stop_confirmation(id)
{
    if (g_State == STATE_OFF) return
    new title[96], label[64]
    formatex(title, charsmax(title), "%L", id, "CW_CONFIRM_STOP")
    new menu = menu_create(title, "menu_stop_confirmation_handler")
    ml_text(id, "CW_CONFIRM_YES", label, charsmax(label)); menu_additem(menu, label, "yes")
    ml_text(id, "CW_CONFIRM_NO", label, charsmax(label)); menu_additem(menu, label, "no")
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL); menu_display(id, menu)
}

stock show_ready_list_menu(id)
{
    new title[96], label[96], players[32], count, callback
    new ReadyMode:listMode = ready_list_mode()
    get_players(players, count, "ch")
    if (listMode == READY_TEAM)
    {
        new readyTeams
        if (g_TeamReady[0]) readyTeams++
        if (g_TeamReady[1]) readyTeams++
        formatex(title, charsmax(title), "%L", id, "CW_READY_LIST_TEAM_TITLE", readyTeams)
    }
    else if (listMode == READY_ADMIN) formatex(title, charsmax(title), "%L", id, "CW_READY_LIST_ADMIN_TITLE")
    else formatex(title, charsmax(title), "%L", id, "CW_READY_LIST_TITLE", ready_count(), required_ready_count())
    new menu = menu_create(title, "menu_ready_list_handler")
    callback = menu_makecallback("menu_ready_list_item_callback")
    new active
    for (new i = 0; i < count; i++)
    {
        new player = players[i], CsTeams:team = cs_get_user_team(player)
        if (team != CS_TEAM_T && team != CS_TEAM_CT) continue
        new name[32], safeName[32]
        get_user_name(player, name, charsmax(name)); sanitize_menu_text(name, safeName, charsmax(safeName))
        new bool:isReady = listMode == READY_TEAM ? g_TeamReady[identity_for_side(team)] : g_Ready[player]
        if (listMode == READY_ADMIN)
        {
            formatex(label, charsmax(label), "%s [%L] - %L", safeName, id, team == CS_TEAM_CT ? "CW_SIDE_CT" : "CW_SIDE_T", id, "CW_READY_ADMIN_VALUE")
        }
        else
        {
            formatex(label, charsmax(label), "%s [%L] - %L", safeName, id, team == CS_TEAM_CT ? "CW_SIDE_CT" : "CW_SIDE_T", id, isReady ? "CW_READY_LIST_READY" : "CW_READY_LIST_NOT_READY")
        }
        menu_additem(menu, label, "", 0, callback); active++
    }
    if (!active)
    {
        ml_text(id, "CW_READY_LIST_EMPTY", label, charsmax(label)); menu_additem(menu, label, "", 0, callback)
    }
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL); menu_display(id, menu)
}

stock ReadyMode:ready_list_mode()
{
    if (g_State != STATE_OFF) return g_ReadyMode
    new value[16]
    get_pcvar_string(g_CvarReadyMode, value, charsmax(value)); strtolower(value)
    if (equal(value, "team")) return READY_TEAM
    if (equal(value, "admin")) return READY_ADMIN
    return READY_PLAYER
}

stock show_config_menu(id)
{
    new title[96], label[64]
    refresh_branding(false)
    formatex(title, charsmax(title), "%s: %L", g_DisplayName, id, "CW_CONFIG_TITLE")
    new menu = menu_create(title, "menu_config_handler")
    ml_text(id, "CW_CONFIG_PRESET", label, charsmax(label)); menu_additem(menu, label, "1")
    ml_text(id, "CW_CONFIG_MAPS", label, charsmax(label)); menu_additem(menu, label, "2")
    ml_text(id, "CW_CONFIG_SAVE", label, charsmax(label)); menu_additem(menu, label, "3")
    ml_text(id, "CW_CONFIG_LOAD", label, charsmax(label)); menu_additem(menu, label, "4")
    ml_text(id, "CW_CONFIG_SETTINGS", label, charsmax(label)); menu_additem(menu, label, "5")
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL); menu_display(id, menu)
}

stock show_settings_menu(id)
{
    new title[96], label[96], value[24]
    load_runtime_settings(false)
    refresh_branding(false); formatex(title, charsmax(title), "%s: %L", g_DisplayName, id, "CW_SETTINGS_TITLE")
    new menu = menu_create(title, "menu_settings_handler")
    get_pcvar_string(g_CvarFormat, value, charsmax(value)); formatex(label, charsmax(label), "%L: %s", id, "CW_SETTING_FORMAT", value); menu_additem(menu, label, "1")
    formatex(label, charsmax(label), "%L: %L", id, "CW_SETTING_MATCH_LENGTH", id, g_Format == FORMAT_TL ? "CW_MINUTES_VALUE" : "CW_ROUNDS_VALUE", current_match_length()); menu_additem(menu, label, "2")
    get_pcvar_string(g_CvarReadyMode, value, charsmax(value)); strtolower(value)
    if (equal(value, "team")) ml_text(id, "CW_READY_TEAM", value, charsmax(value))
    else if (equal(value, "admin")) ml_text(id, "CW_READY_ADMIN_VALUE", value, charsmax(value))
    else ml_text(id, "CW_READY_PLAYER", value, charsmax(value))
    formatex(label, charsmax(label), "%L: %s", id, "CW_SETTING_READY", value); menu_additem(menu, label, "3")
    formatex(label, charsmax(label), "%L: %d", id, "CW_SETTING_MIN_READY", get_pcvar_num(g_CvarMinReady)); menu_additem(menu, label, "4")
    get_pcvar_string(g_CvarSwapPolicy, value, charsmax(value)); strtolower(value)
    ml_text(id, equal(value, "off") ? "CW_SWAP_OFF" : "CW_SWAP_HALVES", value, charsmax(value))
    formatex(label, charsmax(label), "%L: %s", id, "CW_SETTING_SWAP", value); menu_additem(menu, label, "5")
    formatex(label, charsmax(label), "%L: %L", id, "CW_SETTING_SECOND_READY", id, get_pcvar_num(g_CvarSecondHalfReady) ? "CW_ON" : "CW_OFF"); menu_additem(menu, label, "6")
    switch (get_pcvar_num(g_CvarPlayout))
    {
        case 1: ml_text(id, "CW_PLAYOUT_ALWAYS", value, charsmax(value))
        case 2: ml_text(id, "CW_PLAYOUT_VOTE_VALUE", value, charsmax(value))
        default: ml_text(id, "CW_PLAYOUT_CLINCH", value, charsmax(value))
    }
    formatex(label, charsmax(label), "%L: %s", id, "CW_SETTING_PLAYOUT", value); menu_additem(menu, label, "7")
    formatex(label, charsmax(label), "%L: %L", id, "CW_SETTING_OVERTIME", id, get_pcvar_num(g_CvarOvertime) ? "CW_ON" : "CW_OFF"); menu_additem(menu, label, "8")
    formatex(label, charsmax(label), "%L: %L", id, "CW_SETTING_OT_VOTE", id, get_pcvar_num(g_CvarOvertimeVote) ? "CW_ON" : "CW_OFF"); menu_additem(menu, label, "9")
    get_pcvar_string(g_CvarPugStyle, value, charsmax(value)); strtolower(value)
    ml_text(id, equal(value, "manual") ? "CW_PUG_MANUAL" : "CW_PUG_RANDOM", value, charsmax(value))
    formatex(label, charsmax(label), "%L: %s", id, "CW_SETTING_PUG_STYLE", value); menu_additem(menu, label, "10")
    formatex(label, charsmax(label), "%L: %L", id, "CW_SETTING_PUG_PERSIST", id, get_pcvar_num(g_CvarPugPersist) ? "CW_ON" : "CW_OFF"); menu_additem(menu, label, "11")
    formatex(label, charsmax(label), "%L: %L", id, "CW_SETTING_SCREENSHOTS", id, get_pcvar_num(g_CvarScreenshots) ? "CW_ON" : "CW_OFF"); menu_additem(menu, label, "12")
    formatex(label, charsmax(label), "%L: %L", id, "CW_SETTING_ID_SCREENSHOT", id, get_pcvar_num(g_CvarScoreIdScreenshots) ? "CW_ON" : "CW_OFF"); menu_additem(menu, label, "13")
    formatex(label, charsmax(label), "%L: %L", id, "CW_SETTING_STOP_SCREENSHOT", id, get_pcvar_num(g_CvarScreenshotOnStop) ? "CW_ON" : "CW_OFF"); menu_additem(menu, label, "14")
    formatex(label, charsmax(label), "%L: %L", id, "CW_SETTING_TL_FINISH_ROUND", id, get_pcvar_num(g_CvarTimeLimitFinishRound) ? "CW_ON" : "CW_OFF"); menu_additem(menu, label, "15")
    formatex(label, charsmax(label), "%L: %L", id, "CW_SETTING_PLAYOUT_DEFAULT", id, get_pcvar_num(g_CvarPlayoutVoteDefault) ? "CW_PLAYOUT_DEFAULT_CONTINUE" : "CW_PLAYOUT_DEFAULT_END"); menu_additem(menu, label, "16")
    formatex(label, charsmax(label), "%L: %L", id, "CW_SETTING_HUD_INTERVAL", id, "CW_SECONDS", get_pcvar_num(g_CvarHudInterval)); menu_additem(menu, label, "17")
    ml_text(id, "CW_SETTING_TEAMS", label, charsmax(label)); menu_additem(menu, label, "18")
    ml_text(id, "CW_SETTING_TAGS", label, charsmax(label)); menu_additem(menu, label, "19")
    ml_text(id, "CW_CONFIG_PRESET", label, charsmax(label)); menu_additem(menu, label, "20")
    ml_text(id, "CW_CONFIG_MAPS", label, charsmax(label)); menu_additem(menu, label, "21")
    ml_text(id, "CW_CONFIG_SAVE", label, charsmax(label)); menu_additem(menu, label, "22")
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL); menu_display(id, menu)
}

stock current_match_length()
{
    if (g_Format == FORMAT_WL) return get_pcvar_num(g_CvarWinRounds)
    if (g_Format == FORMAT_TL) return get_pcvar_num(g_CvarTimeLimitMinutes)
    return get_pcvar_num(g_CvarHalfRounds)
}

stock show_match_length_menu(id)
{
    if (!safe_configuration_state(id)) return
    new title[96], label[64], info[8], current = current_match_length()
    formatex(title, charsmax(title), "%L", id, "CW_MATCH_LENGTH_TITLE")
    new menu = menu_create(title, "menu_match_length_handler")
    if (g_Format == FORMAT_MR)
    {
        for (new i = 0; i < sizeof g_MrLengthChoices; i++) add_match_length_item(id, menu, g_MrLengthChoices[i], current, "mr")
    }
    else if (g_Format == FORMAT_WL)
    {
        for (new i = 0; i < sizeof g_WlLengthChoices; i++) add_match_length_item(id, menu, g_WlLengthChoices[i], current, "wl")
    }
    else
    {
        for (new i = 0; i < sizeof g_TlLengthChoices; i++) add_match_length_item(id, menu, g_TlLengthChoices[i], current, "tl")
    }
    if (!match_length_choice_exists(current))
    {
        formatex(info, charsmax(info), "%s%d", g_Format == FORMAT_MR ? "mr" : (g_Format == FORMAT_WL ? "wl" : "tl"), current)
        formatex(label, charsmax(label), "%L", id, g_Format == FORMAT_TL ? "CW_MINUTES_CURRENT" : "CW_ROUNDS_CURRENT", current)
        menu_additem(menu, label, info)
    }
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL); menu_display(id, menu)
}

stock add_match_length_item(id, menu, value, current, const format[])
{
    new label[64], info[8]
    formatex(info, charsmax(info), "%s%d", format, value)
    formatex(label, charsmax(label), "%L", id, equal(format, "tl") ? (value == current ? "CW_MINUTES_CURRENT" : "CW_MINUTES_CHOICE") : (value == current ? "CW_ROUNDS_CURRENT" : "CW_ROUNDS_CHOICE"), value)
    menu_additem(menu, label, info)
}

stock bool:match_length_choice_exists(value)
{
    if (g_Format == FORMAT_MR)
    {
        for (new i = 0; i < sizeof g_MrLengthChoices; i++) if (g_MrLengthChoices[i] == value) return true
    }
    else if (g_Format == FORMAT_WL)
    {
        for (new i = 0; i < sizeof g_WlLengthChoices; i++) if (g_WlLengthChoices[i] == value) return true
    }
    else
    {
        for (new i = 0; i < sizeof g_TlLengthChoices; i++) if (g_TlLengthChoices[i] == value) return true
    }
    return false
}

stock show_min_ready_menu(id)
{
    if (!safe_configuration_state(id)) return
    new title[96], label[64], info[8], current = get_pcvar_num(g_CvarMinReady)
    formatex(title, charsmax(title), "%L", id, "CW_MIN_READY_TITLE")
    new menu = menu_create(title, "menu_min_ready_handler")
    for (new i = 0; i < sizeof g_MinReadyChoices; i++)
    {
        num_to_str(g_MinReadyChoices[i], info, charsmax(info))
        formatex(label, charsmax(label), "%L", id, g_MinReadyChoices[i] == current ? "CW_PLAYERS_CURRENT" : "CW_PLAYERS_CHOICE", g_MinReadyChoices[i])
        menu_additem(menu, label, info)
    }
    if (!min_ready_choice_exists(current))
    {
        num_to_str(current, info, charsmax(info))
        formatex(label, charsmax(label), "%L", id, "CW_PLAYERS_CURRENT", current)
        menu_additem(menu, label, info)
    }
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL); menu_display(id, menu)
}

stock bool:min_ready_choice_exists(value)
{
    for (new i = 0; i < sizeof g_MinReadyChoices; i++) if (g_MinReadyChoices[i] == value) return true
    return false
}

stock cycle_format_setting()
{
    new value[8]
    get_pcvar_string(g_CvarFormat, value, charsmax(value)); strtolower(value)
    if (equal(value, "mr")) set_pcvar_string(g_CvarFormat, "wl")
    else if (equal(value, "wl")) set_pcvar_string(g_CvarFormat, "tl")
    else set_pcvar_string(g_CvarFormat, "mr")
}

stock cycle_ready_setting()
{
    new value[16]
    get_pcvar_string(g_CvarReadyMode, value, charsmax(value)); strtolower(value)
    if (equal(value, "player")) set_pcvar_string(g_CvarReadyMode, "team")
    else if (equal(value, "team")) set_pcvar_string(g_CvarReadyMode, "admin")
    else set_pcvar_string(g_CvarReadyMode, "player")
}

stock cycle_swap_setting()
{
    new value[16]
    get_pcvar_string(g_CvarSwapPolicy, value, charsmax(value)); strtolower(value)
    set_pcvar_string(g_CvarSwapPolicy, equal(value, "halves") ? "off" : "halves")
}

stock cycle_pug_style_setting()
{
    new value[16]
    get_pcvar_string(g_CvarPugStyle, value, charsmax(value)); strtolower(value)
    set_pcvar_string(g_CvarPugStyle, equal(value, "random") ? "manual" : "random")
}

stock cycle_hud_interval_setting()
{
    new value = get_pcvar_num(g_CvarHudInterval)
    if (value <= 0) set_pcvar_num(g_CvarHudInterval, 5)
    else if (value <= 5) set_pcvar_num(g_CvarHudInterval, 10)
    else if (value <= 10) set_pcvar_num(g_CvarHudInterval, 15)
    else if (value <= 15) set_pcvar_num(g_CvarHudInterval, 30)
    else set_pcvar_num(g_CvarHudInterval, 0)
}

stock show_preset_menu(id)
{
    if (!safe_configuration_state(id)) return
    new configsDir[128], path[192]
    get_configsdir(configsDir, charsmax(configsDir))
    formatex(path, charsmax(path), "%s/kgb_clan_war_presets.ini", configsDir)
    if (!file_exists(path))
    {
        cw_console_ml(id, "CW_ERR_PRESET_CATALOG")
        return
    }

    new title[96]
    refresh_branding(false); formatex(title, charsmax(title), "%s: %L", g_DisplayName, id, "CW_PRESET_TITLE")
    new menu = menu_create(title, "menu_preset_handler")
    new line[128], length, token[MAX_PRESET_TOKEN + 1], label[MAX_CATALOG_LABEL + 1], count
    for (new lineNumber = 0; read_file(path, lineNumber, line, charsmax(line), length); lineNumber++)
    {
        trim(line)
        if (!line[0] || line[0] == ';' || line[0] == '#') continue
        strtok(line, token, charsmax(token), label, charsmax(label), '|')
        trim(token); trim(label); strtolower(token)
        if (!valid_simple_token(token, MAX_PRESET_TOKEN) || !valid_display_token(label, MAX_CATALOG_LABEL) || !preset_exists(token)) continue
        menu_additem(menu, label, token); count++
    }
    if (!count)
    {
        menu_destroy(menu); cw_console_ml(id, "CW_ERR_PRESET_EMPTY"); return
    }
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL); menu_display(id, menu)
}

stock show_map_menu(id)
{
    if (!safe_configuration_state(id)) return
    new configsDir[128], path[192]
    get_configsdir(configsDir, charsmax(configsDir))
    formatex(path, charsmax(path), "%s/kgb_clan_war_maps.ini", configsDir)
    if (!file_exists(path))
    {
        cw_console_ml(id, "CW_ERR_MAP_CATALOG")
        return
    }

    new title[96]
    refresh_branding(false)
    formatex(title, charsmax(title), "%s: %L", g_DisplayName, id, g_MapMenuSecond[id] ? "CW_MAP_SECOND_TITLE" : "CW_MAP_FIRST_TITLE")
    new menu = menu_create(title, "menu_map_handler"), count
    if (g_MapMenuSecond[id])
    {
        new singleLabel[64]
        ml_text(id, "CW_MAP_SINGLE", singleLabel, charsmax(singleLabel)); menu_additem(menu, singleLabel, "single")
    }
    new line[96], length, token[MAX_MAP_TOKEN + 1], label[MAX_CATALOG_LABEL + 1]
    for (new lineNumber = 0; read_file(path, lineNumber, line, charsmax(line), length); lineNumber++)
    {
        trim(line)
        if (!line[0] || line[0] == ';' || line[0] == '#') continue
        strtok(line, token, charsmax(token), label, charsmax(label), '|')
        trim(token); trim(label); strtolower(token)
        if (!label[0]) copy(label, charsmax(label), token)
        if (!valid_map_token(token) || !valid_display_token(label, MAX_CATALOG_LABEL)) continue
        menu_additem(menu, label, token); count++
    }
    if (!count)
    {
        menu_destroy(menu); cw_console_ml(id, "CW_ERR_MAP_EMPTY"); return
    }
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL); menu_display(id, menu)
}

stock bool:safe_configuration_state(id)
{
    if (crossmap_recovery_pending())
    {
        cw_console_ml(id, "CW_ERR_RECOVERY_PENDING")
        return false
    }
    if (g_State == STATE_OFF || g_State == STATE_WARMUP) return true
    cw_console_ml(id, "CW_ERR_CONFIG_STATE")
    return false
}

stock bool:preset_exists(const preset[])
{
    new configsDir[128], path[224]
    get_configsdir(configsDir, charsmax(configsDir))
    formatex(path, charsmax(path), "%s/kgb_clan_war/presets/%s.cfg", configsDir, preset)
    return bool:file_exists(path)
}

stock bool:preset_config_valid(const preset[])
{
    if (!valid_simple_token(preset, MAX_PRESET_TOKEN) || !preset_exists(preset)) return false
    new configsDir[128], path[224]
    get_configsdir(configsDir, charsmax(configsDir))
    formatex(path, charsmax(path), "%s/kgb_clan_war/presets/%s.cfg", configsDir, preset)
    return managed_config_file_valid(path, true)
}

stock bool:apply_preset(id, const preset[])
{
    if (!safe_configuration_state(id)) return false
    if (!valid_simple_token(preset, MAX_PRESET_TOKEN) || !preset_exists(preset))
    {
        cw_console_ml(id, "CW_ERR_PRESET_NAME")
        return false
    }
    new configsDir[128], path[224]
    get_configsdir(configsDir, charsmax(configsDir))
    formatex(path, charsmax(path), "%s/kgb_clan_war/presets/%s.cfg", configsDir, preset)
    if (!preset_config_valid(preset) || !apply_managed_config_file(path, true))
    {
        cw_console_ml(id, "CW_ERR_PRESET_INVALID")
        return false
    }
    cw_console_ml(id, "CW_PRESET_APPLIED", preset); audit_event("preset_applied")
    return true
}

stock commit_menu_maps(id, const map1[], const map2[])
{
    set_pcvar_string(g_CvarMap1, map1); set_pcvar_string(g_CvarMap2, map2)
    set_pcvar_num(g_CvarMapCount, map2[0] ? 2 : 1)
    load_runtime_settings(false)
    g_MapMenuSecond[id] = false; g_MapMenuFirst[id][0] = 0
    cw_console_ml(id, "CW_MAPS_CONFIGURED", map1, map2[0] ? ", " : "", map2)
}

stock managed_config_index(const name[])
{
    for (new i = 0; i < sizeof g_ManagedConfigNames; i++) if (equali(name, g_ManagedConfigNames[i])) return i
    return -1
}

stock bool:preset_config_index_allowed(index)
{
    switch (index)
    {
        case MC_FORMAT, MC_HALF_ROUNDS, MC_PLAYOUT, MC_PLAYOUT_DEFAULT, MC_TL_FINISH_ROUND,
            MC_OVERTIME, MC_OT_MAX, MC_OT_VOTE, MC_OT_HALF_ROUNDS, MC_OT_MONEY,
            MC_OT_VOTE_SECONDS, MC_OT_VOTE_DEFAULT, MC_READY_MODE, MC_MIN_READY,
            MC_SECOND_READY, MC_SWAP_POLICY, MC_PUG_MODE, MC_PUG_STYLE, MC_PUG_PERSIST: return true
    }
    return false
}

stock bool:parse_uint_exact(const value[], minimum, maximum, &output)
{
    if (!value[0]) return false
    new number
    for (new index = 0; value[index]; index++)
    {
        if (value[index] < '0' || value[index] > '9') return false
        number = number * 10 + value[index] - '0'
        if (number > maximum) return false
    }
    new canonical[16]
    num_to_str(number, canonical, charsmax(canonical))
    if (!equal(value, canonical) || number < minimum) return false
    output = number
    return true
}

stock bool:parse_bool_exact(const value[], &output)
{
    return parse_uint_exact(value, 0, 1, output)
}

stock bool:parse_legacy_tristate(const value[], &output)
{
    if (equal(value, "-1")) { output = -1; return true; }
    return parse_bool_exact(value, output)
}

stock bool:valid_match_id_exact(const value[])
{
    if (strlen(value) != 15 || value[8] != '_') return false
    for (new index = 0; index < 15; index++)
    {
        if (index == 8) continue
        if (value[index] < '0' || value[index] > '9') return false
    }
    return true
}

stock bool:valid_snapshot_value(const value[], maximum)
{
    if (strlen(value) > maximum) return false
    for (new index = 0; value[index]; index++) if (value[index] < 32 || value[index] > 126) return false
    return true
}

stock bool:managed_config_value_valid(index, const value[])
{
    switch (index)
    {
        case MC_DISPLAY_NAME: return valid_display_token(value, MAX_DISPLAY_NAME)
        case MC_CHAT_PREFIX: return valid_display_token(value, MAX_CHAT_PREFIX)
        case MC_TEAM_A_NAME, MC_TEAM_B_NAME: return valid_display_token(value, MAX_TEAM_NAME)
        case MC_TEAM_A_TAG, MC_TEAM_B_TAG: return !value[0] || valid_display_token(value, MAX_TEAM_TAG)
        case MC_FORMAT: return equali(value, "mr") || equali(value, "tl") || equali(value, "wl")
        case MC_READY_MODE: return equali(value, "player") || equali(value, "team") || equali(value, "admin")
        case MC_SWAP_POLICY: return equali(value, "halves") || equali(value, "off")
        case MC_PUG_STYLE: return equali(value, "random") || equali(value, "manual")
        case MC_MAP1, MC_MAP2: return !value[0] || valid_map_token(value)
    }
    new number
    switch (index)
    {
        case MC_PLAYOUT: return parse_uint_exact(value, 0, 2, number)
        case MC_MAP_COUNT: return parse_uint_exact(value, 1, 2, number)
        case MC_HALF_ROUNDS, MC_WIN_ROUNDS: return parse_uint_exact(value, 1, 100, number)
        case MC_TIME_LIMIT: return parse_uint_exact(value, 1, 180, number)
        case MC_OT_MAX: return parse_uint_exact(value, 0, 100, number)
        case MC_OT_HALF_ROUNDS: return parse_uint_exact(value, 1, 20, number)
        case MC_OT_MONEY: return parse_uint_exact(value, 800, 16000, number)
        case MC_OT_VOTE_SECONDS: return parse_uint_exact(value, 5, 30, number)
        case MC_MIN_READY: return parse_uint_exact(value, 1, 32, number)
        case MC_HUD_INTERVAL:
        {
            if (!parse_uint_exact(value, 0, 60, number)) return false
            return number == 0 || number >= 3
        }
        case MC_PLAYOUT_DEFAULT, MC_TL_FINISH_ROUND, MC_OVERTIME, MC_OT_VOTE, MC_OT_VOTE_DEFAULT,
            MC_SECOND_READY, MC_PUG_MODE, MC_PUG_PERSIST, MC_SCREENSHOTS,
            MC_SCOREID_SCREENSHOTS, MC_SCREENSHOT_ON_STOP: return parse_bool_exact(value, number)
    }
    return false
}

stock series_manifest_count()
{
    return sizeof g_ManagedConfigNames + sizeof g_SeriesExtraConfigNames
}

stock series_manifest_cvar_name(index, output[], length)
{
    if (index < sizeof g_ManagedConfigNames) copy(output, length, g_ManagedConfigNames[index])
    else copy(output, length, g_SeriesExtraConfigNames[index - sizeof g_ManagedConfigNames])
}

stock bool:series_config_file_valid(const value[])
{
    if (!value[0]) return true
    if (!valid_simple_token(value, MAX_CONFIG_TOKEN)) return false
    new path[MAX_CONFIG_TOKEN + 5]
    formatex(path, charsmax(path), "%s.cfg", value)
    return bool:file_exists(path)
}

stock bool:series_extra_value_valid(index, const value[])
{
    new SeriesExtraConfigIndex:extraIndex = SeriesExtraConfigIndex:index
    if (extraIndex == SC_HLTV_ENABLED || extraIndex == SC_HLTV_AUTO_RECORD)
    {
        if (equal(value, "-")) return true
    }
    switch (extraIndex)
    {
        case SC_WARMUP_CONFIG, SC_MATCH_CONFIG, SC_OVERTIME_CONFIG, SC_DEFAULT_CONFIG:
            return series_config_file_valid(value)
        case SC_HOSTNAME: return !value[0] || valid_runtime_cvar_value(value, 127)
        case SC_PASSWORD: return !value[0] || valid_runtime_cvar_value(value, 63)
    }
    new number
    switch (extraIndex)
    {
        case SC_HALFTIME_DELAY: return parse_uint_exact(value, 1, 30, number)
        case SC_KNIFE_VOTE_SECONDS: return parse_uint_exact(value, 5, 30, number)
        case SC_AUTO_LIVE, SC_HUD_ANNOUNCEMENTS, SC_KNIFE_VOTE, SC_SET_HOSTNAME,
            SC_SET_PASSWORD, SC_DISABLE_SHIELD, SC_CLIENT_DEMOS, SC_FILE_STATS,
            SC_HLTV_ENABLED, SC_HLTV_AUTO_RECORD: return parse_bool_exact(value, number)
    }
    return false
}

stock bool:series_manifest_value_valid(index, const value[])
{
    if (index < sizeof g_ManagedConfigNames) return managed_config_value_valid(index, value)
    return series_extra_value_valid(index - sizeof g_ManagedConfigNames, value)
}

stock bool:capture_series_manifest()
{
    g_SeriesManifestCaptured = false
    clear_series_manifest_storage()
    new count = series_manifest_count()
    if (count > SERIES_MANIFEST_MAX) return false
    new cvarName[64]
    for (new index = 0; index < count; index++)
    {
        series_manifest_cvar_name(index, cvarName, charsmax(cvarName))
        if (!cvar_exists(cvarName))
        {
            new SeriesExtraConfigIndex:extraIndex = SeriesExtraConfigIndex:(index - sizeof g_ManagedConfigNames)
            if (index >= sizeof g_ManagedConfigNames &&
                (extraIndex == SC_HLTV_ENABLED || extraIndex == SC_HLTV_AUTO_RECORD))
                copy(g_SeriesManifestValues[index], charsmax(g_SeriesManifestValues[]), "-")
            else return false
        }
        else get_cvar_string(cvarName, g_SeriesManifestValues[index], charsmax(g_SeriesManifestValues[]))
        trim(g_SeriesManifestValues[index])
        if (!series_manifest_value_valid(index, g_SeriesManifestValues[index])) return false
    }
    g_SeriesManifestCaptured = true
    return true
}

stock bool:persist_series_manifest()
{
    if (!g_SeriesManifestCaptured || !valid_match_id_exact(g_MatchId)) return false
    new count = series_manifest_count(), key[32], value[16]
    set_localinfo(LI_MANIFEST_ACTIVE, "")
    for (new index = 0; index < count; index++)
    {
        if (!series_manifest_value_valid(index, g_SeriesManifestValues[index])) return false
        formatex(key, charsmax(key), "_kgbcw_m%02d", index)
        set_localinfo(key, g_SeriesManifestValues[index])
    }
    set_localinfo(LI_MANIFEST_VERSION, SERIES_MANIFEST_VERSION)
    num_to_str(count, value, charsmax(value)); set_localinfo(LI_MANIFEST_COUNT, value)
    set_localinfo(LI_MANIFEST_ID, g_MatchId)
    set_localinfo(LI_MANIFEST_ACTIVE, "1")
    return true
}

stock bool:restore_relationships_valid()
{
    new mapCount, pugMode
    if (!parse_uint_exact(g_SeriesRestoreValues[_:MC_MAP_COUNT], 2, 2, mapCount)) return false
    if (!valid_map_token(g_SeriesRestoreValues[_:MC_MAP1]) || !valid_map_token(g_SeriesRestoreValues[_:MC_MAP2]) ||
        equali(g_SeriesRestoreValues[_:MC_MAP1], g_SeriesRestoreValues[_:MC_MAP2])) return false
    if (!parse_bool_exact(g_SeriesRestoreValues[_:MC_PUG_MODE], pugMode)) return false
    return true
}

stock bool:parse_series_manifest()
{
    new active[4], version[8], countValue[8], manifestId[MAX_MATCH_ID + 1], parsedCount
    get_localinfo(LI_MANIFEST_ACTIVE, active, charsmax(active))
    get_localinfo(LI_MANIFEST_VERSION, version, charsmax(version))
    get_localinfo(LI_MANIFEST_COUNT, countValue, charsmax(countValue))
    get_localinfo(LI_MANIFEST_ID, manifestId, charsmax(manifestId))
    new count = series_manifest_count()
    if (!equal(active, "1") || !equal(version, SERIES_MANIFEST_VERSION) ||
        !parse_uint_exact(countValue, count, count, parsedCount) || !valid_match_id_exact(manifestId)) return false

    new key[32], cvarName[64]
    for (new index = 0; index < count; index++)
    {
        formatex(key, charsmax(key), "_kgbcw_m%02d", index)
        get_localinfo(key, g_SeriesRestoreValues[index], charsmax(g_SeriesRestoreValues[]))
        if (!series_manifest_value_valid(index, g_SeriesRestoreValues[index])) return false
        series_manifest_cvar_name(index, cvarName, charsmax(cvarName))
        if (!equal(g_SeriesRestoreValues[index], "-") && !cvar_exists(cvarName)) return false
    }
    if (!restore_relationships_valid()) return false
    copy(g_RestoreMatchId, charsmax(g_RestoreMatchId), manifestId)
    return true
}

stock commit_series_manifest()
{
    new count = series_manifest_count(), cvarName[64]
    for (new index = 0; index < count; index++)
    {
        copy(g_SeriesManifestValues[index], charsmax(g_SeriesManifestValues[]), g_SeriesRestoreValues[index])
        if (equal(g_SeriesRestoreValues[index], "-")) continue
        series_manifest_cvar_name(index, cvarName, charsmax(cvarName))
        set_cvar_string(cvarName, g_SeriesRestoreValues[index])
    }
    copy(g_MatchId, charsmax(g_MatchId), g_RestoreMatchId)
    if (equal(g_SeriesRestoreValues[_:MC_FORMAT], "tl")) g_Format = FORMAT_TL
    else if (equal(g_SeriesRestoreValues[_:MC_FORMAT], "wl")) g_Format = FORMAT_WL
    else g_Format = FORMAT_MR
    if (equal(g_SeriesRestoreValues[_:MC_READY_MODE], "team")) g_ReadyMode = READY_TEAM
    else if (equal(g_SeriesRestoreValues[_:MC_READY_MODE], "admin")) g_ReadyMode = READY_ADMIN
    else g_ReadyMode = READY_PLAYER
    copy(g_TeamAName, charsmax(g_TeamAName), g_SeriesRestoreValues[_:MC_TEAM_A_NAME])
    copy(g_TeamBName, charsmax(g_TeamBName), g_SeriesRestoreValues[_:MC_TEAM_B_NAME])
    copy(g_TeamATag, charsmax(g_TeamATag), g_SeriesRestoreValues[_:MC_TEAM_A_TAG])
    copy(g_TeamBTag, charsmax(g_TeamBTag), g_SeriesRestoreValues[_:MC_TEAM_B_TAG])
    copy(g_Map1, charsmax(g_Map1), g_SeriesRestoreValues[_:MC_MAP1])
    copy(g_Map2, charsmax(g_Map2), g_SeriesRestoreValues[_:MC_MAP2])
    g_MapCount = 2
    refresh_branding(false)
    g_SeriesManifestCaptured = true
}

stock series_managed_number(ManagedConfigIndex:index, cvar)
{
    new valueIndex = _:index
    return g_SeriesManifestCaptured ? str_to_num(g_SeriesManifestValues[valueIndex]) : get_pcvar_num(cvar)
}

stock series_extra_number(SeriesExtraConfigIndex:index, cvar)
{
    new valueIndex = sizeof g_ManagedConfigNames + _:index
    return g_SeriesManifestCaptured ? str_to_num(g_SeriesManifestValues[valueIndex]) : get_pcvar_num(cvar)
}

stock series_managed_string(ManagedConfigIndex:index, cvar, output[], length)
{
    new valueIndex = _:index
    if (g_SeriesManifestCaptured) copy(output, length, g_SeriesManifestValues[valueIndex])
    else get_pcvar_string(cvar, output, length)
}

stock series_extra_string(SeriesExtraConfigIndex:index, cvar, output[], length)
{
    new valueIndex = sizeof g_ManagedConfigNames + _:index
    if (g_SeriesManifestCaptured) copy(output, length, g_SeriesManifestValues[valueIndex])
    else get_pcvar_string(cvar, output, length)
}

stock clear_series_manifest_storage()
{
    new count = series_manifest_count(), key[32]
    set_localinfo(LI_MANIFEST_ACTIVE, "")
    set_localinfo(LI_MANIFEST_VERSION, ""); set_localinfo(LI_MANIFEST_COUNT, ""); set_localinfo(LI_MANIFEST_ID, "")
    for (new index = 0; index < count; index++)
    {
        formatex(key, charsmax(key), "_kgbcw_m%02d", index)
        set_localinfo(key, "")
    }
}

stock discard_series_manifest()
{
    clear_series_manifest_storage()
    g_SeriesManifestCaptured = false
    for (new index = 0; index < SERIES_MANIFEST_MAX; index++) g_SeriesManifestValues[index][0] = 0
}

stock bool:managed_config_file_valid(const path[], bool:preset)
{
    new line[256], length, name[64], value[128]
    for (new lineNumber = 0; read_file(path, lineNumber, line, charsmax(line), length); lineNumber++)
    {
        trim(line)
        if (!line[0] || line[0] == ';' || line[0] == '#' || (line[0] == '/' && line[1] == '/')) continue
        name[0] = 0; value[0] = 0
        if (parse(line, name, charsmax(name), value, charsmax(value)) < 2) return false
        strtolower(name)
        new index = managed_config_index(name)
        if (index < 0 || (preset && !preset_config_index_allowed(index)) || !managed_config_value_valid(index, value)) return false
    }
    return true
}

stock bool:apply_managed_config_file(const path[], bool:preset)
{
    if (!managed_config_file_valid(path, preset)) return false
    snapshot_managed_config()
    new line[256], length, name[64], value[128]
    for (new lineNumber = 0; read_file(path, lineNumber, line, charsmax(line), length); lineNumber++)
    {
        trim(line)
        if (!line[0] || line[0] == ';' || line[0] == '#' || (line[0] == '/' && line[1] == '/')) continue
        parse(line, name, charsmax(name), value, charsmax(value)); strtolower(name)
        set_cvar_string(name, value)
    }
    refresh_branding(false)
    if (full_runtime_config_valid(false))
    {
        load_runtime_settings(false)
        schedule_status_hud()
        return true
    }
    restore_managed_config_snapshot()
    return false
}

stock snapshot_managed_config()
{
    for (new index = 0; index < sizeof g_ManagedConfigNames; index++)
        get_cvar_string(g_ManagedConfigNames[index], g_ConfigRollbackValues[index], charsmax(g_ConfigRollbackValues[]))
}

stock restore_managed_config_snapshot()
{
    for (new index = 0; index < sizeof g_ManagedConfigNames; index++)
        set_cvar_string(g_ManagedConfigNames[index], g_ConfigRollbackValues[index])
    refresh_branding(false); load_runtime_settings(false); schedule_status_hud()
}

stock save_menu_config(id)
{
    if (!safe_configuration_state(id)) return
    if (!get_pcvar_num(g_CvarAllowMenuSave))
    {
        cw_console_ml(id, "CW_ERR_SAVE_DISABLED")
        return
    }
    if (!full_runtime_config_valid(false))
    {
        cw_console_ml(id, "CW_ERR_SAVE_INVALID")
        return
    }
    new displayName[MAX_DISPLAY_NAME + 1], chatPrefix[MAX_CHAT_PREFIX + 1]
    get_pcvar_string(g_CvarDisplayName, displayName, charsmax(displayName)); trim(displayName)
    get_pcvar_string(g_CvarChatPrefix, chatPrefix, charsmax(chatPrefix)); trim(chatPrefix)
    if (!valid_display_token(displayName, MAX_DISPLAY_NAME) || !valid_display_token(chatPrefix, MAX_CHAT_PREFIX))
    {
        cw_console_ml(id, "CW_ERR_SAVE_BRANDING")
        return
    }
    new configsDir[128], path[192], temporaryPath[192]
    get_configsdir(configsDir, charsmax(configsDir)); formatex(path, charsmax(path), "%s/kgb_clan_war_saved.cfg", configsDir)
    formatex(temporaryPath, charsmax(temporaryPath), "%s/kgb_clan_war_saved.cfg.tmp", configsDir)
    if (file_exists(temporaryPath) && !delete_file(temporaryPath))
    {
        cw_console_ml(id, "CW_ERR_SAVE_REPLACE")
        return
    }
    new bool:written = bool:write_file(temporaryPath, "; Generated by KGB Clan War. Contains only the allowlisted non-secret menu snapshot.")
    written = written && save_string_cvar(temporaryPath, "kgb_cw_display_name", g_CvarDisplayName)
    written = written && save_string_cvar(temporaryPath, "kgb_cw_chat_prefix", g_CvarChatPrefix)
    written = written && save_string_cvar(temporaryPath, "kgb_cw_format", g_CvarFormat)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_half_rounds", g_CvarHalfRounds)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_win_rounds", g_CvarWinRounds)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_time_limit_minutes", g_CvarTimeLimitMinutes)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_playout", g_CvarPlayout)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_playout_vote_default", g_CvarPlayoutVoteDefault)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_time_limit_finish_round", g_CvarTimeLimitFinishRound)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_overtime", g_CvarOvertime)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_overtime_max_cycles", g_CvarOvertimeMaxCycles)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_overtime_vote", g_CvarOvertimeVote)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_overtime_half_rounds", g_CvarOvertimeHalfRounds)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_overtime_money", g_CvarOvertimeMoney)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_overtime_vote_seconds", g_CvarOvertimeVoteSeconds)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_overtime_vote_default", g_CvarOvertimeVoteDefault)
    written = written && save_string_cvar(temporaryPath, "kgb_cw_ready_mode", g_CvarReadyMode)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_min_ready", g_CvarMinReady)
    written = written && save_string_cvar(temporaryPath, "kgb_cw_team_a_name", g_CvarTeamAName)
    written = written && save_string_cvar(temporaryPath, "kgb_cw_team_b_name", g_CvarTeamBName)
    written = written && save_string_cvar(temporaryPath, "kgb_cw_team_a_tag", g_CvarTeamATag)
    written = written && save_string_cvar(temporaryPath, "kgb_cw_team_b_tag", g_CvarTeamBTag)
    written = written && save_string_cvar(temporaryPath, "kgb_cw_map1", g_CvarMap1)
    written = written && save_string_cvar(temporaryPath, "kgb_cw_map2", g_CvarMap2)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_map_count", g_CvarMapCount)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_second_half_ready", g_CvarSecondHalfReady)
    written = written && save_string_cvar(temporaryPath, "kgb_cw_swap_policy", g_CvarSwapPolicy)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_hud_interval", g_CvarHudInterval)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_pug_mode", g_CvarPugMode)
    written = written && save_string_cvar(temporaryPath, "kgb_cw_pug_style", g_CvarPugStyle)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_pug_persist", g_CvarPugPersist)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_screenshots", g_CvarScreenshots)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_scoreid_screenshots", g_CvarScoreIdScreenshots)
    written = written && save_number_cvar(temporaryPath, "kgb_cw_screenshot_on_stop", g_CvarScreenshotOnStop)
    /* write_file/file_exists are mod-directory relative. Match that base for
     * rename_file; relative=0 incorrectly resolves from the HLDS process cwd. */
    if (!written || !managed_config_file_valid(temporaryPath, false) || !rename_file(temporaryPath, path, 1))
    {
        if (file_exists(temporaryPath)) delete_file(temporaryPath)
        cw_console_ml(id, "CW_ERR_SAVE_REPLACE")
        return
    }
    cw_console_ml(id, "CW_SAVE_DONE")
}

stock bool:save_string_cvar(const path[], const name[], cvar)
{
    new value[128], line[192]
    get_pcvar_string(cvar, value, charsmax(value)); formatex(line, charsmax(line), "%s ^"%s^"", name, value); return bool:write_file(path, line)
}

stock bool:save_number_cvar(const path[], const name[], cvar)
{
    new line[96]
    formatex(line, charsmax(line), "%s %d", name, get_pcvar_num(cvar)); return bool:write_file(path, line)
}

stock ml_text(id, const key[], output[], length)
{
    new language = id > 0 ? id : LANG_SERVER
    LookupLangKey(output, length, key, language)
}

stock cw_console_ml(id, const key[], any:...)
{
    new translated[MAX_BRANDED_MESSAGE + 1], message[MAX_BRANDED_MESSAGE + 1]
    new language = id > 0 ? id : LANG_SERVER
    LookupLangKey(translated, charsmax(translated), key, language)
    vformat(message, charsmax(message), translated, 3)
    refresh_branding(false)
    console_print(id, "%s %s", g_ChatPrefix, message)
}

stock cw_chat_ml(id, const key[], any:...)
{
    new translated[MAX_BRANDED_MESSAGE + 1], message[MAX_BRANDED_MESSAGE + 1]
    new language = id > 0 ? id : LANG_SERVER
    LookupLangKey(translated, charsmax(translated), key, language)
    vformat(message, charsmax(message), translated, 3)
    refresh_branding(false)
    client_print(id, print_chat, "%s %s", g_ChatPrefix, message)
}

stock bool:start_warmup(bool:resetData)
{
    if (map_transition_blocks_mutation(0, false)) return false
    if (!full_runtime_config_valid(false))
    {
        announce_ml("CW_ERR_WARMUP_CONFIG")
        return false
    }
    if (resetData)
    {
        close_active_lifecycle("warmup_match_stop")
        restore_legacy_record_mode()
        discard_series_manifest()
    }
    cancel_transition_tasks()
    if (resetData) { reset_match_data(true); g_KnifeDecisionMade = false; g_PugActive = false; }
    reset_ready_players()
    load_runtime_settings(false)
    snapshot_environment(); apply_environment(false); set_cw_state(STATE_WARMUP)
    execute_phase_config(g_CvarWarmupConfig, "warmup")
    set_cvar_num("mp_startmoney", 16000); set_cvar_num("mp_freezetime", 1); set_cvar_num("mp_friendlyfire", 0)
    server_cmd("sv_restart 1")
    if (g_ReadyMode == READY_TEAM) announce_ml("CW_WARMUP_STARTED_TEAM")
    else if (g_ReadyMode == READY_ADMIN) announce_ml("CW_WARMUP_STARTED_ADMIN")
    else announce_ml("CW_WARMUP_STARTED_PLAYER")
    audit_event("warmup_start")
    return true
}

stock start_knife_round()
{
    if (map_transition_blocks_mutation(0, false)) return
    if (!full_runtime_config_valid(false))
    {
        announce_ml("CW_ERR_KNIFE_CONFIG")
        return
    }
    close_active_lifecycle("knife_match_stop")
    restore_legacy_record_mode(); discard_series_manifest()
    cancel_transition_tasks(); reset_match_data(true); reset_ready_players(); g_KnifeDecisionMade = false
    load_runtime_settings(false)
    snapshot_environment(); apply_environment(false); set_cw_state(STATE_KNIFE)
    execute_phase_config(g_CvarWarmupConfig, "warmup")
    set_cvar_num("mp_startmoney", 0); set_cvar_num("mp_freezetime", 5); set_cvar_num("mp_friendlyfire", 0)
    server_cmd("sv_restart 1"); announce_ml("CW_KNIFE_STARTED"); audit_event("knife_start")
}

stock bool:start_live_match(bool:preserveSides)
{
    if (map_transition_blocks_mutation(0, false)) return false
    new bool:restarting = g_State == STATE_LIVE || g_State == STATE_HALFTIME || g_State == STATE_HALF_READY || g_State == STATE_OVERTIME_VOTE || g_State == STATE_PLAYOUT_VOTE
    if (!full_runtime_config_valid(true))
    {
        /* A rejected restart must leave the running series and its immutable
         * manifest untouched. A pre-live legacy launch may safely unwind. */
        if (!restarting) { restore_legacy_record_mode(); discard_series_manifest(); }
        announce_ml("CW_ERR_MATCH_CONFIG")
        return false
    }
    if (restarting)
    {
        close_active_lifecycle("restart_match_stop")
        restore_legacy_record_mode()
        discard_series_manifest()
    }
    cancel_transition_tasks()
    if (!load_runtime_settings(false) || !capture_series_manifest())
    {
        restore_legacy_record_mode(); discard_series_manifest()
        announce_ml("CW_ERR_MATCH_CONFIG")
        return false
    }

    reset_match_data(!preserveSides); reset_ready_players(); snapshot_environment(); apply_environment(false)
    create_match_id(); execute_phase_config(g_CvarMatchConfig, "match"); set_cw_state(STATE_LIVE)
    emit_match_event("match_start"); emit_match_event("half_start"); write_stats_event("match_start")
    g_CaptureHalfBaselineAfterLo3 = true
    start_client_demos(); begin_lo3(true, true)
    new format[4]; get_format_name(format, charsmax(format))
    new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    announce_ml("CW_MATCH_STARTED", g_MatchId, labelA, labelB, format, g_MapNumber, g_MapCount)
    return true
}

stock begin_lo3(bool:resetRoundTracking, bool:resetTlTimer = false)
{
    if (map_transition_blocks_mutation(0, false)) return
    new bool:resetTimerAfterLo3 = resetTlTimer || g_ResetTlTimerAfterLo3
    cancel_lo3_tasks(); if (resetRoundTracking) g_RoundsThisHalf = 0
    g_ResetTlTimerAfterLo3 = resetTimerAfterLo3
    if (resetTimerAfterLo3) { remove_task(TASK_TIME_LIMIT); g_TimeLimitExpired = false; }
    g_Lo3Running = true; g_RoundResolved = true; set_cw_state(STATE_LIVE)
    set_task(0.1, "task_restart_first", TASK_LO3_1)
    set_task(2.1, "task_restart_second", TASK_LO3_2)
    set_task(4.1, "task_restart_third", TASK_LO3_3)
    set_task(6.1, "task_finish_lo3", TASK_LO3_DONE)
}

stock close_active_lifecycle(const statsEvent[])
{
    if (g_State != STATE_LIVE && g_State != STATE_HALFTIME && g_State != STATE_HALF_READY && g_State != STATE_OVERTIME_VOTE && g_State != STATE_PLAYOUT_VOTE) return
    emit_match_event("match_stop")
    write_stats_event(statsEvent)
    stop_client_demos()
}

stock stop_match(bool:administrator)
{
    if (map_transition_blocks_mutation(0, false)) return
    if (crossmap_recovery_pending())
    {
        log_amx("Refused to stop match while cross-map baseline recovery is pending")
        return
    }
    cancel_transition_tasks()
    g_PugActive = false
    new bool:hadActiveMatch = g_State == STATE_LIVE || g_State == STATE_HALFTIME || g_State == STATE_HALF_READY || g_State == STATE_OVERTIME_VOTE || g_State == STATE_PLAYOUT_VOTE
    if (hadActiveMatch)
    {
        emit_match_event("match_stop")
        write_stats_event(administrator ? "admin_match_stop" : "match_stop")
    }
    else if (g_State != STATE_OFF)
    {
        audit_event(administrator ? "admin_mode_stop" : "mode_stop")
        write_stats_event(administrator ? "admin_mode_stop" : "mode_stop")
    }
    if (administrator && hadActiveMatch && series_managed_number(MC_SCREENSHOT_ON_STOP, g_CvarScreenshotOnStop)) take_match_screenshots()
    stop_client_demos(); restore_environment(); execute_phase_config(g_CvarDefaultConfig, "default")
    restore_legacy_record_mode()
    reset_match_data(true); reset_ready_players(); clear_crossmap_state(); discard_series_manifest(); clear_pug_resume_state(); set_cw_state(STATE_OFF)
    server_cmd("sv_restart 1"); announce_ml("CW_MATCH_STOPPED")
}

stock restart_current_half()
{
    if (map_transition_blocks_mutation(0, false)) return
    g_TeamAScore = g_HalfStartA; g_TeamBScore = g_HalfStartB; g_RoundsThisHalf = 0
    g_CaptureHalfBaselineAfterLo3 = true
    audit_event("admin_restart_half"); begin_lo3(false, true)
    announce_ml("CW_HALF_RESTARTED", total_score_a(), total_score_b())
}

stock bool:restart_whole_match(id, bool:chatFeedback)
{
    if (map_transition_blocks_mutation(id, chatFeedback)) return false
    if (g_State == STATE_OFF)
    {
        if (chatFeedback) cw_chat_ml(id, "CW_ERR_RESTART_OFF")
        else cw_console_ml(id, "CW_ERR_RESTART_OFF")
        return false
    }
    if (!start_live_match(false))
    {
        if (chatFeedback) cw_chat_ml(id, "CW_ERR_RESTART_FAILED")
        else cw_console_ml(id, "CW_ERR_RESTART_FAILED")
        return false
    }
    audit_event("admin_restart_match")
    return true
}

stock set_player_ready(id, bool:isReady)
{
    if (!is_user_connected(id) || (g_State != STATE_WARMUP && g_State != STATE_HALF_READY))
    {
        cw_chat_ml(id, "CW_ERR_READY_STATE"); return
    }
    if (g_ReadyMode == READY_ADMIN)
    {
        cw_chat_ml(id, "CW_READY_ADMIN"); return
    }
    if (g_ReadyMode == READY_TEAM) { set_team_ready(id, isReady); return; }
    new CsTeams:team = cs_get_user_team(id)
    if (team != CS_TEAM_T && team != CS_TEAM_CT)
    {
        cw_chat_ml(id, "CW_ERR_JOIN_TEAM"); return
    }
    if (g_Ready[id] == isReady)
    {
        cw_chat_ml(id, "CW_READY_UNCHANGED"); return
    }
    g_Ready[id] = isReady
    new name[32]; get_user_name(id, name, charsmax(name))
    announce_ml(isReady ? "CW_PLAYER_READY" : "CW_PLAYER_NOT_READY", name, ready_count(), required_ready_count())
    check_auto_live()
}

stock set_team_ready(id, bool:isReady)
{
    if (!is_user_connected(id) || (g_State != STATE_WARMUP && g_State != STATE_HALF_READY))
    {
        cw_chat_ml(id, "CW_ERR_TEAM_READY_STATE"); return
    }
    if (g_ReadyMode != READY_TEAM)
    {
        cw_chat_ml(id, "CW_ERR_TEAM_READY_DISABLED"); return
    }
    new identity = identity_for_side(cs_get_user_team(id))
    if (identity < 0) { cw_chat_ml(id, "CW_ERR_JOIN_TEAM"); return; }
    g_TeamReady[identity] = isReady
    announce_ml(isReady ? "CW_TEAM_READY" : "CW_TEAM_NOT_READY", identity == 0 ? g_TeamAName : g_TeamBName)
    check_auto_live()
}

stock check_auto_live()
{
    if (!series_extra_number(SC_AUTO_LIVE, g_CvarAutoLive) && g_State != STATE_HALF_READY) return
    if ((g_ReadyMode == READY_PLAYER && ready_count() >= required_ready_count()) ||
        (g_ReadyMode == READY_TEAM && g_TeamReady[0] && g_TeamReady[1]))
    {
        if (g_State == STATE_HALF_READY)
        {
            announce_ml("CW_SECOND_READY_COMPLETE")
            resume_ready_half()
        }
        else
        {
            announce_ml("CW_READY_COMPLETE")
            start_live_match(g_State == STATE_WARMUP && g_KnifeDecisionMade)
        }
    }
}

stock ready_count()
{
    new players[32], count, ready
    get_players(players, count, "ch")
    for (new i = 0; i < count; i++)
    {
        new CsTeams:team = cs_get_user_team(players[i])
        if (g_Ready[players[i]] && (team == CS_TEAM_T || team == CS_TEAM_CT)) ready++
    }
    return ready
}

stock required_ready_count() { return clamp(series_managed_number(MC_MIN_READY, g_CvarMinReady), 1, 32); }

stock handle_round_winner(CsTeams:winner)
{
    if (g_RoundResolved || g_Lo3Running) return
    if (g_State == STATE_KNIFE) { g_RoundResolved = true; begin_knife_vote(winner); return; }
    if (g_State != STATE_LIVE) return
    g_RoundResolved = true; g_RoundsThisHalf++
    if (winner == g_TeamASide) g_TeamAScore++; else g_TeamBScore++
    new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    announce_ml("CW_ROUND_SCORE", labelA, g_TeamAScore, g_TeamBScore, labelB)
    write_stats_event("round_end")
    if (g_Format == FORMAT_TL && g_TimeLimitExpired) complete_time_limit_half()
    else evaluate_match_progress()
}

stock evaluate_match_progress()
{
    if (g_InOvertime) { evaluate_overtime_progress(); return; }
    if (g_Format == FORMAT_TL) return
    if (g_Format == FORMAT_WL)
    {
        new target = clamp(series_managed_number(MC_WIN_ROUNDS, g_CvarWinRounds), 1, 100)
        if (g_TeamAScore >= target || g_TeamBScore >= target) complete_regulation_map()
        return
    }

    new halfRounds = clamp(series_managed_number(MC_HALF_ROUNDS, g_CvarHalfRounds), 1, 100)
    new roundsPlayed = g_TeamAScore + g_TeamBScore
    new playoutMode = clamp(series_managed_number(MC_PLAYOUT, g_CvarPlayout), 0, 2)
    if (playoutMode != 1 && !g_PlayoutDecisionMade && match_is_clinched(halfRounds, roundsPlayed))
    {
        if (playoutMode == 2) begin_playout_vote()
        else complete_regulation_map()
        return
    }
    if (g_RoundsThisHalf < halfRounds) return
    if (g_Half == 1)
    {
        emit_match_event("half_end"); write_stats_event("half_end"); take_match_screenshots()
        g_Half = 2; begin_halftime(); return
    }
    complete_regulation_map()
}

stock bool:match_is_clinched(halfRounds, roundsPlayed)
{
    new remaining = (halfRounds * 2) - roundsPlayed
    if (remaining < 0) remaining = 0
    if (g_MapCount == 1) return g_TeamAScore > g_TeamBScore + remaining || g_TeamBScore > g_TeamAScore + remaining
    if (g_MapNumber == 2) return total_score_a() > total_score_b() + remaining || total_score_b() > total_score_a() + remaining
    return false
}

stock complete_regulation_map(bool:halfAlreadyEnded = false)
{
    if (!halfAlreadyEnded)
    {
        emit_match_event("half_end")
        write_stats_event("half_end")
    }
    take_match_screenshots()
    if (g_MapCount == 2 && g_MapNumber == 1) { begin_map_transition(); return; }
    if (total_score_a() == total_score_b() && series_managed_number(MC_OVERTIME, g_CvarOvertime))
    {
        if (series_managed_number(MC_OT_VOTE, g_CvarOvertimeVote)) begin_overtime_vote()
        else start_overtime_cycle()
        return
    }
    finish_match(false, true)
}

stock begin_halftime()
{
    set_cw_state(STATE_HALFTIME)
    new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    announce_ml(automatic_swaps_enabled() ? "CW_HALFTIME_SWAP" : "CW_HALFTIME_NO_SWAP", labelA, g_TeamAScore, g_TeamBScore, labelB)
    remove_task(TASK_HALFTIME)
    set_task(float(clamp(series_extra_number(SC_HALFTIME_DELAY, g_CvarHalftimeDelay), 1, 30)), "task_begin_next_half", TASK_HALFTIME)
}

stock start_overtime_cycle()
{
    new maxCycles = series_managed_number(MC_OT_MAX, g_CvarOvertimeMaxCycles)
    if (maxCycles > 0 && g_OvertimeCycle >= maxCycles) { finish_match(false); return; }
    g_InOvertime = true; g_OvertimeCycle++; g_Half = 1; g_RoundsThisHalf = 0
    g_HalfStartA = g_TeamAScore; g_HalfStartB = g_TeamBScore
    set_cw_state(STATE_HALFTIME); execute_phase_config(g_CvarOvertimeConfig, "overtime")
    set_cvar_num("mp_startmoney", clamp(series_managed_number(MC_OT_MONEY, g_CvarOvertimeMoney), 800, 16000))
    emit_match_event("overtime_start"); write_stats_event("overtime_start")
    announce_ml("CW_OVERTIME_START", g_OvertimeCycle, clamp(series_managed_number(MC_OT_HALF_ROUNDS, g_CvarOvertimeHalfRounds), 1, 20), clamp(series_managed_number(MC_OT_MONEY, g_CvarOvertimeMoney), 800, 16000))
    set_task(float(clamp(series_extra_number(SC_HALFTIME_DELAY, g_CvarHalftimeDelay), 1, 30)), "task_begin_next_half", TASK_HALFTIME)
}

stock begin_overtime_vote()
{
    set_cw_state(STATE_OVERTIME_VOTE)
    g_OvertimeYesVotes = 0; g_OvertimeNoVotes = 0
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        g_OvertimeVoted[id] = false
        g_OvertimeVoteChoice[id] = 0
        if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id) || identity_for_side(cs_get_user_team(id)) < 0) continue
        show_overtime_vote_menu(id)
    }
    announce_ml("CW_OVERTIME_VOTE_START")
    if (!overtime_eligible_count())
    {
        finish_overtime_vote()
        return
    }
    remove_task(TASK_OVERTIME_VOTE)
    set_task(float(clamp(series_managed_number(MC_OT_VOTE_SECONDS, g_CvarOvertimeVoteSeconds), 5, 30)), "task_finish_overtime_vote", TASK_OVERTIME_VOTE)
}

stock show_overtime_vote_menu(id)
{
    new title[96], label[64]
    refresh_branding(false); formatex(title, charsmax(title), "%s: %L", g_DisplayName, id, "CW_OVERTIME_TITLE")
    new menu = menu_create(title, "menu_overtime_vote_handler")
    ml_text(id, "CW_OVERTIME_YES", label, charsmax(label)); menu_additem(menu, label, "1")
    ml_text(id, "CW_OVERTIME_NO", label, charsmax(label)); menu_additem(menu, label, "2")
    menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER); menu_display(id, menu)
}

stock finish_overtime_vote()
{
    if (g_State != STATE_OVERTIME_VOTE) return
    remove_task(TASK_OVERTIME_VOTE)
    new bool:playOvertime
    if (g_OvertimeYesVotes == g_OvertimeNoVotes) playOvertime = bool:series_managed_number(MC_OT_VOTE_DEFAULT, g_CvarOvertimeVoteDefault)
    else playOvertime = g_OvertimeYesVotes > g_OvertimeNoVotes
    announce_ml(playOvertime ? "CW_OVERTIME_VOTE_PLAY" : "CW_OVERTIME_VOTE_DRAW", g_OvertimeYesVotes, g_OvertimeNoVotes)
    audit_event(playOvertime ? "overtime_vote_play" : "overtime_vote_draw")
    if (playOvertime) start_overtime_cycle()
    else finish_match(false)
}

stock overtime_vote_count() { return g_OvertimeYesVotes + g_OvertimeNoVotes; }

stock recompute_overtime_votes()
{
    g_OvertimeYesVotes = 0; g_OvertimeNoVotes = 0
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        if (!is_user_connected(id) || identity_for_side(cs_get_user_team(id)) < 0)
        {
            g_OvertimeVoted[id] = false; g_OvertimeVoteChoice[id] = 0
            continue
        }
        if (!g_OvertimeVoted[id]) continue
        if (g_OvertimeVoteChoice[id] == 1) g_OvertimeYesVotes++
        else if (g_OvertimeVoteChoice[id] == 2) g_OvertimeNoVotes++
        else g_OvertimeVoted[id] = false
    }
}

stock overtime_eligible_count(excludeId = 0)
{
    new players[32], count, eligible
    get_players(players, count, "ch")
    for (new i = 0; i < count; i++) if (players[i] != excludeId && identity_for_side(cs_get_user_team(players[i])) >= 0) eligible++
    return eligible
}

stock begin_playout_vote()
{
    set_cw_state(STATE_PLAYOUT_VOTE)
    g_PlayoutYesVotes = 0; g_PlayoutNoVotes = 0
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        g_PlayoutVoted[id] = false; g_PlayoutVoteChoice[id] = 0
        if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id) || identity_for_side(cs_get_user_team(id)) < 0) continue
        show_playout_vote_menu(id)
    }
    announce_ml("CW_PLAYOUT_VOTE_START")
    if (!playout_eligible_count()) { finish_playout_vote(); return; }
    remove_task(TASK_PLAYOUT_VOTE)
    set_task(15.0, "task_finish_playout_vote", TASK_PLAYOUT_VOTE)
}

stock show_playout_vote_menu(id)
{
    new title[96], label[64]
    refresh_branding(false); formatex(title, charsmax(title), "%s: %L", g_DisplayName, id, "CW_PLAYOUT_TITLE")
    new menu = menu_create(title, "menu_playout_vote_handler")
    ml_text(id, "CW_PLAYOUT_YES", label, charsmax(label)); menu_additem(menu, label, "1")
    ml_text(id, "CW_PLAYOUT_NO", label, charsmax(label)); menu_additem(menu, label, "2")
    menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER); menu_display(id, menu)
}

stock finish_playout_vote()
{
    if (g_State != STATE_PLAYOUT_VOTE) return
    remove_task(TASK_PLAYOUT_VOTE)
    new bool:playOut
    if (g_PlayoutYesVotes == g_PlayoutNoVotes) playOut = bool:series_managed_number(MC_PLAYOUT_DEFAULT, g_CvarPlayoutVoteDefault)
    else playOut = g_PlayoutYesVotes > g_PlayoutNoVotes
    announce_ml(playOut ? "CW_PLAYOUT_VOTE_PLAY" : "CW_PLAYOUT_VOTE_END", g_PlayoutYesVotes, g_PlayoutNoVotes)
    audit_event(playOut ? "playout_vote_play" : "playout_vote_end")
    if (playOut)
    {
        g_PlayoutDecisionMade = true
        set_cw_state(STATE_LIVE)
    }
    else complete_regulation_map()
}

stock playout_vote_count() { return g_PlayoutYesVotes + g_PlayoutNoVotes; }

stock recompute_playout_votes()
{
    g_PlayoutYesVotes = 0; g_PlayoutNoVotes = 0
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id) || identity_for_side(cs_get_user_team(id)) < 0)
        {
            g_PlayoutVoted[id] = false; g_PlayoutVoteChoice[id] = 0
            continue
        }
        if (!g_PlayoutVoted[id]) continue
        if (g_PlayoutVoteChoice[id] == 1) g_PlayoutYesVotes++
        else if (g_PlayoutVoteChoice[id] == 2) g_PlayoutNoVotes++
        else g_PlayoutVoted[id] = false
    }
}

stock playout_eligible_count(excludeId = 0)
{
    new players[32], count, eligible
    get_players(players, count, "ch")
    for (new i = 0; i < count; i++) if (players[i] != excludeId && identity_for_side(cs_get_user_team(players[i])) >= 0) eligible++
    return eligible
}

stock evaluate_overtime_progress()
{
    new otHalf = clamp(series_managed_number(MC_OT_HALF_ROUNDS, g_CvarOvertimeHalfRounds), 1, 20)
    if (g_RoundsThisHalf < otHalf) return
    if (g_Half == 1)
    {
        emit_match_event("half_end"); write_stats_event("overtime_half_end"); take_match_screenshots()
        g_Half = 2; begin_halftime(); return
    }
    emit_match_event("half_end"); write_stats_event("overtime_half_end"); take_match_screenshots()
    if (total_score_a() == total_score_b()) start_overtime_cycle()
    else finish_match(false, true)
}

stock begin_map_transition()
{
    if (!valid_map_token(g_Map2)) { announce_ml("CW_ERR_MAP2_INVALID"); finish_match(false); return; }
    g_PreviousMapScoreA = g_TeamAScore; g_PreviousMapScoreB = g_TeamBScore
    if (!persist_crossmap_state())
    {
        log_amx("Could not persist the validated series manifest; map two will not start")
        finish_match(false)
        return
    }
    emit_match_event("map_change"); write_stats_event("map_change")
    stop_client_demos()
    g_MapChangePending = true; set_cw_state(STATE_HALFTIME)
    announce_ml("CW_MAP1_COMPLETE", g_PreviousMapScoreA, g_PreviousMapScoreB, g_Map2)
    set_task(5.0, "task_change_map", TASK_MAP_CHANGE)
}

stock finish_match(bool:stopped, bool:screenshotTaken = false)
{
    if (crossmap_recovery_pending())
    {
        log_amx("Refused to finish match while cross-map baseline recovery is pending")
        return
    }
    cancel_transition_tasks(); set_cw_state(STATE_FINISHED)
    new bool:resumePug = g_PugActive && series_managed_number(MC_PUG_PERSIST, g_CvarPugPersist)
    new resumePugStyle[16]
    if (resumePug) series_managed_string(MC_PUG_STYLE, g_CvarPugStyle, resumePugStyle, charsmax(resumePugStyle))
    if (!resumePug) g_PugActive = false
    emit_match_event(stopped ? "match_stop" : "match_end"); write_stats_event(stopped ? "match_stop" : "match_end")
    if (!screenshotTaken) take_match_screenshots()
    stop_client_demos()
    new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    if (total_score_a() == total_score_b()) announce_ml("CW_MATCH_DRAW", labelA, total_score_a(), total_score_b(), labelB)
    else announce_ml("CW_MATCH_WIN", total_score_a() > total_score_b() ? labelA : labelB, total_score_a(), total_score_b())
    restore_environment(); execute_phase_config(g_CvarDefaultConfig, "default")
    restore_legacy_record_mode(); clear_crossmap_state(); discard_series_manifest()
    if (resumePug)
    {
        if (!schedule_persistent_pug_advance(resumePugStyle)) set_task(8.0, "task_return_to_warmup", TASK_WARMUP)
    }
}

stock bool:valid_mapcycle_filename(const value[])
{
    new length = strlen(value)
    if (length < 5 || length > 63 || !equali(value[length - 4], ".txt")) return false
    for (new index = 0; index < length; index++)
    {
        new c = value[index]
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
            (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.')) return false
    }
    return true
}

stock load_valid_mapcycle()
{
    new filename[64]
    get_cvar_string("mapcyclefile", filename, charsmax(filename)); trim(filename)
    if (!valid_mapcycle_filename(filename) || !file_exists(filename)) return 0

    new count, line[192], length, map[MAX_MAP_TOKEN + 1]
    for (new lineNumber = 0; count < MAX_MAPCYCLE_MAPS && read_file(filename, lineNumber, line, charsmax(line), length); lineNumber++)
    {
        trim(line)
        if (!line[0] || line[0] == ';' || line[0] == '#' || (line[0] == '/' && line[1] == '/')) continue
        parse(line, map, charsmax(map)); strtolower(map)
        if (!valid_map_token(map)) continue
        copy(g_MapcycleMaps[count], charsmax(g_MapcycleMaps[]), map)
        count++
    }
    return count
}

stock bool:next_mapcycle_pair(const current[], nextMap[], nextLength, followingMap[], followingLength)
{
    new count = load_valid_mapcycle()
    if (!count) return false
    new currentIndex = -1
    for (new index = 0; index < count; index++)
    {
        if (equali(g_MapcycleMaps[index], current)) { currentIndex = index; break; }
    }
    new nextIndex = -1
    if (currentIndex < 0) nextIndex = 0
    else
    {
        for (new offset = 1; offset <= count; offset++)
        {
            new candidate = (currentIndex + offset) % count
            if (!equali(g_MapcycleMaps[candidate], current))
            {
                nextIndex = candidate
                break
            }
        }
    }
    if (nextIndex < 0) return false
    copy(nextMap, nextLength, g_MapcycleMaps[nextIndex])
    followingMap[0] = 0
    if (count > 1)
    {
        for (new offset = 1; offset < count; offset++)
        {
            new candidate = (nextIndex + offset) % count
            if (!equali(g_MapcycleMaps[candidate], nextMap))
            {
                copy(followingMap, followingLength, g_MapcycleMaps[candidate])
                break
            }
        }
    }
    return true
}

stock bool:schedule_persistent_pug_advance(const frozenStyle[])
{
    new current[MAX_MAP_TOKEN + 1], nextMap[MAX_MAP_TOKEN + 1], followingMap[MAX_MAP_TOKEN + 1], style[16]
    get_mapname(current, charsmax(current))
    if (!next_mapcycle_pair(current, nextMap, charsmax(nextMap), followingMap, charsmax(followingMap)) || equali(nextMap, current))
    {
        log_amx("Persistent PUG could not advance: mapcyclefile has no different installed next map")
        return false
    }
    copy(style, charsmax(style), frozenStyle); strtolower(style)
    if (!equal(style, "random") && !equal(style, "manual")) return false

    clear_pug_resume_state()
    set_localinfo(LI_PUG_NEXT, nextMap); set_localinfo(LI_PUG_FOLLOWING, followingMap)
    set_localinfo(LI_PUG_RESUME_STYLE, style)
    set_localinfo(LI_PUG_RESUME, "1")
    g_MapChangePending = true
    remove_task(TASK_PUG_MAP_CHANGE)
    set_task(8.0, "task_change_pug_map", TASK_PUG_MAP_CHANGE)
    audit_event("pug_mapcycle_advance_queued")
    return true
}

public task_change_pug_map()
{
    new active[4], nextMap[MAX_MAP_TOKEN + 1]
    get_localinfo(LI_PUG_RESUME, active, charsmax(active)); get_localinfo(LI_PUG_NEXT, nextMap, charsmax(nextMap))
    if (!equal(active, "1") || !valid_map_token(nextMap))
    {
        clear_pug_resume_state(); g_MapChangePending = false
        return
    }
    server_cmd("changelevel %s", nextMap)
}

stock bool:resume_persistent_pug()
{
    new active[4], expected[MAX_MAP_TOKEN + 1], following[MAX_MAP_TOKEN + 1], current[MAX_MAP_TOKEN + 1], style[16]
    get_localinfo(LI_PUG_RESUME, active, charsmax(active))
    if (!equal(active, "1")) return false
    get_localinfo(LI_PUG_NEXT, expected, charsmax(expected)); get_localinfo(LI_PUG_FOLLOWING, following, charsmax(following))
    get_localinfo(LI_PUG_RESUME_STYLE, style, charsmax(style)); get_mapname(current, charsmax(current)); strtolower(style)
    if (!valid_map_token(expected) || !equali(expected, current) ||
        (following[0] && (!valid_map_token(following) || equali(expected, following))) ||
        (!equal(style, "random") && !equal(style, "manual")))
    {
        log_amx("Rejected stale or invalid persistent PUG mapcycle state")
        clear_pug_resume_state()
        return false
    }
    set_pcvar_string(g_CvarMap1, expected); set_pcvar_string(g_CvarMap2, following)
    set_pcvar_num(g_CvarMapCount, following[0] ? 2 : 1); set_pcvar_string(g_CvarPugStyle, style)
    g_PugActive = true
    clear_pug_resume_state()
    if (!start_warmup(false))
    {
        g_PugActive = false
        return false
    }
    audit_event("pug_mapcycle_advanced")
    return true
}

stock clear_pug_resume_state()
{
    set_localinfo(LI_PUG_RESUME, "")
    set_localinfo(LI_PUG_NEXT, ""); set_localinfo(LI_PUG_FOLLOWING, ""); set_localinfo(LI_PUG_RESUME_STYLE, "")
}

stock begin_knife_vote(CsTeams:winner)
{
    g_KnifeWinningSide = winner; g_KnifeStayVotes = 0; g_KnifeSwapVotes = 0
    for (new id = 1; id <= MAX_PLAYERS; id++) { g_KnifeVoted[id] = false; g_KnifeVoteChoice[id] = 0; }
    new side[24]; get_side_name(winner, side, charsmax(side))
    if (!get_pcvar_num(g_CvarKnifeVote))
    {
        announce_ml("CW_KNIFE_WIN_STAY", side)
        g_KnifeDecisionMade = true; set_task(3.0, "task_return_to_warmup", TASK_WARMUP); return
    }
    set_cw_state(STATE_KNIFE_VOTE); announce_ml("CW_KNIFE_WIN_VOTE", side)
    for (new id = 1; id <= MAX_PLAYERS; id++) if (is_user_connected(id) && !is_user_bot(id) && !is_user_hltv(id) && cs_get_user_team(id) == winner) show_knife_vote_menu(id)
    if (!knife_eligible_count()) { finish_knife_vote(); return; }
    set_task(float(clamp(get_pcvar_num(g_CvarKnifeVoteSeconds), 5, 30)), "task_finish_knife_vote", TASK_KNIFE_VOTE)
}

stock show_knife_vote_menu(id)
{
    new title[96], label[64]
    refresh_branding(false)
    formatex(title, charsmax(title), "%s: %L", g_DisplayName, id, "CW_KNIFE_TITLE")
    new menu = menu_create(title, "menu_knife_vote_handler")
    ml_text(id, "CW_KNIFE_STAY", label, charsmax(label)); menu_additem(menu, label, "1")
    ml_text(id, "CW_KNIFE_SWAP", label, charsmax(label)); menu_additem(menu, label, "2")
    menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER); menu_display(id, menu)
}

stock finish_knife_vote()
{
    if (g_State != STATE_KNIFE_VOTE || g_KnifeDecisionMade) return
    remove_task(TASK_KNIFE_VOTE)
    g_KnifeDecisionMade = true
    if (g_KnifeSwapVotes > g_KnifeStayVotes)
    {
        swap_players(); toggle_team_a_side(); announce_ml("CW_KNIFE_VOTE_SWAP", g_KnifeSwapVotes, g_KnifeStayVotes); audit_event("knife_vote_swap")
    }
    else
    {
        announce_ml("CW_KNIFE_VOTE_STAY", g_KnifeStayVotes, g_KnifeSwapVotes); audit_event("knife_vote_stay")
    }
    set_task(3.0, "task_return_to_warmup", TASK_WARMUP)
}

stock recompute_knife_votes()
{
    g_KnifeStayVotes = 0; g_KnifeSwapVotes = 0
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id) || cs_get_user_team(id) != g_KnifeWinningSide)
        {
            g_KnifeVoted[id] = false; g_KnifeVoteChoice[id] = 0
            continue
        }
        if (!g_KnifeVoted[id]) continue
        if (g_KnifeVoteChoice[id] == 1) g_KnifeStayVotes++
        else if (g_KnifeVoteChoice[id] == 2) g_KnifeSwapVotes++
        else g_KnifeVoted[id] = false
    }
}

stock knife_eligible_count(excludeId = 0)
{
    new players[32], count, eligible
    get_players(players, count, "ch")
    for (new i = 0; i < count; i++) if (players[i] != excludeId && cs_get_user_team(players[i]) == g_KnifeWinningSide) eligible++
    return eligible
}
stock knife_vote_count() { return g_KnifeStayVotes + g_KnifeSwapVotes; }

stock randomize_pug_teams()
{
    new players[32], count
    get_players(players, count, "ch")
    new activeCount
    for (new i = 0; i < count; i++)
    {
        new CsTeams:team = cs_get_user_team(players[i])
        if (team == CS_TEAM_CT || team == CS_TEAM_T) players[activeCount++] = players[i]
    }
    count = activeCount
    if (count < 2) { announce_ml("CW_ERR_PUG_PLAYERS"); return; }
    for (new i = count - 1; i > 0; i--)
    {
        new target = random_num(0, i), temporary = players[i]
        players[i] = players[target]; players[target] = temporary
    }
    for (new i = 0; i < count; i++)
    {
        new id = players[i]
        if (is_user_alive(id)) user_silentkill(id)
        cs_set_user_team(id, (i % 2) == 0 ? CS_TEAM_CT : CS_TEAM_T)
    }
    g_TeamASide = CS_TEAM_CT; reset_ready_players(); server_cmd("sv_restart 1")
    announce_ml("CW_PUG_RANDOMIZED", count); audit_event("pug_randomized")
}

/* Validate every operator-configurable launch input and relationship using
 * temporary values only. Rejected transitions cannot mutate runtime globals
 * or CVARs. Version/state are plugin-owned status outputs, not launch input. */
stock bool:full_runtime_config_valid(bool:requireStartingMap)
{
    if (crossmap_recovery_pending() || !base_control_config_valid()) return false

    new cvarName[64], value[SERIES_MANIFEST_VALUE_MAX + 1]
    for (new index = 0; index < sizeof g_ManagedConfigNames; index++)
    {
        copy(cvarName, charsmax(cvarName), g_ManagedConfigNames[index])
        if (!cvar_exists(cvarName)) return false
        get_cvar_string(cvarName, value, charsmax(value)); trim(value)
        if (!managed_config_value_valid(index, value)) return false
    }
    for (new index = 0; index < sizeof g_SeriesExtraConfigNames; index++)
    {
        copy(cvarName, charsmax(cvarName), g_SeriesExtraConfigNames[index])
        if (!cvar_exists(cvarName))
        {
            new SeriesExtraConfigIndex:extraIndex = SeriesExtraConfigIndex:index
            if (extraIndex == SC_HLTV_ENABLED || extraIndex == SC_HLTV_AUTO_RECORD) copy(value, charsmax(value), "-")
            else return false
        }
        else get_cvar_string(cvarName, value, charsmax(value))
        trim(value)
        if (!series_extra_value_valid(index, value)) return false
    }

    new map1[MAX_MAP_TOKEN + 1], map2[MAX_MAP_TOKEN + 1], current[MAX_MAP_TOKEN + 1]
    get_pcvar_string(g_CvarMap1, map1, charsmax(map1)); get_pcvar_string(g_CvarMap2, map2, charsmax(map2))
    strtolower(map1); strtolower(map2)
    if (!map1[0]) get_mapname(map1, charsmax(map1))
    if (!valid_map_token(map1)) return false
    if (get_pcvar_num(g_CvarMapCount) == 2 && (!valid_map_token(map2) || equali(map1, map2))) return false
    if (requireStartingMap)
    {
        get_mapname(current, charsmax(current))
        if (!equali(current, map1)) return false
    }
    return true
}

/* These are the only user-configurable base/control CVARs outside the
 * immutable series arrays. kgb_cw_version and kgb_cw_state are plugin-owned
 * status outputs and therefore are deliberately not launch inputs. */
stock bool:base_control_config_valid()
{
    new value[8], number
    get_pcvar_string(g_CvarEnabled, value, charsmax(value)); trim(value)
    if (!parse_bool_exact(value, number)) return false
    get_pcvar_string(g_CvarAllowMenuSave, value, charsmax(value)); trim(value)
    return parse_bool_exact(value, number)
}

stock bool:load_runtime_settings(bool:crossmap)
{
    new value[128]
    get_pcvar_string(g_CvarFormat, value, charsmax(value)); strtolower(value)
    if (equal(value, "mr")) g_Format = FORMAT_MR
    else if (equal(value, "tl")) g_Format = FORMAT_TL
    else if (equal(value, "wl")) g_Format = FORMAT_WL
    else { log_amx("Invalid kgb_cw_format; expected mr, tl or wl"); return false; }

    get_pcvar_string(g_CvarReadyMode, value, charsmax(value)); strtolower(value)
    if (equal(value, "player")) g_ReadyMode = READY_PLAYER
    else if (equal(value, "team")) g_ReadyMode = READY_TEAM
    else if (equal(value, "admin")) g_ReadyMode = READY_ADMIN
    else { log_amx("Invalid kgb_cw_ready_mode; expected player, team or admin"); return false; }

    get_pcvar_string(g_CvarSwapPolicy, value, charsmax(value)); strtolower(value)
    if (!equal(value, "halves") && !equal(value, "off"))
    {
        log_amx("Invalid kgb_cw_swap_policy; expected halves or off"); return false
    }

    get_pcvar_string(g_CvarTeamAName, g_TeamAName, charsmax(g_TeamAName))
    get_pcvar_string(g_CvarTeamBName, g_TeamBName, charsmax(g_TeamBName))
    get_pcvar_string(g_CvarTeamATag, g_TeamATag, charsmax(g_TeamATag))
    get_pcvar_string(g_CvarTeamBTag, g_TeamBTag, charsmax(g_TeamBTag))
    if (!valid_display_token(g_TeamAName, MAX_TEAM_NAME) || !valid_display_token(g_TeamBName, MAX_TEAM_NAME))
    {
        log_amx("Rejected unsafe team name"); return false
    }
    if ((g_TeamATag[0] && !valid_display_token(g_TeamATag, MAX_TEAM_TAG)) ||
        (g_TeamBTag[0] && !valid_display_token(g_TeamBTag, MAX_TEAM_TAG)))
    {
        log_amx("Rejected unsafe clan tag"); return false
    }

    get_pcvar_string(g_CvarMap1, g_Map1, charsmax(g_Map1))
    get_pcvar_string(g_CvarMap2, g_Map2, charsmax(g_Map2))
    strtolower(g_Map1); strtolower(g_Map2)
    g_MapCount = clamp(get_pcvar_num(g_CvarMapCount), 1, 2)
    if (!g_Map1[0])
    {
        get_mapname(g_Map1, charsmax(g_Map1))
        set_pcvar_string(g_CvarMap1, g_Map1)
    }
    if (!valid_map_token(g_Map1)) { log_amx("Invalid kgb_cw_map1"); return false; }
    if (g_MapCount == 2 && (!valid_map_token(g_Map2) || equali(g_Map1, g_Map2)))
    {
        log_amx("Invalid kgb_cw_map2 for two-map match"); return false
    }

    if (!validate_phase_config(g_CvarWarmupConfig, "warmup") ||
        !validate_phase_config(g_CvarMatchConfig, "match") ||
        !validate_phase_config(g_CvarOvertimeConfig, "overtime") ||
        !validate_phase_config(g_CvarDefaultConfig, "default")) return false

    if (!crossmap) g_MapNumber = 1
    return true
}

stock bool:validate_phase_config(cvar, const phase[])
{
    new token[MAX_CONFIG_TOKEN + 1], path[MAX_CONFIG_TOKEN + 5]
    get_pcvar_string(cvar, token, charsmax(token))
    if (!token[0]) return true
    if (!valid_simple_token(token, MAX_CONFIG_TOKEN))
    {
        log_amx("Rejected unsafe %s config basename", phase); return false
    }
    formatex(path, charsmax(path), "%s.cfg", token)
    if (!file_exists(path))
    {
        log_amx("Required %s config file does not exist: %s", phase, path)
        return false
    }
    return true
}

stock execute_phase_config(cvar, const phase[])
{
    new token[MAX_CONFIG_TOKEN + 1]
    if (cvar == g_CvarWarmupConfig) series_extra_string(SC_WARMUP_CONFIG, cvar, token, charsmax(token))
    else if (cvar == g_CvarMatchConfig) series_extra_string(SC_MATCH_CONFIG, cvar, token, charsmax(token))
    else if (cvar == g_CvarOvertimeConfig) series_extra_string(SC_OVERTIME_CONFIG, cvar, token, charsmax(token))
    else if (cvar == g_CvarDefaultConfig) series_extra_string(SC_DEFAULT_CONFIG, cvar, token, charsmax(token))
    else get_pcvar_string(cvar, token, charsmax(token))
    if (!token[0]) return
    if (!valid_simple_token(token, MAX_CONFIG_TOKEN))
    {
        log_amx("Refused unsafe %s config at execution time", phase); return
    }
    /* Only ASCII alphanumeric, underscore and hyphen reach server_cmd. */
    server_cmd("exec %s.cfg", token); server_exec()
    log_amx("Executed validated %s config", phase)
}

stock bool:valid_simple_token(const value[], maxLength)
{
    new length = strlen(value)
    if (length < 1 || length > maxLength) return false
    for (new i = 0; i < length; i++)
    {
        new c = value[i]
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-')) return false
    }
    return true
}

stock bool:is_decimal_number(const value[])
{
    if (!value[0]) return false
    for (new i = 0; value[i]; i++) if (value[i] < '0' || value[i] > '9') return false
    return true
}

stock bool:valid_map_token(const value[])
{
    return valid_simple_token(value, MAX_MAP_TOKEN) && is_map_valid(value)
}

stock bool:valid_display_token(const value[], maxLength)
{
    new length = strlen(value)
    if (length < 1 || length > maxLength) return false
    for (new i = 0; i < length; i++)
    {
        new c = value[i]
        if (c < 32 || c > 126 || c == ';' || c == '^"' || c == '%' || c == 92) return false
    }
    return true
}

stock refresh_branding(bool:logInvalid)
{
    new value[128]

    series_managed_string(MC_DISPLAY_NAME, g_CvarDisplayName, value, charsmax(value)); trim(value)
    if (valid_display_token(value, MAX_DISPLAY_NAME)) copy(g_DisplayName, charsmax(g_DisplayName), value)
    else
    {
        copy(g_DisplayName, charsmax(g_DisplayName), DEFAULT_DISPLAY_NAME)
        if (logInvalid) log_amx("Rejected unsafe or empty display name; using package default")
    }

    series_managed_string(MC_CHAT_PREFIX, g_CvarChatPrefix, value, charsmax(value)); trim(value)
    if (valid_display_token(value, MAX_CHAT_PREFIX)) copy(g_ChatPrefix, charsmax(g_ChatPrefix), value)
    else
    {
        copy(g_ChatPrefix, charsmax(g_ChatPrefix), DEFAULT_CHAT_PREFIX)
        if (logInvalid) log_amx("Rejected unsafe or empty chat prefix; using package default")
    }
}

stock snapshot_environment()
{
    if (g_EnvironmentSaved) return
    get_cvar_string("hostname", g_OldHostname, charsmax(g_OldHostname))
    get_cvar_string("sv_password", g_OldPassword, charsmax(g_OldPassword))
    if (cvar_exists("sv_allow_shield")) get_cvar_string("sv_allow_shield", g_OldShield, charsmax(g_OldShield)); else g_OldShield[0] = 0
    g_EnvironmentSaved = true
}

stock apply_environment(bool:logChanges)
{
    new value[128]
    if (series_extra_number(SC_SET_HOSTNAME, g_CvarSetHostname))
    {
        series_extra_string(SC_HOSTNAME, g_CvarHostname, value, charsmax(value))
        if (valid_runtime_cvar_value(value, 127))
        {
            set_cvar_string("hostname", value)
            if (logChanges) log_amx("Applied managed match hostname")
        }
        else log_amx("Rejected invalid managed hostname")
    }
    if (series_extra_number(SC_SET_PASSWORD, g_CvarSetPassword))
    {
        new password[64]
        series_extra_string(SC_PASSWORD, g_CvarPassword, password, charsmax(password))
        if (valid_runtime_cvar_value(password, 63))
        {
            set_cvar_string("sv_password", password)
            if (logChanges) log_amx("Applied managed match password (redacted)")
        }
        else log_amx("Rejected invalid managed password (redacted)")
    }
    if (series_extra_number(SC_DISABLE_SHIELD, g_CvarDisableShield) && cvar_exists("sv_allow_shield"))
    {
        set_cvar_num("sv_allow_shield", 0)
        if (logChanges) log_amx("Disabled tactical shield")
    }
    g_ShieldRestricted = bool:series_extra_number(SC_DISABLE_SHIELD, g_CvarDisableShield)
    if (g_ShieldRestricted)
    {
        for (new id = 1; id <= MAX_PLAYERS; id++)
        {
            if (is_user_connected(id) && cs_get_user_shield(id)) engclient_cmd(id, "drop", "weapon_shield")
        }
    }
}

stock bool:valid_runtime_cvar_value(const value[], maxLength)
{
    new length = strlen(value)
    if (length > maxLength) return false
    for (new i = 0; i < length; i++)
    {
        if (value[i] < 32 || value[i] > 126 || value[i] == '^"' || value[i] == ';' || value[i] == 92) return false
    }
    return true
}

stock restore_environment()
{
    if (!g_EnvironmentSaved) return
    set_cvar_string("hostname", g_OldHostname)
    set_cvar_string("sv_password", g_OldPassword)
    if (g_OldShield[0] && cvar_exists("sv_allow_shield")) set_cvar_string("sv_allow_shield", g_OldShield)
    g_ShieldRestricted = false; g_EnvironmentSaved = false; g_OldPassword[0] = 0
    log_amx("Restored managed hostname, password (redacted), and shield state")
}

stock bool:persist_crossmap_state()
{
    if (crossmap_recovery_pending())
    {
        log_amx("Refused to overwrite pending cross-map baseline recovery")
        return false
    }
    new value[32]
    set_localinfo(LI_ACTIVE, "")
    if (!persist_series_manifest()) return false
    set_localinfo(LI_MAP, g_Map2)
    num_to_str(g_TeamAScore, value, charsmax(value)); set_localinfo(LI_SCORE_A, value)
    num_to_str(g_TeamBScore, value, charsmax(value)); set_localinfo(LI_SCORE_B, value)
    set_localinfo(LI_MATCH_ID, g_MatchId); set_localinfo(LI_RECOVERY_ID, g_MatchId)
    set_localinfo(LI_OLD_HOST, g_OldHostname)
    set_localinfo(LI_OLD_PASS, g_OldPassword); set_localinfo(LI_OLD_SHIELD, g_OldShield)
    set_localinfo(LI_ENV_SAVED, g_EnvironmentSaved ? "1" : "0")
    num_to_str(_:g_TeamASide, value, charsmax(value)); set_localinfo(LI_TEAM_A_SIDE, value)
    set_localinfo(LI_PUG_ACTIVE, g_PugActive ? "1" : "0")
    if (g_PugActive)
    {
        series_managed_string(MC_PUG_STYLE, g_CvarPugStyle, value, charsmax(value)); set_localinfo(LI_PUG_STYLE, value)
    }
    else set_localinfo(LI_PUG_STYLE, "")
    set_localinfo(LI_LEGACY_RECORD, g_LegacyRecordOverride ? "1" : "0")
    num_to_str(g_LegacyOldClientDemos, value, charsmax(value)); set_localinfo(LI_LEGACY_CLIENT, value)
    num_to_str(g_LegacyOldHltvEnabled, value, charsmax(value)); set_localinfo(LI_LEGACY_HLTV_ENABLED, value)
    num_to_str(g_LegacyOldHltvAuto, value, charsmax(value)); set_localinfo(LI_LEGACY_HLTV_AUTO, value)
    set_localinfo(LI_ACTIVE, "1")
    return true
}

stock bool:parse_crossmap_envelope()
{
    new active[4], expected[MAX_MAP_TOKEN + 1], current[MAX_MAP_TOKEN + 1]
    new storedMatchId[MAX_MATCH_ID + 1], recoveryId[MAX_MATCH_ID + 1]
    new scoreAValue[16], scoreBValue[16], envSaved[4]
    new oldHostname[128], oldPassword[64], oldShield[8], sideValue[8]
    new pugValue[4], pugStyle[16], legacyValue[4], legacyClientValue[8]
    new legacyHltvEnabledValue[8], legacyHltvAutoValue[8]
    new scoreA, scoreB, side, pugActive, legacyActive, legacyClient, legacyHltvEnabled, legacyHltvAuto

    get_localinfo(LI_ACTIVE, active, charsmax(active))
    get_localinfo(LI_MAP, expected, charsmax(expected)); get_mapname(current, charsmax(current))
    get_localinfo(LI_MATCH_ID, storedMatchId, charsmax(storedMatchId))
    get_localinfo(LI_RECOVERY_ID, recoveryId, charsmax(recoveryId))
    get_localinfo(LI_SCORE_A, scoreAValue, charsmax(scoreAValue)); get_localinfo(LI_SCORE_B, scoreBValue, charsmax(scoreBValue))
    get_localinfo(LI_ENV_SAVED, envSaved, charsmax(envSaved))
    get_localinfo(LI_OLD_HOST, oldHostname, charsmax(oldHostname)); get_localinfo(LI_OLD_PASS, oldPassword, charsmax(oldPassword))
    get_localinfo(LI_OLD_SHIELD, oldShield, charsmax(oldShield)); get_localinfo(LI_TEAM_A_SIDE, sideValue, charsmax(sideValue))
    get_localinfo(LI_PUG_ACTIVE, pugValue, charsmax(pugValue)); get_localinfo(LI_PUG_STYLE, pugStyle, charsmax(pugStyle)); strtolower(pugStyle)
    get_localinfo(LI_LEGACY_RECORD, legacyValue, charsmax(legacyValue))
    get_localinfo(LI_LEGACY_CLIENT, legacyClientValue, charsmax(legacyClientValue))
    get_localinfo(LI_LEGACY_HLTV_ENABLED, legacyHltvEnabledValue, charsmax(legacyHltvEnabledValue))
    get_localinfo(LI_LEGACY_HLTV_AUTO, legacyHltvAutoValue, charsmax(legacyHltvAutoValue))

    if (!equal(active, "1") || !parse_series_manifest() || !valid_match_id_exact(storedMatchId) ||
        !valid_match_id_exact(recoveryId) || !equal(recoveryId, storedMatchId) ||
        !equal(storedMatchId, g_RestoreMatchId) || !valid_map_token(expected) || !equali(expected, current) ||
        !equali(expected, g_SeriesRestoreValues[_:MC_MAP2])) return false
    if (!parse_uint_exact(scoreAValue, 0, 1000, scoreA) || !parse_uint_exact(scoreBValue, 0, 1000, scoreB) ||
        !equal(envSaved, "1") || !valid_snapshot_value(oldHostname, 127) || !valid_snapshot_value(oldPassword, 63)) return false
    if (oldShield[0])
    {
        new shield
        if (!parse_bool_exact(oldShield, shield)) return false
    }
    if (!parse_uint_exact(sideValue, _:CS_TEAM_T, _:CS_TEAM_CT, side) ||
        !parse_bool_exact(pugValue, pugActive) || !parse_bool_exact(legacyValue, legacyActive) ||
        !parse_bool_exact(legacyClientValue, legacyClient) || !parse_legacy_tristate(legacyHltvEnabledValue, legacyHltvEnabled) ||
        !parse_legacy_tristate(legacyHltvAutoValue, legacyHltvAuto)) return false
    if (pugActive)
    {
        if (!equal(pugStyle, g_SeriesRestoreValues[_:MC_PUG_STYLE]) || !str_to_num(g_SeriesRestoreValues[_:MC_PUG_MODE])) return false
    }
    else if (pugStyle[0]) return false

    new hltvEnabledIndex = sizeof g_ManagedConfigNames + _:SC_HLTV_ENABLED
    new hltvAutoIndex = sizeof g_ManagedConfigNames + _:SC_HLTV_AUTO_RECORD
    if (legacyActive)
    {
        if ((equal(g_SeriesRestoreValues[hltvEnabledIndex], "-") && legacyHltvEnabled != -1) ||
            (!equal(g_SeriesRestoreValues[hltvEnabledIndex], "-") && legacyHltvEnabled < 0) ||
            (equal(g_SeriesRestoreValues[hltvAutoIndex], "-") && legacyHltvAuto != -1) ||
            (!equal(g_SeriesRestoreValues[hltvAutoIndex], "-") && legacyHltvAuto < 0)) return false
    }
    else if (legacyClient != 0 || legacyHltvEnabled != -1 || legacyHltvAuto != -1) return false

    g_RestoreScoreA = scoreA; g_RestoreScoreB = scoreB; g_RestoreTeamASide = CsTeams:side
    copy(g_RestoreOldHostname, charsmax(g_RestoreOldHostname), oldHostname)
    copy(g_RestoreOldPassword, charsmax(g_RestoreOldPassword), oldPassword)
    copy(g_RestoreOldShield, charsmax(g_RestoreOldShield), oldShield)
    g_RestorePugActive = bool:pugActive; copy(g_RestorePugStyle, charsmax(g_RestorePugStyle), pugStyle)
    g_RestoreLegacyRecord = bool:legacyActive; g_RestoreLegacyClient = legacyClient
    g_RestoreLegacyHltvEnabled = legacyHltvEnabled; g_RestoreLegacyHltvAuto = legacyHltvAuto
    return true
}

stock commit_crossmap_envelope()
{
    commit_series_manifest()
    g_PreviousMapScoreA = g_RestoreScoreA; g_PreviousMapScoreB = g_RestoreScoreB
    g_MapNumber = 2; g_MapCount = 2; g_TeamAScore = 0; g_TeamBScore = 0
    g_Half = 1; g_RoundsThisHalf = 0; g_HalfStartA = 0; g_HalfStartB = 0
    g_InOvertime = false; g_OvertimeCycle = 0; g_TeamASide = g_RestoreTeamASide
    copy(g_OldHostname, charsmax(g_OldHostname), g_RestoreOldHostname)
    copy(g_OldPassword, charsmax(g_OldPassword), g_RestoreOldPassword)
    copy(g_OldShield, charsmax(g_OldShield), g_RestoreOldShield)
    g_EnvironmentSaved = true
    g_PugActive = g_RestorePugActive
    if (g_PugActive) set_pcvar_string(g_CvarPugStyle, g_RestorePugStyle)
    g_LegacyRecordOverride = g_RestoreLegacyRecord
    g_LegacyOldClientDemos = g_RestoreLegacyClient
    g_LegacyOldHltvEnabled = g_RestoreLegacyHltvEnabled
    g_LegacyOldHltvAuto = g_RestoreLegacyHltvAuto
}

/* A full map-two envelope may be rejected because its topology, manifest, or
 * scores are stale without making its separately validated pre-match baseline
 * unsafe. Restore that baseline before invalidating the persisted envelope so
 * a failed resume cannot strand temporary credentials or recording policy. */
stock bool:restore_rejected_crossmap_state()
{
    new recoveryPending[4], envSaved[4], oldHostname[128], oldPassword[64], oldShield[8], shield
    new storedMatchId[MAX_MATCH_ID + 1], recoveryId[MAX_MATCH_ID + 1]
    new legacyValue[4], legacyClientValue[8], legacyHltvEnabledValue[8], legacyHltvAutoValue[8]
    new legacyActive, legacyClient, legacyHltvEnabled, legacyHltvAuto
    new bool:complete = true, bool:legacyComplete = true, bool:legacyValueRestored
    get_localinfo(LI_RECOVERY_PENDING, recoveryPending, charsmax(recoveryPending))
    new bool:wasPending = bool:equal(recoveryPending, "1")
    get_localinfo(LI_MATCH_ID, storedMatchId, charsmax(storedMatchId))
    get_localinfo(LI_RECOVERY_ID, recoveryId, charsmax(recoveryId))
    if (!valid_match_id_exact(storedMatchId) || !valid_match_id_exact(recoveryId) || !equal(storedMatchId, recoveryId))
    {
        set_localinfo(LI_RECOVERY_PENDING, "1")
        log_amx("Cross-map recovery identity is missing or mismatched; evidence was preserved")
        return false
    }
    get_localinfo(LI_ENV_SAVED, envSaved, charsmax(envSaved))
    get_localinfo(LI_OLD_HOST, oldHostname, charsmax(oldHostname)); get_localinfo(LI_OLD_PASS, oldPassword, charsmax(oldPassword))
    get_localinfo(LI_OLD_SHIELD, oldShield, charsmax(oldShield))

    if (equal(envSaved, "done"))
    {
        if (!wasPending) complete = false
    }
    else if (envSaved[0])
    {
        if (equal(envSaved, "1") && valid_snapshot_value(oldHostname, 127) && valid_snapshot_value(oldPassword, 63) &&
            (!oldShield[0] || parse_bool_exact(oldShield, shield)))
        {
            copy(g_OldHostname, charsmax(g_OldHostname), oldHostname)
            copy(g_OldPassword, charsmax(g_OldPassword), oldPassword)
            copy(g_OldShield, charsmax(g_OldShield), oldShield)
            g_EnvironmentSaved = true
            restore_environment()
            set_localinfo(LI_OLD_HOST, ""); set_localinfo(LI_OLD_PASS, "")
            set_localinfo(LI_OLD_SHIELD, ""); set_localinfo(LI_ENV_SAVED, "done")
        }
        else complete = false
    }
    else complete = false

    get_localinfo(LI_LEGACY_RECORD, legacyValue, charsmax(legacyValue))
    if (equal(legacyValue, "done"))
    {
        if (!wasPending) legacyComplete = false
    }
    else if (!legacyValue[0])
        legacyComplete = false
    else
    {
        if (!parse_bool_exact(legacyValue, legacyActive)) legacyComplete = false
        else
        {
            get_localinfo(LI_LEGACY_CLIENT, legacyClientValue, charsmax(legacyClientValue))
            get_localinfo(LI_LEGACY_HLTV_ENABLED, legacyHltvEnabledValue, charsmax(legacyHltvEnabledValue))
            get_localinfo(LI_LEGACY_HLTV_AUTO, legacyHltvAutoValue, charsmax(legacyHltvAutoValue))

            if (equal(legacyClientValue, "done"))
            {
                if (!wasPending) legacyComplete = false
            }
            else if (legacyClientValue[0])
            {
                if (parse_bool_exact(legacyClientValue, legacyClient) && (legacyActive || legacyClient == 0))
                {
                    if (legacyActive) set_pcvar_num(g_CvarClientDemos, legacyClient)
                    set_localinfo(LI_LEGACY_CLIENT, "done")
                    if (legacyActive) legacyValueRestored = true
                }
                else legacyComplete = false
            }
            else legacyComplete = false
            if (equal(legacyHltvEnabledValue, "done"))
            {
                if (!wasPending) legacyComplete = false
            }
            else if (legacyHltvEnabledValue[0])
            {
                if (!parse_legacy_tristate(legacyHltvEnabledValue, legacyHltvEnabled) ||
                    (!legacyActive && legacyHltvEnabled != -1)) legacyComplete = false
                else if (legacyHltvEnabled < 0 || cvar_exists("kgb_cw_hltv_enabled"))
                {
                    if (legacyHltvEnabled >= 0) set_cvar_num("kgb_cw_hltv_enabled", legacyHltvEnabled)
                    set_localinfo(LI_LEGACY_HLTV_ENABLED, "done")
                    if (legacyActive) legacyValueRestored = true
                }
                else legacyComplete = false
            }
            else legacyComplete = false
            if (equal(legacyHltvAutoValue, "done"))
            {
                if (!wasPending) legacyComplete = false
            }
            else if (legacyHltvAutoValue[0])
            {
                if (!parse_legacy_tristate(legacyHltvAutoValue, legacyHltvAuto) ||
                    (!legacyActive && legacyHltvAuto != -1)) legacyComplete = false
                else if (legacyHltvAuto < 0 || cvar_exists("kgb_cw_hltv_auto_record"))
                {
                    if (legacyHltvAuto >= 0) set_cvar_num("kgb_cw_hltv_auto_record", legacyHltvAuto)
                    set_localinfo(LI_LEGACY_HLTV_AUTO, "done")
                    if (legacyActive) legacyValueRestored = true
                }
                else legacyComplete = false
            }
            else legacyComplete = false

            get_localinfo(LI_LEGACY_CLIENT, legacyClientValue, charsmax(legacyClientValue))
            get_localinfo(LI_LEGACY_HLTV_ENABLED, legacyHltvEnabledValue, charsmax(legacyHltvEnabledValue))
            get_localinfo(LI_LEGACY_HLTV_AUTO, legacyHltvAutoValue, charsmax(legacyHltvAutoValue))
            if (legacyComplete && equal(legacyClientValue, "done") &&
                equal(legacyHltvEnabledValue, "done") && equal(legacyHltvAutoValue, "done"))
            {
                set_localinfo(LI_LEGACY_RECORD, "done")
                set_localinfo(LI_LEGACY_CLIENT, ""); set_localinfo(LI_LEGACY_HLTV_ENABLED, "")
                set_localinfo(LI_LEGACY_HLTV_AUTO, "")
            }
            else legacyComplete = false
        }
    }
    if (!legacyComplete) complete = false
    if (legacyValueRestored && legacyComplete) audit_event("legacy_record_mode_restored")
    /* Keep the identity and handled markers journaled until the caller
     * reaches the dedicated finalizer. A reload in this narrow
     * interval safely retries the idempotent done-marked recovery. */
    set_localinfo(LI_RECOVERY_PENDING, "1")
    return complete
}

stock clear_crossmap_state(bool:preserveRecovery = false)
{
    new bool:keepRecovery = preserveRecovery || crossmap_recovery_pending()
    clear_crossmap_storage(keepRecovery)
}

/* This is the only path allowed to discard a pending recovery journal. Its
 * callers have already restored every independently recoverable baseline.
 * First invalidate the active envelope while the done-marked journal remains
 * retryable. Clearing pending is the commit point; stale payload left by a
 * later interruption is harmless and is overwritten by the next envelope. */
stock finalize_crossmap_recovery()
{
    clear_crossmap_storage(true)
    set_localinfo(LI_RECOVERY_PENDING, "")
    clear_crossmap_recovery_storage()
}

stock clear_crossmap_storage(bool:keepRecovery)
{
    set_localinfo(LI_ACTIVE, ""); set_localinfo(LI_MAP, "")
    clear_series_manifest_storage()
    set_localinfo(LI_SCORE_A, ""); set_localinfo(LI_SCORE_B, "")
    set_localinfo(LI_TEAM_A_SIDE, "")
    set_localinfo(LI_PUG_ACTIVE, ""); set_localinfo(LI_PUG_STYLE, "")
    if (!keepRecovery)
    {
        set_localinfo(LI_RECOVERY_PENDING, "")
        clear_crossmap_recovery_storage()
    }
}

stock clear_crossmap_recovery_storage()
{
    set_localinfo(LI_MATCH_ID, ""); set_localinfo(LI_RECOVERY_ID, "")
    set_localinfo(LI_OLD_HOST, ""); set_localinfo(LI_OLD_PASS, "")
    set_localinfo(LI_OLD_SHIELD, ""); set_localinfo(LI_ENV_SAVED, "")
    set_localinfo(LI_LEGACY_RECORD, ""); set_localinfo(LI_LEGACY_CLIENT, "")
    set_localinfo(LI_LEGACY_HLTV_ENABLED, ""); set_localinfo(LI_LEGACY_HLTV_AUTO, "")
}

stock bool:crossmap_recovery_pending()
{
    new value[4]
    get_localinfo(LI_RECOVERY_PENDING, value, charsmax(value))
    return bool:equal(value, "1")
}

stock create_match_id() { get_time("%Y%m%d_%H%M%S", g_MatchId, charsmax(g_MatchId)); }

stock start_client_demos()
{
    if (!series_extra_number(SC_CLIENT_DEMOS, g_CvarClientDemos)) return
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        start_client_demo(id)
    }
    log_amx("Requested opt-in client demos with sanitized filenames")
}

stock start_client_demo(id)
{
    if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id) || g_DemoStarted[id]) return
    new name[32], safeName[32], demo[96]
    get_user_name(id, name, charsmax(name)); sanitize_file_component(name, safeName, charsmax(safeName))
    formatex(demo, charsmax(demo), "kgbcw_%s_m%d_%s", g_MatchId, g_MapNumber, safeName)
    client_cmd(id, "record %s", demo); g_DemoStarted[id] = true
}

stock stop_client_demos()
{
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        if (g_DemoStarted[id] && is_user_connected(id)) client_cmd(id, "stop")
        g_DemoStarted[id] = false
    }
}

stock take_match_screenshots()
{
    if (series_managed_number(MC_SCREENSHOTS, g_CvarScreenshots))
    {
        for (new id = 1; id <= MAX_PLAYERS; id++)
        {
            if (is_user_connected(id) && !is_user_bot(id) && !is_user_hltv(id)) client_cmd(id, "snapshot")
        }
        log_amx("Requested opt-in client score screenshots")
    }
    if (!series_managed_number(MC_SCOREID_SCREENSHOTS, g_CvarScoreIdScreenshots)) return
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id) || !(get_user_flags(id) & ADMIN_CFG)) continue
        show_identity_motd(id)
        remove_task(TASK_SCOREID_SNAPSHOT + id)
        g_ScoreIdSnapshotAuthorized[id] = true
        set_task(0.8, "task_scoreid_snapshot", TASK_SCOREID_SNAPSHOT + id)
    }
    log_amx("Requested opt-in admin identity screenshots")
}

stock sanitize_file_component(const input[], output[], length)
{
    new position
    for (new i = 0; input[i] && position < length; i++)
    {
        new c = input[i]
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-') output[position++] = c
        else output[position++] = '_'
    }
    if (!position) output[position++] = 'p'
    output[position] = 0
}

stock emit_match_event(const event[])
{
    if (g_ForwardEvent >= 0)
    {
        new result
        ExecuteForward(g_ForwardEvent, result, event, g_TeamAName, g_TeamBName, g_MapNumber, g_Half, total_score_a(), total_score_b())
    }
    audit_event(event)
}

stock audit_event(const event[])
{
    new stateText[24]
    state_name(stateText, charsmax(stateText))
    log_amx("event=%s match=%s state=%s tag_a=%s tag_b=%s map=%d half=%d score_a=%d score_b=%d", event, g_MatchId, stateText, g_TeamATag, g_TeamBTag, g_MapNumber, g_Half, total_score_a(), total_score_b())
    log_to_file("kgb_clan_war.log", "event=%s match=%s state=%s team_a=%s tag_a=%s team_b=%s tag_b=%s map=%d half=%d score_a=%d score_b=%d", event, g_MatchId, stateText, g_TeamAName, g_TeamATag, g_TeamBName, g_TeamBTag, g_MapNumber, g_Half, total_score_a(), total_score_b())
}

stock write_stats_event(const event[])
{
    if (!series_extra_number(SC_FILE_STATS, g_CvarFileStats) || !g_MatchId[0]) return
    new dataDir[128], directory[192], path[256], timestamp[32], line[384]
    get_localinfo("amxx_datadir", dataDir, charsmax(dataDir))
    formatex(directory, charsmax(directory), "%s/kgb_clan_war", dataDir); mkdir(directory)
    formatex(path, charsmax(path), "%s/%s.log", directory, g_MatchId)
    get_time("%Y-%m-%dT%H:%M:%S", timestamp, charsmax(timestamp))
    formatex(line, charsmax(line), "timestamp=%s event=%s map=%d half=%d overtime=%d team_a=%s tag_a=%s team_b=%s tag_b=%s score_a=%d score_b=%d", timestamp, event, g_MapNumber, g_Half, g_OvertimeCycle, g_TeamAName, g_TeamATag, g_TeamBName, g_TeamBTag, total_score_a(), total_score_b())
    write_file(path, line)
    if (equali(event, "half_end") || equali(event, "overtime_half_end")) write_half_player_stats(path, timestamp, event)
}

stock capture_half_player_baseline()
{
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        if (is_user_connected(id))
        {
            g_HalfKillsStart[id] = get_user_frags(id)
            g_HalfDeathsStart[id] = cs_get_user_deaths(id)
        }
        else
        {
            g_HalfKillsStart[id] = 0; g_HalfDeathsStart[id] = 0
        }
    }
}

stock write_half_player_stats(const path[], const timestamp[], const event[])
{
    new players[32], count
    get_players(players, count, "ch")
    for (new i = 0; i < count; i++)
    {
        new id = players[i], name[32], safeName[64], authid[36], side[24], line[384]
        get_user_name(id, name, charsmax(name)); sanitize_log_component(name, safeName, charsmax(safeName))
        get_user_authid(id, authid, charsmax(authid)); get_side_name(cs_get_user_team(id), side, charsmax(side))
        formatex(line, charsmax(line), "timestamp=%s event=%s kind=player map=%d half=%d overtime=%d userid=%d authid=%s name=%s side=%s half_kills=%d half_deaths=%d scoreboard_kills=%d scoreboard_deaths=%d", timestamp, event, g_MapNumber, g_Half, g_OvertimeCycle, get_user_userid(id), authid, safeName, side, get_user_frags(id) - g_HalfKillsStart[id], cs_get_user_deaths(id) - g_HalfDeathsStart[id], get_user_frags(id), cs_get_user_deaths(id))
        write_file(path, line)
    }
}

stock sanitize_log_component(const input[], output[], length)
{
    new position
    for (new i = 0; input[i] && position < length; i++)
    {
        new c = input[i]
        if (c <= 32 || c > 126 || c == '=' || c == 92) c = '_'
        output[position++] = c
    }
    output[position] = 0
}

stock print_score(id, bool:detailed)
{
    new stateText[24], format[4], side[24]
    new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
    state_name(stateText, charsmax(stateText)); get_format_name(format, charsmax(format)); get_side_name(g_TeamASide, side, charsmax(side))
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    if (id == 0)
    {
        cw_console_ml(0, "CW_SCORE_MAP", g_MapNumber, labelA, g_TeamAScore, g_TeamBScore, labelB)
        if (g_MapCount == 2) cw_console_ml(0, "CW_SCORE_SERIES", labelA, total_score_a(), total_score_b(), labelB)
        if (detailed) cw_console_ml(0, "CW_SCORE_DETAIL", stateText, format, g_MapNumber, g_MapCount, g_Half, g_OvertimeCycle, side)
    }
    else
    {
        cw_chat_ml(id, "CW_SCORE_MAP", g_MapNumber, labelA, g_TeamAScore, g_TeamBScore, labelB)
        if (g_MapCount == 2) cw_chat_ml(id, "CW_SCORE_SERIES", labelA, total_score_a(), total_score_b(), labelB)
        if (detailed) cw_chat_ml(id, "CW_SCORE_DETAIL", stateText, format, g_MapNumber, g_MapCount, g_Half, g_OvertimeCycle, side)
    }
}

stock swap_players()
{
    new players[32], count
    get_players(players, count, "h")
    for (new i = 0; i < count; i++)
    {
        new id = players[i]
        new CsTeams:team = cs_get_user_team(id)
        if (team == CS_TEAM_CT) cs_set_user_team(id, CS_TEAM_T)
        else if (team == CS_TEAM_T) cs_set_user_team(id, CS_TEAM_CT)
    }
}

stock toggle_team_a_side() { g_TeamASide = g_TeamASide == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT; }

stock bool:automatic_swaps_enabled()
{
    new value[16]
    series_managed_string(MC_SWAP_POLICY, g_CvarSwapPolicy, value, charsmax(value)); strtolower(value)
    return bool:equal(value, "halves")
}
stock identity_for_side(CsTeams:side)
{
    if (side != CS_TEAM_CT && side != CS_TEAM_T) return -1
    return side == g_TeamASide ? 0 : 1
}

stock reset_match_data(bool:resetSides)
{
    g_MatchId[0] = 0
    g_TeamAScore = 0; g_TeamBScore = 0; g_PreviousMapScoreA = 0; g_PreviousMapScoreB = 0
    g_HalfStartA = 0; g_HalfStartB = 0; g_Half = 1; g_RoundsThisHalf = 0
    g_OvertimeCycle = 0; g_InOvertime = false; g_RoundResolved = false; g_Lo3Running = false; g_MapNumber = 1
    g_OvertimeYesVotes = 0; g_OvertimeNoVotes = 0
    g_PlayoutYesVotes = 0; g_PlayoutNoVotes = 0; g_PlayoutDecisionMade = false
    g_TimeLimitExpired = false; g_ResetTlTimerAfterLo3 = false
    if (resetSides) g_TeamASide = CS_TEAM_CT
}

stock reset_ready_players()
{
    for (new id = 1; id <= MAX_PLAYERS; id++) g_Ready[id] = false
    g_TeamReady[0] = false; g_TeamReady[1] = false
}

stock cancel_transition_tasks()
{
    cancel_lo3_tasks(); remove_task(TASK_HALFTIME); remove_task(TASK_WARMUP)
    g_CaptureHalfBaselineAfterLo3 = false; g_ResetTlTimerAfterLo3 = false; g_TimeLimitExpired = false
    remove_task(TASK_KNIFE_VOTE); remove_task(TASK_OVERTIME_VOTE); remove_task(TASK_PLAYOUT_VOTE); remove_task(TASK_TIME_LIMIT); remove_task(TASK_TL_ROUND_END); remove_task(TASK_MAP_CHANGE); remove_task(TASK_PUG_MAP_CHANGE)
    for (new id = 1; id <= MAX_PLAYERS; id++) remove_task(TASK_KNIFE_EQUIP + id)
}

stock cancel_lo3_tasks()
{
    remove_task(TASK_LO3_1); remove_task(TASK_LO3_2); remove_task(TASK_LO3_3); remove_task(TASK_LO3_DONE)
    g_Lo3Running = false
}

stock schedule_time_limit_half()
{
    remove_task(TASK_TIME_LIMIT)
    set_task(float(clamp(series_managed_number(MC_TIME_LIMIT, g_CvarTimeLimitMinutes), 1, 180)) * 60.0, "task_time_limit_half", TASK_TIME_LIMIT)
}

stock schedule_status_hud()
{
    remove_task(TASK_STATUS_HUD)
    new interval = series_managed_number(MC_HUD_INTERVAL, g_CvarHudInterval)
    if (interval > 0) set_task(float(clamp(interval, 3, 60)), "task_status_hud", TASK_STATUS_HUD)
}

stock set_scoreboard_team_score(const team[], score)
{
    message_begin(MSG_ALL, get_user_msgid("TeamScore")); write_string(team); write_short(score); message_end()
}

stock set_cw_state(MatchState:matchState)
{
    g_State = matchState
    new name[24]; state_name(name, charsmax(name)); set_pcvar_string(g_CvarState, name)
}

stock state_name(output[], length)
{
    switch (g_State)
    {
        case STATE_WARMUP: copy(output, length, "warmup")
        case STATE_KNIFE: copy(output, length, "knife")
        case STATE_KNIFE_VOTE: copy(output, length, "knife_vote")
        case STATE_LIVE: copy(output, length, "live")
        case STATE_HALFTIME: copy(output, length, "halftime")
        case STATE_HALF_READY: copy(output, length, "half_ready")
        case STATE_OVERTIME_VOTE: copy(output, length, "overtime_vote")
        case STATE_PLAYOUT_VOTE: copy(output, length, "playout_vote")
        case STATE_FINISHED: copy(output, length, "finished")
        default: copy(output, length, "off")
    }
}

stock get_format_name(output[], length)
{
    switch (g_Format)
    {
        case FORMAT_TL: copy(output, length, "TL")
        case FORMAT_WL: copy(output, length, "WL")
        default: copy(output, length, "MR")
    }
}

stock get_ready_mode_name(output[], length)
{
    switch (g_ReadyMode)
    {
        case READY_TEAM: copy(output, length, "team")
        case READY_ADMIN: copy(output, length, "admin")
        default: copy(output, length, "player")
    }
}

stock get_side_name(CsTeams:side, output[], length)
{
    if (side == CS_TEAM_CT) copy(output, length, "Counter-Terrorists")
    else if (side == CS_TEAM_T) copy(output, length, "Terrorists")
    else copy(output, length, "spectators")
}

stock get_team_label(identity, output[], length)
{
    if (identity == 0)
    {
        if (g_TeamATag[0]) formatex(output, length, "%s [%s]", g_TeamAName, g_TeamATag)
        else copy(output, length, g_TeamAName)
    }
    else
    {
        if (g_TeamBTag[0]) formatex(output, length, "%s [%s]", g_TeamBName, g_TeamBTag)
        else copy(output, length, g_TeamBName)
    }
}

stock total_score_a() { return g_PreviousMapScoreA + g_TeamAScore; }
stock total_score_b() { return g_PreviousMapScoreB + g_TeamBScore; }

stock announce_ml(const key[], any:...)
{
    new translated[MAX_BRANDED_MESSAGE + 1], message[MAX_BRANDED_MESSAGE + 1]
    refresh_branding(false)
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        if (!is_user_connected(id)) continue
        new language = id
        LookupLangKey(translated, charsmax(translated), key, language)
        vformat(message, charsmax(message), translated, 2)
        client_print(id, print_chat, "%s %s", g_ChatPrefix, message)
        if (series_extra_number(SC_HUD_ANNOUNCEMENTS, g_CvarHudAnnouncements))
        {
            set_hudmessage(0, 180, 255, -1.0, 0.18, 0, 1.0, 4.0, 0.1, 0.2, -1)
            show_hudmessage(id, "%s %s", g_ChatPrefix, message)
        }
    }
    new serverLanguage = LANG_SERVER
    LookupLangKey(translated, charsmax(translated), key, serverLanguage)
    vformat(message, charsmax(message), translated, 2)
    server_print("%s %s", g_ChatPrefix, message)
}
