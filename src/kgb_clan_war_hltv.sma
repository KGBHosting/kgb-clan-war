// SPDX-License-Identifier: GPL-3.0-or-later

#include <amxmodx>
#include <amxmisc>
#include <sockets>

#define PLUGIN_NAME "KGB Clan War: HLTV"
#define PLUGIN_VERSION "0.3.0"
#define PLUGIN_AUTHOR "KGB Hosting"

#define TASK_HLTV_START 88401
#define TASK_HLTV_STOP 88402
#define TASK_RCON_POLL 88403
#define TASK_CONFIG_MONITOR 88404

#define RCON_PASSWORD_MAX 63
#define RCON_COMMAND_MAX 159
#define RCON_PACKET_MAX 511
#define RCON_POLL_ATTEMPTS 20
#define DEFAULT_CHAT_PREFIX "[KGB CW]"
#define CHAT_PREFIX_MAX 23

enum RconOperation { RCON_NONE = 0, RCON_GENERIC, RCON_START_RECORDING, RCON_STOP_RECORDING }

new g_CvarEnabled
new g_CvarAutoRecord
new g_CvarStartDelay
new g_CvarStopDelay
new g_CvarFilePrefix
new g_CvarRconEnabled
new g_CvarRconHost
new g_CvarRconPort
new g_CvarProxyDelay
new g_CvarChatPrefix

new bool:g_Recording
new g_RecordFile[96]
new g_TeamA[32]
new g_TeamB[32]
new g_MapNumber

new g_RconSocket = -1
new g_RconPollCount
new g_RconCommand[RCON_COMMAND_MAX + 1]
new bool:g_RconCredentialWarningShown
new bool:g_StopPathWarningShown
new RconOperation:g_RconOperation = RCON_NONE
new bool:g_RecordStartPending, bool:g_RecordStopPending
new bool:g_RecordRestartPending

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_dictionary("kgb_clan_war.txt")
    register_cvar("kgb_cw_hltv_version", PLUGIN_VERSION, FCVAR_SERVER | FCVAR_SPONLY)

    g_CvarEnabled = register_cvar("kgb_cw_hltv_enabled", "0")
    g_CvarAutoRecord = register_cvar("kgb_cw_hltv_auto_record", "1")
    g_CvarStartDelay = register_cvar("kgb_cw_hltv_start_delay", "3.0")
    g_CvarStopDelay = register_cvar("kgb_cw_hltv_stop_delay", "5.0")
    g_CvarFilePrefix = register_cvar("kgb_cw_hltv_file_prefix", "kgb_cw")
    g_CvarRconEnabled = register_cvar("kgb_cw_hltv_rcon_enabled", "0")
    g_CvarRconHost = register_cvar("kgb_cw_hltv_rcon_host", "127.0.0.1")
    g_CvarRconPort = register_cvar("kgb_cw_hltv_rcon_port", "27020")
    g_CvarProxyDelay = register_cvar("kgb_cw_hltv_proxy_delay", "30")

    register_concmd("amx_cw_hltv_menu", "command_hltv_menu", ADMIN_CFG, "- interactive HLTV controls")
    register_concmd("amx_cw_hltv_status", "command_hltv_status", ADMIN_CFG, "- show HLTV integration status")
    register_concmd("amx_cw_hltv_test", "command_hltv_test", ADMIN_CFG, "- send a harmless proxy echo test")
    register_concmd("amx_cw_hltv_delay", "command_hltv_delay", ADMIN_CFG, "<0-3600 seconds>")
}

public plugin_cfg()
{
    server_cmd("exec addons/amxmodx/configs/kgb_clan_war_hltv.cfg")
    server_exec()
    g_CvarChatPrefix = get_cvar_pointer("kgb_cw_chat_prefix")
    remove_task(TASK_CONFIG_MONITOR)
    set_task(1.0, "task_monitor_configuration", TASK_CONFIG_MONITOR, _, _, "b")
}

public plugin_end()
{
    remove_task(TASK_HLTV_START)
    remove_task(TASK_HLTV_STOP)
    remove_task(TASK_CONFIG_MONITOR)
    stop_recording_on_unload()
    close_rcon_socket()
    clear_rcon_request_state()
    g_RecordStartPending = false; g_RecordStopPending = false; g_RecordRestartPending = false
}

public command_hltv_menu(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    new title[96], label[96]
    formatex(title, charsmax(title), "%L", id, "CW_HLTV_TITLE", clamp(get_pcvar_num(g_CvarProxyDelay), 0, 3600))
    new menu = menu_create(title, "menu_hltv_handler")
    formatex(label, charsmax(label), "%L", id, get_pcvar_num(g_CvarEnabled) ? "CW_HLTV_DISABLE" : "CW_HLTV_ENABLE"); menu_additem(menu, label, "1")
    formatex(label, charsmax(label), "%L", id, get_pcvar_num(g_CvarAutoRecord) ? "CW_HLTV_AUTO_DISABLE" : "CW_HLTV_AUTO_ENABLE"); menu_additem(menu, label, "2")
    formatex(label, charsmax(label), "%L", id, "CW_HLTV_DELAY", 0); menu_additem(menu, label, "3")
    formatex(label, charsmax(label), "%L", id, "CW_HLTV_DELAY", 30); menu_additem(menu, label, "4")
    formatex(label, charsmax(label), "%L", id, "CW_HLTV_DELAY", 90); menu_additem(menu, label, "5")
    formatex(label, charsmax(label), "%L", id, "CW_HLTV_TEST"); menu_additem(menu, label, "6")
    formatex(label, charsmax(label), "%L", id, "CW_HLTV_STATUS"); menu_additem(menu, label, "7")
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL); menu_display(id, menu)
    return PLUGIN_HANDLED
}

public menu_hltv_handler(id, menu, item)
{
    if (item == MENU_EXIT || !(get_user_flags(id) & ADMIN_CFG))
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    new access, info[8], label[64], callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), label, charsmax(label), callback)
    switch (str_to_num(info))
    {
        case 1:
        {
            set_pcvar_num(g_CvarEnabled, !get_pcvar_num(g_CvarEnabled)); enforce_disabled_recording_stop()
            hltv_console_ml(id, get_pcvar_num(g_CvarEnabled) ? "CW_HLTV_INTEGRATION_ENABLED" : "CW_HLTV_INTEGRATION_DISABLED")
        }
        case 2:
        {
            set_pcvar_num(g_CvarAutoRecord, !get_pcvar_num(g_CvarAutoRecord)); enforce_disabled_recording_stop()
            hltv_console_ml(id, get_pcvar_num(g_CvarAutoRecord) ? "CW_HLTV_AUTO_ENABLED" : "CW_HLTV_AUTO_DISABLED")
        }
        case 3: apply_proxy_delay(id, 0)
        case 4: apply_proxy_delay(id, 30)
        case 5: apply_proxy_delay(id, 90)
        case 6: test_hltv_command_path(id)
        case 7: show_hltv_status(id)
    }
    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public command_hltv_status(id, level, cid)
{
    if (cmd_access(id, level, cid, 1)) show_hltv_status(id)
    return PLUGIN_HANDLED
}

public command_hltv_test(id, level, cid)
{
    if (cmd_access(id, level, cid, 1)) test_hltv_command_path(id)
    return PLUGIN_HANDLED
}

public command_hltv_delay(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
    new value[16]
    read_argv(1, value, charsmax(value))
    if (!is_decimal_number(value)) hltv_console_ml(id, "CW_HLTV_INVALID_DELAY")
    else apply_proxy_delay(id, clamp(str_to_num(value), 0, 3600))
    return PLUGIN_HANDLED
}

stock show_hltv_status(id)
{
    new hltv = find_connected_hltv()
    hltv_console_ml(id, "CW_HLTV_STATUS_LINE", get_pcvar_num(g_CvarEnabled), get_pcvar_num(g_CvarAutoRecord), g_Recording, g_RecordStartPending, g_RecordStopPending, hltv > 0, get_pcvar_num(g_CvarRconEnabled), clamp(get_pcvar_num(g_CvarProxyDelay), 0, 3600), g_RecordFile[0] ? g_RecordFile : "none")
}

stock test_hltv_command_path(id)
{
    if (dispatch_proxy_command("echo kgb_cw_hltv_test")) hltv_console_ml(id, "CW_HLTV_TEST_QUEUED")
    else hltv_console_ml(id, "CW_HLTV_NO_PATH")
}

stock apply_proxy_delay(id, seconds)
{
    seconds = clamp(seconds, 0, 3600)
    new command[32]
    formatex(command, charsmax(command), "delay %d", seconds)
    if (!dispatch_proxy_command(command))
    {
        hltv_console_ml(id, "CW_HLTV_DELAY_NO_PATH")
        return
    }
    set_pcvar_num(g_CvarProxyDelay, seconds)
    hltv_console_ml(id, "CW_HLTV_DELAY_QUEUED", seconds)
}

stock bool:dispatch_proxy_command(const command[])
{
    new hltv = find_connected_hltv()
    if (hltv > 0)
    {
        client_cmd(hltv, "%s", command)
        return true
    }
    return begin_rcon_command(command, RCON_GENERIC)
}

stock bool:is_decimal_number(const value[])
{
    if (!value[0]) return false
    for (new i = 0; value[i]; i++) if (value[i] < '0' || value[i] > '9') return false
    return true
}

stock hltv_console_ml(id, const key[], any:...)
{
    new translated[191], message[191], prefix[CHAT_PREFIX_MAX + 1]
    new language = id > 0 ? id : LANG_SERVER
    LookupLangKey(translated, charsmax(translated), key, language)
    vformat(message, charsmax(message), translated, 3)
    get_hltv_prefix(prefix, charsmax(prefix))
    console_print(id, "%s HLTV %s", prefix, message)
}

stock get_hltv_prefix(output[], length)
{
    output[0] = 0
    if (g_CvarChatPrefix > 0) get_pcvar_string(g_CvarChatPrefix, output, length)
    trim(output)
    new size = strlen(output)
    if (size < 1 || size > CHAT_PREFIX_MAX)
    {
        copy(output, length, DEFAULT_CHAT_PREFIX)
        return
    }
    for (new i = 0; i < size; i++)
    {
        new c = output[i]
        if (c < 32 || c > 126 || c == ';' || c == '^"' || c == '%' || c == 92)
        {
            copy(output, length, DEFAULT_CHAT_PREFIX)
            return
        }
    }
}

/**
 * Public forward emitted by compatible KGB Clan War core releases.
 * Unknown events are intentionally ignored for forward compatibility.
 */
public kgb_cw_event(const event[], const team_a[], const team_b[], map_number, half, score_a, score_b)
{
    if (equali(event, "map_change"))
    {
        g_RecordRestartPending = false; remove_task(TASK_HLTV_START); remove_task(TASK_HLTV_STOP); task_stop_recording(); return
    }
    if (equali(event, "match_end") || equali(event, "match_stop"))
    {
        g_RecordRestartPending = false
        remove_task(TASK_HLTV_START); remove_task(TASK_HLTV_STOP)
        set_task(clamp_delay(get_pcvar_float(g_CvarStopDelay)), "task_stop_recording", TASK_HLTV_STOP)
        return
    }
    if (!get_pcvar_num(g_CvarEnabled) || !get_pcvar_num(g_CvarAutoRecord))
    {
        return
    }

    if (equali(event, "match_start"))
    {
        copy(g_TeamA, charsmax(g_TeamA), team_a)
        copy(g_TeamB, charsmax(g_TeamB), team_b)
        g_MapNumber = map_number

        remove_task(TASK_HLTV_STOP); remove_task(TASK_HLTV_START)
        if (g_Recording || g_RecordStartPending || g_RecordStopPending || g_RconOperation != RCON_NONE)
        {
            g_RecordRestartPending = true
            drive_recording_restart()
        }
        else schedule_recording_start()
    }
    else if (equali(event, "half_start") && map_number == 2 && half == 1 && !g_Recording)
    {
        // Map two resumes with half_start rather than a second match_start.
        copy(g_TeamA, charsmax(g_TeamA), team_a)
        copy(g_TeamB, charsmax(g_TeamB), team_b)
        g_MapNumber = map_number

        remove_task(TASK_HLTV_STOP); remove_task(TASK_HLTV_START)
        schedule_recording_start()
    }
}

public task_monitor_configuration()
{
    enforce_disabled_recording_stop()
    drive_recording_restart()
}

stock schedule_recording_start()
{
    if (!get_pcvar_num(g_CvarEnabled) || !get_pcvar_num(g_CvarAutoRecord))
    {
        g_RecordRestartPending = false
        return
    }
    remove_task(TASK_HLTV_START)
    set_task(clamp_delay(get_pcvar_float(g_CvarStartDelay)), "task_start_recording", TASK_HLTV_START)
}

stock drive_recording_restart()
{
    if (!g_RecordRestartPending) return
    if (!get_pcvar_num(g_CvarEnabled) || !get_pcvar_num(g_CvarAutoRecord))
    {
        g_RecordRestartPending = false
        return
    }
    if (g_RecordStartPending)
    {
        finish_rcon_request(false)
        return
    }
    if (g_RecordStopPending || g_RconOperation != RCON_NONE) return
    if (g_Recording)
    {
        task_stop_recording()
        return
    }
    g_RecordRestartPending = false
    schedule_recording_start()
}

stock enforce_disabled_recording_stop()
{
    if (get_pcvar_num(g_CvarEnabled) && get_pcvar_num(g_CvarAutoRecord)) return
    remove_task(TASK_HLTV_START)
    if (g_Recording || g_RecordStartPending) task_stop_recording()
}

public task_start_recording()
{
    if (!get_pcvar_num(g_CvarEnabled) || !get_pcvar_num(g_CvarAutoRecord) || g_Recording || g_RecordStartPending || g_RecordStopPending)
    {
        return
    }

    build_record_filename(g_RecordFile, charsmax(g_RecordFile))

    new hltv = find_connected_hltv()
    if (hltv > 0)
    {
        client_cmd(hltv, "delay %d", clamp(get_pcvar_num(g_CvarProxyDelay), 0, 3600))
        client_cmd(hltv, "record %s", g_RecordFile)
        g_Recording = true
        g_StopPathWarningShown = false
        server_print("[KGB CW HLTV] Recording requested from the connected HLTV proxy.")

        return
    }

    if (get_pcvar_num(g_CvarRconEnabled))
    {
        new command[RCON_COMMAND_MAX + 1]
        formatex(command, charsmax(command), "delay %d;record %s", clamp(get_pcvar_num(g_CvarProxyDelay), 0, 3600), g_RecordFile)

        if (begin_rcon_command(command, RCON_START_RECORDING))
        {
            g_RecordStartPending = true
            g_StopPathWarningShown = false
            server_print("[KGB CW HLTV] Delay plus recording request is pending an HLTV RCON challenge.")
        }
        else g_RecordFile[0] = 0
    }
    else
    {
        server_print("[KGB CW HLTV] No connected HLTV proxy was found; recording was not started.")
        g_RecordFile[0] = 0
    }
}

public task_stop_recording()
{
    if (g_RecordStartPending)
    {
        finish_rcon_request(false)
        g_RecordFile[0] = 0
        server_print("[KGB CW HLTV] Pending start request was cancelled before authentication.")
        drive_recording_restart()
        return
    }
    if (!g_Recording || g_RecordStopPending)
    {
        return
    }

    new hltv = find_connected_hltv()
    if (hltv > 0)
    {
        client_cmd(hltv, "stoprecording")
        server_print("[KGB CW HLTV] Stop recording requested from the connected HLTV proxy.")
        g_Recording = false; g_RecordFile[0] = 0
        g_StopPathWarningShown = false
        drive_recording_restart()
    }
    else if (get_pcvar_num(g_CvarRconEnabled))
    {
        if (begin_rcon_command("stoprecording", RCON_STOP_RECORDING))
        {
            g_RecordStopPending = true
            server_print("[KGB CW HLTV] Stop request is pending an HLTV RCON challenge.")
        }
        else g_RecordRestartPending = false
    }
    else
    {
        if (!g_StopPathWarningShown)
        {
            server_print("[KGB CW HLTV] The recorded proxy is no longer connected; recording remains active/unknown because no stop command path exists.")
            g_StopPathWarningShown = true
        }
        g_RecordRestartPending = false
    }

}

public task_poll_rcon()
{
    if (g_RconSocket < 0)
    {
        return
    }

#if defined SOCK_NON_BLOCKING
    if (!socket_is_readable(g_RconSocket, 0))
#else
    if (!socket_change(g_RconSocket, 0))
#endif
    {
        g_RconPollCount++
        if (g_RconPollCount >= RCON_POLL_ATTEMPTS)
        {
            server_print("[KGB CW HLTV] HLTV RCON challenge timed out.")
            finish_rcon_request(false)

            return
        }

        set_task(0.1, "task_poll_rcon", TASK_RCON_POLL)

        return
    }

    new response[RCON_PACKET_MAX + 1]
    new received = socket_recv(g_RconSocket, response, RCON_PACKET_MAX)
    if (received <= 0)
    {
        server_print("[KGB CW HLTV] HLTV RCON challenge could not be read.")
        finish_rcon_request(false)

        return
    }

    if (received > RCON_PACKET_MAX)
    {
        received = RCON_PACKET_MAX
    }
    response[received] = 0

    new challenge[32]
    if (!extract_rcon_challenge(response, challenge, charsmax(challenge)))
    {
        server_print("[KGB CW HLTV] HLTV returned an invalid RCON challenge.")
        finish_rcon_request(false)

        return
    }

    new bool:sent = send_authenticated_rcon(challenge)
    arrayset(response, 0, sizeof response)
    arrayset(challenge, 0, sizeof challenge)
    finish_rcon_request(sent)
}

stock bool:begin_rcon_command(const command[], RconOperation:operation)
{
    if (!get_pcvar_num(g_CvarRconEnabled))
    {
        return false
    }
    if (g_RconSocket >= 0 || g_RconCommand[0] || g_RconOperation != RCON_NONE)
    {
        server_print("[KGB CW HLTV] RCON operation rejected because another request is pending.")
        return false
    }

    new host[64]
    get_pcvar_string(g_CvarRconHost, host, charsmax(host))
    trim(host)

    new port = get_pcvar_num(g_CvarRconPort)
    if (!is_valid_ipv4(host) || port < 1 || port > 65535)
    {
        server_print("[KGB CW HLTV] RCON host must be a numeric IPv4 address and port must be between 1 and 65535.")

        return false
    }

    new password[RCON_PASSWORD_MAX + 1]
    if (!read_rcon_password(password, charsmax(password)))
    {
        if (!g_RconCredentialWarningShown)
        {
            server_print("[KGB CW HLTV] RCON is enabled but its dedicated credential file is missing or invalid.")
            g_RconCredentialWarningShown = true
        }

        arrayset(password, 0, sizeof password)

        return false
    }
    arrayset(password, 0, sizeof password)

    copy(g_RconCommand, charsmax(g_RconCommand), command)
    g_RconOperation = operation

    new socketError
    g_RconSocket = socket_open(host, port, SOCKET_UDP, socketError)
    if (g_RconSocket < 0)
    {
        server_print("[KGB CW HLTV] Could not open the HLTV RCON socket (error %d).", socketError)
        clear_rcon_request_state()

        return false
    }

    new packet[64]
    packet[0] = -1
    packet[1] = -1
    packet[2] = -1
    packet[3] = -1
    new payloadLength = formatex(packet[4], charsmax(packet) - 4, "challenge rcon^n")

    if (socket_send(g_RconSocket, packet, payloadLength + 4) < 0)
    {
        server_print("[KGB CW HLTV] Could not request an HLTV RCON challenge.")
        arrayset(packet, 0, sizeof packet)
        close_rcon_socket(); clear_rcon_request_state()

        return false
    }

    arrayset(packet, 0, sizeof packet)
    g_RconPollCount = 0
    remove_task(TASK_RCON_POLL)
    set_task(0.1, "task_poll_rcon", TASK_RCON_POLL)

    return true
}

stock bool:send_authenticated_rcon(const challenge[])
{
    new password[RCON_PASSWORD_MAX + 1]
    if (!read_rcon_password(password, charsmax(password)))
    {
        server_print("[KGB CW HLTV] The RCON credential could not be read when sending the command.")
        arrayset(password, 0, sizeof password)

        return false
    }

    new packet[RCON_PACKET_MAX + 1]
    packet[0] = -1
    packet[1] = -1
    packet[2] = -1
    packet[3] = -1
    new payloadLength = formatex(
        packet[4],
        charsmax(packet) - 4,
        "rcon %s ^"%s^" %s^n",
        challenge,
        password,
        g_RconCommand
    )

    if (payloadLength <= 0 || payloadLength + 4 > RCON_PACKET_MAX)
    {
        server_print("[KGB CW HLTV] The bounded RCON request could not be constructed.")
    }
    else if (socket_send(g_RconSocket, packet, payloadLength + 4) < 0)
    {
        server_print("[KGB CW HLTV] The authenticated RCON request could not be sent.")
    }
    else
    {
        arrayset(password, 0, sizeof password)
        arrayset(packet, 0, sizeof packet)
        return true
    }

    arrayset(password, 0, sizeof password)
    arrayset(packet, 0, sizeof packet)
    return false
}

stock finish_rcon_request(bool:success)
{
    new RconOperation:operation = g_RconOperation
    close_rcon_socket()
    clear_rcon_request_state()
    if (operation == RCON_START_RECORDING)
    {
        g_RecordStartPending = false
        if (success)
        {
            g_Recording = true
            g_StopPathWarningShown = false
            server_print("[KGB CW HLTV] Delay plus recording request was authenticated and sent.")
        }
        else
        {
            g_RecordFile[0] = 0
            server_print("[KGB CW HLTV] Recording did not start because the pending RCON request failed.")
        }
    }
    else if (operation == RCON_STOP_RECORDING)
    {
        g_RecordStopPending = false
        if (success)
        {
            g_Recording = false; g_RecordFile[0] = 0
            g_StopPathWarningShown = false
            server_print("[KGB CW HLTV] Stop request was authenticated and sent.")
        }
        else
        {
            g_RecordRestartPending = false
            server_print("[KGB CW HLTV] Stop request failed; recording state remains active/unknown and a replacement recording will not start.")
        }
    }
    drive_recording_restart()
}

stock stop_recording_on_unload()
{
    if (!g_Recording && !g_RecordStartPending && !g_RecordStopPending) return

    new hltv = find_connected_hltv()
    if (hltv > 0)
    {
        client_cmd(hltv, "stoprecording")
        server_print("[KGB CW HLTV] Stop recording requested from the connected proxy during plugin unload.")
        return
    }

    /* A pending start that never authenticated cannot have begun recording. */
    if (g_RecordStartPending)
    {
        server_print("[KGB CW HLTV] Cancelled an unauthenticated start request during plugin unload.")
        return
    }
    if (!get_pcvar_num(g_CvarRconEnabled))
    {
        server_print("[KGB CW HLTV] Plugin unloaded while recording remained active/unknown and no stop command path existed.")
        return
    }

    close_rcon_socket(); clear_rcon_request_state()
    if (!begin_rcon_command("stoprecording", RCON_STOP_RECORDING))
    {
        server_print("[KGB CW HLTV] Could not begin the bounded unload stop request; recording remains active/unknown.")
        return
    }
    remove_task(TASK_RCON_POLL)

    /* Unload cannot leave asynchronous work behind. Bound this one challenge
     * exchange to 100 ms, then fail closed without claiming that recording
     * stopped when the proxy did not answer. */
#if defined SOCK_NON_BLOCKING
    if (!socket_is_readable(g_RconSocket, 100000))
#else
    if (!socket_change(g_RconSocket, 100000))
#endif
    {
        server_print("[KGB CW HLTV] Timed out waiting for the unload stop challenge; recording remains active/unknown.")
        return
    }
    new response[RCON_PACKET_MAX + 1]
    new received = socket_recv(g_RconSocket, response, RCON_PACKET_MAX)
    if (received <= 0)
    {
        server_print("[KGB CW HLTV] Could not read the unload stop challenge; recording remains active/unknown.")
        return
    }
    if (received > RCON_PACKET_MAX) received = RCON_PACKET_MAX
    response[received] = 0
    new challenge[32]
    if (!extract_rcon_challenge(response, challenge, charsmax(challenge)) || !send_authenticated_rcon(challenge))
    {
        server_print("[KGB CW HLTV] Could not authenticate the unload stop request; recording remains active/unknown.")
        arrayset(response, 0, sizeof response); arrayset(challenge, 0, sizeof challenge)
        return
    }
    server_print("[KGB CW HLTV] Authenticated stop recording request sent during plugin unload.")
    arrayset(response, 0, sizeof response); arrayset(challenge, 0, sizeof challenge)
}

stock bool:read_rcon_password(password[], passwordLength)
{
    new configsDir[128]
    new credentialPath[192]
    get_configsdir(configsDir, charsmax(configsDir))
    formatex(credentialPath, charsmax(credentialPath), "%s/kgb_clan_war_hltv_rcon.key", configsDir)

    if (!file_exists(credentialPath))
    {
        return false
    }

    new line[96]
    new textLength
    for (new lineNumber = 0; read_file(credentialPath, lineNumber, line, charsmax(line), textLength); lineNumber++)
    {
        trim(line)
        if (!line[0] || line[0] == ';' || line[0] == '#' || (line[0] == '/' && line[1] == '/'))
        {
            continue
        }

        if (strlen(line) > passwordLength || !is_safe_rcon_password(line))
        {
            arrayset(line, 0, sizeof line)

            return false
        }

        copy(password, passwordLength, line)
        arrayset(line, 0, sizeof line)

        return true
    }

    arrayset(line, 0, sizeof line)

    return false
}

stock bool:is_safe_rcon_password(const password[])
{
    if (!password[0])
    {
        return false
    }

    for (new i = 0; password[i]; i++)
    {
        if (password[i] < 33 || password[i] > 126 || password[i] == 34 || password[i] == 92)
        {
            return false
        }
    }

    return true
}

stock bool:extract_rcon_challenge(const response[], challenge[], challengeLength)
{
    new position = containi(response, "challenge rcon ")
    if (position < 0)
    {
        return false
    }

    position += 15
    new outputPosition
    if (response[position] == '-' && outputPosition < challengeLength)
    {
        challenge[outputPosition++] = response[position++]
    }

    while (response[position] && outputPosition < challengeLength)
    {
        if (response[position] < '0' || response[position] > '9')
        {
            break
        }

        challenge[outputPosition++] = response[position++]
    }
    challenge[outputPosition] = 0

    return outputPosition > 0 && !(outputPosition == 1 && challenge[0] == '-')
}

stock bool:is_valid_ipv4(const address[])
{
    new octets
    new digits
    new value

    for (new i = 0; ; i++)
    {
        new character = address[i]
        if (character >= '0' && character <= '9')
        {
            value = (value * 10) + (character - '0')
            digits++
            if (digits > 3 || value > 255)
            {
                return false
            }
        }
        else if (character == '.' || character == 0)
        {
            if (!digits)
            {
                return false
            }

            octets++
            if (character == 0)
            {
                break
            }

            digits = 0
            value = 0
        }
        else
        {
            return false
        }
    }

    return octets == 4
}

stock find_connected_hltv()
{
    new maxPlayers = get_maxplayers()
    for (new id = 1; id <= maxPlayers; id++)
    {
        if (is_user_connected(id) && is_user_hltv(id))
        {
            return id
        }
    }

    return 0
}

stock build_record_filename(output[], outputLength)
{
    new prefix[32]
    new timestamp[32]
    new safeTeamA[32]
    new safeTeamB[32]
    get_pcvar_string(g_CvarFilePrefix, prefix, charsmax(prefix))
    format_time(timestamp, charsmax(timestamp), "%Y%m%d-%H%M%S")

    sanitize_filename_copy(prefix, safeTeamA, charsmax(safeTeamA))
    copy(prefix, charsmax(prefix), safeTeamA)
    sanitize_filename_copy(g_TeamA, safeTeamA, charsmax(safeTeamA))
    sanitize_filename_copy(g_TeamB, safeTeamB, charsmax(safeTeamB))

    if (!prefix[0])
    {
        copy(prefix, charsmax(prefix), "kgb_cw")
    }
    if (!safeTeamA[0])
    {
        copy(safeTeamA, charsmax(safeTeamA), "team-a")
    }
    if (!safeTeamB[0])
    {
        copy(safeTeamB, charsmax(safeTeamB), "team-b")
    }

    formatex(output, outputLength, "%s_%s_%s-vs-%s_map%d", prefix, timestamp, safeTeamA, safeTeamB, g_MapNumber)
}

stock sanitize_filename_copy(const source[], output[], outputLength)
{
    new position
    for (new i = 0; source[i] && position < outputLength; i++)
    {
        new character = source[i]
        if ((character >= 'a' && character <= 'z') ||
            (character >= 'A' && character <= 'Z') ||
            (character >= '0' && character <= '9') ||
            character == '-' || character == '_')
        {
            output[position++] = character
        }
        else if (position > 0 && output[position - 1] != '-')
        {
            output[position++] = '-'
        }
    }

    while (position > 0 && output[position - 1] == '-')
    {
        position--
    }
    output[position] = 0
}

stock Float:clamp_delay(Float:value)
{
    if (value < 0.1)
    {
        return 0.1
    }
    if (value > 60.0)
    {
        return 60.0
    }

    return value
}

stock close_rcon_socket()
{
    remove_task(TASK_RCON_POLL)
    if (g_RconSocket >= 0)
    {
        socket_close(g_RconSocket)
        g_RconSocket = -1
    }
}

stock clear_rcon_request_state()
{
    arrayset(g_RconCommand, 0, sizeof g_RconCommand)
    g_RconOperation = RCON_NONE
}
