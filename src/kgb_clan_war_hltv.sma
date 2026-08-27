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

#define RCON_PASSWORD_MAX 63
#define RCON_COMMAND_MAX 159
#define RCON_PACKET_MAX 511
#define RCON_POLL_ATTEMPTS 20

new g_CvarEnabled
new g_CvarAutoRecord
new g_CvarStartDelay
new g_CvarStopDelay
new g_CvarFilePrefix
new g_CvarRconEnabled
new g_CvarRconHost
new g_CvarRconPort
new g_CvarProxyDelay

new bool:g_Recording
new g_RecordFile[96]
new g_TeamA[32]
new g_TeamB[32]
new g_MapNumber

new g_RconSocket = -1
new g_RconPollCount
new g_RconCommand[RCON_COMMAND_MAX + 1]
new bool:g_RconCredentialWarningShown

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
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
}

public plugin_end()
{
    remove_task(TASK_HLTV_START)
    remove_task(TASK_HLTV_STOP)
    close_rcon_socket()
    clear_rcon_command()
}

public command_hltv_menu(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
    new title[96]
    formatex(title, charsmax(title), "KGB Clan War HLTV (delay %ds)", clamp(get_pcvar_num(g_CvarProxyDelay), 0, 3600))
    new menu = menu_create(title, "menu_hltv_handler")
    menu_additem(menu, get_pcvar_num(g_CvarEnabled) ? "Disable integration" : "Enable integration", "1")
    menu_additem(menu, get_pcvar_num(g_CvarAutoRecord) ? "Disable automatic recording" : "Enable automatic recording", "2")
    menu_additem(menu, "Set proxy delay: 0 seconds", "3")
    menu_additem(menu, "Set proxy delay: 30 seconds", "4")
    menu_additem(menu, "Set proxy delay: 90 seconds", "5")
    menu_additem(menu, "Test proxy command path", "6")
    menu_additem(menu, "Show status", "7")
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
        case 1: { set_pcvar_num(g_CvarEnabled, !get_pcvar_num(g_CvarEnabled)); hltv_console(id, "Integration is now %s.", get_pcvar_num(g_CvarEnabled) ? "enabled" : "disabled"); }
        case 2: { set_pcvar_num(g_CvarAutoRecord, !get_pcvar_num(g_CvarAutoRecord)); hltv_console(id, "Automatic recording is now %s.", get_pcvar_num(g_CvarAutoRecord) ? "enabled" : "disabled"); }
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
    if (!is_decimal_number(value)) hltv_console(id, "Delay must be an integer from 0 through 3600 seconds.")
    else apply_proxy_delay(id, clamp(str_to_num(value), 0, 3600))
    return PLUGIN_HANDLED
}

stock show_hltv_status(id)
{
    new hltv = find_connected_hltv()
    hltv_console(id, "enabled=%d auto_record=%d recording=%d connected_proxy=%d rcon=%d delay=%d file=%s", get_pcvar_num(g_CvarEnabled), get_pcvar_num(g_CvarAutoRecord), g_Recording, hltv > 0, get_pcvar_num(g_CvarRconEnabled), clamp(get_pcvar_num(g_CvarProxyDelay), 0, 3600), g_RecordFile[0] ? g_RecordFile : "none")
}

stock test_hltv_command_path(id)
{
    if (dispatch_proxy_command("echo kgb_cw_hltv_test")) hltv_console(id, "Harmless test command queued. Confirm receipt in the HLTV console/log.")
    else hltv_console(id, "No connected proxy or explicitly enabled RCON path is available.")
}

stock apply_proxy_delay(id, seconds)
{
    seconds = clamp(seconds, 0, 3600)
    new command[32]
    formatex(command, charsmax(command), "delay %d", seconds)
    if (!dispatch_proxy_command(command))
    {
        hltv_console(id, "Delay was not changed because no proxy command path is available.")
        return
    }
    set_pcvar_num(g_CvarProxyDelay, seconds)
    hltv_console(id, "Proxy delay command queued: %d seconds.", seconds)
}

stock bool:dispatch_proxy_command(const command[])
{
    new hltv = find_connected_hltv()
    if (hltv > 0)
    {
        client_cmd(hltv, "%s", command)
        return true
    }
    return begin_rcon_command(command)
}

stock bool:is_decimal_number(const value[])
{
    if (!value[0]) return false
    for (new i = 0; value[i]; i++) if (value[i] < '0' || value[i] > '9') return false
    return true
}

stock hltv_console(id, const format[], any:...)
{
    new message[191]
    vformat(message, charsmax(message), format, 3)
    console_print(id, "[KGB CW HLTV] %s", message)
}

/**
 * Public forward emitted by compatible KGB Clan War core releases.
 * Unknown events are intentionally ignored for forward compatibility.
 */
public kgb_cw_event(const event[], const team_a[], const team_b[], map_number, half, score_a, score_b)
{
    if (!get_pcvar_num(g_CvarEnabled) || !get_pcvar_num(g_CvarAutoRecord))
    {
        return
    }

    if (equali(event, "match_start"))
    {
        copy(g_TeamA, charsmax(g_TeamA), team_a)
        copy(g_TeamB, charsmax(g_TeamB), team_b)
        g_MapNumber = map_number

        remove_task(TASK_HLTV_STOP)
        remove_task(TASK_HLTV_START)
        set_task(clamp_delay(get_pcvar_float(g_CvarStartDelay)), "task_start_recording", TASK_HLTV_START)
    }
    else if (equali(event, "half_start") && map_number == 2 && half == 1 && !g_Recording)
    {
        // Map two resumes with half_start rather than a second match_start.
        copy(g_TeamA, charsmax(g_TeamA), team_a)
        copy(g_TeamB, charsmax(g_TeamB), team_b)
        g_MapNumber = map_number

        remove_task(TASK_HLTV_STOP)
        remove_task(TASK_HLTV_START)
        set_task(clamp_delay(get_pcvar_float(g_CvarStartDelay)), "task_start_recording", TASK_HLTV_START)
    }
    else if (equali(event, "map_change"))
    {
        // A delayed task would be destroyed when AMXX unloads for the map change.
        remove_task(TASK_HLTV_START)
        remove_task(TASK_HLTV_STOP)
        task_stop_recording()
    }
    else if (equali(event, "match_end") || equali(event, "match_stop"))
    {
        remove_task(TASK_HLTV_START)
        remove_task(TASK_HLTV_STOP)
        set_task(clamp_delay(get_pcvar_float(g_CvarStopDelay)), "task_stop_recording", TASK_HLTV_STOP)
    }
}

public task_start_recording()
{
    if (!get_pcvar_num(g_CvarEnabled) || !get_pcvar_num(g_CvarAutoRecord) || g_Recording)
    {
        return
    }

    build_record_filename(g_RecordFile, charsmax(g_RecordFile))

    new hltv = find_connected_hltv()
    if (hltv > 0)
    {
        client_cmd(hltv, "record %s", g_RecordFile)
        g_Recording = true
        server_print("[KGB CW HLTV] Recording requested from the connected HLTV proxy.")

        return
    }

    if (get_pcvar_num(g_CvarRconEnabled))
    {
        new command[RCON_COMMAND_MAX + 1]
        formatex(command, charsmax(command), "record %s", g_RecordFile)

        if (begin_rcon_command(command))
        {
            g_Recording = true
            server_print("[KGB CW HLTV] Recording requested through explicitly enabled HLTV RCON.")
        }
    }
    else
    {
        server_print("[KGB CW HLTV] No connected HLTV proxy was found; recording was not started.")
    }
}

public task_stop_recording()
{
    if (!g_Recording)
    {
        return
    }

    new hltv = find_connected_hltv()
    if (hltv > 0)
    {
        client_cmd(hltv, "stoprecording")
        server_print("[KGB CW HLTV] Stop recording requested from the connected HLTV proxy.")
    }
    else if (get_pcvar_num(g_CvarRconEnabled))
    {
        if (begin_rcon_command("stoprecording"))
        {
            server_print("[KGB CW HLTV] Stop recording requested through explicitly enabled HLTV RCON.")
        }
    }
    else
    {
        server_print("[KGB CW HLTV] The recorded proxy is no longer connected; no stop command was sent.")
    }

    g_Recording = false
    g_RecordFile[0] = 0
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
            close_rcon_socket()
            clear_rcon_command()

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
        close_rcon_socket()
        clear_rcon_command()

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
        close_rcon_socket()
        clear_rcon_command()

        return
    }

    send_authenticated_rcon(challenge)
    arrayset(response, 0, sizeof response)
    arrayset(challenge, 0, sizeof challenge)
    close_rcon_socket()
    clear_rcon_command()
}

stock bool:begin_rcon_command(const command[])
{
    if (!get_pcvar_num(g_CvarRconEnabled))
    {
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

    close_rcon_socket()
    copy(g_RconCommand, charsmax(g_RconCommand), command)

    new socketError
    g_RconSocket = socket_open(host, port, SOCKET_UDP, socketError)
    if (g_RconSocket < 0)
    {
        server_print("[KGB CW HLTV] Could not open the HLTV RCON socket (error %d).", socketError)
        clear_rcon_command()

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
        close_rcon_socket()
        clear_rcon_command()

        return false
    }

    arrayset(packet, 0, sizeof packet)
    g_RconPollCount = 0
    remove_task(TASK_RCON_POLL)
    set_task(0.1, "task_poll_rcon", TASK_RCON_POLL)

    return true
}

stock send_authenticated_rcon(const challenge[])
{
    new password[RCON_PASSWORD_MAX + 1]
    if (!read_rcon_password(password, charsmax(password)))
    {
        server_print("[KGB CW HLTV] The RCON credential could not be read when sending the command.")
        arrayset(password, 0, sizeof password)

        return
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

    arrayset(password, 0, sizeof password)
    arrayset(packet, 0, sizeof packet)
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

stock clear_rcon_command()
{
    arrayset(g_RconCommand, 0, sizeof g_RconCommand)
}
