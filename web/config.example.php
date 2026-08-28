<?php

declare(strict_types=1);

// Copy this file outside the web document root, for example to
// /etc/kgb-clan-war/web-stats.php, and restrict it to the PHP service account.
return [
    'database' => [
        'dsn' => 'mysql:host=127.0.0.1;port=3306;dbname=kgb_cw;charset=utf8mb4',
        'username' => 'kgb_cw_web_reader',
        'password' => 'replace-with-a-dedicated-read-only-password',
    ],
    'site' => [
        'title' => 'Clan War Statistics',
        'page_size' => 25,
        'max_page_size' => 100,
    ],
    'access' => [
        // Basic authentication is mandatory; terminate HTTPS at the web server.
        'mode' => 'basic',
        'username' => 'stats',
        // Generate with: php -r 'echo password_hash("new password", PASSWORD_DEFAULT), PHP_EOL;'
        'password_hash' => 'replace-with-a-password_hash-result',
    ],
    'privacy' => [
        // False keeps raw Steam authentication IDs out of rendered pages and URLs.
        'show_auth_ids' => false,
        // Generate with: php -r 'echo bin2hex(random_bytes(32)), PHP_EOL;'
        'player_link_secret' => 'replace-with-at-least-32-random-bytes',
    ],
];
