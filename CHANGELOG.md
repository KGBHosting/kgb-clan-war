# Changelog

## 1.0.0 - initial stable release

- Promoted the development-qualified `0.5.0` code to the first stable release
  without changing match behavior or enabling an integration by default.
- Includes the independently implemented Clan War match controller and the
  optional, disabled-by-default HLTV and SQL integrations, plus the read-only
  web statistics browser.
- Includes the configurable `kgb_cw_display_name` and `kgb_cw_chat_prefix`
  branding controls for KGB Hosting customers and independent operators.
- Retains the admin-only, non-mutating `amx_cw_safety_status` command. Its
  stable output reports the plugin version, match state, series-policy freeze
  state, and configured/effective local file-stat values without exposing
  credentials or player identities.
- Preserves `kgb_cw_file_stats 0` and every other safe default.

## 0.5.0 - qualification candidate

- Added the admin-only, non-mutating `amx_cw_safety_status` command. Its stable
  output reports the plugin version, match state, series-policy freeze state,
  and configured/effective local file-stat values without exposing credentials
  or player identities.
- Preserved `kgb_cw_file_stats 0` and every other safe default. This candidate
  does not change match behavior or enable an integration.

`v0.5.0` remains a qualification candidate until its exact workflow-built
artifacts pass development-server testing. A tag or GitHub release is not
production approval.
