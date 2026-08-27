-- KGB Clan War v0.2.0 -> v0.3.0 MySQL/MariaDB player-table migration.
-- This is idempotent and fail-closed. It accepts only the exact public v0.2.0
-- table, exact final v0.3.0 table, or the known interrupted state where the
-- new column exists but the old primary key remains. Stop the server first.

DROP PROCEDURE IF EXISTS kgb_cw_migrate_players_v030;
DELIMITER //
CREATE PROCEDURE kgb_cw_migrate_players_v030()
BEGIN
    DECLARE column_signature TEXT DEFAULT '';
    DECLARE primary_signature TEXT DEFAULT '';
    DECLARE v02_signature TEXT DEFAULT 'match_uid:varchar:64:NO:<NULL>:|auth_id:varchar:40:NO:<NULL>:|player_name:varchar:64:NO:<NULL>:|last_team:varchar:16:NO:<NULL>:|kills:int::NO:0:|deaths:int::NO:0:|headshots:int::NO:0:|updated_at:timestamp::NO:current_timestamp:';
    DECLARE v03_fresh_signature TEXT DEFAULT 'match_uid:varchar:64:NO:<NULL>:|map_number:int::NO:<NULL>:|auth_id:varchar:40:NO:<NULL>:|player_name:varchar:64:NO:<NULL>:|last_team:varchar:16:NO:<NULL>:|kills:int::NO:0:|deaths:int::NO:0:|headshots:int::NO:0:|updated_at:timestamp::NO:current_timestamp:';
    DECLARE v03_migrated_signature TEXT DEFAULT 'match_uid:varchar:64:NO:<NULL>:|map_number:int::NO:1:|auth_id:varchar:40:NO:<NULL>:|player_name:varchar:64:NO:<NULL>:|last_team:varchar:16:NO:<NULL>:|kills:int::NO:0:|deaths:int::NO:0:|headshots:int::NO:0:|updated_at:timestamp::NO:current_timestamp:';

    SELECT COALESCE(GROUP_CONCAT(CONCAT(
        COLUMN_NAME, ':', DATA_TYPE, ':', COALESCE(CHARACTER_MAXIMUM_LENGTH, ''), ':',
        IS_NULLABLE, ':', IF(COLUMN_DEFAULT IS NULL, '<NULL>', REPLACE(LOWER(COLUMN_DEFAULT), '()', '')), ':', EXTRA
    ) ORDER BY ORDINAL_POSITION SEPARATOR '|'), '')
      INTO column_signature
      FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'kgb_cw_players';

    SELECT COALESCE(GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ','), '')
      INTO primary_signature
      FROM INFORMATION_SCHEMA.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'kgb_cw_players' AND INDEX_NAME = 'PRIMARY';

    IF column_signature = v02_signature AND primary_signature = 'match_uid,auth_id' THEN
        ALTER TABLE kgb_cw_players ADD COLUMN map_number INTEGER NOT NULL DEFAULT 1 AFTER match_uid;
        ALTER TABLE kgb_cw_players DROP PRIMARY KEY, ADD PRIMARY KEY (match_uid, map_number, auth_id);
    ELSEIF column_signature = v03_migrated_signature AND primary_signature = 'match_uid,auth_id' THEN
        ALTER TABLE kgb_cw_players DROP PRIMARY KEY, ADD PRIMARY KEY (match_uid, map_number, auth_id);
    ELSEIF (column_signature = v03_migrated_signature OR column_signature = v03_fresh_signature)
        AND primary_signature = 'match_uid,map_number,auth_id' THEN
        SET primary_signature = primary_signature;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unsupported kgb_cw_players schema; refusing migration';
    END IF;
END//
DELIMITER ;

CALL kgb_cw_migrate_players_v030();
DROP PROCEDURE kgb_cw_migrate_players_v030;
