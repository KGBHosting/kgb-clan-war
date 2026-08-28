# Optional web statistics browser

KGB Clan War includes a standalone, read-only PHP browser for the optional
SQLX statistics. It provides match and half details, map history and
leaderboards, player totals and match history, and team outcome history. It is
inspired by the useful browsing scope of the historical AMX Match Deluxe web
template, but it is a new implementation for the fixed KGB Clan War v0.3 SQL
contract.

The browser is not installed into the game server and is not a Panel plugin.
Deploy it as a separate PHP service with network access to the statistics
database. Enabling `kgb_cw_sql_enabled` and deploying this browser are separate
operator decisions.

## Supported read contract

The browser probes all required columns before serving a request and supports
the four tables in [`sql/schema.sql`](../sql/schema.sql):

| Table | Browser interpretation |
| --- | --- |
| `kgb_cw_matches` | One series. `score_a` and `score_b` are the cumulative series score at the latest lifecycle snapshot. Only `status = 'match_end'` contributes to win/loss/draw totals; `match_stop` is reported separately. |
| `kgb_cw_maps` | One last-known snapshot per match and map number. Scores are cumulative series scores at the last event recorded on that map, not isolated map scores. |
| `kgb_cw_halves` | Last-known lifecycle snapshot for each `(match_uid, map_number, half, event_type)`. This is not an append-only round/event log. |
| `kgb_cw_players` | Map-scoped absolute totals per Steam authentication ID. Names and `last_team` are the latest observed name and CS side for that row. |

The SQL integration writes asynchronously and does not declare foreign keys.
The browser therefore tolerates a match appearing briefly before its related
map or player rows. Missing tables or columns fail closed with a generic 503.

The current schema cannot reliably map a player to Team A or Team B across side
swaps: `last_team` records only the player's last `T`/`CT` side. The team view
intentionally reports series outcomes and history but does not invent named
team rosters. No SQL plugin or schema change is required for the supported
views.

## Deployment boundary

Requirements:

- PHP 8.3 or newer with `pdo_mysql`;
- MySQL or MariaDB using the v0.3 schema;
- HTTPS before using the built-in Basic authentication mode;
- a dedicated database principal with `SELECT` on only the four
  `kgb_cw_*` statistics tables;
- a configuration file outside the HTTP document root, readable only by the
  PHP service account;
- a retention and access policy covering player names and Steam
  authentication IDs.

Do not serve the repository root or `web/` as the document root. The document
root must be exactly `web/public`; `web/src`, `web/templates`, the example
configuration, source, SQL, and repository metadata must remain outside it.

Example database grants, adjusted for the actual database and web-service host:

```sql
CREATE USER 'kgb_cw_web_reader'@'web-service-host'
    IDENTIFIED BY 'unique-high-entropy-password';
GRANT SELECT ON kgb_cw.kgb_cw_matches TO 'kgb_cw_web_reader'@'web-service-host';
GRANT SELECT ON kgb_cw.kgb_cw_maps TO 'kgb_cw_web_reader'@'web-service-host';
GRANT SELECT ON kgb_cw.kgb_cw_halves TO 'kgb_cw_web_reader'@'web-service-host';
GRANT SELECT ON kgb_cw.kgb_cw_players TO 'kgb_cw_web_reader'@'web-service-host';
```

Copy [`web/config.example.php`](../web/config.example.php) to a path such as
`/etc/kgb-clan-war/web-stats.php`, replace every placeholder, and set restrictive
ownership and permissions. Point the PHP-FPM environment variable
`KGB_CW_STATS_CONFIG` to that absolute path. Never commit or package the live
copy.

The example defaults to `access.mode = basic`; its placeholder password hash is
invalid, so the application remains unavailable until the operator supplies a
real `password_hash()` result. `access.mode = public` is an explicit choice and
should be used only for intentionally public statistics or when a trusted
reverse proxy already enforces access. In either case, keep HTTPS, database
least privilege, and the privacy/retention boundary.

`privacy.player_link_secret` creates keyed, opaque player identifiers for URLs.
Keep it stable and secret. Rotating it invalidates old player links. Raw Steam
authentication IDs are omitted from rendered pages by default; setting
`show_auth_ids = true` exposes them to every authorized viewer and should be
covered by the privacy notice.

The front controller accepts only GET and HEAD, uses an allowlisted route set,
caps page size at 100 and page number at 1,000, executes only prepared SELECT
statements, escapes all database output, and sends a restrictive content
security policy. There are no create, update, or delete endpoints. Database
retention/deletion remains an operator process outside this browser.

## Nginx/PHP-FPM outline

The exact socket and paths depend on the host. The important boundary is the
document root and the single PHP entry point:

```nginx
server {
    listen 443 ssl;
    server_name stats.example.test;
    root /opt/kgb-clan-war/web/public;
    index index.php;

    location / {
        try_files $uri /index.php?$query_string;
    }

    location = /index.php {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root/index.php;
        fastcgi_param KGB_CW_STATS_CONFIG /etc/kgb-clan-war/web-stats.php;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }

    location ~ \.php$ { return 404; }
}
```

The application uses query-string routes, so URL rewriting is optional. Ensure
the web server does not expose dotfiles, backups, configuration files, or
directory listings.

## Reproducible checks

```sh
./scripts/test-web-stats.sh
./scripts/test-web-stats-mariadb.sh
```

The first command lints all browser/test PHP, performs a read-only SQL static
check, and runs a SQLite in-memory test double covering routing, pagination,
aggregates, escaping, opaque player links, and access control. The second uses
the same digest-pinned MariaDB image as the SQL migration gate, exercises native
PDO prepares and MariaDB's SHA-256 player lookup, verifies schema probes, and
proves the test reader cannot delete data.

For a deployed smoke test, first request the HTTPS URL without credentials and
confirm a 401. Then use an interactive credential prompt and confirm each of the
Matches, Maps, Players, and Teams views returns 200 without disclosing a PHP or
database error. A local/container pass does not prove production database
connectivity, reverse-proxy authentication, TLS, or live statistics content.
