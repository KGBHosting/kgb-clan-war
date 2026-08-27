// SPDX-License-Identifier: GPL-3.0-or-later

#include <amxmodx>
#include <sqlx>

#define PLUGIN_NAME "KGB Clan War: SQL"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR "KGB Hosting"

#define EVENT_QUEUE_MAX 16
#define EVENT_NAME_MAX 23
#define TEAM_NAME_MAX 31
#define MATCH_UID_MAX 63
#define QUERY_MAX 1535
#define TASK_VALIDATE_CROSSMAP 88501

#define LI_CORE_ACTIVE "_kgbcw_active"
#define LI_CORE_MAP "_kgbcw_map"
#define LI_SQL_MATCH_UID "_kgbcw_sql_match_uid"

new g_CvarEnabled
new Handle:g_DbTuple = Empty_Handle
new g_SchemaQueriesPending
new bool:g_SchemaReady
new bool:g_DatabaseFailed
new g_QueryFailures
new bool:g_WaitingForCrossmapResume

new g_QueuedCount
new g_QueuedEvent[EVENT_QUEUE_MAX][EVENT_NAME_MAX + 1]
new g_QueuedTeamA[EVENT_QUEUE_MAX][TEAM_NAME_MAX + 1]
new g_QueuedTeamB[EVENT_QUEUE_MAX][TEAM_NAME_MAX + 1]
new g_QueuedMap[EVENT_QUEUE_MAX]
new g_QueuedHalf[EVENT_QUEUE_MAX]
new g_QueuedScoreA[EVENT_QUEUE_MAX]
new g_QueuedScoreB[EVENT_QUEUE_MAX]
new bool:g_QueueWarningShown

new bool:g_MatchActive
new g_MatchUid[MATCH_UID_MAX + 1]
new g_MatchTeamA[TEAM_NAME_MAX + 1]
new g_MatchTeamB[TEAM_NAME_MAX + 1]
new g_CurrentMapNumber
new g_CurrentHalf
new g_CurrentScoreA
new g_CurrentScoreB

new g_PlayerAuth[33][40]
new g_PlayerName[33][64]
new g_PlayerTeam[33][16]
new g_PlayerKills[33]
new g_PlayerDeaths[33]
new g_PlayerHeadshots[33]

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_cvar("kgb_cw_sql_version", PLUGIN_VERSION, FCVAR_SERVER | FCVAR_SPONLY)
    g_CvarEnabled = register_cvar("kgb_cw_sql_enabled", "0")

    register_event("DeathMsg", "event_player_death", "a")
}

public plugin_cfg()
{
    server_cmd("exec addons/amxmodx/configs/kgb_clan_war_sql.cfg")
    server_exec()
    restore_crossmap_match_uid()

    if (get_pcvar_num(g_CvarEnabled))
    {
        initialize_database()
    }
}

public plugin_end()
{
    if (g_DbTuple != Empty_Handle)
    {
        SQL_FreeHandle(g_DbTuple)
        g_DbTuple = Empty_Handle
    }
}

public client_authorized(id)
{
    reset_player(id)
    refresh_player_identity(id)
}

public client_infochanged(id)
{
    if (is_user_connected(id) && !is_user_hltv(id))
    {
        get_user_info(id, "name", g_PlayerName[id], charsmax(g_PlayerName[]))
    }
}

public client_disconnect(id)
{
    if (g_MatchActive)
    {
        persist_player(id)
    }

    reset_player(id)
}

/**
 * Public forward emitted by compatible KGB Clan War core releases.
 * Credentials come exclusively from AMX Mod X's standard sql.cfg through
 * SQL_MakeStdTuple(); this plugin contains no database credentials.
 */
public kgb_cw_event(const event[], const team_a[], const team_b[], map_number, half, score_a, score_b)
{
    if (!get_pcvar_num(g_CvarEnabled) || g_DatabaseFailed)
    {
        if (equali(event, "match_end") || equali(event, "match_stop"))
        {
            clear_crossmap_match_uid()
            g_MatchActive = false
        }

        return
    }

    if (g_DbTuple == Empty_Handle)
    {
        initialize_database()
    }

    if (!is_supported_event(event))
    {
        return
    }

    if (equali(event, "half_start") && map_number == 2 && half == 1)
    {
        confirm_crossmap_resume()
    }

    if (!g_SchemaReady)
    {
        queue_lifecycle_event(event, team_a, team_b, map_number, half, score_a, score_b)

        return
    }

    persist_lifecycle_event(event, team_a, team_b, map_number, half, score_a, score_b)
}

public event_player_death()
{
    if (!g_MatchActive || !get_pcvar_num(g_CvarEnabled) || !g_SchemaReady || g_DatabaseFailed)
    {
        return
    }

    new killer = read_data(1)
    new victim = read_data(2)
    new headshot = read_data(3)

    if (victim >= 1 && victim <= 32 && !is_user_hltv(victim))
    {
        refresh_player_identity(victim)
        g_PlayerDeaths[victim]++
    }

    if (killer >= 1 && killer <= 32 && killer != victim && !is_user_hltv(killer))
    {
        refresh_player_identity(killer)
        g_PlayerKills[killer]++
        if (headshot)
        {
            g_PlayerHeadshots[killer]++
        }
    }
}

public query_schema_result(failState, Handle:query, error[], errorNumber, data[], dataSize, Float:queueTime)
{
    if (failState != TQUERY_SUCCESS)
    {
        database_query_failed("schema", error, errorNumber)

        return
    }

    if (g_SchemaQueriesPending > 0)
    {
        g_SchemaQueriesPending--
    }

    if (!g_SchemaQueriesPending && !g_DatabaseFailed)
    {
        g_SchemaReady = true
        server_print("[KGB CW SQL] Database schema is ready.")
        flush_lifecycle_queue()
    }
}

public query_result(failState, Handle:query, error[], errorNumber, data[], dataSize, Float:queueTime)
{
    if (failState != TQUERY_SUCCESS)
    {
        database_query_failed("write", error, errorNumber)
    }
}

stock initialize_database()
{
    if (g_DbTuple != Empty_Handle || g_DatabaseFailed)
    {
        return
    }

    g_DbTuple = SQL_MakeStdTuple(5)
    if (g_DbTuple == Empty_Handle)
    {
        server_print("[KGB CW SQL] Could not initialize the standard AMX Mod X SQL tuple; statistics are disabled.")
        g_DatabaseFailed = true

        return
    }

    g_SchemaQueriesPending = 4

    new schemaQuery[1024]
    copy(schemaQuery, charsmax(schemaQuery), "CREATE TABLE IF NOT EXISTS kgb_cw_matches (match_uid VARCHAR(64) NOT NULL PRIMARY KEY,")
    add(schemaQuery, charsmax(schemaQuery), "team_a_name VARCHAR(64) NOT NULL,team_b_name VARCHAR(64) NOT NULL,status VARCHAR(24) NOT NULL,")
    add(schemaQuery, charsmax(schemaQuery), "map_number INTEGER NOT NULL DEFAULT 1,current_half INTEGER NOT NULL DEFAULT 1,score_a INTEGER NOT NULL DEFAULT 0,")
    add(schemaQuery, charsmax(schemaQuery), "score_b INTEGER NOT NULL DEFAULT 0,started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,ended_at TIMESTAMP NULL)")
    threaded_schema_query(schemaQuery)

    copy(schemaQuery, charsmax(schemaQuery), "CREATE TABLE IF NOT EXISTS kgb_cw_maps (match_uid VARCHAR(64) NOT NULL,map_number INTEGER NOT NULL,")
    add(schemaQuery, charsmax(schemaQuery), "map_name VARCHAR(64) NOT NULL,status VARCHAR(24) NOT NULL,current_half INTEGER NOT NULL DEFAULT 1,")
    add(schemaQuery, charsmax(schemaQuery), "score_a INTEGER NOT NULL DEFAULT 0,score_b INTEGER NOT NULL DEFAULT 0,recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,")
    add(schemaQuery, charsmax(schemaQuery), "PRIMARY KEY (match_uid,map_number))")
    threaded_schema_query(schemaQuery)

    copy(schemaQuery, charsmax(schemaQuery), "CREATE TABLE IF NOT EXISTS kgb_cw_halves (match_uid VARCHAR(64) NOT NULL,map_number INTEGER NOT NULL,")
    add(schemaQuery, charsmax(schemaQuery), "half INTEGER NOT NULL,event_type VARCHAR(24) NOT NULL,score_a INTEGER NOT NULL DEFAULT 0,")
    add(schemaQuery, charsmax(schemaQuery), "score_b INTEGER NOT NULL DEFAULT 0,recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,")
    add(schemaQuery, charsmax(schemaQuery), "PRIMARY KEY (match_uid,map_number,half,event_type))")
    threaded_schema_query(schemaQuery)

    copy(schemaQuery, charsmax(schemaQuery), "CREATE TABLE IF NOT EXISTS kgb_cw_players (match_uid VARCHAR(64) NOT NULL,auth_id VARCHAR(40) NOT NULL,")
    add(schemaQuery, charsmax(schemaQuery), "player_name VARCHAR(64) NOT NULL,last_team VARCHAR(16) NOT NULL,kills INTEGER NOT NULL DEFAULT 0,")
    add(schemaQuery, charsmax(schemaQuery), "deaths INTEGER NOT NULL DEFAULT 0,headshots INTEGER NOT NULL DEFAULT 0,updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,")
    add(schemaQuery, charsmax(schemaQuery), "PRIMARY KEY (match_uid,auth_id))")
    threaded_schema_query(schemaQuery)
}

stock threaded_schema_query(const statement[])
{
    SQL_ThreadQuery(g_DbTuple, "query_schema_result", statement)
}

stock persist_lifecycle_event(const event[], const teamA[], const teamB[], mapNumber, half, scoreA, scoreB)
{
    if (equali(event, "match_start"))
    {
        begin_match(teamA, teamB, mapNumber, half, scoreA, scoreB)

        return
    }

    ensure_match(teamA, teamB, mapNumber, half, scoreA, scoreB)
    copy(g_MatchTeamA, charsmax(g_MatchTeamA), teamA)
    copy(g_MatchTeamB, charsmax(g_MatchTeamB), teamB)
    g_CurrentMapNumber = mapNumber
    g_CurrentHalf = half
    g_CurrentScoreA = scoreA
    g_CurrentScoreB = scoreB

    if (equali(event, "half_start") || equali(event, "half_end") || equali(event, "overtime_start"))
    {
        persist_half(event)
        persist_match_snapshot(event, false)
        persist_map_snapshot(event)
    }
    else if (equali(event, "match_end") || equali(event, "match_stop"))
    {
        persist_all_players()
        persist_match_snapshot(event, true)
        persist_map_snapshot(event)
        g_MatchActive = false
        clear_crossmap_match_uid()
    }
    else if (equali(event, "map_change"))
    {
        persist_all_players()
        persist_match_snapshot(event, false)
        persist_map_snapshot(event)
    }
}

stock begin_match(const teamA[], const teamB[], mapNumber, half, scoreA, scoreB)
{
    generate_match_uid(g_MatchUid, charsmax(g_MatchUid))
    copy(g_MatchTeamA, charsmax(g_MatchTeamA), teamA)
    copy(g_MatchTeamB, charsmax(g_MatchTeamB), teamB)
    g_CurrentMapNumber = mapNumber
    g_CurrentHalf = half
    g_CurrentScoreA = scoreA
    g_CurrentScoreB = scoreB
    g_MatchActive = true
    set_localinfo(LI_SQL_MATCH_UID, g_MatchUid)

    reset_all_players()
    capture_connected_players()

    new uid[129], escapedTeamA[129], escapedTeamB[129]
    quote_sql(g_MatchUid, uid, charsmax(uid))
    quote_sql(g_MatchTeamA, escapedTeamA, charsmax(escapedTeamA))
    quote_sql(g_MatchTeamB, escapedTeamB, charsmax(escapedTeamB))

    new query[QUERY_MAX + 1]
    formatex(
        query,
        charsmax(query),
        "INSERT INTO kgb_cw_matches (match_uid,team_a_name,team_b_name,status,map_number,current_half,score_a,score_b) VALUES ('%s','%s','%s','match_start',%d,%d,%d,%d)",
        uid,
        escapedTeamA,
        escapedTeamB,
        mapNumber,
        half,
        scoreA,
        scoreB
    )
    run_write_query(query)
    persist_map_snapshot("match_start")
}

stock ensure_match(const teamA[], const teamB[], mapNumber, half, scoreA, scoreB)
{
    if (g_MatchUid[0])
    {
        return
    }

    begin_match(teamA, teamB, mapNumber, half, scoreA, scoreB)
}

stock persist_match_snapshot(const status[], bool:ended)
{
    new uid[129], escapedStatus[49], query[QUERY_MAX + 1]
    quote_sql(g_MatchUid, uid, charsmax(uid))
    quote_sql(status, escapedStatus, charsmax(escapedStatus))

    if (ended)
    {
        formatex(
            query,
            charsmax(query),
            "UPDATE kgb_cw_matches SET status='%s',map_number=%d,current_half=%d,score_a=%d,score_b=%d,ended_at=CURRENT_TIMESTAMP WHERE match_uid='%s'",
            escapedStatus,
            g_CurrentMapNumber,
            g_CurrentHalf,
            g_CurrentScoreA,
            g_CurrentScoreB,
            uid
        )
    }
    else
    {
        formatex(
            query,
            charsmax(query),
            "UPDATE kgb_cw_matches SET status='%s',map_number=%d,current_half=%d,score_a=%d,score_b=%d WHERE match_uid='%s'",
            escapedStatus,
            g_CurrentMapNumber,
            g_CurrentHalf,
            g_CurrentScoreA,
            g_CurrentScoreB,
            uid
        )
    }
    run_write_query(query)
}

stock persist_map_snapshot(const status[])
{
    new mapName[64], uid[129], escapedMap[129], escapedStatus[49]
    get_mapname(mapName, charsmax(mapName))
    quote_sql(g_MatchUid, uid, charsmax(uid))
    quote_sql(mapName, escapedMap, charsmax(escapedMap))
    quote_sql(status, escapedStatus, charsmax(escapedStatus))

    new query[QUERY_MAX + 1]
    formatex(
        query,
        charsmax(query),
        "REPLACE INTO kgb_cw_maps (match_uid,map_number,map_name,status,current_half,score_a,score_b,recorded_at) VALUES ('%s',%d,'%s','%s',%d,%d,%d,CURRENT_TIMESTAMP)",
        uid,
        g_CurrentMapNumber,
        escapedMap,
        escapedStatus,
        g_CurrentHalf,
        g_CurrentScoreA,
        g_CurrentScoreB
    )
    run_write_query(query)
}

stock persist_half(const event[])
{
    new uid[129], escapedEvent[49], query[QUERY_MAX + 1]
    quote_sql(g_MatchUid, uid, charsmax(uid))
    quote_sql(event, escapedEvent, charsmax(escapedEvent))

    formatex(
        query,
        charsmax(query),
        "REPLACE INTO kgb_cw_halves (match_uid,map_number,half,event_type,score_a,score_b,recorded_at) VALUES ('%s',%d,%d,'%s',%d,%d,CURRENT_TIMESTAMP)",
        uid,
        g_CurrentMapNumber,
        g_CurrentHalf,
        escapedEvent,
        g_CurrentScoreA,
        g_CurrentScoreB
    )
    run_write_query(query)
}

stock persist_player(id)
{
    if (!g_MatchUid[0] || id < 1 || id > 32 || !g_PlayerAuth[id][0])
    {
        return
    }

    new uid[129], authId[81], playerName[129], team[33]
    quote_sql(g_MatchUid, uid, charsmax(uid))
    quote_sql(g_PlayerAuth[id], authId, charsmax(authId))
    quote_sql(g_PlayerName[id], playerName, charsmax(playerName))
    quote_sql(g_PlayerTeam[id], team, charsmax(team))

    new query[QUERY_MAX + 1]
    formatex(
        query,
        charsmax(query),
        "REPLACE INTO kgb_cw_players (match_uid,auth_id,player_name,last_team,kills,deaths,headshots,updated_at) VALUES ('%s','%s','%s','%s',%d,%d,%d,CURRENT_TIMESTAMP)",
        uid,
        authId,
        playerName,
        team,
        g_PlayerKills[id],
        g_PlayerDeaths[id],
        g_PlayerHeadshots[id]
    )
    run_write_query(query)
}

stock persist_all_players()
{
    for (new id = 1; id <= 32; id++)
    {
        if (g_PlayerAuth[id][0])
        {
            if (is_user_connected(id))
            {
                refresh_player_identity(id)
            }
            persist_player(id)
        }
    }
}

stock capture_connected_players()
{
    for (new id = 1; id <= 32; id++)
    {
        if (is_user_connected(id) && !is_user_hltv(id))
        {
            refresh_player_identity(id)
        }
    }
}

stock refresh_player_identity(id)
{
    if (id < 1 || id > 32 || !is_user_connected(id) || is_user_hltv(id))
    {
        return
    }

    get_user_name(id, g_PlayerName[id], charsmax(g_PlayerName[]))
    get_user_authid(id, g_PlayerAuth[id], charsmax(g_PlayerAuth[]))
    get_user_team(id, g_PlayerTeam[id], charsmax(g_PlayerTeam[]))

    if (!g_PlayerAuth[id][0] || equali(g_PlayerAuth[id], "STEAM_ID_PENDING"))
    {
        formatex(g_PlayerAuth[id], charsmax(g_PlayerAuth[]), "USERID:%d", get_user_userid(id))
    }
    else if (equali(g_PlayerAuth[id], "BOT"))
    {
        formatex(g_PlayerAuth[id], charsmax(g_PlayerAuth[]), "BOT:%d", get_user_userid(id))
    }
}

stock reset_player(id)
{
    g_PlayerAuth[id][0] = 0
    g_PlayerName[id][0] = 0
    g_PlayerTeam[id][0] = 0
    g_PlayerKills[id] = 0
    g_PlayerDeaths[id] = 0
    g_PlayerHeadshots[id] = 0
}

stock reset_all_players()
{
    for (new id = 1; id <= 32; id++)
    {
        reset_player(id)
    }
}

stock queue_lifecycle_event(const event[], const teamA[], const teamB[], mapNumber, half, scoreA, scoreB)
{
    if (g_QueuedCount >= EVENT_QUEUE_MAX)
    {
        if (!g_QueueWarningShown)
        {
            server_print("[KGB CW SQL] The startup event queue is full; additional lifecycle snapshots will be skipped until SQL is ready.")
            g_QueueWarningShown = true
        }

        return
    }

    copy(g_QueuedEvent[g_QueuedCount], charsmax(g_QueuedEvent[]), event)
    copy(g_QueuedTeamA[g_QueuedCount], charsmax(g_QueuedTeamA[]), teamA)
    copy(g_QueuedTeamB[g_QueuedCount], charsmax(g_QueuedTeamB[]), teamB)
    g_QueuedMap[g_QueuedCount] = mapNumber
    g_QueuedHalf[g_QueuedCount] = half
    g_QueuedScoreA[g_QueuedCount] = scoreA
    g_QueuedScoreB[g_QueuedCount] = scoreB
    g_QueuedCount++
}

stock flush_lifecycle_queue()
{
    for (new i = 0; i < g_QueuedCount; i++)
    {
        persist_lifecycle_event(
            g_QueuedEvent[i],
            g_QueuedTeamA[i],
            g_QueuedTeamB[i],
            g_QueuedMap[i],
            g_QueuedHalf[i],
            g_QueuedScoreA[i],
            g_QueuedScoreB[i]
        )
    }

    g_QueuedCount = 0
}

stock bool:is_supported_event(const event[])
{
    return equali(event, "match_start") ||
        equali(event, "half_start") ||
        equali(event, "half_end") ||
        equali(event, "match_end") ||
        equali(event, "match_stop") ||
        equali(event, "map_change") ||
        equali(event, "overtime_start")
}

stock generate_match_uid(output[], outputLength)
{
    new timestamp[24]
    format_time(timestamp, charsmax(timestamp), "%Y%m%d%H%M%S")
    formatex(output, outputLength, "%s-%d-%06d", timestamp, get_cvar_num("hostport"), random_num(0, 999999))
}

public task_validate_crossmap_resume()
{
    if (!g_WaitingForCrossmapResume)
    {
        return
    }

    server_print("[KGB CW SQL] Discarded stale cross-map SQL match state because map two did not resume.")
    clear_crossmap_match_uid()
    g_MatchActive = false
}

stock restore_crossmap_match_uid()
{
    new coreActive[4]
    new expectedMap[32]
    new currentMap[32]
    new storedUid[MATCH_UID_MAX + 1]
    get_localinfo(LI_CORE_ACTIVE, coreActive, charsmax(coreActive))
    get_localinfo(LI_CORE_MAP, expectedMap, charsmax(expectedMap))
    get_localinfo(LI_SQL_MATCH_UID, storedUid, charsmax(storedUid))
    get_mapname(currentMap, charsmax(currentMap))

    if (equal(coreActive, "1") && equali(expectedMap, currentMap) && valid_match_uid(storedUid))
    {
        copy(g_MatchUid, charsmax(g_MatchUid), storedUid)
        g_MatchActive = true
        g_WaitingForCrossmapResume = true
        remove_task(TASK_VALIDATE_CROSSMAP)
        set_task(2.0, "task_validate_crossmap_resume", TASK_VALIDATE_CROSSMAP)

        return
    }

    // Never revive an identifier unless the core confirms the expected map.
    clear_crossmap_match_uid()
    g_MatchActive = false
}

stock confirm_crossmap_resume()
{
    if (!g_WaitingForCrossmapResume)
    {
        return
    }

    g_WaitingForCrossmapResume = false
    remove_task(TASK_VALIDATE_CROSSMAP)
}

stock clear_crossmap_match_uid()
{
    remove_task(TASK_VALIDATE_CROSSMAP)
    set_localinfo(LI_SQL_MATCH_UID, "")
    g_MatchUid[0] = 0
    g_WaitingForCrossmapResume = false
}

stock bool:valid_match_uid(const value[])
{
    new length = strlen(value)
    if (length < 1 || length > MATCH_UID_MAX)
    {
        return false
    }

    for (new i = 0; i < length; i++)
    {
        if ((value[i] >= 'a' && value[i] <= 'z') ||
            (value[i] >= 'A' && value[i] <= 'Z') ||
            (value[i] >= '0' && value[i] <= '9') ||
            value[i] == '-' || value[i] == '_' || value[i] == '.')
        {
            continue
        }

        return false
    }

    return true
}

stock quote_sql(const source[], output[], outputLength)
{
    if (SQL_QuoteString(Empty_Handle, output, outputLength, source) < 0)
    {
        output[0] = 0
    }
}

stock run_write_query(const query[])
{
    if (g_DbTuple != Empty_Handle && g_SchemaReady && !g_DatabaseFailed)
    {
        SQL_ThreadQuery(g_DbTuple, "query_result", query)
    }
}

stock database_query_failed(const operation[], const error[], errorNumber)
{
    g_QueryFailures++
    if (g_QueryFailures <= 3)
    {
        server_print("[KGB CW SQL] Asynchronous %s failed (error %d): %s", operation, errorNumber, error)
    }

    if (g_QueryFailures >= 3)
    {
        server_print("[KGB CW SQL] SQL persistence is disabled for this map after repeated failures; the core match plugin remains active.")
        g_DatabaseFailed = true
        g_SchemaReady = false
    }
}
