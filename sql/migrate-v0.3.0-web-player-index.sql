-- KGB Clan War v0.3.0 optional web-statistics player-index migration.
-- Run this once before enabling the web browser against an existing database.
-- It is idempotent and fail-closed: only the exact supported v0.3.0 player
-- table is accepted. Prefix, invisible, ignored, and non-equality indexes do
-- not satisfy the browser contract.

DROP PROCEDURE IF EXISTS kgb_cw_add_web_player_index_v030;
DELIMITER //
CREATE PROCEDURE kgb_cw_add_web_player_index_v030()
BEGIN
    DECLARE column_signature TEXT DEFAULT '';
    DECLARE primary_signature TEXT DEFAULT '';
    DECLARE leading_auth_indexes INTEGER DEFAULT 0;
    DECLARE reserved_name_indexes INTEGER DEFAULT 0;
    DECLARE fallback_name_indexes INTEGER DEFAULT 0;
    DECLARE has_is_visible INTEGER DEFAULT 0;
    DECLARE has_ignored INTEGER DEFAULT 0;
    DECLARE index_query TEXT DEFAULT '';
    DECLARE v03_fresh_signature TEXT DEFAULT 'match_uid:varchar:64:NO:<NULL>:|map_number:int::NO:<NULL>:|auth_id:varchar:40:NO:<NULL>:|player_name:varchar:64:NO:<NULL>:|last_team:varchar:16:NO:<NULL>:|kills:int::NO:0:|deaths:int::NO:0:|headshots:int::NO:0:|updated_at:timestamp::NO:current_timestamp:';
    DECLARE v03_migrated_signature TEXT DEFAULT 'match_uid:varchar:64:NO:<NULL>:|map_number:int::NO:1:|auth_id:varchar:40:NO:<NULL>:|player_name:varchar:64:NO:<NULL>:|last_team:varchar:16:NO:<NULL>:|kills:int::NO:0:|deaths:int::NO:0:|headshots:int::NO:0:|updated_at:timestamp::NO:current_timestamp:';
    DECLARE v03_mysql_fresh_signature TEXT DEFAULT 'match_uid:varchar:64:NO:<NULL>:|map_number:int::NO:<NULL>:|auth_id:varchar:40:NO:<NULL>:|player_name:varchar:64:NO:<NULL>:|last_team:varchar:16:NO:<NULL>:|kills:int::NO:0:|deaths:int::NO:0:|headshots:int::NO:0:|updated_at:timestamp::NO:current_timestamp:DEFAULT_GENERATED';
    DECLARE v03_mysql_migrated_signature TEXT DEFAULT 'match_uid:varchar:64:NO:<NULL>:|map_number:int::NO:1:|auth_id:varchar:40:NO:<NULL>:|player_name:varchar:64:NO:<NULL>:|last_team:varchar:16:NO:<NULL>:|kills:int::NO:0:|deaths:int::NO:0:|headshots:int::NO:0:|updated_at:timestamp::NO:current_timestamp:DEFAULT_GENERATED';

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

    SELECT COUNT(*) INTO has_is_visible
      FROM INFORMATION_SCHEMA.COLUMNS
     WHERE LOWER(TABLE_SCHEMA) = 'information_schema' AND UPPER(TABLE_NAME) = 'STATISTICS'
       AND UPPER(COLUMN_NAME) = 'IS_VISIBLE';

    SELECT COUNT(*) INTO has_ignored
      FROM INFORMATION_SCHEMA.COLUMNS
     WHERE LOWER(TABLE_SCHEMA) = 'information_schema' AND UPPER(TABLE_NAME) = 'STATISTICS'
       AND UPPER(COLUMN_NAME) = 'IGNORED';

    SET index_query = CONCAT(
        'SELECT COUNT(*) INTO @kgb_cw_usable_auth_indexes FROM INFORMATION_SCHEMA.STATISTICS ',
        'WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=''kgb_cw_players'' ',
        'AND COLUMN_NAME=''auth_id'' AND SEQ_IN_INDEX=1 AND SUB_PART IS NULL ',
        'AND INDEX_TYPE IN (''BTREE'',''HASH'')',
        IF(has_is_visible > 0, ' AND UPPER(IS_VISIBLE)=''YES''', ''),
        IF(has_ignored > 0, ' AND UPPER(IGNORED)=''NO''', '')
    );
    SET @kgb_cw_usable_auth_indexes = 0;
    SET @kgb_cw_index_query = index_query;
    PREPARE kgb_cw_index_statement FROM @kgb_cw_index_query;
    EXECUTE kgb_cw_index_statement;
    DEALLOCATE PREPARE kgb_cw_index_statement;
    SET leading_auth_indexes = @kgb_cw_usable_auth_indexes;

    SELECT COUNT(*)
      INTO reserved_name_indexes
      FROM INFORMATION_SCHEMA.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'kgb_cw_players'
       AND INDEX_NAME = 'kgb_cw_players_auth_id';

    SELECT COUNT(*)
      INTO fallback_name_indexes
      FROM INFORMATION_SCHEMA.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'kgb_cw_players'
       AND INDEX_NAME = 'kgb_cw_players_auth_id_full';

    IF NOT ((column_signature = v03_fresh_signature OR column_signature = v03_migrated_signature
        OR column_signature = v03_mysql_fresh_signature OR column_signature = v03_mysql_migrated_signature)
        AND primary_signature = 'match_uid,map_number,auth_id') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unsupported kgb_cw_players schema; refusing web index migration';
    ELSEIF leading_auth_indexes > 0 THEN
        SET leading_auth_indexes = leading_auth_indexes;
    ELSEIF reserved_name_indexes = 0 THEN
        ALTER TABLE kgb_cw_players ADD INDEX kgb_cw_players_auth_id (auth_id);
    ELSEIF fallback_name_indexes = 0 THEN
        ALTER TABLE kgb_cw_players ADD INDEX kgb_cw_players_auth_id_full (auth_id);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Web player index names are occupied by incompatible definitions';
    END IF;
END//
DELIMITER ;

CALL kgb_cw_add_web_player_index_v030();
DROP PROCEDURE kgb_cw_add_web_player_index_v030;
