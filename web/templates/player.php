<?php

declare(strict_types=1);

use function Kgb\ClanWar\Web\e;
use function Kgb\ClanWar\Web\pagination;
use function Kgb\ClanWar\Web\player_label;
use function Kgb\ClanWar\Web\url;

?>
<h1><?= e($player['player_name']) ?></h1>
<p><?= e(player_label($player, $showAuthIds)) ?></p>
<div class="metrics">
    <div class="metric">Matches<strong><?= e($player['match_count']) ?></strong></div>
    <div class="metric">Maps<strong><?= e($player['map_count']) ?></strong></div>
    <div class="metric">Kills<strong><?= e($player['kills']) ?></strong></div>
    <div class="metric">Deaths<strong><?= e($player['deaths']) ?></strong></div>
    <div class="metric">Headshots<strong><?= e($player['headshots']) ?></strong></div>
</div>
<section class="panel">
    <h2>Match history</h2>
    <?php if ($matches['items'] === []): ?><p class="empty">No match history is available.</p><?php else: ?>
    <table>
        <thead><tr><th>Started</th><th>Match</th><th>Status</th><th>Maps</th><th>K</th><th>D</th><th>HS</th></tr></thead>
        <tbody><?php foreach ($matches['items'] as $match): ?><tr>
            <td><?= e($match['started_at']) ?></td>
            <td><a href="<?= e(url(['view' => 'match', 'id' => $match['match_uid']])) ?>"><?= e($match['team_a_name']) ?> vs <?= e($match['team_b_name']) ?></a></td>
            <td><span class="status"><?= e($match['status']) ?></span></td><td><?= e($match['map_count']) ?></td>
            <td><?= e($match['kills']) ?></td><td><?= e($match['deaths']) ?></td><td><?= e($match['headshots']) ?></td>
        </tr><?php endforeach; ?></tbody>
    </table>
    <?= pagination($page, $perPage, $matches['total'], ['view' => 'player', 'id' => $player['player_token'], 'per_page' => $perPage]) ?>
    <?php endif; ?>
</section>
