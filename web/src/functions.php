<?php

declare(strict_types=1);

namespace Kgb\ClanWar\Web;

function e(mixed $value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/** @param array<string, scalar> $parameters */
function url(array $parameters): string
{
    return '?' . http_build_query($parameters, '', '&', PHP_QUERY_RFC3986);
}

/** @param array{auth_id:string,player_key:string} $player */
function player_label(array $player, bool $showAuthIds): string
{
    if ($showAuthIds) {
        return $player['auth_id'];
    }

    return 'Player ' . strtoupper(substr($player['player_key'], 0, 10));
}

/**
 * @param array<string, scalar> $parameters
 */
function pagination(int $page, int $perPage, int $total, array $parameters): string
{
    $pages = min(1000, max(1, (int) ceil($total / $perPage)));
    if ($pages <= 1) {
        return '';
    }

    $parts = ['<nav class="pagination" aria-label="Pagination">'];
    if ($page > 1) {
        $parts[] = '<a rel="prev" href="' . e(url($parameters + ['page' => $page - 1])) . '">Previous</a>';
    }

    $parts[] = '<span>Page ' . e($page) . ' of ' . e($pages) . '</span>';

    if ($page < $pages) {
        $parts[] = '<a rel="next" href="' . e(url($parameters + ['page' => $page + 1])) . '">Next</a>';
    }

    $parts[] = '</nav>';

    return implode('', $parts);
}
