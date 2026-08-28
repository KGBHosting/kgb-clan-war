<?php

declare(strict_types=1);

use function Kgb\ClanWar\Web\e;
use function Kgb\ClanWar\Web\pagination;
use function Kgb\ClanWar\Web\player_label;
use function Kgb\ClanWar\Web\url;

?>
<h1>Players</h1>
<div class="panel">
<?php if ($result['items'] === []): ?><p class="empty">No player statistics have been recorded.</p><?php else: ?>
    <table>
        <thead><tr><th>Player</th><th>Latest name</th><th>Matches</th><th>Maps</th><th>K</th><th>D</th><th>HS</th><th>Last seen</th></tr></thead>
        <tbody><?php foreach ($result['items'] as $player): ?><tr>
            <td><a href="<?= e(url(['view' => 'player', 'id' => $player['player_key']])) ?>"><?= e(player_label($player, $showAuthIds)) ?></a></td>
            <td><?= e($player['player_name']) ?></td><td><?= e($player['match_count']) ?></td><td><?= e($player['map_count']) ?></td>
            <td><?= e($player['kills']) ?></td><td><?= e($player['deaths']) ?></td><td><?= e($player['headshots']) ?></td><td><?= e($player['last_seen_at']) ?></td>
        </tr><?php endforeach; ?></tbody>
    </table>
    <?= pagination($page, $perPage, $result['total'], ['view' => 'players', 'per_page' => $perPage]) ?>
<?php endif; ?>
</div>
