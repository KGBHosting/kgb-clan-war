<?php

declare(strict_types=1);

namespace Kgb\ClanWar\Web;

use RuntimeException;

final class Config
{
    /** @return array<string, mixed> */
    public static function load(string $path, string $publicDirectory): array
    {
        if ($path === '' || !str_starts_with($path, DIRECTORY_SEPARATOR)) {
            throw new RuntimeException('KGB_CW_STATS_CONFIG must be an absolute path.');
        }

        $lexicalPath = self::normalizeAbsolutePath($path);
        $lexicalPublic = self::normalizeAbsolutePath($publicDirectory);
        if (self::inside($lexicalPath, $lexicalPublic)) {
            throw new RuntimeException('The statistics configuration must be outside the public document root.');
        }

        $realPath = realpath($path);
        $realPublic = realpath($publicDirectory);
        if ($realPath === false || !is_file($realPath) || !is_readable($realPath)) {
            throw new RuntimeException('The statistics configuration is not readable.');
        }
        $permissions = fileperms($realPath);
        if ($permissions !== false && ($permissions & 0o007) !== 0) {
            throw new RuntimeException('The statistics configuration must not be accessible to other users.');
        }
        if ($realPublic !== false && ($realPath === $realPublic || str_starts_with($realPath, $realPublic . DIRECTORY_SEPARATOR))) {
            throw new RuntimeException('The statistics configuration must be outside the public document root.');
        }

        $config = require $realPath;
        if (!is_array($config)) {
            throw new RuntimeException('The statistics configuration must return an array.');
        }

        return self::validate($config);
    }

    /**
     * @param array<string, mixed> $config
     * @return array<string, mixed>
     */
    public static function validate(array $config): array
    {
        $database = self::section($config, 'database');
        $site = self::section($config, 'site');
        $access = self::section($config, 'access');
        $privacy = self::section($config, 'privacy');

        $dsn = self::text($database, 'dsn', 512);
        if (!str_starts_with($dsn, 'mysql:') || !preg_match('/(?:^|;)charset=utf8mb4(?:;|$)/i', $dsn)) {
            throw new RuntimeException('The web statistics browser requires a MySQL/MariaDB PDO DSN with charset=utf8mb4.');
        }

        $mode = self::text($access, 'mode', 16);
        if ($mode !== 'basic') {
            throw new RuntimeException('Access mode must be basic.');
        }
        self::text($access, 'username', 128);
        $passwordHash = self::text($access, 'password_hash', 255);
        if (password_get_info($passwordHash)['algoName'] === 'unknown') {
            throw new RuntimeException('Basic access requires a password_hash() result.');
        }

        $playerLinkSecret = self::text($privacy, 'player_link_secret', 256);
        if (strlen($playerLinkSecret) < 32 || str_starts_with($playerLinkSecret, 'replace-')) {
            throw new RuntimeException('player_link_secret must contain at least 32 bytes.');
        }

        return [
            'database' => [
                'dsn' => $dsn,
                'username' => self::text($database, 'username', 128),
                'password' => (string) ($database['password'] ?? ''),
            ],
            'site' => [
                'title' => self::text($site, 'title', 120),
                'page_size' => self::integer($site, 'page_size', 1, 100),
                'max_page_size' => self::integer($site, 'max_page_size', 1, 100),
            ],
            'access' => [
                'mode' => $mode,
                'username' => (string) ($access['username'] ?? ''),
                'password_hash' => (string) ($access['password_hash'] ?? ''),
            ],
            'privacy' => [
                'show_auth_ids' => self::boolean($privacy, 'show_auth_ids', false),
                'player_link_secret' => $playerLinkSecret,
            ],
        ];
    }

    /** @param array<string, mixed> $config @return array<string, mixed> */
    private static function section(array $config, string $name): array
    {
        if (!isset($config[$name]) || !is_array($config[$name])) {
            throw new RuntimeException("Missing configuration section: {$name}.");
        }

        return $config[$name];
    }

    /** @param array<string, mixed> $section */
    private static function text(array $section, string $key, int $maxLength): string
    {
        $value = $section[$key] ?? null;
        if (!is_string($value) || trim($value) === '' || strlen($value) > $maxLength) {
            throw new RuntimeException("Invalid configuration value: {$key}.");
        }

        return trim($value);
    }

    /** @param array<string, mixed> $section */
    private static function integer(array $section, string $key, int $minimum, int $maximum): int
    {
        $value = filter_var($section[$key] ?? null, FILTER_VALIDATE_INT);
        if ($value === false || $value < $minimum || $value > $maximum) {
            throw new RuntimeException("Invalid configuration value: {$key}.");
        }

        return $value;
    }

    /** @param array<string, mixed> $section */
    private static function boolean(array $section, string $key, bool $default): bool
    {
        if (!array_key_exists($key, $section)) {
            return $default;
        }
        if (!is_bool($section[$key])) {
            throw new RuntimeException("Invalid configuration value: {$key} must be a boolean.");
        }

        return $section[$key];
    }

    private static function normalizeAbsolutePath(string $path): string
    {
        $segments = [];
        foreach (explode(DIRECTORY_SEPARATOR, $path) as $segment) {
            if ($segment === '' || $segment === '.') {
                continue;
            }
            if ($segment === '..') {
                array_pop($segments);
                continue;
            }
            $segments[] = $segment;
        }

        return DIRECTORY_SEPARATOR . implode(DIRECTORY_SEPARATOR, $segments);
    }

    private static function inside(string $path, string $directory): bool
    {
        return $path === $directory || str_starts_with($path, rtrim($directory, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR);
    }
}
