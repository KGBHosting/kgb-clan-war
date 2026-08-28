<?php

declare(strict_types=1);

namespace Kgb\ClanWar\Web;

final class Input
{
    public static function page(mixed $value): int
    {
        if (!is_int($value) && (!is_string($value) || !preg_match('/^[0-9]{1,6}$/D', $value))) {
            return 1;
        }

        return min(1000, max(1, (int) $value));
    }

    public static function perPage(mixed $value, int $default, int $maximum): int
    {
        if (!is_int($value) && (!is_string($value) || !preg_match('/^[0-9]{1,3}$/D', $value))) {
            return min($default, $maximum);
        }

        return min($maximum, max(1, (int) $value));
    }

    public static function matchUid(mixed $value): ?string
    {
        if (!is_string($value) || !preg_match('/^[A-Za-z0-9._-]{1,64}$/D', $value)) {
            return null;
        }

        return $value;
    }

    public static function playerKey(mixed $value): ?string
    {
        if (!is_string($value) || !preg_match('/^[a-f0-9]{64}$/D', $value)) {
            return null;
        }

        return $value;
    }

    public static function label(mixed $value): ?string
    {
        if (!is_string($value) || $value === '' || strlen($value) > 64 || preg_match('/[\x00-\x1F\x7F]/', $value)) {
            return null;
        }

        return $value;
    }
}
