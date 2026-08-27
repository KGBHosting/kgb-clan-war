#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARIADB_IMAGE="${MARIADB_IMAGE:-mariadb@sha256:8d9046cdb0b0961b3d2119bcb4bea62a185f11944be5968bc42b81d47801902e}"
CONTAINER_NAME="kgb-cw-sql-test-${RANDOM}-$$"
# This credential exists only inside the isolated, non-published test container.
TEST_PASSWORD="kgb-cw-local-test-only"

command -v docker >/dev/null 2>&1 || {
	printf 'Docker is required for the MariaDB migration regression.\n' >&2
	exit 1
}

cleanup() {
	docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --detach --rm --network none --name "$CONTAINER_NAME" \
	-e MARIADB_ROOT_PASSWORD="$TEST_PASSWORD" \
	-e MARIADB_DATABASE=kgb_cw \
	"$MARIADB_IMAGE" --skip-log-bin >/dev/null

ready=0
for _attempt in $(seq 1 30); do
	if docker exec -e MYSQL_PWD="$TEST_PASSWORD" "$CONTAINER_NAME" \
		mariadb --batch --skip-column-names --user=root --execute='SELECT 1' >/dev/null 2>&1; then
		ready=1
		break
	fi
	sleep 1
done
if test "$ready" -ne 1; then
	printf 'The isolated MariaDB test container did not become ready.\n' >&2
	exit 1
fi

mysql_exec() {
	docker exec -i -e MYSQL_PWD="$TEST_PASSWORD" "$CONTAINER_NAME" \
		mariadb --batch --skip-column-names --user=root kgb_cw
}

# Begin with the exact player table published in v0.2.0 and real map-one data.
mysql_exec < "$ROOT_DIR/tests/sql/v0.2.0-player-schema.sql"
mysql_exec <<'SQL'
INSERT INTO kgb_cw_players
    (match_uid,auth_id,player_name,last_team,kills,deaths,headshots)
VALUES
    ('series-1','STEAM_0:1:111','Player One','CT',5,1,0),
    ('series-1','STEAM_0:1:222','Player Two','T',0,0,0);
SQL

mysql_exec < "$ROOT_DIR/sql/migrate-v0.2.0-to-v0.3.0.sql"

primary_columns="$(mysql_exec <<'SQL'
SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',')
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA=DATABASE()
  AND TABLE_NAME='kgb_cw_players'
  AND INDEX_NAME='PRIMARY';
SQL
)"
test "$primary_columns" = 'match_uid,map_number,auth_id'
test "$(mysql_exec <<'SQL'
SELECT CONCAT(map_number,':',kills,':',deaths,':',headshots)
FROM kgb_cw_players
WHERE match_uid='series-1' AND auth_id='STEAM_0:1:111';
SQL
)" = '1:5:1:0'

# Exercise the same delta-upsert form used by the plugin: reconnect deltas add
# to map one, while map two is an independent row and zero-event players remain.
mysql_exec <<'SQL'
INSERT INTO kgb_cw_players
    (match_uid,map_number,auth_id,player_name,last_team,kills,deaths,headshots,updated_at)
VALUES
    ('series-1',1,'STEAM_0:1:111','Player One','T',3,2,1,CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    player_name=VALUES(player_name),
    last_team=VALUES(last_team),
    kills=kills+VALUES(kills),
    deaths=deaths+VALUES(deaths),
    headshots=headshots+VALUES(headshots),
    updated_at=CURRENT_TIMESTAMP;

INSERT INTO kgb_cw_players
    (match_uid,map_number,auth_id,player_name,last_team,kills,deaths,headshots,updated_at)
VALUES
    ('series-1',2,'STEAM_0:1:111','Player One','CT',4,0,2,CURRENT_TIMESTAMP),
    ('series-1',2,'STEAM_0:1:222','Player Two','T',0,0,0,CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    player_name=VALUES(player_name),
    last_team=VALUES(last_team),
    kills=kills+VALUES(kills),
    deaths=deaths+VALUES(deaths),
    headshots=headshots+VALUES(headshots),
    updated_at=CURRENT_TIMESTAMP;
SQL

test "$(mysql_exec <<'SQL'
SELECT CONCAT(map_number,':',kills,':',deaths,':',headshots)
FROM kgb_cw_players
WHERE match_uid='series-1' AND auth_id='STEAM_0:1:111'
ORDER BY map_number;
SQL
)" = $'1:8:3:1\n2:4:0:2'
test "$(mysql_exec <<'SQL'
SELECT COUNT(*)
FROM kgb_cw_players
WHERE match_uid='series-1' AND map_number=2
  AND auth_id='STEAM_0:1:222' AND kills=0 AND deaths=0 AND headshots=0;
SQL
)" = '1'

printf 'Exact v0.2.0 MariaDB migration and map/reconnect accumulation checks passed.\n'
