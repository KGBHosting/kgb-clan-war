<?php

declare(strict_types=1);

use Kgb\ClanWar\Web\AccessGate;
use Kgb\ClanWar\Web\Application;
use Kgb\ClanWar\Web\Config;
use Kgb\ClanWar\Web\Input;
use Kgb\ClanWar\Web\PlayerLink;
use Kgb\ClanWar\Web\StatsRepository;
use Kgb\ClanWar\Web\View;

require dirname(__DIR__, 2) . '/web/src/autoload.php';

function check(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

function insertRow(PDO $pdo, string $table, array $row): void
{
    $columns = array_keys($row);
    $placeholders = array_map(static fn (string $column): string => ':' . $column, $columns);
    $statement = $pdo->prepare(sprintf(
        'INSERT INTO %s (%s) VALUES (%s)',
        $table,
        implode(',', $columns),
        implode(',', $placeholders)
    ));
    $statement->execute($row);
}

// SQLite is an explicit test double. Production connection code accepts only
// MySQL/MariaDB, while the separate container test exercises that real dialect.
$pdo = class_exists(Pdo\Sqlite::class) ? new Pdo\Sqlite('sqlite::memory:') : new PDO('sqlite::memory:');
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
$schema = (string) file_get_contents(dirname(__DIR__, 2) . '/sql/schema.sql');
$schema = str_replace(",\n    INDEX kgb_cw_players_auth_id (auth_id)", '', $schema);
$pdo->exec($schema);
$pdo->exec('CREATE INDEX kgb_cw_players_auth_prefix ON kgb_cw_players (substr(auth_id, 1, 1))');

insertRow($pdo, 'kgb_cw_matches', [
    'match_uid' => 'match-1', 'team_a_name' => 'Alpha', 'team_b_name' => '<script>Beta</script>',
    'status' => 'match_end', 'map_number' => 2, 'current_half' => 2, 'score_a' => 16, 'score_b' => 10,
    'started_at' => '2026-08-01 10:00:00', 'ended_at' => '2026-08-01 11:00:00',
]);
insertRow($pdo, 'kgb_cw_matches', [
    'match_uid' => 'match-2', 'team_a_name' => 'Alpha', 'team_b_name' => 'Gamma',
    'status' => 'match_stop', 'map_number' => 1, 'current_half' => 1, 'score_a' => 5, 'score_b' => 3,
    'started_at' => '2026-08-02 10:00:00', 'ended_at' => '2026-08-02 10:20:00',
]);
insertRow($pdo, 'kgb_cw_matches', [
    'match_uid' => 'match-3', 'team_a_name' => 'Gamma', 'team_b_name' => 'Alpha',
    'status' => 'match_end', 'map_number' => 1, 'current_half' => 2, 'score_a' => 12, 'score_b' => 12,
    'started_at' => '2026-08-03 10:00:00', 'ended_at' => '2026-08-03 11:00:00',
]);
foreach ([
    ['match-1', 1, 'de_dust2', 'map_change', 2, 8, 7, '2026-08-01 10:30:00'],
    ['match-1', 2, 'de_nuke', 'match_end', 2, 16, 10, '2026-08-01 11:00:00'],
    ['match-2', 1, 'de_dust2', 'match_stop', 1, 5, 3, '2026-08-02 10:20:00'],
    ['match-3', 1, 'de_dust2', 'match_end', 2, 12, 12, '2026-08-03 11:00:00'],
] as [$uid, $number, $name, $status, $half, $scoreA, $scoreB, $recorded]) {
    insertRow($pdo, 'kgb_cw_maps', [
        'match_uid' => $uid, 'map_number' => $number, 'map_name' => $name, 'status' => $status,
        'current_half' => $half, 'score_a' => $scoreA, 'score_b' => $scoreB, 'recorded_at' => $recorded,
    ]);
}
insertRow($pdo, 'kgb_cw_halves', [
    'match_uid' => 'match-1', 'map_number' => 1, 'half' => 1, 'event_type' => 'half_end',
    'score_a' => 8, 'score_b' => 7, 'recorded_at' => '2026-08-01 10:30:00',
]);
foreach ([
    ['match-1', 1, 'STEAM_0:1:111', 'Player One', 'CT', 8, 3, 2, '2026-08-01 10:30:00'],
    ['match-1', 2, 'STEAM_0:1:111', 'Player One', 'T', 7, 4, 1, '2026-08-01 11:00:00'],
    ['match-1', 1, 'STEAM_0:1:222', '<img src=x onerror=alert(1)>', 'T', 3, 8, 0, '2026-08-01 10:30:00'],
    ['match-3', 1, 'STEAM_0:1:111', 'Player One Latest', 'CT', 12, 12, 4, '2026-08-03 11:00:00'],
] as [$uid, $number, $auth, $name, $team, $kills, $deaths, $headshots, $updated]) {
    insertRow($pdo, 'kgb_cw_players', [
        'match_uid' => $uid, 'map_number' => $number, 'auth_id' => $auth, 'player_name' => $name,
        'last_team' => $team, 'kills' => $kills, 'deaths' => $deaths, 'headshots' => $headshots, 'updated_at' => $updated,
    ]);
}

$prefixPlan = $pdo->prepare('EXPLAIN QUERY PLAN SELECT auth_id FROM kgb_cw_players WHERE auth_id=:auth_id');
$prefixPlan->execute(['auth_id' => 'STEAM_0:1:111']);
check(!str_contains(implode(' ', array_column($prefixPlan->fetchAll(), 'detail')), 'kgb_cw_players_auth_prefix'), 'A prefix-only player index incorrectly satisfied exact lookup.');
$pdo->exec('CREATE INDEX kgb_cw_players_auth_id ON kgb_cw_players (auth_id)');

$secret = 'test-only-player-link-secret-32-bytes-minimum';
$repository = new StatsRepository($pdo);
$playerLink = new PlayerLink($secret);
$repository->assertCompatibleSchema();

$matches = $repository->matches(1, 2);
check($matches['total'] === 3 && count($matches['items']) === 2, 'Match pagination/count failed.');
check($repository->match('match-1')['score_a'] === 16, 'Match detail failed.');
check(count($repository->matchMaps('match-1')) === 2, 'Match map detail failed.');
check(count($repository->matchPlayers('match-1')) === 3, 'Match player detail failed.');

$maps = $repository->maps(1, 25);
check($maps['total'] === 2 && $maps['items'][0]['map_name'] === 'de_dust2', 'Map aggregation failed.');
check(count($repository->mapPlayers('de_dust2')) === 2, 'Map player aggregation failed.');

$players = $repository->players(1, 25);
check($players['total'] === 2, 'Player aggregation failed.');
$player = $repository->playerByAuthId('STEAM_0:1:111');
check($player !== null && $player['player_name'] === 'Player One Latest', 'Exact player lookup/latest name failed.');
check((int) $player['kills'] === 27 && $repository->playerMatches($player['auth_id'], 1, 25)['total'] === 2, 'Player totals/history failed.');

$queryPlan = $pdo->prepare('EXPLAIN QUERY PLAN SELECT auth_id FROM kgb_cw_players WHERE auth_id=:auth_id');
$queryPlan->execute(['auth_id' => 'STEAM_0:1:111']);
check(str_contains(implode(' ', array_column($queryPlan->fetchAll(), 'detail')), 'kgb_cw_players_auth_id'), 'Exact player lookup did not use the auth_id index.');

$playerToken = $playerLink->encode('STEAM_0:1:111');
$secondToken = $playerLink->encode('STEAM_0:1:111');
check($playerToken !== $secondToken, 'Player links reused a nonce.');
check(!str_contains($playerToken, 'STEAM_0:1:111'), 'Player link exposed the raw auth ID.');
check($playerLink->decode($playerToken) === 'STEAM_0:1:111', 'Player link did not decrypt to the exact auth ID.');
check($playerLink->decode($secondToken) === 'STEAM_0:1:111', 'Second randomized player link did not decrypt.');
check((new PlayerLink('different-test-only-secret-with-32-bytes'))->decode($playerToken) === null, 'A different player-link secret decrypted the token.');
$replacement = str_ends_with($playerToken, 'A') ? 'B' : 'A';
$tamperedToken = substr($playerToken, 0, -1) . $replacement;
check($playerLink->decode($tamperedToken) === null, 'A tampered player link was accepted.');
check(Input::playerToken($playerToken) === $playerToken && Input::playerToken('v1.invalid') === null, 'Player token input validation failed.');

$alpha = $repository->teamSummary('Alpha');
check($alpha !== null && (int) $alpha['wins'] === 1 && (int) $alpha['draws'] === 1 && (int) $alpha['stopped_count'] === 1, 'Team outcomes failed.');
check($repository->teamSummary("Alpha' OR 1=1 --") === null, 'Prepared team lookup accepted an injection-shaped value.');

$view = new View(dirname(__DIR__, 2) . '/web/templates', 'Test <Stats>');
$application = new Application($repository, $playerLink, $view, 25, 100, false);
$playerPage = $application->handle(['view' => 'player', 'id' => $playerToken]);
check($playerPage->status === 200, 'Player page failed.');
check(!str_contains($playerPage->body, 'STEAM_0:1:111'), 'Raw auth ID leaked with show_auth_ids disabled.');
check(str_contains($playerPage->body, 'Player One Latest'), 'Player page omitted the latest name.');
check($application->handle(['view' => 'player', 'id' => $tamperedToken])->status === 404, 'Tampered player token did not return a generic not-found response.');
$matchPage = $application->handle(['view' => 'match', 'id' => 'match-1']);
check(!str_contains($matchPage->body, '<script>Beta</script>'), 'Team XSS was not escaped.');
check(str_contains($matchPage->body, '&lt;script&gt;Beta&lt;/script&gt;'), 'Escaped team name was not rendered.');
check(!str_contains($matchPage->body, '<img src=x onerror=alert(1)>'), 'Player-name XSS was not escaped.');
$mapPage = $application->handle(['view' => 'map', 'id' => 'de_dust2']);
$playersPage = $application->handle(['view' => 'players']);
foreach ([$matchPage, $mapPage, $playersPage] as $privatePage) {
    check(!str_contains($privatePage->body, 'STEAM_0:'), 'A raw auth ID leaked from a default player-bearing view.');
}
check($application->handle(['view' => 'match', 'id' => ['match-1']])->status === 404, 'Array input was not rejected.');
check($application->handle(['view' => 'unknown'])->status === 404, 'Unknown view was not rejected.');

check(Input::page('9999999') === 1 && Input::page('1001') === 1000, 'Page bounds failed.');
check(Input::perPage('999', 25, 100) === 100, 'Page-size bound failed.');

$passwordHash = password_hash('test password', PASSWORD_DEFAULT);
$access = ['mode' => 'basic', 'username' => 'viewer', 'password_hash' => $passwordHash];
check(!AccessGate::allows($access, []), 'Basic access did not default deny.');
check(AccessGate::allows($access, ['HTTP_AUTHORIZATION' => 'Basic ' . base64_encode('viewer:test password')]), 'Valid Basic access failed.');
check(!AccessGate::allows($access, ['HTTP_AUTHORIZATION' => 'Basic ' . base64_encode('viewer:wrong')]), 'Invalid Basic access was accepted.');

$validConfig = [
    'database' => ['dsn' => 'mysql:host=localhost;dbname=test;charset=utf8mb4', 'username' => 'reader', 'password' => 'test-only'],
    'site' => ['title' => 'Test', 'page_size' => 25, 'max_page_size' => 100],
    'access' => $access,
    'privacy' => ['show_auth_ids' => false, 'player_link_secret' => $secret],
];
check(Config::validate($validConfig)['access']['mode'] === 'basic', 'Valid configuration was rejected.');
check(Config::validate($validConfig)['privacy']['show_auth_ids'] === false, 'A literal false privacy flag was not preserved.');
check(Config::validate(array_replace_recursive($validConfig, ['privacy' => ['show_auth_ids' => true]]))['privacy']['show_auth_ids'] === true, 'A literal true privacy flag was not preserved.');
foreach (['false', 'true', 0, 1] as $unsafeBoolean) {
    try {
        Config::validate(array_replace_recursive($validConfig, ['privacy' => ['show_auth_ids' => $unsafeBoolean]]));
        throw new RuntimeException('A non-boolean privacy flag was accepted.');
    } catch (RuntimeException $exception) {
        check($exception->getMessage() !== 'A non-boolean privacy flag was accepted.', $exception->getMessage());
    }
}
try {
    Config::validate(array_replace_recursive($validConfig, ['access' => ['mode' => 'public']]));
    throw new RuntimeException('Anonymous public access mode was accepted.');
} catch (RuntimeException $exception) {
    check($exception->getMessage() !== 'Anonymous public access mode was accepted.', $exception->getMessage());
}
try {
    Config::validate(array_replace_recursive($validConfig, ['privacy' => ['player_link_secret' => 'short']]));
    throw new RuntimeException('Short player-link secret was accepted.');
} catch (RuntimeException $exception) {
    check($exception->getMessage() !== 'Short player-link secret was accepted.', $exception->getMessage());
}
$configPath = tempnam(sys_get_temp_dir(), 'kgb-cw-web-config-');
if ($configPath === false) {
    throw new RuntimeException('Could not create the test configuration fixture.');
}
file_put_contents($configPath, "<?php\nreturn " . var_export($validConfig, true) . ";\n");
chmod($configPath, 0640);
check(Config::load($configPath, dirname(__DIR__, 2) . '/web/public')['site']['title'] === 'Test', 'External configuration load failed.');
chmod($configPath, 0644);
try {
    Config::load($configPath, dirname(__DIR__, 2) . '/web/public');
    throw new RuntimeException('World-readable configuration was accepted.');
} catch (RuntimeException $exception) {
    check($exception->getMessage() !== 'World-readable configuration was accepted.', $exception->getMessage());
} finally {
    unlink($configPath);
}

$symlinkRoot = sys_get_temp_dir() . '/kgb-cw-web-config-' . bin2hex(random_bytes(8));
$symlinkPublic = $symlinkRoot . '/public';
if (!mkdir($symlinkPublic, 0700, true)) {
    throw new RuntimeException('Could not create the symlink configuration fixture.');
}
$symlinkTarget = $symlinkRoot . '/outside.php';
$symlinkPath = $symlinkPublic . '/config.php';
file_put_contents($symlinkTarget, "<?php\nreturn " . var_export($validConfig, true) . ";\n");
chmod($symlinkTarget, 0640);
if (!symlink($symlinkTarget, $symlinkPath)) {
    throw new RuntimeException('Could not create the symlink configuration fixture.');
}
try {
    Config::load($symlinkPath, $symlinkPublic);
    throw new RuntimeException('A config path lexically under the public root was accepted through a symlink.');
} catch (RuntimeException $exception) {
    check($exception->getMessage() !== 'A config path lexically under the public root was accepted through a symlink.', $exception->getMessage());
} finally {
    unlink($symlinkPath);
    unlink($symlinkTarget);
    rmdir($symlinkPublic);
    rmdir($symlinkRoot);
}

$pdo->exec('PRAGMA query_only=ON');
check($repository->matches(1, 1)['total'] === 3, 'Repository failed on a read-only test connection.');
try {
    $pdo->exec("DELETE FROM kgb_cw_matches WHERE match_uid='match-1'");
    throw new RuntimeException('Read-only SQLite test double unexpectedly accepted a write.');
} catch (PDOException) {
    // Expected test-double behavior.
}

printf("SQLite repository, indexed encrypted links, routing, escaping, access, and bounds checks passed.\n");
