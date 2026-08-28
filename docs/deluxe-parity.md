# Deluxe workflow parity

This project is an independent GPL implementation. The legacy customer archive
was used only as black-box evidence of operator-visible filenames, configuration
knobs, menu/message labels, and workflows. Its `amx_match_deluxe.amxx` binary was
not decompiled, linked, copied, or redistributed. Its language and league files
were not copied. The public behavior reference is the
[AMX Match Deluxe thread](https://forums.alliedmods.net/showthread.php?t=5231).

## v0.4.0 clean-room coverage

| Observed workflow | KGB Clan War implementation |
| --- | --- |
| League/config selection | Strict catalog plus managed preset directory; fresh generic MR15, MR12, and PUG examples. |
| Default map selection | Operator-owned map catalog; menu selects one or two maps and hides maps not installed on the server. |
| Saved menu setup | Opt-in snapshot containing an explicit non-secret CVAR allowlist plus an interactive settings wizard. Match format, format-specific length, ready mode, and minimum-ready count are available without console CVAR editing. Presets/snapshots are fully prevalidated before mutation; snapshots use a validated temporary file and POSIX atomic replacement from the documented AMX Mod X mod-directory base. Password, hostname, SQL, and RCON values are excluded. Existing Windows snapshots fail closed because portable C-runtime replacement is not guaranteed. |
| Multilingual UI | Fresh AMX Mod X dictionary with English and German customer-visible controls, match lifecycle, votes, HUD, score/identity, and HLTV UI; operators can extend it. |
| Overtime and regulation play-out choices | Optional active-player play-overtime/accept-draw vote plus clinch/always/player-vote regulation playout, both with explicit tie/no-vote defaults. |
| Time-limit halves | Each half timer starts after LO3, is reset by an administrator half restart, and by default lets the active round finish before the half transition. |
| Ready/side policy | Optional second-half re-ready gate and `halves`/`off` automatic swap policy; administrator and knife-vote swaps remain available. Connected players can open a localized, read-only ready-list menu; mutating match controls remain `ADMIN_CFG`-gated. |
| Knife enforcement | The knife phase continuously removes non-knife weapons and blocks weapon-box/armoury pickup until the phase ends. |
| Legacy launch aliases | The documented `amx_match`, `amx_match2`, `amx_match3`, and `amx_match4` one/two-map forms plus lifecycle/team aliases route through the validated KGB state machine. MR, TL, and the later documented WL rule are supported. Legacy `amx_matchrelo3` and `/relo3` restore the current-half score baseline before LO3, while KGB-specific `amx_cw_relo3` preserves the score. Legacy whole-match restart refuses from the off state. |
| State-aware match menu | The core registers its validated branded control menu in the standard AMX Mod X `amxmodmenu`. It exposes only actions valid for the current state, includes half/match restart, and confirms complete-match reset and stop actions. While a cross-map or persistent-PUG change is pending, only read-only status/ready-list actions remain available; stale menu selections and direct mutating commands fail closed so `plugin_end` preserves the transition owner. |
| Recurring HUD | Configurable recurring ready count or current-map score display. |
| Legacy score/identity view | Public current-map score, a separately labelled series aggregate, and `ADMIN_CFG`-only SteamID/current-scoreboard reports. Enabled identity evidence is requested automatically at half/map/match boundaries and optionally on administrator stop. |
| File statistics | Lifecycle rows plus connected-player per-half deltas and current-scoreboard K-D; fields explicitly avoid implying cumulative identity statistics. |
| HLTV configuration and delay | Admin menu/commands for enable, auto-record, status, harmless path test, and bounded proxy delay actually sent before `record`. RCON operations are serialized and pending/failure state is conservative. Credentials remain file-only. |
| Broader PUG operation | Atomic validated start, spectator-safe randomization, admin-managed manual assignments, cross-map session state, and persistent advancement through validated installed entries in the server `mapcyclefile` before PUG warmup resumes. |
| Immutable two-map series | A versioned manifest freezes the full match policy, topology, phase configs, client-demo policy, and HLTV recording mode at live start. Map two restores only after every field and active marker validate; terminal/failure paths invalidate the marker first and restore independent environment/recording baselines. An identity-bound recovery journal blocks new/config/resume/admin lifecycle flows, survives stop/finish/clear paths, and can be cleared only by a successful safe recovery after an optional missing HLTV CVAR becomes available. |
| SQL map/reconnect totals | The public v0.2.0 MySQL/MariaDB player table is upgraded to a map-scoped primary key. Delta upserts preserve map one, zero-event map-two players, and accumulated same-SteamID reconnect sessions without `REPLACE` data loss. |

## Deliberate non-equivalence

- The old binary's internal state machine and exact edge-case behavior cannot be
  proven from an opaque artifact, so binary or bug-for-bug equivalence is not a
  release claim.
- Named CAL/ESL/EuroCup/JUL rulesets are not shipped. League rules change and
  their historical files have unclear provenance. Operators can add reviewed,
  current presets without recompiling the plugin.
- The legacy message file is not reused. v0.4.0 supplies independently written
  English and German customer-visible text. Technical server audit/error logs
  remain English so operators have one searchable diagnostic vocabulary.
- HLTV passwords cannot be entered or displayed through an in-game menu/CVAR.
  The dedicated key file is a deliberate credential-boundary improvement.
- Manual PUG assignment is admin-driven. It does not attempt to reproduce an
  unknown legacy captain-selection algorithm.
- Screenshot and client-demo actions are requests. GoldSrc clients may reject
  or restrict them, so the plugin cannot prove that a client wrote a file.
- Per-half file-stat rows cover players connected at the half boundary. Fully
  reconstructing a player who disconnects mid-half requires durable event or
  SQL capture and is not claimed by the local text log.
- The opaque legacy binary may contain internal workflows that cannot be
  discovered or faithfully reproduced from the operator-visible archive.

Compiler compatibility and installer tests are necessary but not sufficient
runtime proof. Qualification still requires the target HLDS/ReHLDS, MetaMod,
AMX Mod X modules, maps, connected players, and the actual HLTV topology. A
client-visible release claim additionally requires a real supported game client.
