# Security Policy

## Supported versions

Security fixes are made for the latest tagged major release. Operators should
upgrade to the most recent release and verify the published SHA-256 checksum
before installation.

## Reporting a vulnerability

Please use GitHub's private vulnerability-reporting feature for this
repository. Do not disclose exploitable details in a public issue. Include the
affected version, AMX Mod X version, reproduction steps, and impact. KGB
Hosting will acknowledge a complete report, investigate it, and coordinate a
fix and disclosure when the report is confirmed.

## Operational security

- The core plugin works without database or RCON credentials.
- SQL persistence and UDP RCON are optional and disabled in shipped examples.
- The installer never creates `kgb_clan_war_hltv_rcon.key`, never writes to
  AMX Mod X `sql.cfg`, and never overwrites an existing plugin config.
- If UDP RCON is enabled, restrict it to the HLTV host at the network layer,
  use a unique high-entropy secret, set the key file to the game-server user
  only, and rotate it if exposed.
- Give the SQL account access only to the dedicated match-statistics schema.
  Never reuse a panel, game-server, or administrative database account.
- SQL player statistics contain Steam authentication IDs and player names.
  Restrict access and define a privacy notice, retention period, and deletion
  process appropriate to the server's users and jurisdiction.
- Client-side demo and screenshot requests and server hostname/password
  changes are opt-in because they affect players or server access.
- Release builds use a digest-pinned build container, checksum-verified AMX Mod
  X compiler archives, and checksum-verified release assets.

Do not commit credentials, key files, live `sql.cfg` files, server passwords,
player auth data, or match data to this repository.
