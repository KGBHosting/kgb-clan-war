-- KGB Clan War 2.x optional SQLX persistence schema.
-- The plugin creates these tables automatically when kgb_cw_sql_enabled is 1.
-- It uses the connection selected by AMX Mod X's standard sql.cfg.

CREATE TABLE IF NOT EXISTS kgb_cw_matches (
    match_uid VARCHAR(64) NOT NULL PRIMARY KEY,
    team_a_name VARCHAR(64) NOT NULL,
    team_b_name VARCHAR(64) NOT NULL,
    status VARCHAR(24) NOT NULL,
    map_number INTEGER NOT NULL DEFAULT 1,
    current_half INTEGER NOT NULL DEFAULT 1,
    score_a INTEGER NOT NULL DEFAULT 0,
    score_b INTEGER NOT NULL DEFAULT 0,
    started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS kgb_cw_maps (
    match_uid VARCHAR(64) NOT NULL,
    map_number INTEGER NOT NULL,
    map_name VARCHAR(64) NOT NULL,
    status VARCHAR(24) NOT NULL,
    current_half INTEGER NOT NULL DEFAULT 1,
    score_a INTEGER NOT NULL DEFAULT 0,
    score_b INTEGER NOT NULL DEFAULT 0,
    recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (match_uid, map_number)
);

CREATE TABLE IF NOT EXISTS kgb_cw_halves (
    match_uid VARCHAR(64) NOT NULL,
    map_number INTEGER NOT NULL,
    half INTEGER NOT NULL,
    event_type VARCHAR(24) NOT NULL,
    score_a INTEGER NOT NULL DEFAULT 0,
    score_b INTEGER NOT NULL DEFAULT 0,
    recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (match_uid, map_number, half, event_type)
);

CREATE TABLE IF NOT EXISTS kgb_cw_players (
    match_uid VARCHAR(64) NOT NULL,
    auth_id VARCHAR(40) NOT NULL,
    player_name VARCHAR(64) NOT NULL,
    last_team VARCHAR(16) NOT NULL,
    kills INTEGER NOT NULL DEFAULT 0,
    deaths INTEGER NOT NULL DEFAULT 0,
    headshots INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (match_uid, auth_id)
);
