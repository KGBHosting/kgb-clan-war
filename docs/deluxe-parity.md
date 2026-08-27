# Deluxe workflow parity

This project is an independent GPL implementation. The legacy customer archive
was used only as black-box evidence of operator-visible filenames, configuration
knobs, menu/message labels, and workflows. Its `amx_match_deluxe.amxx` binary was
not decompiled, linked, copied, or redistributed. Its language and league files
were not copied.

## v0.3.0 clean-room coverage

| Observed workflow | KGB Clan War implementation |
| --- | --- |
| League/config selection | Strict catalog plus managed preset directory; fresh generic MR15, MR12, and PUG examples. |
| Default map selection | Operator-owned map catalog; menu selects one or two maps and hides maps not installed on the server. |
| Saved menu setup | Opt-in snapshot containing an explicit non-secret CVAR allowlist plus an interactive settings wizard; password, hostname, SQL, and RCON values are excluded. |
| Multilingual UI | Fresh AMX Mod X dictionary with English and German customer-visible controls, match lifecycle, votes, HUD, score/identity, and HLTV UI; operators can extend it. |
| Overtime play-out choice | Optional active-player play-overtime/accept-draw vote with bounded duration and an explicit tie/no-vote default. |
| Ready/side policy | Optional second-half re-ready gate and `halves`/`off` automatic swap policy; administrator and knife-vote swaps remain available. |
| Knife enforcement | The knife phase continuously removes non-knife weapons and blocks weapon-box/armoury pickup until the phase ends. |
| Legacy launch aliases | One-shot `amx_match` setup and legacy ready/chat aliases route through the validated KGB state machine. |
| Recurring HUD | Configurable recurring ready count or current-map score display. |
| Legacy score/identity view | Public current-map score, a separately labelled series aggregate, and `ADMIN_CFG`-only SteamID/current-scoreboard reports. An additional opt-in MOTD/screenshot request makes the evidence flow explicit. |
| File statistics | Lifecycle rows plus connected-player per-half deltas and current-scoreboard K-D; fields explicitly avoid implying cumulative identity statistics. |
| HLTV configuration and delay | Admin menu/commands for enable, auto-record, status, harmless path test, and bounded proxy delay actually sent before `record`. RCON operations are serialized and pending/failure state is conservative. Credentials remain file-only. |
| Broader PUG operation | Atomic validated start, spectator-safe randomization, admin-managed manual assignments, cross-map session state, and mapcycle rotation after a completed two-map PUG. |

## Deliberate non-equivalence

- The old binary's internal state machine and exact edge-case behavior cannot be
  proven from an opaque artifact, so binary or bug-for-bug equivalence is not a
  release claim.
- Named CAL/ESL/EuroCup/JUL rulesets are not shipped. League rules change and
  their historical files have unclear provenance. Operators can add reviewed,
  current presets without recompiling the plugin.
- The legacy message file is not reused. v0.3.0 supplies independently written
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
