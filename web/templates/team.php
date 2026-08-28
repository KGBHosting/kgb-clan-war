<?php

declare(strict_types=1);

use function Kgb\ClanWar\Web\e;
use function Kgb\ClanWar\Web\pagination;
use function Kgb\ClanWar\Web\url;

?>
<h1>Team <?= e($summary['team_name']) ?></h1>
<div class="metrics">
    <div class="metric">Matches<strong><?= e($summary['match_count']) ?></strong></div>
    <div class="metric">Wins<strong><?= e($summary['wins']) ?></strong></div>
    <div class="metric">Losses<strong><?= e($summary['losses']) ?></strong></div>
    <div class="metric">Draws<strong><?= e($summary['draws']) ?></strong></div>
    <div class="metric">Stopped<strong><?= e($summary['stopped_count']) ?></strong></div>
</div>
<section class="panel">
    <h2>Match history</h2>
    <p class="notice">Wins, losses, and draws include only rows whose final status is <code>match_end</code>. Stopped matches are reported separately.</p>
    <table>
        <thead><tr><th>Started</th><th>Match</th><th>Score</th><th>Status</th></tr></thead>
        <tbody><?php foreach ($matches['items'] as $match): ?><tr>
            <td><?= e($match['started_at']) ?></td>
            <td><a href="<?= e(url(['view' => 'match', 'id' => $match['match_uid']])) ?>"><?= e($match['team_a_name']) ?> vs <?= e($match['team_b_name']) ?></a></td>
            <td><?= e($match['score_a']) ?>–<?= e($match['score_b']) ?></td><td><span class="status"><?= e($match['status']) ?></span></td>
        </tr><?php endforeach; ?></tbody>
    </table>
    <?= pagination($page, $perPage, $matches['total'], ['view' => 'team', 'id' => $summary['team_name'], 'per_page' => $perPage]) ?>
</section>
