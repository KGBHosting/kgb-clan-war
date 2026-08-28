<?php

declare(strict_types=1);

use function Kgb\ClanWar\Web\e;
use function Kgb\ClanWar\Web\pagination;
use function Kgb\ClanWar\Web\url;

?>
<h1>Teams</h1>
<div class="panel">
<?php if ($result['items'] === []): ?><p class="empty">No team statistics have been recorded.</p><?php else: ?>
    <table>
        <thead><tr><th>Team</th><th>Matches</th><th>Completed</th><th>W</th><th>L</th><th>D</th><th>Stopped</th><th>Last match</th></tr></thead>
        <tbody><?php foreach ($result['items'] as $team): ?><tr>
            <td><a href="<?= e(url(['view' => 'team', 'id' => $team['team_name']])) ?>"><?= e($team['team_name']) ?></a></td>
            <td><?= e($team['match_count']) ?></td><td><?= e($team['completed_count']) ?></td><td><?= e($team['wins']) ?></td>
            <td><?= e($team['losses']) ?></td><td><?= e($team['draws']) ?></td><td><?= e($team['stopped_count']) ?></td><td><?= e($team['last_match_at']) ?></td>
        </tr><?php endforeach; ?></tbody>
    </table>
    <?= pagination($page, $perPage, $result['total'], ['view' => 'teams', 'per_page' => $perPage]) ?>
<?php endif; ?>
</div>
