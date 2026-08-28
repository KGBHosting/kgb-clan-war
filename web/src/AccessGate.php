<?php

declare(strict_types=1);

namespace Kgb\ClanWar\Web;

final class AccessGate
{
    /**
     * @param array<string, mixed> $access
     * @param array<string, mixed> $server
     */
    public static function allows(array $access, array $server): bool
    {
        [$username, $password] = self::credentials($server);
        $expectedUsername = (string) ($access['username'] ?? '');
        $passwordHash = (string) ($access['password_hash'] ?? '');

        return $username !== null
            && $password !== null
            && hash_equals($expectedUsername, $username)
            && password_verify($password, $passwordHash);
    }

    /** @param array<string, mixed> $server @return array{?string,?string} */
    private static function credentials(array $server): array
    {
        if (isset($server['PHP_AUTH_USER'], $server['PHP_AUTH_PW'])) {
            return [(string) $server['PHP_AUTH_USER'], (string) $server['PHP_AUTH_PW']];
        }

        $authorization = $server['HTTP_AUTHORIZATION'] ?? $server['REDIRECT_HTTP_AUTHORIZATION'] ?? null;
        if (!is_string($authorization) || !str_starts_with($authorization, 'Basic ')) {
            return [null, null];
        }

        $decoded = base64_decode(substr($authorization, 6), true);
        if ($decoded === false || !str_contains($decoded, ':')) {
            return [null, null];
        }

        return explode(':', $decoded, 2);
    }
}
