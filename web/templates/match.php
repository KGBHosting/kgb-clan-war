<?php

declare(strict_types=1);

use function Kgb\ClanWar\Web\e;
use function Kgb\ClanWar\Web\player_label;
use function Kgb\ClanWar\Web\url;

?>
<h1><?= e($match['team_a_name']) ?> vs <?= e($match['team_b_name']) ?></h1>
<div class="metrics">
    <div class="metric">Series score<strong><?= e($match['score_a']) ?>–<?= e($match['score_b']) ?></strong></div>
    <div class="metric">Status<strong><?= e($match['status']) ?></strong></div>
    <div class="metric">Started<strong><?= e($match['started_at']) ?></strong></div>
    <div class="metric">Ended<strong><?= e($match['ended_at'] ?? '—') ?></strong></div>
</div>

<section class="panel">
    <h2>Maps</h2>
    <p class="notice">Map rows store the cumulative series score at the last event recorded on that map.</p>
    <?php if ($maps === []): ?><p class="empty">No map snapshots are available.</p><?php else: ?>
    <table>
        <thead><tr><th>#</th><th>Map</th><th>Recorded score</th><th>Half</th><th>Status</th><th>Recorded</th></tr></thead>
        <tbody><?php foreach ($maps as $map): ?><tr>
            <td><?= e($map['map_number']) ?></td>
            <td><a href="<?= e(url(['view' => 'map', 'id' => $map['map_name']])) ?>"><?= e($map['map_name']) ?></a></td>
            <td><?= e($map['score_a']) ?>–<?= e($map['score_b']) ?></td>
            <td><?= e($map['current_half']) ?></td>
            <td><span class="status"><?= e($map['status']) ?></span></td>
            <td><?= e($map['recorded_at']) ?></td>
        </tr><?php endforeach; ?></tbody>
    </table>
    <?php endif; ?>
</section>

<section class="panel">
    <h2>Half timeline</h2>
    <?php if ($halves === []): ?><p class="empty">No half snapshots are available.</p><?php else: ?>
    <table>
        <thead><tr><th>Map</th><th>Half</th><th>Event</th><th>Series score</th><th>Recorded</th></tr></thead>
        <tbody><?php foreach ($halves as $half): ?><tr>
            <td><?= e($half['map_number']) ?></td><td><?= e($half['half']) ?></td><td><?= e($half['event_type']) ?></td>
            <td><?= e($half['score_a']) ?>–<?= e($half['score_b']) ?></td><td><?= e($half['recorded_at']) ?></td>
        </tr><?php endforeach; ?></tbody>
    </table>
    <?php endif; ?>
</section>

<section class="panel">
    <h2>Player map totals</h2>
    <?php if ($players === []): ?><p class="empty">No player totals are available.</p><?php else: ?>
    <table>
        <thead><tr><th>Map</th><th>Player</th><th>Name</th><th>Last side</th><th>K</th><th>D</th><th>HS</th></tr></thead>
        <tbody><?php foreach ($players as $player): ?><tr>
            <td><?= e($player['map_number']) ?></td>
            <td><a href="<?= e(url(['view' => 'player', 'id' => $player['player_token']])) ?>"><?= e(player_label($player, $showAuthIds)) ?></a></td>
            <td><?= e($player['player_name']) ?></td><td><?= e($player['last_team']) ?></td>
            <td><?= e($player['kills']) ?></td><td><?= e($player['deaths']) ?></td><td><?= e($player['headshots']) ?></td>
        </tr><?php endforeach; ?></tbody>
    </table>
    <?php endif; ?>
</section>
