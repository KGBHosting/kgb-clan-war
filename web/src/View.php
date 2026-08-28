<?php

declare(strict_types=1);

namespace Kgb\ClanWar\Web;

use RuntimeException;

final class View
{
    public function __construct(
        private readonly string $templateDirectory,
        private readonly string $siteTitle,
    ) {
    }

    /** @param array<string, mixed> $data */
    public function render(string $template, string $title, array $data = []): string
    {
        if (!preg_match('/^[a-z_]+$/D', $template)) {
            throw new RuntimeException('Invalid internal template name.');
        }

        $templatePath = $this->templateDirectory . '/' . $template . '.php';
        $layoutPath = $this->templateDirectory . '/layout.php';
        if (!is_file($templatePath) || !is_file($layoutPath)) {
            throw new RuntimeException('A required view template is missing.');
        }

        extract($data, EXTR_SKIP);
        ob_start();
        require $templatePath;
        $content = (string) ob_get_clean();

        $siteTitle = $this->siteTitle;
        ob_start();
        require $layoutPath;

        return (string) ob_get_clean();
    }
}
