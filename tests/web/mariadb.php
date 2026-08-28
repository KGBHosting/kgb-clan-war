<?php

declare(strict_types=1);

use Kgb\ClanWar\Web\Database;
use Kgb\ClanWar\Web\PlayerLink;
use Kgb\ClanWar\Web\StatsRepository;

require dirname(__DIR__, 2) . '/web/src/autoload.php';

$dsn = (string) getenv('KGB_CW_TEST_DSN');
$username = (string) getenv('KGB_CW_TEST_USERNAME');
$password = (string) getenv('KGB_CW_TEST_PASSWORD');
$pdo = Database::connect(['dsn' => $dsn, 'username' => $username, 'password' => $password]);
$repository = new StatsRepository($pdo);
$playerLink = new PlayerLink('mariadb-test-player-link-secret-32-bytes');
$expectIndexRejection = (string) getenv('KGB_CW_EXPECT_INDEX_REJECTION');
if ($expectIndexRejection !== '') {
    try {
        $repository->assertCompatibleSchema();
    } catch (RuntimeException $exception) {
        if (str_contains($exception->getMessage(), 'full usable auth_id')) {
            printf("MariaDB %s auth_id index was rejected.\n", $expectIndexRejection);
            exit(0);
        }
        throw $exception;
    }

    throw new RuntimeException("MariaDB {$expectIndexRejection} auth_id index satisfied the schema gate.");
}
$repository->assertCompatibleSchema();

if ($repository->matches(1, 25)['total'] !== 1
    || $repository->maps(1, 25)['total'] !== 1
    || $repository->players(1, 25)['total'] !== 1
    || $repository->teams(1, 25)['total'] !== 2) {
    throw new RuntimeException('MariaDB read contract returned unexpected aggregates.');
}
if ($repository->match('mariadb-match') === null
    || count($repository->matchMaps('mariadb-match')) !== 1
    || count($repository->matchHalves('mariadb-match')) !== 1
    || count($repository->matchPlayers('mariadb-match')) !== 1
    || $repository->mapSummary('de_dust2') === null
    || $repository->mapMatches('de_dust2', 1, 25)['total'] !== 1
    || count($repository->mapPlayers('de_dust2')) !== 1
    || $repository->teamSummary('Alpha') === null
    || $repository->teamMatches('Alpha', 1, 25)['total'] !== 1) {
    throw new RuntimeException('A MariaDB detail query failed its native-prepare contract.');
}

$playerToken = $playerLink->encode('STEAM_0:1:999');
$authId = $playerLink->decode($playerToken);
if ($authId !== 'STEAM_0:1:999' || (int) $repository->playerByAuthId($authId)['kills'] !== 9) {
    throw new RuntimeException('MariaDB native prepared player lookup failed.');
}
if ($repository->playerMatches('STEAM_0:1:999', 1, 25)['total'] !== 1) {
    throw new RuntimeException('MariaDB native prepared player history failed.');
}

$explain = $pdo->prepare('EXPLAIN SELECT auth_id FROM kgb_cw_players FORCE INDEX (kgb_cw_players_auth_id) WHERE auth_id=:auth_id');
$explain->execute(['auth_id' => 'STEAM_0:1:999']);
if (($explain->fetch()['key'] ?? null) !== 'kgb_cw_players_auth_id') {
    throw new RuntimeException('MariaDB could not use the leading auth_id index for exact player lookup.');
}

try {
    $pdo->exec("DELETE FROM kgb_cw_matches WHERE match_uid='mariadb-match'");
    throw new RuntimeException('The SELECT-only MariaDB account unexpectedly accepted a write.');
} catch (PDOException) {
    // Expected: deployment contract uses a SELECT-only database principal.
}

printf("MariaDB native prepares, indexed encrypted player links, schema probes, and SELECT-only grants passed.\n");
