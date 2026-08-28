<?php

declare(strict_types=1);

use function Kgb\ClanWar\Web\e;
use function Kgb\ClanWar\Web\url;

?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($title) ?> · <?= e($siteTitle) ?></title>
    <link rel="stylesheet" href="app.css">
</head>
<body>
<header class="shell">
    <a href="<?= e(url(['view' => 'matches'])) ?>"><strong><?= e($siteTitle) ?></strong></a>
    <nav class="primary" aria-label="Statistics views">
        <a href="<?= e(url(['view' => 'matches'])) ?>">Matches</a>
        <a href="<?= e(url(['view' => 'maps'])) ?>">Maps</a>
        <a href="<?= e(url(['view' => 'players'])) ?>">Players</a>
        <a href="<?= e(url(['view' => 'teams'])) ?>">Teams</a>
    </nav>
</header>
<main class="shell">
    <?= $content ?>
</main>
<footer>
    <div class="shell">Read-only KGB Clan War statistics.</div>
</footer>
</body>
</html>
