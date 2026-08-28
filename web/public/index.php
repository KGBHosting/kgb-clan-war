<?php

declare(strict_types=1);

use Kgb\ClanWar\Web\AccessGate;
use Kgb\ClanWar\Web\Application;
use Kgb\ClanWar\Web\Config;
use Kgb\ClanWar\Web\Database;
use Kgb\ClanWar\Web\PlayerLink;
use Kgb\ClanWar\Web\StatsRepository;
use Kgb\ClanWar\Web\View;

require dirname(__DIR__) . '/src/autoload.php';

header('Content-Type: text/html; charset=utf-8');
header('Content-Security-Policy: default-src \'self\'; style-src \'self\'; img-src \'self\'; base-uri \'none\'; form-action \'self\'; frame-ancestors \'none\'');
header('Referrer-Policy: no-referrer');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Permissions-Policy: camera=(), microphone=(), geolocation=()');
header('Cache-Control: private, no-store');
header('Pragma: no-cache');

$method = (string) ($_SERVER['REQUEST_METHOD'] ?? 'GET');
$isHead = $method === 'HEAD';
if (!in_array($method, ['GET', 'HEAD'], true)) {
    header('Allow: GET, HEAD');
    http_response_code(405);
    echo 'Method not allowed.';
    exit;
}

try {
    $config = Config::load((string) getenv('KGB_CW_STATS_CONFIG'), __DIR__);
    if (!AccessGate::allows($config['access'], $_SERVER)) {
        header('WWW-Authenticate: Basic realm="KGB Clan War statistics", charset="UTF-8"');
        http_response_code(401);
        if (!$isHead) {
            echo 'Authentication required.';
        }
        exit;
    }

    $repository = new StatsRepository(Database::connect($config['database']));
    $repository->assertCompatibleSchema();

    $application = new Application(
        $repository,
        new PlayerLink($config['privacy']['player_link_secret']),
        new View(dirname(__DIR__) . '/templates', $config['site']['title']),
        $config['site']['page_size'],
        $config['site']['max_page_size'],
        $config['privacy']['show_auth_ids']
    );
    $response = $application->handle($_GET);
    http_response_code($response->status);
    if (!$isHead) {
        echo $response->body;
    }
} catch (Throwable $exception) {
    error_log('[KGB CW Stats] ' . $exception->getMessage());
    http_response_code(503);
    if (!$isHead) {
        echo 'Statistics are temporarily unavailable.';
    }
}
