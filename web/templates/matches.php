<?php

declare(strict_types=1);

use function Kgb\ClanWar\Web\e;
use function Kgb\ClanWar\Web\pagination;
use function Kgb\ClanWar\Web\url;

?>
<h1>Matches</h1>
<div class="panel">
<?php if ($result['items'] === []): ?>
    <p class="empty">No match statistics have been recorded.</p>
<?php else: ?>
    <table>
        <thead><tr><th>Started</th><th>Match</th><th>Score</th><th>Status</th><th>Maps</th><th>Players</th></tr></thead>
        <tbody>
        <?php foreach ($result['items'] as $match): ?>
            <tr>
                <td><?= e($match['started_at']) ?></td>
                <td><a href="<?= e(url(['view' => 'match', 'id' => $match['match_uid']])) ?>"><?= e($match['team_a_name']) ?> vs <?= e($match['team_b_name']) ?></a></td>
                <td><?= e($match['score_a']) ?>–<?= e($match['score_b']) ?></td>
                <td><span class="status"><?= e($match['status']) ?></span></td>
                <td><?= e($match['map_count']) ?></td>
                <td><?= e($match['player_count']) ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
    <?= pagination($page, $perPage, $result['total'], ['view' => 'matches', 'per_page' => $perPage]) ?>
<?php endif; ?>
</div>
