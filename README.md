# KGB Clan War

KGB Clan War is a GPL-licensed AMX Mod X match controller for Counter-Strike
1.6. It is an independently implemented, reviewable alternative to shipping
opaque legacy match-plugin binaries.

The core plugin owns the match state. HLTV recording and SQL statistics are
separate, optional plugins so a normal Clan War server needs neither network
credentials nor a database.

## Release policy

There is no stable release yet. Tags below `v1.0.0` are qualification builds
for CI and development-server testing. GitHub marks every `v0.x.x` release as
a prerelease. The first customer-stable release will be `v1.0.0`, after the
core workflow has passed real ReHLDS and Valve Steam client qualification.

The current qualification line includes the practical AMX Match Deluxe feature
set: player/team/admin ready modes; max-round, win-limit, and time-limit
formats; playout; knife stay/swap voting; team names and tags; one- or two-map
matches; phase configs; match/half restart; PUG team randomization; optional
hostname/password and client demo/screenshot actions; file statistics; optional
HLTV recording; and optional SQLX persistence.

“Deluxe feature set” describes supported operator workflows, not shared code or
binary compatibility. KGB Clan War does not contain AMX Match Deluxe source,
release binaries, language files, or league presets.

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
  commands, screenshots, and PUG randomization are disabled by default.
- The release never contains an RCON password or database credential. HLTV
  RCON reads its password from an operator-created
  `addons/amxmodx/configs/kgb_clan_war_hltv_rcon.key`. SQLX reads the normal
  AMX Mod X `addons/amxmodx/configs/sql.cfg`.
- Client demo and screenshot commands are requests to connected clients. A
  client can reject or restrict them; the plugin cannot guarantee a recording.
- A series is intentionally limited to one or two installed maps. Map and
  phase-config basenames are validated before they reach server commands.
- This repository proves source review and compiler compatibility. A compiled
  plugin still needs runtime qualification on the target ReHLDS/HLDS build,
  MetaMod, AMX Mod X modules, maps, SQL driver, and HLTV topology.

See [SECURITY.md](SECURITY.md) before enabling an external integration.

## Install

KGB Hosting customers should install the published gamemode through the Panel.
The Panel plugin manager selects exact plugin versions, downloads private
artifacts, verifies their checksum, and owns rollback. Do not also copy GitHub
release binaries into a Panel-managed server.

For a standalone server, download the required `.amxx` files and matching
`.sha256` files from the same tagged release, verify each checksum, then copy
the plugins into `cstrike/addons/amxmodx/plugins/`. Add the core and any chosen
optional integrations to `cstrike/addons/amxmodx/configs/plugins.ini`.

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
| `amx_cw_teams <team-a> <team-b>` | Set team display names. Quote names containing spaces. |
| `amx_cw_tags <tag-a> <tag-b>` | Set clan tags. |
| `amx_cw_maps <map1> [map2]` | Select one or two installed maps. |
| `amx_cw_stop` | Stop the match and restore the captured server environment. |
| `amx_cw_score` | Show the public match score. |
| `amx_cw_status` | Show detailed match status. |

Player chat shortcuts are `/ready`, `/notready`, `/teamready`,
`/teamnotready`, `/score`, and `/cw`; `!` prefixes also work.

## Core configuration

The installer creates
`addons/amxmodx/configs/kgb_clan_war.cfg` from the safe example when missing.

| CVAR | Default | Meaning |
| --- | --- | --- |
| `kgb_cw_enabled` | `1` | Enable core controls. |
| `kgb_cw_min_ready` | `10` | Required ready players. |
| `kgb_cw_ready_mode` | `player` | `player`, `team`, or `admin`. |
| `kgb_cw_auto_live` | `0` | Automatically start after readiness. |
| `kgb_cw_format` | `mr` | `mr`, `wl`, or `tl`. |
| `kgb_cw_half_rounds` | `15` | Regulation rounds per half for max-round mode. |
| `kgb_cw_win_rounds` | `16` | Win target for win-limit mode. |
| `kgb_cw_time_limit_minutes` | `20` | Minutes per half for time-limit mode. |
| `kgb_cw_playout` | `0` | Play all scheduled regulation rounds after a winner is known. |
| `kgb_cw_overtime` | `1` | Enable overtime for tied regulation. |
| `kgb_cw_overtime_max_cycles` | `3` | Bound repeated overtime cycles; `0` explicitly means unlimited. |
| `kgb_cw_overtime_half_rounds` | `3` | Overtime rounds per half. |
| `kgb_cw_overtime_money` | `10000` | Overtime start money, clamped by the plugin. |
| `kgb_cw_team_a_name`, `kgb_cw_team_b_name` | `Team A`, `Team B` | Team display names. |
| `kgb_cw_team_a_tag`, `kgb_cw_team_b_tag` | empty | Optional clan tags. |
| `kgb_cw_map1`, `kgb_cw_map2` | empty | Installed map basenames. |
| `kgb_cw_map_count` | `1` | One- or two-map match. |
| `kgb_cw_warmup_config` | `kgb_gamemode` | Validated warmup config basename. |
| `kgb_cw_match_config` | `kgb_gamemode` | Validated live config basename. |
| `kgb_cw_overtime_config` | `kgb_gamemode` | Validated overtime config basename. |
| `kgb_cw_default_config` | `kgb_gamemode` | Config restored after the match. |
| `kgb_cw_halftime_delay` | `5` | Delay before the next half. |
| `kgb_cw_knife_vote` | `1` | Let the knife winner vote to stay or swap. |
| `kgb_cw_knife_vote_seconds` | `15` | Knife decision timeout. |
| `kgb_cw_pug_mode` | `0` | Permit PUG randomization. |
| `kgb_cw_set_hostname` | `0` | Opt in to temporary hostname changes. |
| `kgb_cw_hostname` | empty | Temporary match hostname. |
| `kgb_cw_set_password` | `0` | Opt in to temporary `sv_password`. |
| `kgb_cw_password` | empty | Temporary match password; protect this config. |
| `kgb_cw_disable_shield` | `0` | Opt in to changing shield availability. |
| `kgb_cw_client_demos` | `0` | Request client demo recording. |
| `kgb_cw_screenshots` | `0` | Request halftime/final screenshots. |
| `kgb_cw_file_stats` | `1` | Write local lifecycle statistics. |
| `kgb_cw_hud_announcements` | `1` | Show match HUD announcements. |

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
Steam authentication IDs, current names, team, kills, deaths, and headshots.
Operators are responsible for an appropriate notice, lawful basis, access
control, retention period, and deletion process for that personal data.

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
./scripts/package.sh v0.1.0
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
- `kgb-clan-war-v0.1.0.zip` and `kgb-clan-war-v0.1.0.zip.sha256`

The ZIP is the convenience distribution: binaries, checksums, safe config
examples, corresponding source, build/install scripts, license, and security
policy. Individual binaries remain available for plugin-manager ingestion.

## License

Copyright (C) 2026 KGB Hosting.

KGB Clan War is free software licensed under the GNU General Public License
version 3 or, at your option, any later version. See [LICENSE](LICENSE).
