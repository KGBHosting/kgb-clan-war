<?php

declare(strict_types=1);

use function Kgb\ClanWar\Web\e;
use function Kgb\ClanWar\Web\pagination;
use function Kgb\ClanWar\Web\player_label;
use function Kgb\ClanWar\Web\url;

?>
<h1>Map <?= e($summary['map_name']) ?></h1>
<div class="metrics">
    <div class="metric">Matches<strong><?= e($summary['match_count']) ?></strong></div>
    <div class="metric">Map records<strong><?= e($summary['map_records']) ?></strong></div>
    <div class="metric">Last recorded<strong><?= e($summary['last_recorded_at']) ?></strong></div>
</div>
<section class="panel">
    <h2>Match history</h2>
    <p class="notice">Recorded scores are cumulative series scores, not isolated per-map scores.</p>
    <?php if ($matches['items'] === []): ?><p class="empty">No match history is available.</p><?php else: ?>
    <table>
        <thead><tr><th>Recorded</th><th>Match</th><th>Map #</th><th>Recorded score</th><th>Status</th></tr></thead>
        <tbody><?php foreach ($matches['items'] as $match): ?><tr>
            <td><?= e($match['recorded_at']) ?></td>
            <td><a href="<?= e(url(['view' => 'match', 'id' => $match['match_uid']])) ?>"><?= e($match['team_a_name']) ?> vs <?= e($match['team_b_name']) ?></a></td>
            <td><?= e($match['map_number']) ?></td><td><?= e($match['recorded_score_a']) ?>–<?= e($match['recorded_score_b']) ?></td>
            <td><span class="status"><?= e($match['status']) ?></span></td>
        </tr><?php endforeach; ?></tbody>
    </table>
    <?= pagination($page, $perPage, $matches['total'], ['view' => 'map', 'id' => $summary['map_name'], 'per_page' => $perPage]) ?>
    <?php endif; ?>
</section>
<section class="panel">
    <h2>Top players</h2>
    <?php if ($players === []): ?><p class="empty">No player totals are available.</p><?php else: ?>
    <table>
        <thead><tr><th>Player</th><th>Name</th><th>Matches</th><th>K</th><th>D</th><th>HS</th></tr></thead>
        <tbody><?php foreach ($players as $player): ?><tr>
            <td><a href="<?= e(url(['view' => 'player', 'id' => $player['player_token']])) ?>"><?= e(player_label($player, $showAuthIds)) ?></a></td>
            <td><?= e($player['player_name']) ?></td><td><?= e($player['match_count']) ?></td>
            <td><?= e($player['kills']) ?></td><td><?= e($player['deaths']) ?></td><td><?= e($player['headshots']) ?></td>
        </tr><?php endforeach; ?></tbody>
    </table>
    <?php endif; ?>
</section>
