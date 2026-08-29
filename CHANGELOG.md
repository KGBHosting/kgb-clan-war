# Changelog

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
