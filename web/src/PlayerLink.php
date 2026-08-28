<?php

declare(strict_types=1);

namespace Kgb\ClanWar\Web;

use RuntimeException;
use SodiumException;

final class PlayerLink
{
    private const PREFIX = 'v1.';
    private const AAD = 'kgb-clan-war-player-link-v1';

    private readonly string $encryptionKey;
    private readonly string $aliasKey;

    public function __construct(string $secret)
    {
        if (!function_exists('sodium_crypto_aead_xchacha20poly1305_ietf_encrypt')) {
            throw new RuntimeException('The sodium PHP extension is required for private player links.');
        }

        $this->encryptionKey = sodium_crypto_generichash(
            "encryption\0" . $secret,
            '',
            SODIUM_CRYPTO_AEAD_XCHACHA20POLY1305_IETF_KEYBYTES
        );
        $this->aliasKey = sodium_crypto_generichash("alias\0" . $secret);
    }

    public function encode(string $authId): string
    {
        if (!self::validAuthId($authId)) {
            throw new RuntimeException('The database returned an invalid player authentication ID.');
        }

        $nonce = random_bytes(SODIUM_CRYPTO_AEAD_XCHACHA20POLY1305_IETF_NPUBBYTES);
        $ciphertext = sodium_crypto_aead_xchacha20poly1305_ietf_encrypt(
            $authId,
            self::AAD,
            $nonce,
            $this->encryptionKey
        );

        return self::PREFIX . sodium_bin2base64(
            $nonce . $ciphertext,
            SODIUM_BASE64_VARIANT_URLSAFE_NO_PADDING
        );
    }

    public function decode(string $token): ?string
    {
        if (!preg_match('/^v1\.[A-Za-z0-9_-]{55,108}$/D', $token)) {
            return null;
        }

        try {
            $payload = sodium_base642bin(
                substr($token, strlen(self::PREFIX)),
                SODIUM_BASE64_VARIANT_URLSAFE_NO_PADDING,
                ''
            );
        } catch (SodiumException) {
            return null;
        }

        $nonceLength = SODIUM_CRYPTO_AEAD_XCHACHA20POLY1305_IETF_NPUBBYTES;
        $minimumLength = $nonceLength + SODIUM_CRYPTO_AEAD_XCHACHA20POLY1305_IETF_ABYTES + 1;
        $maximumLength = $nonceLength + SODIUM_CRYPTO_AEAD_XCHACHA20POLY1305_IETF_ABYTES + 40;
        if (strlen($payload) < $minimumLength || strlen($payload) > $maximumLength) {
            return null;
        }

        $plaintext = sodium_crypto_aead_xchacha20poly1305_ietf_decrypt(
            substr($payload, $nonceLength),
            self::AAD,
            substr($payload, 0, $nonceLength),
            $this->encryptionKey
        );

        return is_string($plaintext) && self::validAuthId($plaintext) ? $plaintext : null;
    }

    public function alias(string $authId): string
    {
        if (!self::validAuthId($authId)) {
            throw new RuntimeException('The database returned an invalid player authentication ID.');
        }

        return strtoupper(substr(hash_hmac('sha256', $authId, $this->aliasKey), 0, 10));
    }

    private static function validAuthId(string $authId): bool
    {
        return preg_match('/^[\x21-\x7E]{1,40}$/D', $authId) === 1;
    }
}
