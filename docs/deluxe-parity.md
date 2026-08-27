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
| Saved menu setup | Opt-in snapshot containing an explicit non-secret CVAR allowlist; password, hostname, SQL, and RCON values are excluded. |
| Multilingual UI | AMX Mod X dictionary with English and German control/config/overtime-vote strings; operators can extend it. |
| Overtime play-out choice | Optional active-player play-overtime/accept-draw vote with bounded duration and an explicit tie/no-vote default. |
| Legacy score/identity view | Public branded score plus an `ADMIN_CFG`-only console report with SteamID, side, kills, and deaths. |
| HLTV configuration and delay | Admin menu/commands for enable, auto-record, status, harmless path test, and bounded proxy delay. Credentials remain file-only. |
| Broader PUG operation | Explicit PUG start/stop, random teams, or admin-managed manual team assignments during warmup. |

## Deliberate non-equivalence

- The old binary's internal state machine and exact edge-case behavior cannot be
  proven from an opaque artifact, so binary or bug-for-bug equivalence is not a
  release claim.
- Named CAL/ESL/EuroCup/JUL rulesets are not shipped. League rules change and
  their historical files have unclear provenance. Operators can add reviewed,
  current presets without recompiling the plugin.
- The legacy message file is not reused. v0.3.0 localizes the new menu and vote
  workflows; older lifecycle prose remains English until independently
  translated.
- HLTV passwords cannot be entered or displayed through an in-game menu/CVAR.
  The dedicated key file is a deliberate credential-boundary improvement.
- Manual PUG assignment is admin-driven. It does not attempt to reproduce an
  unknown legacy captain-selection algorithm.

Compiler compatibility and installer tests are necessary but not sufficient
runtime proof. Qualification still requires the target HLDS/ReHLDS, MetaMod,
AMX Mod X modules, maps, connected players, and the actual HLTV topology. A
client-visible release claim additionally requires a real supported game client.
