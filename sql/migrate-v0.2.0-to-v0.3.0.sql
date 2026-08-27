-- KGB Clan War v0.2.0 -> v0.3.0 MySQL/MariaDB player-table migration.
-- The plugin performs this migration automatically. This file is provided for
-- operators who require an explicitly reviewed maintenance-window migration.
-- Run it exactly once against the schema used by AMX Mod X sql.cfg.
-- Stop the game server first so the SQL plugin cannot race this DDL.

ALTER TABLE kgb_cw_players
    ADD COLUMN map_number INTEGER NOT NULL DEFAULT 1 AFTER match_uid;

ALTER TABLE kgb_cw_players
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (match_uid, map_number, auth_id);
