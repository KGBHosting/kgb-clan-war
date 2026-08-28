<?php

declare(strict_types=1);

namespace Kgb\ClanWar\Web;

use PDO;
use PDOStatement;

final class StatsRepository
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly string $playerLinkSecret,
    ) {
    }

    public function assertCompatibleSchema(): void
    {
        $probes = [
            'SELECT match_uid,team_a_name,team_b_name,status,map_number,current_half,score_a,score_b,started_at,ended_at FROM kgb_cw_matches WHERE 1=0',
            'SELECT match_uid,map_number,map_name,status,current_half,score_a,score_b,recorded_at FROM kgb_cw_maps WHERE 1=0',
            'SELECT match_uid,map_number,half,event_type,score_a,score_b,recorded_at FROM kgb_cw_halves WHERE 1=0',
            'SELECT match_uid,map_number,auth_id,player_name,last_team,kills,deaths,headshots,updated_at FROM kgb_cw_players WHERE 1=0',
        ];

        foreach ($probes as $probe) {
            $this->prepared($probe);
        }
    }

    /** @return array{items:list<array<string,mixed>>,total:int} */
    public function matches(int $page, int $perPage): array
    {
        $sql = <<<'SQL'
SELECT m.match_uid,m.team_a_name,m.team_b_name,m.status,m.map_number,m.current_half,
       m.score_a,m.score_b,m.started_at,m.ended_at,
       COUNT(DISTINCT mp.map_number) AS map_count,
       COUNT(DISTINCT p.auth_id) AS player_count
FROM kgb_cw_matches m
LEFT JOIN kgb_cw_maps mp ON mp.match_uid=m.match_uid
LEFT JOIN kgb_cw_players p ON p.match_uid=m.match_uid
GROUP BY m.match_uid,m.team_a_name,m.team_b_name,m.status,m.map_number,m.current_half,
         m.score_a,m.score_b,m.started_at,m.ended_at
ORDER BY m.started_at DESC,m.match_uid DESC
SQL;

        return $this->page($sql, [], 'SELECT COUNT(*) FROM kgb_cw_matches', [], $page, $perPage);
    }

    /** @return array<string,mixed>|null */
    public function match(string $matchUid): ?array
    {
        return $this->one(
            'SELECT match_uid,team_a_name,team_b_name,status,map_number,current_half,score_a,score_b,started_at,ended_at FROM kgb_cw_matches WHERE match_uid=:match_uid',
            ['match_uid' => $matchUid]
        );
    }

    /** @return list<array<string,mixed>> */
    public function matchMaps(string $matchUid): array
    {
        return $this->all(
            'SELECT match_uid,map_number,map_name,status,current_half,score_a,score_b,recorded_at FROM kgb_cw_maps WHERE match_uid=:match_uid ORDER BY map_number ASC',
            ['match_uid' => $matchUid]
        );
    }

    /** @return list<array<string,mixed>> */
    public function matchHalves(string $matchUid): array
    {
        return $this->all(
            'SELECT match_uid,map_number,half,event_type,score_a,score_b,recorded_at FROM kgb_cw_halves WHERE match_uid=:match_uid ORDER BY map_number ASC,half ASC,recorded_at ASC,event_type ASC',
            ['match_uid' => $matchUid]
        );
    }

    /** @return list<array<string,mixed>> */
    public function matchPlayers(string $matchUid): array
    {
        $sql = <<<'SQL'
SELECT p.match_uid,p.map_number,p.auth_id,p.player_name,p.last_team,p.kills,p.deaths,p.headshots,p.updated_at,
       SHA2(CONCAT(:link_secret,p.auth_id),256) AS player_key
FROM kgb_cw_players p
WHERE p.match_uid=:match_uid
ORDER BY p.map_number ASC,p.kills DESC,p.deaths ASC,p.player_name ASC
SQL;

        return $this->all($sql, ['link_secret' => $this->playerLinkSecret, 'match_uid' => $matchUid]);
    }

    /** @return array{items:list<array<string,mixed>>,total:int} */
    public function maps(int $page, int $perPage): array
    {
        $sql = <<<'SQL'
SELECT map_name,COUNT(DISTINCT match_uid) AS match_count,COUNT(*) AS map_records,
       MAX(recorded_at) AS last_recorded_at
FROM kgb_cw_maps
GROUP BY map_name
ORDER BY match_count DESC,map_name ASC
SQL;
        $count = 'SELECT COUNT(*) FROM (SELECT map_name FROM kgb_cw_maps GROUP BY map_name) counted_maps';

        return $this->page($sql, [], $count, [], $page, $perPage);
    }

    /** @return array<string,mixed>|null */
    public function mapSummary(string $mapName): ?array
    {
        return $this->one(
            'SELECT map_name,COUNT(DISTINCT match_uid) AS match_count,COUNT(*) AS map_records,MAX(recorded_at) AS last_recorded_at FROM kgb_cw_maps WHERE map_name=:map_name GROUP BY map_name',
            ['map_name' => $mapName]
        );
    }

    /** @return array{items:list<array<string,mixed>>,total:int} */
    public function mapMatches(string $mapName, int $page, int $perPage): array
    {
        $sql = <<<'SQL'
SELECT m.match_uid,m.team_a_name,m.team_b_name,m.status,m.score_a,m.score_b,m.started_at,m.ended_at,
       mp.map_number,mp.current_half,mp.score_a AS recorded_score_a,mp.score_b AS recorded_score_b,mp.recorded_at
FROM kgb_cw_maps mp
INNER JOIN kgb_cw_matches m ON m.match_uid=mp.match_uid
WHERE mp.map_name=:map_name
ORDER BY mp.recorded_at DESC,m.match_uid DESC
SQL;
        $count = 'SELECT COUNT(*) FROM kgb_cw_maps WHERE map_name=:map_name';
        $params = ['map_name' => $mapName];

        return $this->page($sql, $params, $count, $params, $page, $perPage);
    }

    /** @return list<array<string,mixed>> */
    public function mapPlayers(string $mapName, int $limit = 25): array
    {
        $sql = <<<'SQL'
SELECT p.auth_id,
       (SELECT p2.player_name FROM kgb_cw_players p2 WHERE p2.auth_id=p.auth_id ORDER BY p2.updated_at DESC,p2.match_uid DESC,p2.map_number DESC LIMIT 1) AS player_name,
       SHA2(CONCAT(:link_secret,p.auth_id),256) AS player_key,
       COUNT(DISTINCT p.match_uid) AS match_count,SUM(p.kills) AS kills,SUM(p.deaths) AS deaths,SUM(p.headshots) AS headshots
FROM kgb_cw_players p
INNER JOIN kgb_cw_maps mp ON mp.match_uid=p.match_uid AND mp.map_number=p.map_number
WHERE mp.map_name=:map_name
GROUP BY p.auth_id
ORDER BY kills DESC,deaths ASC,player_name ASC
LIMIT :limit
SQL;

        return $this->all($sql, ['link_secret' => $this->playerLinkSecret, 'map_name' => $mapName, 'limit' => $limit]);
    }

    /** @return array{items:list<array<string,mixed>>,total:int} */
    public function players(int $page, int $perPage): array
    {
        $sql = <<<'SQL'
SELECT p.auth_id,
       (SELECT p2.player_name FROM kgb_cw_players p2 WHERE p2.auth_id=p.auth_id ORDER BY p2.updated_at DESC,p2.match_uid DESC,p2.map_number DESC LIMIT 1) AS player_name,
       SHA2(CONCAT(:link_secret,p.auth_id),256) AS player_key,
       COUNT(DISTINCT p.match_uid) AS match_count,COUNT(*) AS map_count,
       SUM(p.kills) AS kills,SUM(p.deaths) AS deaths,SUM(p.headshots) AS headshots,MAX(p.updated_at) AS last_seen_at
FROM kgb_cw_players p
GROUP BY p.auth_id
ORDER BY kills DESC,deaths ASC,player_name ASC
SQL;
        $count = 'SELECT COUNT(DISTINCT auth_id) FROM kgb_cw_players';

        return $this->page($sql, ['link_secret' => $this->playerLinkSecret], $count, [], $page, $perPage);
    }

    /** @return array<string,mixed>|null */
    public function playerByKey(string $playerKey): ?array
    {
        $sql = <<<'SQL'
SELECT p.auth_id,
       (SELECT p2.player_name FROM kgb_cw_players p2 WHERE p2.auth_id=p.auth_id ORDER BY p2.updated_at DESC,p2.match_uid DESC,p2.map_number DESC LIMIT 1) AS player_name,
       SHA2(CONCAT(:select_secret,p.auth_id),256) AS player_key,
       COUNT(DISTINCT p.match_uid) AS match_count,COUNT(*) AS map_count,
       SUM(p.kills) AS kills,SUM(p.deaths) AS deaths,SUM(p.headshots) AS headshots,MAX(p.updated_at) AS last_seen_at
FROM kgb_cw_players p
WHERE SHA2(CONCAT(:where_secret,p.auth_id),256)=:player_key
GROUP BY p.auth_id
SQL;

        return $this->one($sql, [
            'select_secret' => $this->playerLinkSecret,
            'where_secret' => $this->playerLinkSecret,
            'player_key' => $playerKey,
        ]);
    }

    /** @return array{items:list<array<string,mixed>>,total:int} */
    public function playerMatches(string $authId, int $page, int $perPage): array
    {
        $sql = <<<'SQL'
SELECT m.match_uid,m.team_a_name,m.team_b_name,m.status,m.score_a,m.score_b,m.started_at,m.ended_at,
       COUNT(*) AS map_count,SUM(p.kills) AS kills,SUM(p.deaths) AS deaths,SUM(p.headshots) AS headshots
FROM kgb_cw_players p
INNER JOIN kgb_cw_matches m ON m.match_uid=p.match_uid
WHERE p.auth_id=:auth_id
GROUP BY m.match_uid,m.team_a_name,m.team_b_name,m.status,m.score_a,m.score_b,m.started_at,m.ended_at
ORDER BY m.started_at DESC,m.match_uid DESC
SQL;
        $count = 'SELECT COUNT(DISTINCT match_uid) FROM kgb_cw_players WHERE auth_id=:auth_id';
        $params = ['auth_id' => $authId];

        return $this->page($sql, $params, $count, $params, $page, $perPage);
    }

    /** @return array{items:list<array<string,mixed>>,total:int} */
    public function teams(int $page, int $perPage): array
    {
        $appearances = <<<'SQL'
SELECT team_a_name AS team_name,status,score_a AS score_for,score_b AS score_against,started_at FROM kgb_cw_matches
UNION ALL
SELECT team_b_name AS team_name,status,score_b AS score_for,score_a AS score_against,started_at FROM kgb_cw_matches
SQL;
        $sql = <<<SQL
SELECT team_name,COUNT(*) AS match_count,
       SUM(CASE WHEN status='match_end' THEN 1 ELSE 0 END) AS completed_count,
       SUM(CASE WHEN status='match_end' AND score_for>score_against THEN 1 ELSE 0 END) AS wins,
       SUM(CASE WHEN status='match_end' AND score_for<score_against THEN 1 ELSE 0 END) AS losses,
       SUM(CASE WHEN status='match_end' AND score_for=score_against THEN 1 ELSE 0 END) AS draws,
       SUM(CASE WHEN status='match_stop' THEN 1 ELSE 0 END) AS stopped_count,
       MAX(started_at) AS last_match_at
FROM ({$appearances}) appearances
GROUP BY team_name
ORDER BY wins DESC,match_count DESC,team_name ASC
SQL;
        $count = 'SELECT COUNT(*) FROM (SELECT team_a_name AS team_name FROM kgb_cw_matches UNION SELECT team_b_name AS team_name FROM kgb_cw_matches) counted_teams';

        return $this->page($sql, [], $count, [], $page, $perPage);
    }

    /** @return array<string,mixed>|null */
    public function teamSummary(string $teamName): ?array
    {
        $sql = <<<'SQL'
SELECT COUNT(*) AS match_count,
       SUM(CASE WHEN status='match_end' THEN 1 ELSE 0 END) AS completed_count,
       SUM(CASE WHEN status='match_end' AND ((team_a_name=:win_a AND score_a>score_b) OR (team_b_name=:win_b AND score_b>score_a)) THEN 1 ELSE 0 END) AS wins,
       SUM(CASE WHEN status='match_end' AND ((team_a_name=:loss_a AND score_a<score_b) OR (team_b_name=:loss_b AND score_b<score_a)) THEN 1 ELSE 0 END) AS losses,
       SUM(CASE WHEN status='match_end' AND score_a=score_b THEN 1 ELSE 0 END) AS draws,
       SUM(CASE WHEN status='match_stop' THEN 1 ELSE 0 END) AS stopped_count,
       MAX(started_at) AS last_match_at
FROM kgb_cw_matches
WHERE team_a_name=:where_a OR team_b_name=:where_b
SQL;

        $row = $this->one($sql, [
            'win_a' => $teamName,
            'win_b' => $teamName,
            'loss_a' => $teamName,
            'loss_b' => $teamName,
            'where_a' => $teamName,
            'where_b' => $teamName,
        ]);
        if ($row === null || (int) $row['match_count'] === 0) {
            return null;
        }
        $row['team_name'] = $teamName;

        return $row;
    }

    /** @return array{items:list<array<string,mixed>>,total:int} */
    public function teamMatches(string $teamName, int $page, int $perPage): array
    {
        $sql = <<<'SQL'
SELECT match_uid,team_a_name,team_b_name,status,score_a,score_b,started_at,ended_at
FROM kgb_cw_matches
WHERE team_a_name=:team_a OR team_b_name=:team_b
ORDER BY started_at DESC,match_uid DESC
SQL;
        $count = 'SELECT COUNT(*) FROM kgb_cw_matches WHERE team_a_name=:team_a OR team_b_name=:team_b';
        $params = ['team_a' => $teamName, 'team_b' => $teamName];

        return $this->page($sql, $params, $count, $params, $page, $perPage);
    }

    /**
     * @param array<string, int|string> $params
     * @param array<string, int|string> $countParams
     * @return array{items:list<array<string,mixed>>,total:int}
     */
    private function page(string $sql, array $params, string $countSql, array $countParams, int $page, int $perPage): array
    {
        $offset = ($page - 1) * $perPage;
        $items = $this->all($sql . ' LIMIT :_limit OFFSET :_offset', $params + ['_limit' => $perPage, '_offset' => $offset]);
        $count = $this->prepared($countSql, $countParams);

        return ['items' => $items, 'total' => (int) $count->fetchColumn()];
    }

    /** @param array<string, int|string> $params @return list<array<string,mixed>> */
    private function all(string $sql, array $params = []): array
    {
        return $this->prepared($sql, $params)->fetchAll();
    }

    /** @param array<string, int|string> $params @return array<string,mixed>|null */
    private function one(string $sql, array $params = []): ?array
    {
        $row = $this->prepared($sql, $params)->fetch();

        return $row === false ? null : $row;
    }

    /** @param array<string, int|string> $params */
    private function prepared(string $sql, array $params = []): PDOStatement
    {
        $statement = $this->pdo->prepare($sql);
        foreach ($params as $name => $value) {
            $statement->bindValue(':' . $name, $value, is_int($value) ? PDO::PARAM_INT : PDO::PARAM_STR);
        }
        $statement->execute();

        return $statement;
    }
}
