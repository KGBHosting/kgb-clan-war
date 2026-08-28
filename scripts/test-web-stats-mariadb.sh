#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARIADB_IMAGE="${MARIADB_IMAGE:-mariadb@sha256:8d9046cdb0b0961b3d2119bcb4bea62a185f11944be5968bc42b81d47801902e}"
CONTAINER_NAME="kgb-cw-web-test-${RANDOM}-$$"
# These credentials exist only inside the isolated test container.
ROOT_PASSWORD="kgb-cw-web-root-test-only"
READER_PASSWORD="kgb-cw-web-reader-test-only"

command -v docker >/dev/null 2>&1 || {
	printf 'Docker is required for the MariaDB web statistics integration test.\n' >&2
	exit 1
}
php -m | grep -Fx 'pdo_mysql' >/dev/null || {
	printf 'PHP pdo_mysql is required for the MariaDB web statistics integration test.\n' >&2
	exit 1
}

cleanup() {
	docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --detach --rm --name "$CONTAINER_NAME" \
	-p 127.0.0.1::3306 \
	-e MARIADB_ROOT_PASSWORD="$ROOT_PASSWORD" \
	-e MARIADB_DATABASE=kgb_cw \
	"$MARIADB_IMAGE" --skip-log-bin >/dev/null

ready=0
for _attempt in $(seq 1 30); do
	if docker exec -e MYSQL_PWD="$ROOT_PASSWORD" "$CONTAINER_NAME" \
		mariadb --batch --skip-column-names --user=root --execute='SELECT 1' >/dev/null 2>&1; then
		ready=1
		break
	fi
	sleep 1
done
if test "$ready" -ne 1; then
	printf 'The isolated MariaDB web test container did not become ready.\n' >&2
	exit 1
fi

mysql_exec() {
	docker exec -i -e MYSQL_PWD="$ROOT_PASSWORD" "$CONTAINER_NAME" \
		mariadb --batch --skip-column-names --user=root kgb_cw
}

mysql_exec < "$ROOT_DIR/sql/schema.sql"
mysql_exec <<'SQL'
ALTER TABLE kgb_cw_players DROP INDEX kgb_cw_players_auth_id;
SQL
mysql_exec < "$ROOT_DIR/sql/migrate-v0.3.0-web-player-index.sql"
mysql_exec < "$ROOT_DIR/sql/migrate-v0.3.0-web-player-index.sql"

INDEX_SIGNATURE="$(mysql_exec <<'SQL'
SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',')
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='kgb_cw_players'
  AND INDEX_NAME='kgb_cw_players_auth_id';
SQL
)"
if test "$INDEX_SIGNATURE" != 'auth_id'; then
	printf 'The web player-index migration did not produce the expected index.\n' >&2
	exit 1
fi

mysql_exec <<'SQL'
INSERT INTO kgb_cw_matches
    (match_uid,team_a_name,team_b_name,status,map_number,current_half,score_a,score_b,started_at,ended_at)
VALUES ('mariadb-match','Alpha','Beta','match_end',1,2,16,12,'2026-08-01 10:00:00','2026-08-01 11:00:00');
INSERT INTO kgb_cw_maps
    (match_uid,map_number,map_name,status,current_half,score_a,score_b,recorded_at)
VALUES ('mariadb-match',1,'de_dust2','match_end',2,16,12,'2026-08-01 11:00:00');
INSERT INTO kgb_cw_halves
    (match_uid,map_number,half,event_type,score_a,score_b,recorded_at)
VALUES ('mariadb-match',1,2,'half_end',16,12,'2026-08-01 11:00:00');
INSERT INTO kgb_cw_players
    (match_uid,map_number,auth_id,player_name,last_team,kills,deaths,headshots,updated_at)
VALUES ('mariadb-match',1,'STEAM_0:1:999','MariaDB Player','CT',9,4,3,'2026-08-01 11:00:00');
CREATE USER 'web_reader'@'%' IDENTIFIED BY 'kgb-cw-web-reader-test-only';
GRANT SELECT ON kgb_cw.* TO 'web_reader'@'%';
FLUSH PRIVILEGES;
SQL

PORT_BINDING="$(docker port "$CONTAINER_NAME" 3306/tcp | head -1)"
HOST_PORT="${PORT_BINDING##*:}"
case "$HOST_PORT" in
	'' | *[!0-9]*) printf 'Could not resolve the test MariaDB host port.\n' >&2; exit 1 ;;
esac

KGB_CW_TEST_DSN="mysql:host=127.0.0.1;port=$HOST_PORT;dbname=kgb_cw;charset=utf8mb4" \
KGB_CW_TEST_USERNAME=web_reader \
KGB_CW_TEST_PASSWORD="$READER_PASSWORD" \
	php "$ROOT_DIR/tests/web/mariadb.php"

mysql_exec <<'SQL'
ALTER TABLE kgb_cw_players ADD COLUMN unexpected_column INTEGER NULL;
SQL
if mysql_exec < "$ROOT_DIR/sql/migrate-v0.3.0-web-player-index.sql" >/dev/null 2>&1; then
	printf 'The web player-index migration accepted an unsupported schema.\n' >&2
	exit 1
fi

printf 'MariaDB idempotent and fail-closed web index migration checks passed.\n'
