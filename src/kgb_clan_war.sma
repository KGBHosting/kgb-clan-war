/* SPDX-License-Identifier: GPL-3.0-or-later */

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>

#define PLUGIN_NAME "KGB Clan War"
#define PLUGIN_VERSION "0.2.0"
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

enum MatchState { STATE_OFF = 0, STATE_WARMUP, STATE_KNIFE, STATE_KNIFE_VOTE, STATE_LIVE, STATE_HALFTIME, STATE_FINISHED }
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
new bool:g_EnvironmentSaved, bool:g_MapChangePending, bool:g_KnifeDecisionMade
new bool:g_ShieldRestricted

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
new g_CvarFormat, g_CvarHalfRounds, g_CvarWinRounds, g_CvarTimeLimitMinutes, g_CvarPlayout
new g_CvarOvertime, g_CvarOvertimeMaxCycles, g_CvarOvertimeHalfRounds, g_CvarOvertimeMoney
new g_CvarHudAnnouncements, g_CvarState
new g_CvarTeamAName, g_CvarTeamBName, g_CvarTeamATag, g_CvarTeamBTag
new g_CvarMap1, g_CvarMap2, g_CvarMapCount
new g_CvarWarmupConfig, g_CvarMatchConfig, g_CvarOvertimeConfig, g_CvarDefaultConfig
new g_CvarHalftimeDelay, g_CvarKnifeVote, g_CvarKnifeVoteSeconds, g_CvarPugMode
new g_CvarSetHostname, g_CvarHostname, g_CvarSetPassword, g_CvarPassword, g_CvarDisableShield
new g_CvarClientDemos, g_CvarScreenshots, g_CvarFileStats

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
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
    g_CvarOvertime = register_cvar("kgb_cw_overtime", "1")
    g_CvarOvertimeMaxCycles = register_cvar("kgb_cw_overtime_max_cycles", "3")
    g_CvarOvertimeHalfRounds = register_cvar("kgb_cw_overtime_half_rounds", "3")
    g_CvarOvertimeMoney = register_cvar("kgb_cw_overtime_money", "10000")
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

    /* Risky or client-affecting behavior is opt-in. */
    g_CvarSetHostname = register_cvar("kgb_cw_set_hostname", "0")
    g_CvarHostname = register_cvar("kgb_cw_hostname", "")
    g_CvarSetPassword = register_cvar("kgb_cw_set_password", "0")
    g_CvarPassword = register_cvar("kgb_cw_password", "", FCVAR_PROTECTED)
    g_CvarDisableShield = register_cvar("kgb_cw_disable_shield", "0")
    g_CvarClientDemos = register_cvar("kgb_cw_client_demos", "0")
    g_CvarScreenshots = register_cvar("kgb_cw_screenshots", "0")
    g_CvarFileStats = register_cvar("kgb_cw_file_stats", "1")

    register_concmd("amx_cw_menu", "command_menu", ADMIN_CFG, "- open match controls")
    register_concmd("amx_cw_warmup", "command_warmup", ADMIN_CFG, "- start warmup")
    register_concmd("amx_cw_knife", "command_knife", ADMIN_CFG, "- start knife round")
    register_concmd("amx_cw_live", "command_live", ADMIN_CFG, "- start a match with LO3")
    register_concmd("amx_cw_relo3", "command_relo3", ADMIN_CFG, "- repeat LO3 without resetting score")
    register_concmd("amx_cw_swap", "command_swap", ADMIN_CFG, "- swap T and CT")
    register_concmd("amx_cw_restart_half", "command_restart_half", ADMIN_CFG, "- reset the current half")
    register_concmd("amx_cw_restart_match", "command_restart_match", ADMIN_CFG, "- reset the whole match")
    register_concmd("amx_cw_pug_randomize", "command_pug_randomize", ADMIN_CFG, "- randomly balance warmup players")
    register_concmd("amx_cw_teams", "command_teams", ADMIN_CFG, "<team-a> <team-b>")
    register_concmd("amx_cw_tags", "command_tags", ADMIN_CFG, "<tag-a> <tag-b>")
    register_concmd("amx_cw_maps", "command_maps", ADMIN_CFG, "<map1> [map2]")
    register_concmd("amx_cw_stop", "command_stop", ADMIN_CFG, "- stop and restore server")
    register_concmd("amx_cw_score", "command_score", 0, "- show score")
    register_concmd("amx_cw_status", "command_status", 0, "- show detailed status")
    register_clcmd("say", "command_say")
    register_clcmd("say_team", "command_say")
    register_clcmd("shield", "command_shield_purchase")
    register_clcmd("shieldgun", "command_shield_purchase")

    register_event("HLTV", "event_new_round", "a", "1=0", "2=0")
    register_event("ResetHUD", "event_player_spawn", "be")
    register_event("SendAudio", "event_ct_win", "a", "2=%!MRAD_ctwin")
    register_event("SendAudio", "event_t_win", "a", "2=%!MRAD_terwin")

    g_ForwardEvent = CreateMultiForward("kgb_cw_event", ET_IGNORE, FP_STRING, FP_STRING, FP_STRING, FP_CELL, FP_CELL, FP_CELL, FP_CELL)
}

public plugin_cfg()
{
    /* This is a fixed package-owned path, not user input. */
    server_cmd("exec addons/amxmodx/configs/kgb_clan_war.cfg")
    server_exec()
    refresh_branding(true)
    set_cw_state(STATE_OFF)
    set_task(1.0, "task_resume_crossmap", TASK_RESUME_MAP)
}

public plugin_end()
{
    if (!g_MapChangePending)
    {
        stop_client_demos()
        restore_environment()
    }
    if (g_ForwardEvent >= 0) DestroyForward(g_ForwardEvent)
}

public client_putinserver(id)
{
    clear_client_state(id)
    if (g_State == STATE_LIVE && get_pcvar_num(g_CvarClientDemos)) start_client_demo(id)
}
public client_disconnected(id) { clear_client_state(id); }

stock clear_client_state(id)
{
    g_Ready[id] = false
    g_DemoStarted[id] = false
    g_KnifeVoted[id] = false
}

public command_menu(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id)) show_control_menu(id)
    return PLUGIN_HANDLED
}

public command_warmup(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id)) start_warmup(true)
    return PLUGIN_HANDLED
}

public command_knife(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id)) start_knife_round()
    return PLUGIN_HANDLED
}

public command_live(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id)) start_live_match(g_State == STATE_WARMUP && g_KnifeDecisionMade)
    return PLUGIN_HANDLED
}

public command_relo3(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (g_State != STATE_LIVE) cw_console(id, "A live match is not running.")
    else begin_lo3(false)
    return PLUGIN_HANDLED
}

public command_swap(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (g_Lo3Running || g_State == STATE_HALFTIME) cw_console(id, "A transition is in progress.")
    else
    {
        swap_players()
        toggle_team_a_side()
        announce("Teams were swapped by an administrator.")
        audit_event("admin_swap")
    }
    return PLUGIN_HANDLED
}

public command_restart_half(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (g_State != STATE_LIVE) cw_console(id, "A live match is not running.")
    else restart_current_half()
    return PLUGIN_HANDLED
}

public command_restart_match(id, level, cid)
{
    if (cmd_access(id, level, cid, 1) && mode_enabled(id))
    {
        start_live_match(false)
        audit_event("admin_restart_match")
    }
    return PLUGIN_HANDLED
}

public command_pug_randomize(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !mode_enabled(id)) return PLUGIN_HANDLED
    if (!get_pcvar_num(g_CvarPugMode)) cw_console(id, "Set kgb_cw_pug_mode 1 to opt in.")
    else if (g_State != STATE_OFF && g_State != STATE_WARMUP) cw_console(id, "Randomization is only safe while off or warming up.")
    else randomize_pug_teams()
    return PLUGIN_HANDLED
}

public command_teams(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED
    new a[MAX_TEAM_NAME + 1], b[MAX_TEAM_NAME + 1]
    read_argv(1, a, charsmax(a)); read_argv(2, b, charsmax(b)); trim(a); trim(b)
    if (!valid_display_token(a, MAX_TEAM_NAME) || !valid_display_token(b, MAX_TEAM_NAME))
    {
        cw_console(id, "Team names contain unsafe characters or exceed %d bytes.", MAX_TEAM_NAME)
        return PLUGIN_HANDLED
    }
    set_pcvar_string(g_CvarTeamAName, a); set_pcvar_string(g_CvarTeamBName, b)
    copy(g_TeamAName, charsmax(g_TeamAName), a); copy(g_TeamBName, charsmax(g_TeamBName), b)
    announce("Teams configured: %s versus %s.", a, b)
    audit_event("teams_configured")
    return PLUGIN_HANDLED
}

public command_tags(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED
    new a[MAX_TEAM_TAG + 1], b[MAX_TEAM_TAG + 1]
    read_argv(1, a, charsmax(a)); read_argv(2, b, charsmax(b)); trim(a); trim(b)
    if ((a[0] && !valid_display_token(a, MAX_TEAM_TAG)) || (b[0] && !valid_display_token(b, MAX_TEAM_TAG)))
    {
        cw_console(id, "Clan tags contain unsafe characters or exceed %d bytes.", MAX_TEAM_TAG)
        return PLUGIN_HANDLED
    }
    set_pcvar_string(g_CvarTeamATag, a); set_pcvar_string(g_CvarTeamBTag, b)
    copy(g_TeamATag, charsmax(g_TeamATag), a); copy(g_TeamBTag, charsmax(g_TeamBTag), b)
    announce("Clan tags updated for %s and %s.", g_TeamAName, g_TeamBName)
    audit_event("tags_configured")
    return PLUGIN_HANDLED
}

public command_maps(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    new map1[MAX_MAP_TOKEN + 1], map2[MAX_MAP_TOKEN + 1]
    read_argv(1, map1, charsmax(map1)); read_argv(2, map2, charsmax(map2))
    strtolower(map1); strtolower(map2)
    if (!valid_map_token(map1) || (map2[0] && (!valid_map_token(map2) || equali(map1, map2))))
    {
        cw_console(id, "Use one or two different installed map basenames.")
        return PLUGIN_HANDLED
    }
    set_pcvar_string(g_CvarMap1, map1); set_pcvar_string(g_CvarMap2, map2)
    set_pcvar_num(g_CvarMapCount, map2[0] ? 2 : 1)
    cw_console(id, "Maps: %s%s%s", map1, map2[0] ? ", " : "", map2)
    return PLUGIN_HANDLED
}

public command_stop(id, level, cid)
{
    if (cmd_access(id, level, cid, 1)) stop_match(true)
    return PLUGIN_HANDLED
}

public command_score(id) { print_score(id, false); return PLUGIN_HANDLED; }
public command_status(id) { print_score(id, true); return PLUGIN_HANDLED; }

public command_shield_purchase(id)
{
    if (!g_ShieldRestricted) return PLUGIN_CONTINUE
    cw_chat(id, "The tactical shield is restricted for this match.")
    return PLUGIN_HANDLED
}

public command_say(id)
{
    if (!get_pcvar_num(g_CvarEnabled)) return PLUGIN_CONTINUE
    new text[64]
    read_args(text, charsmax(text)); remove_quotes(text); trim(text)
    if (equali(text, "/ready") || equali(text, "!ready")) { set_player_ready(id, true); return PLUGIN_HANDLED; }
    if (equali(text, "/notready") || equali(text, "!notready")) { set_player_ready(id, false); return PLUGIN_HANDLED; }
    if (equali(text, "/teamready") || equali(text, "!teamready")) { set_team_ready(id, true); return PLUGIN_HANDLED; }
    if (equali(text, "/teamnotready") || equali(text, "!teamnotready")) { set_team_ready(id, false); return PLUGIN_HANDLED; }
    if (equali(text, "/score") || equali(text, "!score")) { print_score(id, false); return PLUGIN_HANDLED; }
    if (equali(text, "/cw") || equali(text, "!cw"))
    {
        if (get_user_flags(id) & ADMIN_CFG) show_control_menu(id); else print_score(id, false)
        return PLUGIN_HANDLED
    }
    return PLUGIN_CONTINUE
}

public menu_control_handler(id, menu, item)
{
    if (item == MENU_EXIT || !(get_user_flags(id) & ADMIN_CFG) || !get_pcvar_num(g_CvarEnabled))
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new access, info[8], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    switch (str_to_num(info))
    {
        case 1: start_warmup(true)
        case 2: start_knife_round()
        case 3: start_live_match(g_State == STATE_WARMUP && g_KnifeDecisionMade)
        case 4: if (g_State == STATE_LIVE) begin_lo3(false)
        case 5: print_score(id, true)
        case 6: if (!g_Lo3Running && g_State != STATE_HALFTIME) { swap_players(); toggle_team_a_side(); announce("Teams swapped."); }
        case 7: if (get_pcvar_num(g_CvarPugMode) && (g_State == STATE_OFF || g_State == STATE_WARMUP)) randomize_pug_teams()
        case 8: stop_match(true)
    }
    menu_destroy(menu)
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
    if (str_to_num(info) == 2) g_KnifeSwapVotes++; else g_KnifeStayVotes++
    cw_chat(id, "Vote recorded.")
    menu_destroy(menu)
    if (knife_vote_count() >= knife_eligible_count()) finish_knife_vote()
    return PLUGIN_HANDLED
}

public event_new_round() { g_RoundResolved = false; }
public event_ct_win() { handle_round_winner(CS_TEAM_CT); }
public event_t_win() { handle_round_winner(CS_TEAM_T); }

public event_player_spawn(id)
{
    if (g_State == STATE_KNIFE && is_user_alive(id)) set_task(0.2, "task_equip_knife", TASK_KNIFE_EQUIP + id)
}

public task_equip_knife(taskId)
{
    new id = taskId - TASK_KNIFE_EQUIP
    if (g_State != STATE_KNIFE || !is_user_alive(id)) return
    strip_user_weapons(id); give_item(id, "weapon_knife"); engclient_cmd(id, "weapon_knife")
}

public task_restart_first() { server_cmd("sv_restart 1"); announce("Live on three: restart 1/3."); }
public task_restart_second() { server_cmd("sv_restart 1"); announce("Live on three: restart 2/3."); }
public task_restart_third() { server_cmd("sv_restart 1"); announce("Live on three: restart 3/3."); }

public task_finish_lo3()
{
    g_Lo3Running = false; g_RoundResolved = false; set_cw_state(STATE_LIVE)
    announce("MATCH IS LIVE. Good luck and have fun.")
    audit_event("lo3_complete")
}

public task_begin_next_half()
{
    if (g_State != STATE_HALFTIME) return
    swap_players(); toggle_team_a_side(); g_RoundsThisHalf = 0
    g_HalfStartA = g_TeamAScore; g_HalfStartB = g_TeamBScore
    execute_phase_config(g_InOvertime ? g_CvarOvertimeConfig : g_CvarMatchConfig, g_InOvertime ? "overtime" : "match")
    if (g_InOvertime) set_cvar_num("mp_startmoney", clamp(get_pcvar_num(g_CvarOvertimeMoney), 800, 16000))
    set_scoreboard_team_score("CT", 0); set_scoreboard_team_score("TERRORIST", 0)
    emit_match_event("half_start"); begin_lo3(false)
    if (g_Format == FORMAT_TL) schedule_time_limit_half()
    new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    announce("Half %d is starting. %s %d - %d %s.", g_Half, labelA, total_score_a(), total_score_b(), labelB)
}

public task_return_to_warmup() { start_warmup(false); }
public task_finish_knife_vote() { finish_knife_vote(); }

public task_time_limit_half()
{
    if (g_State != STATE_LIVE || g_Format != FORMAT_TL) return
    emit_match_event("half_end"); write_stats_event("half_end")
    if (g_Half == 1) { take_client_screenshots(); g_Half = 2; begin_halftime(); }
    else complete_regulation_map(true)
}

public task_change_map()
{
    if (!g_MapChangePending || !valid_map_token(g_Map2))
    {
        announce("Map transition aborted because map 2 is invalid.")
        g_MapChangePending = false; clear_crossmap_state(); finish_match(false); return
    }
    /* g_Map2 was strictly tokenized and verified with is_map_valid. */
    server_cmd("changelevel %s", g_Map2)
}

public task_resume_crossmap()
{
    new active[4]
    get_localinfo(LI_ACTIVE, active, charsmax(active))
    if (!equal(active, "1")) return

    new expected[MAX_MAP_TOKEN + 1], current[MAX_MAP_TOKEN + 1], value[32]
    get_localinfo(LI_MAP, expected, charsmax(expected)); get_mapname(current, charsmax(current))
    if (!valid_map_token(expected) || !equali(expected, current) || !load_runtime_settings(true))
    {
        log_amx("Rejected stale or invalid cross-map match state")
        restore_crossmap_environment(); clear_crossmap_state(); return
    }
    get_localinfo(LI_SCORE_A, value, charsmax(value)); g_PreviousMapScoreA = clamp(str_to_num(value), 0, 1000)
    get_localinfo(LI_SCORE_B, value, charsmax(value)); g_PreviousMapScoreB = clamp(str_to_num(value), 0, 1000)
    get_localinfo(LI_MATCH_ID, g_MatchId, charsmax(g_MatchId))
    load_env_snapshot()
    get_localinfo(LI_TEAM_A_SIDE, value, charsmax(value))
    new restoredSide = str_to_num(value)
    if (restoredSide != _:CS_TEAM_CT && restoredSide != _:CS_TEAM_T)
    {
        log_amx("Rejected invalid cross-map team side")
        restore_environment(); clear_crossmap_state(); return
    }
    g_TeamASide = CsTeams:restoredSide
    clear_crossmap_state()

    g_MapNumber = 2; g_MapCount = 2; g_TeamAScore = 0; g_TeamBScore = 0
    g_Half = 1; g_RoundsThisHalf = 0; g_HalfStartA = 0; g_HalfStartB = 0
    g_InOvertime = false; g_OvertimeCycle = 0
    apply_environment(false); execute_phase_config(g_CvarMatchConfig, "match")
    set_cw_state(STATE_LIVE); emit_match_event("half_start"); write_stats_event("map_resume")
    start_client_demos(); begin_lo3(true)
    if (g_Format == FORMAT_TL) schedule_time_limit_half()
    announce("Match %s resumed safely on map 2: %s.", g_MatchId, current)
}

stock bool:mode_enabled(id)
{
    if (get_pcvar_num(g_CvarEnabled)) return true
    cw_console(id, "Controls are disabled by kgb_cw_enabled.")
    return false
}

stock show_control_menu(id)
{
    refresh_branding(false)
    new menu = menu_create(g_DisplayName, "menu_control_handler")
    menu_additem(menu, "Start warmup", "1")
    menu_additem(menu, "Start knife round", "2")
    menu_additem(menu, "Start match (LO3)", "3")
    menu_additem(menu, "Repeat LO3", "4")
    menu_additem(menu, "Show detailed status", "5")
    menu_additem(menu, "Swap teams", "6")
    menu_additem(menu, "Randomize PUG teams", "7")
    menu_additem(menu, "Stop and restore", "8")
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
    menu_display(id, menu)
}

stock start_warmup(bool:resetData)
{
    if (!runtime_config_valid(false))
    {
        announce("Warmup could not start: configuration validation failed.")
        return
    }
    if (resetData) close_active_lifecycle("warmup_match_stop")
    cancel_transition_tasks()
    if (resetData) { reset_match_data(true); g_KnifeDecisionMade = false; }
    reset_ready_players()
    load_runtime_settings(false)
    snapshot_environment(); apply_environment(false); set_cw_state(STATE_WARMUP)
    execute_phase_config(g_CvarWarmupConfig, "warmup")
    set_cvar_num("mp_startmoney", 16000); set_cvar_num("mp_freezetime", 1); set_cvar_num("mp_friendlyfire", 0)
    server_cmd("sv_restart 1")
    new readyName[8]; get_ready_mode_name(readyName, charsmax(readyName))
    announce("Warmup started. Ready mode: %s.", readyName)
    audit_event("warmup_start")
}

stock start_knife_round()
{
    if (!runtime_config_valid(false))
    {
        announce("Knife round could not start: configuration validation failed.")
        return
    }
    close_active_lifecycle("knife_match_stop")
    cancel_transition_tasks(); reset_match_data(true); reset_ready_players(); g_KnifeDecisionMade = false
    load_runtime_settings(false)
    snapshot_environment(); apply_environment(false); set_cw_state(STATE_KNIFE)
    execute_phase_config(g_CvarWarmupConfig, "warmup")
    set_cvar_num("mp_startmoney", 0); set_cvar_num("mp_freezetime", 5); set_cvar_num("mp_friendlyfire", 0)
    server_cmd("sv_restart 1"); announce("Knife round started."); audit_event("knife_start")
}

stock start_live_match(bool:preserveSides)
{
    if (!runtime_config_valid(true))
    {
        announce("Match could not start: configuration or map validation failed.")
        return
    }
    new bool:restarting = g_State == STATE_LIVE || g_State == STATE_HALFTIME
    if (restarting) close_active_lifecycle("restart_match_stop")
    cancel_transition_tasks()
    load_runtime_settings(false)

    reset_match_data(!preserveSides); reset_ready_players(); snapshot_environment(); apply_environment(false)
    create_match_id(); execute_phase_config(g_CvarMatchConfig, "match"); set_cw_state(STATE_LIVE)
    emit_match_event("match_start"); emit_match_event("half_start"); write_stats_event("match_start")
    start_client_demos(); begin_lo3(true)
    if (g_Format == FORMAT_TL) schedule_time_limit_half()
    new format[4]; get_format_name(format, charsmax(format))
    new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    announce("Match %s started: %s versus %s, format %s, map %d/%d.", g_MatchId, labelA, labelB, format, g_MapNumber, g_MapCount)
}

stock begin_lo3(bool:resetRoundTracking)
{
    cancel_lo3_tasks(); if (resetRoundTracking) g_RoundsThisHalf = 0
    g_Lo3Running = true; g_RoundResolved = true; set_cw_state(STATE_LIVE)
    set_task(0.1, "task_restart_first", TASK_LO3_1)
    set_task(2.1, "task_restart_second", TASK_LO3_2)
    set_task(4.1, "task_restart_third", TASK_LO3_3)
    set_task(6.1, "task_finish_lo3", TASK_LO3_DONE)
}

stock close_active_lifecycle(const statsEvent[])
{
    if (g_State != STATE_LIVE && g_State != STATE_HALFTIME) return
    emit_match_event("match_stop")
    write_stats_event(statsEvent)
    stop_client_demos()
}

stock stop_match(bool:administrator)
{
    cancel_transition_tasks()
    if (g_State == STATE_LIVE || g_State == STATE_HALFTIME)
    {
        emit_match_event("match_stop")
        write_stats_event(administrator ? "admin_match_stop" : "match_stop")
    }
    else if (g_State != STATE_OFF)
    {
        audit_event(administrator ? "admin_mode_stop" : "mode_stop")
        write_stats_event(administrator ? "admin_mode_stop" : "mode_stop")
    }
    stop_client_demos(); restore_environment(); execute_phase_config(g_CvarDefaultConfig, "default")
    reset_match_data(true); reset_ready_players(); clear_crossmap_state(); set_cw_state(STATE_OFF)
    server_cmd("sv_restart 1"); announce("Clan War stopped; managed server settings were restored.")
}

stock restart_current_half()
{
    g_TeamAScore = g_HalfStartA; g_TeamBScore = g_HalfStartB; g_RoundsThisHalf = 0
    audit_event("admin_restart_half"); begin_lo3(false)
    announce("Current half restarted. Score restored to %d-%d.", total_score_a(), total_score_b())
}

stock set_player_ready(id, bool:isReady)
{
    if (!is_user_connected(id) || g_State != STATE_WARMUP)
    {
        cw_chat(id, "Ready status is available during warmup only."); return
    }
    if (g_ReadyMode == READY_ADMIN)
    {
        cw_chat(id, "This match is started by an administrator."); return
    }
    if (g_ReadyMode == READY_TEAM) { set_team_ready(id, isReady); return; }
    new CsTeams:team = cs_get_user_team(id)
    if (team != CS_TEAM_T && team != CS_TEAM_CT)
    {
        cw_chat(id, "Join a playing team first."); return
    }
    if (g_Ready[id] == isReady)
    {
        cw_chat(id, "Your ready state is unchanged."); return
    }
    g_Ready[id] = isReady
    new name[32]; get_user_name(id, name, charsmax(name))
    announce("%s is %s. Ready: %d/%d.", name, isReady ? "ready" : "not ready", ready_count(), required_ready_count())
    check_auto_live()
}

stock set_team_ready(id, bool:isReady)
{
    if (!is_user_connected(id) || g_State != STATE_WARMUP)
    {
        cw_chat(id, "Team ready status is available during warmup only."); return
    }
    if (g_ReadyMode != READY_TEAM)
    {
        cw_chat(id, "Team-ready mode is not enabled."); return
    }
    new identity = identity_for_side(cs_get_user_team(id))
    if (identity < 0) { cw_chat(id, "Join a playing team first."); return; }
    g_TeamReady[identity] = isReady
    announce("%s is now %s.", identity == 0 ? g_TeamAName : g_TeamBName, isReady ? "ready" : "not ready")
    check_auto_live()
}

stock check_auto_live()
{
    if (!get_pcvar_num(g_CvarAutoLive)) return
    if ((g_ReadyMode == READY_PLAYER && ready_count() >= required_ready_count()) ||
        (g_ReadyMode == READY_TEAM && g_TeamReady[0] && g_TeamReady[1]))
    {
        announce("Ready requirement reached. Starting match.")
        start_live_match(g_State == STATE_WARMUP && g_KnifeDecisionMade)
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

stock required_ready_count() { return clamp(get_pcvar_num(g_CvarMinReady), 1, 32); }

stock handle_round_winner(CsTeams:winner)
{
    if (g_RoundResolved || g_Lo3Running) return
    if (g_State == STATE_KNIFE) { g_RoundResolved = true; begin_knife_vote(winner); return; }
    if (g_State != STATE_LIVE) return
    g_RoundResolved = true; g_RoundsThisHalf++
    if (winner == g_TeamASide) g_TeamAScore++; else g_TeamBScore++
    new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    announce("Score: %s %d - %d %s.", labelA, total_score_a(), total_score_b(), labelB)
    write_stats_event("round_end"); evaluate_match_progress()
}

stock evaluate_match_progress()
{
    if (g_InOvertime) { evaluate_overtime_progress(); return; }
    if (g_Format == FORMAT_TL) return
    if (g_Format == FORMAT_WL)
    {
        new target = clamp(get_pcvar_num(g_CvarWinRounds), 1, 100)
        if (g_TeamAScore >= target || g_TeamBScore >= target) complete_regulation_map()
        return
    }

    new halfRounds = clamp(get_pcvar_num(g_CvarHalfRounds), 1, 100)
    new roundsPlayed = g_TeamAScore + g_TeamBScore
    if (!get_pcvar_num(g_CvarPlayout) && match_is_clinched(halfRounds, roundsPlayed))
    {
        complete_regulation_map(); return
    }
    if (g_RoundsThisHalf < halfRounds) return
    if (g_Half == 1)
    {
        emit_match_event("half_end"); write_stats_event("half_end"); take_client_screenshots()
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
    if (g_MapCount == 2 && g_MapNumber == 1) { begin_map_transition(); return; }
    if (total_score_a() == total_score_b() && get_pcvar_num(g_CvarOvertime)) { start_overtime_cycle(); return; }
    finish_match(false)
}

stock begin_halftime()
{
    set_cw_state(STATE_HALFTIME)
    new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    announce("Halftime. %s %d - %d %s. Swapping sides.", labelA, total_score_a(), total_score_b(), labelB)
    remove_task(TASK_HALFTIME)
    set_task(float(clamp(get_pcvar_num(g_CvarHalftimeDelay), 1, 30)), "task_begin_next_half", TASK_HALFTIME)
}

stock start_overtime_cycle()
{
    new maxCycles = get_pcvar_num(g_CvarOvertimeMaxCycles)
    if (maxCycles > 0 && g_OvertimeCycle >= maxCycles) { finish_match(false); return; }
    g_InOvertime = true; g_OvertimeCycle++; g_Half = 1; g_RoundsThisHalf = 0
    g_HalfStartA = g_TeamAScore; g_HalfStartB = g_TeamBScore
    set_cw_state(STATE_HALFTIME); execute_phase_config(g_CvarOvertimeConfig, "overtime")
    set_cvar_num("mp_startmoney", clamp(get_pcvar_num(g_CvarOvertimeMoney), 800, 16000))
    emit_match_event("overtime_start"); write_stats_event("overtime_start")
    announce("Starting overtime %d (MR%d, $%d).", g_OvertimeCycle, clamp(get_pcvar_num(g_CvarOvertimeHalfRounds), 1, 20), clamp(get_pcvar_num(g_CvarOvertimeMoney), 800, 16000))
    set_task(float(clamp(get_pcvar_num(g_CvarHalftimeDelay), 1, 30)), "task_begin_next_half", TASK_HALFTIME)
}

stock evaluate_overtime_progress()
{
    new otHalf = clamp(get_pcvar_num(g_CvarOvertimeHalfRounds), 1, 20)
    if (g_RoundsThisHalf < otHalf) return
    if (g_Half == 1)
    {
        emit_match_event("half_end"); write_stats_event("overtime_half_end"); take_client_screenshots()
        g_Half = 2; begin_halftime(); return
    }
    emit_match_event("half_end"); write_stats_event("overtime_half_end")
    if (total_score_a() == total_score_b()) { take_client_screenshots(); start_overtime_cycle(); }
    else finish_match(false)
}

stock begin_map_transition()
{
    if (!valid_map_token(g_Map2)) { announce("Map 2 became invalid; ending safely."); finish_match(false); return; }
    emit_match_event("map_change"); write_stats_event("map_change")
    take_client_screenshots(); stop_client_demos()
    g_PreviousMapScoreA = g_TeamAScore; g_PreviousMapScoreB = g_TeamBScore
    persist_crossmap_state(); g_MapChangePending = true; set_cw_state(STATE_HALFTIME)
    announce("Map 1 complete: %d-%d. Changing to %s.", g_PreviousMapScoreA, g_PreviousMapScoreB, g_Map2)
    set_task(5.0, "task_change_map", TASK_MAP_CHANGE)
}

stock finish_match(bool:stopped)
{
    cancel_transition_tasks(); set_cw_state(STATE_FINISHED)
    emit_match_event(stopped ? "match_stop" : "match_end"); write_stats_event(stopped ? "match_stop" : "match_end")
    take_client_screenshots(); stop_client_demos()
    new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    if (total_score_a() == total_score_b()) announce("MATCH FINISHED AS A DRAW: %s %d - %d %s.", labelA, total_score_a(), total_score_b(), labelB)
    else announce("MATCH FINISHED. %s wins %d-%d.", total_score_a() > total_score_b() ? labelA : labelB, total_score_a(), total_score_b())
    restore_environment(); execute_phase_config(g_CvarDefaultConfig, "default"); clear_crossmap_state()
}

stock begin_knife_vote(CsTeams:winner)
{
    g_KnifeWinningSide = winner; g_KnifeStayVotes = 0; g_KnifeSwapVotes = 0
    for (new id = 1; id <= MAX_PLAYERS; id++) g_KnifeVoted[id] = false
    new side[24]; get_side_name(winner, side, charsmax(side))
    if (!get_pcvar_num(g_CvarKnifeVote))
    {
        announce("Knife round won by %s. Winning side stays.", side)
        g_KnifeDecisionMade = true; set_task(3.0, "task_return_to_warmup", TASK_WARMUP); return
    }
    set_cw_state(STATE_KNIFE_VOTE); announce("Knife round won by %s. Winners vote to stay or swap.", side)
    for (new id = 1; id <= MAX_PLAYERS; id++) if (is_user_connected(id) && cs_get_user_team(id) == winner) show_knife_vote_menu(id)
    set_task(float(clamp(get_pcvar_num(g_CvarKnifeVoteSeconds), 5, 30)), "task_finish_knife_vote", TASK_KNIFE_VOTE)
}

stock show_knife_vote_menu(id)
{
    new menu = menu_create("Knife winner: choose side", "menu_knife_vote_handler")
    menu_additem(menu, "Stay", "1"); menu_additem(menu, "Swap", "2")
    menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER); menu_display(id, menu)
}

stock finish_knife_vote()
{
    if (g_State != STATE_KNIFE_VOTE || g_KnifeDecisionMade) return
    remove_task(TASK_KNIFE_VOTE)
    g_KnifeDecisionMade = true
    if (g_KnifeSwapVotes > g_KnifeStayVotes)
    {
        swap_players(); toggle_team_a_side(); announce("Knife vote: swap (%d-%d).", g_KnifeSwapVotes, g_KnifeStayVotes); audit_event("knife_vote_swap")
    }
    else
    {
        announce("Knife vote: stay (%d-%d). Ties stay.", g_KnifeStayVotes, g_KnifeSwapVotes); audit_event("knife_vote_stay")
    }
    set_task(3.0, "task_return_to_warmup", TASK_WARMUP)
}

stock knife_eligible_count()
{
    new count
    for (new id = 1; id <= MAX_PLAYERS; id++) if (is_user_connected(id) && cs_get_user_team(id) == g_KnifeWinningSide) count++
    return count
}
stock knife_vote_count() { return g_KnifeStayVotes + g_KnifeSwapVotes; }

stock randomize_pug_teams()
{
    new players[32], count
    get_players(players, count, "ch")
    if (count < 2) { announce("At least two humans are required for PUG randomization."); return; }
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
    announce("PUG teams randomized and balanced (%d players).", count); audit_event("pug_randomized")
}

/* Validate into a temporary snapshot so a rejected transition cannot mutate a live match. */
stock bool:runtime_config_valid(bool:requireStartingMap)
{
    new MatchFormat:oldFormat = g_Format
    new ReadyMode:oldReadyMode = g_ReadyMode
    new oldMapNumber = g_MapNumber, oldMapCount = g_MapCount
    new oldMap1[MAX_MAP_TOKEN + 1], oldMap2[MAX_MAP_TOKEN + 1]
    new oldTeamA[MAX_TEAM_NAME + 1], oldTeamB[MAX_TEAM_NAME + 1]
    new oldTagA[MAX_TEAM_TAG + 1], oldTagB[MAX_TEAM_TAG + 1]
    copy(oldMap1, charsmax(oldMap1), g_Map1); copy(oldMap2, charsmax(oldMap2), g_Map2)
    copy(oldTeamA, charsmax(oldTeamA), g_TeamAName); copy(oldTeamB, charsmax(oldTeamB), g_TeamBName)
    copy(oldTagA, charsmax(oldTagA), g_TeamATag); copy(oldTagB, charsmax(oldTagB), g_TeamBTag)

    new bool:valid = load_runtime_settings(false)
    if (valid && requireStartingMap) valid = validate_starting_map()

    g_Format = oldFormat; g_ReadyMode = oldReadyMode
    g_MapNumber = oldMapNumber; g_MapCount = oldMapCount
    copy(g_Map1, charsmax(g_Map1), oldMap1); copy(g_Map2, charsmax(g_Map2), oldMap2)
    copy(g_TeamAName, charsmax(g_TeamAName), oldTeamA); copy(g_TeamBName, charsmax(g_TeamBName), oldTeamB)
    copy(g_TeamATag, charsmax(g_TeamATag), oldTagA); copy(g_TeamBTag, charsmax(g_TeamBTag), oldTagB)
    return valid
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
    if (!g_Map1[0]) get_mapname(g_Map1, charsmax(g_Map1))
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

stock bool:validate_starting_map()
{
    new current[MAX_MAP_TOKEN + 1]
    get_mapname(current, charsmax(current))
    return bool:equali(current, g_Map1)
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
    get_pcvar_string(cvar, token, charsmax(token))
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

    get_pcvar_string(g_CvarDisplayName, value, charsmax(value)); trim(value)
    if (valid_display_token(value, MAX_DISPLAY_NAME)) copy(g_DisplayName, charsmax(g_DisplayName), value)
    else
    {
        copy(g_DisplayName, charsmax(g_DisplayName), DEFAULT_DISPLAY_NAME)
        if (logInvalid) log_amx("Rejected unsafe or empty display name; using package default")
    }

    get_pcvar_string(g_CvarChatPrefix, value, charsmax(value)); trim(value)
    if (valid_display_token(value, MAX_CHAT_PREFIX)) copy(g_ChatPrefix, charsmax(g_ChatPrefix), value)
    else
    {
        copy(g_ChatPrefix, charsmax(g_ChatPrefix), DEFAULT_CHAT_PREFIX)
        if (logInvalid) log_amx("Rejected unsafe or empty chat prefix; using package default")
    }
}

stock cw_console(id, const format[], any:...)
{
    new message[MAX_BRANDED_MESSAGE + 1]
    vformat(message, charsmax(message), format, 3)
    refresh_branding(false)
    console_print(id, "%s %s", g_ChatPrefix, message)
}

stock cw_chat(id, const format[], any:...)
{
    new message[MAX_BRANDED_MESSAGE + 1]
    vformat(message, charsmax(message), format, 3)
    refresh_branding(false)
    client_print(id, print_chat, "%s %s", g_ChatPrefix, message)
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
    if (get_pcvar_num(g_CvarSetHostname))
    {
        get_pcvar_string(g_CvarHostname, value, charsmax(value))
        if (valid_runtime_cvar_value(value, 127))
        {
            set_cvar_string("hostname", value)
            if (logChanges) log_amx("Applied managed match hostname")
        }
        else log_amx("Rejected invalid managed hostname")
    }
    if (get_pcvar_num(g_CvarSetPassword))
    {
        new password[64]
        get_pcvar_string(g_CvarPassword, password, charsmax(password))
        if (valid_runtime_cvar_value(password, 63))
        {
            set_cvar_string("sv_password", password)
            if (logChanges) log_amx("Applied managed match password (redacted)")
        }
        else log_amx("Rejected invalid managed password (redacted)")
    }
    if (get_pcvar_num(g_CvarDisableShield) && cvar_exists("sv_allow_shield"))
    {
        set_cvar_num("sv_allow_shield", 0)
        if (logChanges) log_amx("Disabled tactical shield")
    }
    g_ShieldRestricted = bool:get_pcvar_num(g_CvarDisableShield)
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

stock persist_crossmap_state()
{
    new value[32]
    set_localinfo(LI_ACTIVE, "1"); set_localinfo(LI_MAP, g_Map2)
    num_to_str(g_TeamAScore, value, charsmax(value)); set_localinfo(LI_SCORE_A, value)
    num_to_str(g_TeamBScore, value, charsmax(value)); set_localinfo(LI_SCORE_B, value)
    set_localinfo(LI_MATCH_ID, g_MatchId); set_localinfo(LI_OLD_HOST, g_OldHostname)
    set_localinfo(LI_OLD_PASS, g_OldPassword); set_localinfo(LI_OLD_SHIELD, g_OldShield)
    set_localinfo(LI_ENV_SAVED, g_EnvironmentSaved ? "1" : "0")
    num_to_str(_:g_TeamASide, value, charsmax(value)); set_localinfo(LI_TEAM_A_SIDE, value)
}

stock load_env_snapshot()
{
    new saved[4]
    get_localinfo(LI_OLD_HOST, g_OldHostname, charsmax(g_OldHostname))
    get_localinfo(LI_OLD_PASS, g_OldPassword, charsmax(g_OldPassword))
    get_localinfo(LI_OLD_SHIELD, g_OldShield, charsmax(g_OldShield))
    get_localinfo(LI_ENV_SAVED, saved, charsmax(saved)); g_EnvironmentSaved = bool:equal(saved, "1")
}

stock restore_crossmap_environment()
{
    load_env_snapshot(); restore_environment()
}

stock clear_crossmap_state()
{
    set_localinfo(LI_ACTIVE, ""); set_localinfo(LI_MAP, "")
    set_localinfo(LI_SCORE_A, ""); set_localinfo(LI_SCORE_B, "")
    set_localinfo(LI_MATCH_ID, ""); set_localinfo(LI_OLD_HOST, "")
    set_localinfo(LI_OLD_PASS, ""); set_localinfo(LI_OLD_SHIELD, ""); set_localinfo(LI_ENV_SAVED, "")
    set_localinfo(LI_TEAM_A_SIDE, "")
}

stock create_match_id() { get_time("%Y%m%d_%H%M%S", g_MatchId, charsmax(g_MatchId)); }

stock start_client_demos()
{
    if (!get_pcvar_num(g_CvarClientDemos)) return
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

stock take_client_screenshots()
{
    if (!get_pcvar_num(g_CvarScreenshots)) return
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        if (is_user_connected(id) && !is_user_bot(id) && !is_user_hltv(id)) client_cmd(id, "snapshot")
    }
    log_amx("Requested opt-in client screenshots")
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
    if (!get_pcvar_num(g_CvarFileStats) || !g_MatchId[0]) return
    new dataDir[128], directory[192], path[256], timestamp[32], line[384]
    get_localinfo("amxx_datadir", dataDir, charsmax(dataDir))
    formatex(directory, charsmax(directory), "%s/kgb_clan_war", dataDir); mkdir(directory)
    formatex(path, charsmax(path), "%s/%s.log", directory, g_MatchId)
    get_time("%Y-%m-%dT%H:%M:%S", timestamp, charsmax(timestamp))
    formatex(line, charsmax(line), "timestamp=%s event=%s map=%d half=%d overtime=%d team_a=%s tag_a=%s team_b=%s tag_b=%s score_a=%d score_b=%d", timestamp, event, g_MapNumber, g_Half, g_OvertimeCycle, g_TeamAName, g_TeamATag, g_TeamBName, g_TeamBTag, total_score_a(), total_score_b())
    write_file(path, line)
}

stock print_score(id, bool:detailed)
{
    new stateText[24], format[4], side[24], detail[192]
    new labelA[MAX_TEAM_LABEL + 1], labelB[MAX_TEAM_LABEL + 1]
    state_name(stateText, charsmax(stateText)); get_format_name(format, charsmax(format)); get_side_name(g_TeamASide, side, charsmax(side))
    get_team_label(0, labelA, charsmax(labelA)); get_team_label(1, labelB, charsmax(labelB))
    if (detailed) formatex(detail, charsmax(detail), " | state=%s format=%s map=%d/%d half=%d overtime=%d side_a=%s", stateText, format, g_MapNumber, g_MapCount, g_Half, g_OvertimeCycle, side)
    if (id == 0) cw_console(0, "%s %d - %d %s%s", labelA, total_score_a(), total_score_b(), labelB, detailed ? detail : "")
    else cw_chat(id, "%s %d - %d %s%s", labelA, total_score_a(), total_score_b(), labelB, detailed ? detail : "")
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
    remove_task(TASK_KNIFE_VOTE); remove_task(TASK_TIME_LIMIT); remove_task(TASK_MAP_CHANGE)
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
    set_task(float(clamp(get_pcvar_num(g_CvarTimeLimitMinutes), 1, 180)) * 60.0, "task_time_limit_half", TASK_TIME_LIMIT)
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

stock announce(const format[], any:...)
{
    new message[MAX_BRANDED_MESSAGE + 1]
    vformat(message, charsmax(message), format, 2)
    refresh_branding(false)
    client_print(0, print_chat, "%s %s", g_ChatPrefix, message); server_print("%s %s", g_ChatPrefix, message)
    if (get_pcvar_num(g_CvarHudAnnouncements))
    {
        set_hudmessage(0, 180, 255, -1.0, 0.18, 0, 1.0, 4.0, 0.1, 0.2, -1)
        show_hudmessage(0, "%s", message)
    }
}
