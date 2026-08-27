# KGB Clan War

KGB Clan War is a GPL-licensed AMX Mod X match controller for Counter-Strike
1.6. It is an independently implemented, reviewable alternative to shipping
opaque legacy match-plugin binaries.

The core plugin owns the match state. HLTV recording and SQL statistics are
separate, optional plugins so a normal Clan War server needs neither network
credentials nor a database.

## Release policy

`v0.3.0` is the next qualification candidate. It is not a release until the
tagged release workflow completes. The earlier stable-version candidate was
withdrawn when configurable operator branding was added; do not deploy that
candidate. Promote `v0.3.0` only after its CI and development-server
qualification evidence is complete.

The qualification line includes the practical AMX Match Deluxe feature
set: player/team/admin ready modes; max-round, win-limit, and time-limit
formats; clinch/always/voted playout; knife stay/swap voting; team names and tags; one- or two-map
matches; phase configs; operator-managed league presets and default-map menus;
an allowlisted saved menu snapshot and setup wizard; fresh English/German
message catalogs; an optional overtime play/draw vote; a second-half re-ready
gate and configurable automatic side-swap policy; clearly separated live-map
and series scores; admin-only SteamID reports and automatic opt-in identity screenshots;
interactive HLTV status/test/delay controls; match/half restart; persistent
random or admin-drafted PUG sessions; recurring ready/score HUDs; optional
hostname/password and client demo/screenshot actions; lifecycle plus per-half
player file statistics; optional HLTV recording; and optional SQLX persistence.

“Deluxe feature set” describes supported operator workflows, not shared code or
binary compatibility. KGB Clan War does not contain AMX Match Deluxe source,
release binaries, language files, or league presets. The shipped presets and
translations are new clean-room material and do not claim conformance with
CAL, ESL, or another league's rules.

## Components

| Artifact | Default | Purpose |
| --- | --- | --- |
| `kgb_clan_war.amxx` | Enabled | Required match controller and operator commands. |
| `kgb_clan_war_hltv.amxx` | Integration disabled | Records through a connected HLTV proxy or explicitly enabled UDP RCON. |
| `kgb_clan_war_sql.amxx` | Integration disabled | Persists match, map, half, and player statistics with threaded SQLX queries. |

The optional plugins consume the lifecycle forward emitted by the core. Keep
the core before them in `plugins.ini`.

## Safe defaults and limitations

- SQL, UDP RCON, server hostname/password changes, shield changes, client demo
  commands, screenshots, saved menu configuration, overtime voting, and PUG
  behavior are disabled by default.
- The release never contains an RCON password or database credential. HLTV
  RCON reads its password from an operator-created
  `addons/amxmodx/configs/kgb_clan_war_hltv_rcon.key`. SQLX reads the normal
  AMX Mod X `addons/amxmodx/configs/sql.cfg`.
- Client demo and screenshot commands are requests to connected clients. A
  client can reject or restrict them; the plugin cannot guarantee a recording.
- Per-half file-stat rows describe players connected when a half ends. They do
  not reconstruct a disconnected player's complete history.
- A series is intentionally limited to one or two installed maps. Map and
  phase-config basenames are validated before they reach server commands.
- This repository proves source review and compiler compatibility. A compiled
  plugin still needs runtime qualification on the target ReHLDS/HLDS build,
  MetaMod, AMX Mod X modules, maps, SQL driver, and HLTV topology.

See [SECURITY.md](SECURITY.md) before enabling an external integration.
The clean-room comparison and deliberate non-equivalence boundaries are in
[`docs/deluxe-parity.md`](docs/deluxe-parity.md).

## Install

KGB Hosting customers should install the published gamemode through the Panel.
The Panel plugin manager selects exact plugin versions, downloads private
artifacts, verifies their checksum, and owns rollback. Do not also copy GitHub
release binaries into a Panel-managed server.

For a standalone server, download the required `.amxx` files and matching
`.sha256` files from the same tagged release, verify each checksum, then copy
the plugins into `cstrike/addons/amxmodx/plugins/`. Add the core and any chosen
optional integrations to `cstrike/addons/amxmodx/configs/plugins.ini`.

This is not restricted to KGB Hosting infrastructure. Server operators outside
KGB Hosting may install, run, modify, and redistribute it under GPLv3-or-later,
subject to that license's terms. See [License and branding](#license-and-branding)
before using KGB names or visual identity in a third-party service.

The source checkout also provides an idempotent installer. Its server root is
the directory that contains `addons/`, normally `cstrike`:

```sh
# Core only
./scripts/install.sh /path/to/cstrike

# Core plus a connected HLTV integration
./scripts/install.sh --with-hltv /path/to/cstrike

# Core plus both optional integrations, still disabled in their configs
./scripts/install.sh --all /path/to/cstrike
```

The installer copies a config example only when the corresponding live config
does not exist. It leaves existing configs and disabled `plugins.ini` entries
unchanged, verifies AMXX magic and the matching checksum before copying a
binary, and never creates credential files. It also creates the competitive
`cstrike/kgb_gamemode.cfg` phase baseline when missing and preserves an
operator-owned file on every later run.

## Operator commands

Commands that change match state require the standard AMX Mod X `ADMIN_CFG`
access flag.

| Command | Purpose |
| --- | --- |
| `amx_cw_menu` | Open match controls. |
| `amx_cw_warmup` | Enter warmup and clear readiness. |
| `amx_cw_knife` | Start the knife round and optional stay/swap decision. |
| `amx_cw_live` | Start a configured match with live-on-three. |
| `amx_cw_relo3` | Repeat live-on-three without resetting the score. |
| `amx_cw_swap` | Swap Terrorist and Counter-Terrorist sides. |
| `amx_cw_restart_half` | Reset the current half. |
| `amx_cw_restart_match` | Reset the complete match. |
| `amx_cw_pug_randomize` | Randomize warmup players when PUG mode is enabled. |
| `amx_cw_pug_start [random\|manual]` | Start a PUG warmup using the selected team workflow. |
| `amx_cw_pug_assign <player> <a\|b>` | Assign a player during a manual PUG draft. |
| `amx_cw_pug_stop` | Stop the active PUG and restore managed server state. |
| `amx_cw_config_menu` | Open preset, default-map, and saved-snapshot controls. |
| `amx_cw_setup`, `amx_cw_settings` | Open the interactive teams/tags, format, ready, swap, playout, overtime, PUG, HUD, screenshot, preset, map, and save workflow. |
| `amx_cw_presets`, `amx_cw_preset <name>` | Browse or apply an installed clean-room league preset. |
| `amx_cw_map_menu` | Select one or two installed maps from the operator catalog. |
| `amx_cw_save_config`, `amx_cw_load_saved` | Save/load the non-secret allowlisted menu snapshot. |
| `amx_cw_teams <team-a> <team-b>` | Set team display names. Quote names containing spaces. |
| `amx_cw_tags <tag-a> <tag-b>` | Set clan tags. |
| `amx_cw_maps <map1> [map2]` | Select one or two installed maps. |
| `amx_cw_stop` | Stop the match and restore the captured server environment. |
| `amx_cw_score` | Show the public match score. |
| `amx_cw_scoreids` | Print detailed score and player SteamIDs to an authorized admin's console only. |
| `amx_cw_scoreids_snapshot` | Show an authorized admin the current score/SteamID MOTD, then request one screenshot when explicitly enabled. |
| `amx_match <team-a> <team-b> [preset]` | Compact KGB launcher that applies an optional managed preset and enters warmup. |
| `amx_match <team-a> <team-b> <mrXX\|tlXX\|wlXX> <config> [recdemo\|rechltv\|recboth]` | Full legacy-compatible one-map launcher. |
| `amx_match2 <mrXX\|tlXX\|wlXX> <config> [recdemo\|rechltv\|recboth]` | Full one-map launcher using the configured team names. |
| `amx_match3 <team-a> <team-b> <mrXX\|tlXX\|wlXX> <config> <map2> [recdemo\|rechltv\|recboth]` | Full two-map launcher. Map one is the currently loaded map. |
| `amx_match4 <mrXX\|tlXX\|wlXX> <config> <map2> [recdemo\|rechltv\|recboth]` | Full two-map launcher using the configured team names. |
| `amx_matchrestart`, `amx_matchstop`, `amx_matchstart`, `amx_matchrelo3` | Legacy lifecycle aliases routed through the same state machine. |
| `amx_swapteams`, `amx_randomizeteams` | Legacy team-control aliases with the normal KGB access and state checks. |
| `amx_cw_status` | Show detailed match status. |

Player chat shortcuts are `/ready`, `/notready`, `/teamready`,
`/teamnotready`, `/start`, `/score`, and `/cw`; `!` prefixes also work. Bare
`ready`, `notready`, `teamready`, and `teamnotready` are accepted for legacy
client binds. `/start`, `/stop`, `/restart`, and `/relo3` still respect the
configured state and access rules.

## Core configuration

The installer creates
`addons/amxmodx/configs/kgb_clan_war.cfg` from the safe example when missing.

| CVAR | Default | Meaning |
| --- | --- | --- |
| `kgb_cw_enabled` | `1` | Enable core controls. |
| `kgb_cw_display_name` | `KGB Clan War` | In-game control and knife-vote menu branding. |
| `kgb_cw_chat_prefix` | `[KGB CW]` | Prefix for core chat, HUD, command feedback, score/status, announcements, and localized HLTV admin feedback. |
| `kgb_cw_min_ready` | `10` | Required ready players. |
| `kgb_cw_ready_mode` | `player` | `player`, `team`, or `admin`. |
| `kgb_cw_auto_live` | `0` | Automatically start after readiness. |
| `kgb_cw_hud_interval` | `10` | Recurring ready/live-score HUD interval when HUD announcements are enabled; `0` disables it, otherwise it is clamped to 3-60 seconds. |
| `kgb_cw_format` | `mr` | `mr`, `wl`, or `tl`. |
| `kgb_cw_half_rounds` | `15` | Regulation rounds per half for max-round mode. |
| `kgb_cw_win_rounds` | `16` | Win target for win-limit mode. |
| `kgb_cw_time_limit_minutes` | `20` | Minutes per half for time-limit mode. |
| `kgb_cw_playout` | `0` | Regulation result handling: `0` ends when clinched, `1` always plays out, `2` asks active players. |
| `kgb_cw_playout_vote_default` | `1` | Tied/no-vote playout decision: `1` continues, `0` ends. |
| `kgb_cw_time_limit_finish_round` | `1` | Finish the active round after a time-limit half expires; `0` transitions immediately. Each half timer begins only after its LO3 completes. |
| `kgb_cw_overtime` | `1` | Enable overtime for tied regulation. |
| `kgb_cw_overtime_max_cycles` | `3` | Bound repeated overtime cycles; `0` explicitly means unlimited. |
| `kgb_cw_overtime_half_rounds` | `3` | Overtime rounds per half. |
| `kgb_cw_overtime_money` | `10000` | Overtime start money, clamped by the plugin. |
| `kgb_cw_overtime_vote` | `0` | Ask active players whether to play overtime or accept a draw. |
| `kgb_cw_overtime_vote_seconds` | `15` | Overtime vote duration, clamped to 5-30 seconds. |
| `kgb_cw_overtime_vote_default` | `1` | Tied/no-vote decision: `1` plays overtime, `0` accepts the draw. |
| `kgb_cw_team_a_name`, `kgb_cw_team_b_name` | `Team A`, `Team B` | Team display names. |
| `kgb_cw_team_a_tag`, `kgb_cw_team_b_tag` | empty | Optional clan tags. |
| `kgb_cw_map1`, `kgb_cw_map2` | empty | Installed map basenames. |
| `kgb_cw_map_count` | `1` | One- or two-map match. |
| `kgb_cw_warmup_config` | `kgb_gamemode` | Validated warmup config basename. |
| `kgb_cw_match_config` | `kgb_gamemode` | Validated live config basename. |
| `kgb_cw_overtime_config` | `kgb_gamemode` | Validated overtime config basename. |
| `kgb_cw_default_config` | `kgb_gamemode` | Config restored after the match. |
| `kgb_cw_halftime_delay` | `5` | Delay before the next half. |
| `kgb_cw_second_half_ready` | `0` | Pause before each regulation/overtime second half until the configured player/team/admin ready gate is satisfied again. |
| `kgb_cw_swap_policy` | `halves` | `halves` swaps sides automatically; `off` retains sides. Knife/admin swaps remain explicit. |
| `kgb_cw_knife_vote` | `1` | Let the knife winner vote to stay or swap. |
| `kgb_cw_knife_vote_seconds` | `15` | Knife decision timeout. |
| `kgb_cw_pug_mode` | `0` | Permit PUG randomization. |
| `kgb_cw_pug_style` | `random` | Default `random` or admin-managed `manual` team workflow. |
| `kgb_cw_pug_persist` | `1` | Preserve the PUG session across map two and return to warmup after a completed PUG series. |
| `kgb_cw_allow_menu_save` | `0` | Permit writing the allowlisted, non-secret saved snapshot. |
| `kgb_cw_set_hostname` | `0` | Opt in to temporary hostname changes. |
| `kgb_cw_hostname` | empty | Temporary match hostname. |
| `kgb_cw_set_password` | `0` | Opt in to temporary `sv_password`. |
| `kgb_cw_password` | empty | Temporary match password; protect this config. |
| `kgb_cw_disable_shield` | `0` | Opt in to changing shield availability. |
| `kgb_cw_client_demos` | `0` | Request client demo recording. |
| `kgb_cw_screenshots` | `0` | Request halftime/final screenshots. |
| `kgb_cw_scoreid_screenshots` | `0` | Allow the admin-only detailed score/SteamID MOTD plus one screenshot request. |
| `kgb_cw_screenshot_on_stop` | `0` | Apply enabled score/identity screenshot workflows to an administrator stop. |
| `kgb_cw_file_stats` | `1` | Write lifecycle rows and connected-player half deltas/current-scoreboard K-D. |
| `kgb_cw_hud_announcements` | `1` | Show match HUD announcements. |

Brand values are trimmed and limited to visible ASCII: 47 bytes for the display
name and 23 bytes for the chat prefix. Empty, overlong, or unsafe values
containing command/control metacharacters are rejected at render time and fall
back to the defaults above. A branding change therefore takes effect without
reloading the plugin, while malformed input cannot be passed to server
commands. For example, an independent league could set:

```cfg
kgb_cw_display_name "Example League Match"
kgb_cw_chat_prefix "[MATCH]"
```

These settings change presentation only: plugin metadata, authorship, command
names, CVAR names, artifact names, and the license remain unchanged.

`kgb_cw_state` and the three `*_version` CVARs are runtime status values, not
operator settings. The complete examples are in [`configs/`](configs/).
The default phase basename resolves to the shipped
[`configs/kgb_gamemode.cfg.example`](configs/kgb_gamemode.cfg.example), which
matches the KGB Panel Clan War competitive server-CVAR baseline.

## Optional integrations

HLTV first uses an already connected proxy. UDP RCON is a separate explicit
fallback and accepts only a numeric IPv4 destination. Leave
`kgb_cw_hltv_rcon_enabled 0` unless the proxy cannot connect to the game server
and the network path is restricted to that proxy.

SQL persistence uses threaded SQLX queries so match writes do not block the
game loop. It creates the fixed `kgb_cw_*` tables listed in
[`sql/schema.sql`](sql/schema.sql). Configure a least-privilege database account
in AMX Mod X `sql.cfg`, then set `kgb_cw_sql_enabled 1`. Player rows include
Steam authentication IDs, map number, current names, team, kills, deaths, and
headshots. The `(match_uid, map_number, auth_id)` key preserves map-one totals
when map two starts and records connected zero-event players on each map. If a
development server used an older v0.3.0 prerelease schema, drop and recreate
`kgb_cw_players` before qualification; no public stable release used that
schema.
Operators are responsible for an appropriate notice, lawful basis, access
control, retention period, and deletion process for that personal data.

The core and HLTV integration load
`addons/amxmodx/data/lang/kgb_clan_war.txt`. The repository ships fresh English
and German translations for customer-visible controls and match lifecycle
messages; operators can extend the AMX Mod X dictionary without recompiling.
Technical server audit/error logs remain in English. Preset and map catalogs are
operator-owned after first install. Catalog tokens are strictly validated,
presets can only be read below the managed preset directory, and every line is
prevalidated against the preset allowlist before any setting changes. Maps must
be installed before they appear in the menu. Saved snapshots are likewise
prevalidated, applied with rollback on runtime-validation failure, and written
through a validated temporary file plus an atomic rename. The save workflow
deliberately excludes `kgb_cw_password`, hostname changes, SQL settings, and
HLTV RCON credentials.

HLTV administrators can use `amx_cw_hltv_menu`, `amx_cw_hltv_status`,
`amx_cw_hltv_test`, and `amx_cw_hltv_delay <0-3600>`. A delay/test action is
sent only to a connected proxy or the explicitly enabled UDP RCON path. The
test queues a harmless `echo`; the operator must confirm its receipt in the
HLTV console/log. The configured delay is sent immediately before each record
request. RCON operations are serialized; `recording=1` is not reported until
the authenticated request is sent, while a failed stop remains active/unknown
instead of claiming success. Disabling the integration or automatic recording
also requests a stop for any active or pending recording. Menu changes affect
the running server only; edit `kgb_clan_war_hltv.cfg` to persist them.
On plugin unload, a connected proxy is stopped directly; the RCON fallback
performs one bounded 100 ms authenticated stop exchange and reports an
active/unknown state rather than claiming success if the proxy does not answer.
Credentials remain file-only and cannot be entered through the menu or a CVAR.

## Build and compatibility

Docker is required. The build uses a digest-pinned 32-bit Debian container,
downloads the selected pinned AMX Mod X compiler archive, verifies its SHA-256
before extraction, compiles with container networking disabled, and writes a
checksum beside every artifact. Builds and packages also reject binaries whose
first four bytes are not the AMXX `XXMA` magic used by the Panel artifact gate.

```sh
./scripts/build.sh
./scripts/check-source-capabilities.sh
./scripts/check-compatibility.sh
./scripts/test-install.sh
./scripts/package.sh v0.3.0
```

Compatibility checks compile all three plugins against AMX Mod X `1.8.2`,
`1.9`, and `1.10`. Published binaries are built with the oldest supported
compiler, `1.8.2`, so they remain loadable across that supported range; a
successful compile with a newer compiler does not establish backward binary
compatibility. Tagged `v*` pushes must match the version declared in every
source file. The GitHub workflow repeats the matrix, installation tests, and
checksum verification before creating a release.

## Release assets

- `kgb_clan_war.amxx` and `kgb_clan_war.amxx.sha256`
- `kgb_clan_war_hltv.amxx` and `kgb_clan_war_hltv.amxx.sha256`
- `kgb_clan_war_sql.amxx` and `kgb_clan_war_sql.amxx.sha256`
- `kgb-clan-war-v0.3.0.zip` and `kgb-clan-war-v0.3.0.zip.sha256`

The ZIP is the convenience distribution: binaries, checksums, safe config
examples, corresponding source, build/install scripts, license, and security
policy. Individual binaries remain available for plugin-manager ingestion.

## License and branding

Copyright (C) 2026 KGB Hosting.

KGB Clan War is free software licensed under the GNU General Public License
version 3 or, at your option, any later version. See [LICENSE](LICENSE).
The GPL covers the source and binaries and allows third-party operators to use
and redistribute them under its terms. It does not grant trademark rights in
the KGB Hosting name, logos, or other brand assets, or permission to imply that
a third-party service is operated, endorsed, or supported by KGB Hosting.

The default `KGB Clan War` and `[KGB CW]` strings identify the upstream plugin.
Independent operators can set `kgb_cw_display_name` and
`kgb_cw_chat_prefix` to their own truthful presentation without removing
copyright, authorship, or license notices.
