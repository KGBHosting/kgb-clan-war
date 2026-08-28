<?php

declare(strict_types=1);

use Kgb\ClanWar\Web\Database;
use Kgb\ClanWar\Web\StatsRepository;

require dirname(__DIR__, 2) . '/web/src/autoload.php';

$dsn = (string) getenv('KGB_CW_TEST_DSN');
$username = (string) getenv('KGB_CW_TEST_USERNAME');
$password = (string) getenv('KGB_CW_TEST_PASSWORD');
$pdo = Database::connect(['dsn' => $dsn, 'username' => $username, 'password' => $password]);
$repository = new StatsRepository($pdo, 'mariadb-test-player-link-secret-32-bytes');
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

$playerKey = hash('sha256', 'mariadb-test-player-link-secret-32-bytes' . 'STEAM_0:1:999');
if ((int) $repository->playerByKey($playerKey)['kills'] !== 9) {
    throw new RuntimeException('MariaDB native prepared player lookup failed.');
}
if ($repository->playerMatches('STEAM_0:1:999', 1, 25)['total'] !== 1) {
    throw new RuntimeException('MariaDB native prepared player history failed.');
}

try {
    $pdo->exec("DELETE FROM kgb_cw_matches WHERE match_uid='mariadb-match'");
    throw new RuntimeException('The SELECT-only MariaDB account unexpectedly accepted a write.');
} catch (PDOException) {
    // Expected: deployment contract uses a SELECT-only database principal.
}

printf("MariaDB native prepares, SHA2 player links, schema probes, and SELECT-only grants passed.\n");
