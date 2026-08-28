<?php

declare(strict_types=1);

namespace Kgb\ClanWar\Web;

use PDO;
use RuntimeException;

final class Database
{
    /** @param array<string, string> $config */
    public static function connect(array $config): PDO
    {
        $dsn = $config['dsn'] ?? '';
        if (!str_starts_with($dsn, 'mysql:')) {
            throw new RuntimeException('Only MySQL/MariaDB is supported by the deployed web browser.');
        }

        $options = [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::ATTR_STRINGIFY_FETCHES => false,
        ];
        $multiStatementConstant = defined('Pdo\\Mysql::ATTR_MULTI_STATEMENTS')
            ? 'Pdo\\Mysql::ATTR_MULTI_STATEMENTS'
            : 'PDO::MYSQL_ATTR_MULTI_STATEMENTS';
        $options[constant($multiStatementConstant)] = false;

        return new PDO(
            $dsn,
            $config['username'] ?? '',
            $config['password'] ?? '',
            $options
        );
    }
}
