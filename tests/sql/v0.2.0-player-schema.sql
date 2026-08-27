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
