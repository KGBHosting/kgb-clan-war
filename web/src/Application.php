<?php

declare(strict_types=1);

namespace Kgb\ClanWar\Web;

final class Application
{
    public function __construct(
        private readonly StatsRepository $repository,
        private readonly View $view,
        private readonly int $defaultPageSize,
        private readonly int $maximumPageSize,
        private readonly bool $showAuthIds,
    ) {
    }

    /** @param array<string, mixed> $query */
    public function handle(array $query): Response
    {
        $route = is_string($query['view'] ?? null) ? $query['view'] : 'matches';
        $page = Input::page($query['page'] ?? 1);
        $perPage = Input::perPage($query['per_page'] ?? $this->defaultPageSize, $this->defaultPageSize, $this->maximumPageSize);

        return match ($route) {
            'matches' => $this->matches($page, $perPage),
            'match' => $this->match($query['id'] ?? null),
            'maps' => $this->maps($page, $perPage),
            'map' => $this->map($query['id'] ?? null, $page, $perPage),
            'players' => $this->players($page, $perPage),
            'player' => $this->player($query['id'] ?? null, $page, $perPage),
            'teams' => $this->teams($page, $perPage),
            'team' => $this->team($query['id'] ?? null, $page, $perPage),
            default => $this->notFound(),
        };
    }

    private function matches(int $page, int $perPage): Response
    {
        return new Response(200, $this->view->render('matches', 'Matches', [
            'result' => $this->repository->matches($page, $perPage),
            'page' => $page,
            'perPage' => $perPage,
        ]));
    }

    private function match(mixed $value): Response
    {
        $matchUid = Input::matchUid($value);
        if ($matchUid === null || ($match = $this->repository->match($matchUid)) === null) {
            return $this->notFound();
        }

        return new Response(200, $this->view->render('match', $match['team_a_name'] . ' vs ' . $match['team_b_name'], [
            'match' => $match,
            'maps' => $this->repository->matchMaps($matchUid),
            'halves' => $this->repository->matchHalves($matchUid),
            'players' => $this->repository->matchPlayers($matchUid),
            'showAuthIds' => $this->showAuthIds,
        ]));
    }

    private function maps(int $page, int $perPage): Response
    {
        return new Response(200, $this->view->render('maps', 'Maps', [
            'result' => $this->repository->maps($page, $perPage),
            'page' => $page,
            'perPage' => $perPage,
        ]));
    }

    private function map(mixed $value, int $page, int $perPage): Response
    {
        $mapName = Input::label($value);
        if ($mapName === null || ($summary = $this->repository->mapSummary($mapName)) === null) {
            return $this->notFound();
        }

        return new Response(200, $this->view->render('map', 'Map ' . $mapName, [
            'summary' => $summary,
            'matches' => $this->repository->mapMatches($mapName, $page, $perPage),
            'players' => $this->repository->mapPlayers($mapName),
            'page' => $page,
            'perPage' => $perPage,
            'showAuthIds' => $this->showAuthIds,
        ]));
    }

    private function players(int $page, int $perPage): Response
    {
        return new Response(200, $this->view->render('players', 'Players', [
            'result' => $this->repository->players($page, $perPage),
            'page' => $page,
            'perPage' => $perPage,
            'showAuthIds' => $this->showAuthIds,
        ]));
    }

    private function player(mixed $value, int $page, int $perPage): Response
    {
        $playerKey = Input::playerKey($value);
        if ($playerKey === null || ($player = $this->repository->playerByKey($playerKey)) === null) {
            return $this->notFound();
        }

        return new Response(200, $this->view->render('player', 'Player ' . $player['player_name'], [
            'player' => $player,
            'matches' => $this->repository->playerMatches($player['auth_id'], $page, $perPage),
            'page' => $page,
            'perPage' => $perPage,
            'showAuthIds' => $this->showAuthIds,
        ]));
    }

    private function teams(int $page, int $perPage): Response
    {
        return new Response(200, $this->view->render('teams', 'Teams', [
            'result' => $this->repository->teams($page, $perPage),
            'page' => $page,
            'perPage' => $perPage,
        ]));
    }

    private function team(mixed $value, int $page, int $perPage): Response
    {
        $teamName = Input::label($value);
        if ($teamName === null || ($summary = $this->repository->teamSummary($teamName)) === null) {
            return $this->notFound();
        }

        return new Response(200, $this->view->render('team', 'Team ' . $teamName, [
            'summary' => $summary,
            'matches' => $this->repository->teamMatches($teamName, $page, $perPage),
            'page' => $page,
            'perPage' => $perPage,
        ]));
    }

    private function notFound(): Response
    {
        return new Response(404, $this->view->render('error', 'Not found', [
            'message' => 'The requested statistics view was not found.',
        ]));
    }
}
