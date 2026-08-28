<?php

declare(strict_types=1);

use function Kgb\ClanWar\Web\e;
use function Kgb\ClanWar\Web\pagination;
use function Kgb\ClanWar\Web\url;

?>
<h1>Maps</h1>
<div class="panel">
<?php if ($result['items'] === []): ?><p class="empty">No map statistics have been recorded.</p><?php else: ?>
    <table>
        <thead><tr><th>Map</th><th>Matches</th><th>Records</th><th>Last recorded</th></tr></thead>
        <tbody><?php foreach ($result['items'] as $map): ?><tr>
            <td><a href="<?= e(url(['view' => 'map', 'id' => $map['map_name']])) ?>"><?= e($map['map_name']) ?></a></td>
            <td><?= e($map['match_count']) ?></td><td><?= e($map['map_records']) ?></td><td><?= e($map['last_recorded_at']) ?></td>
        </tr><?php endforeach; ?></tbody>
    </table>
    <?= pagination($page, $perPage, $result['total'], ['view' => 'maps', 'per_page' => $perPage]) ?>
<?php endif; ?>
</div>
