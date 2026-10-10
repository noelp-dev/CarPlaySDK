<?php

declare(strict_types=1);

namespace Fatsoenlijk\CarPlay;

final class TemplateValidator
{
    public const TYPES = ['list', 'grid', 'information', 'message', 'search', 'tabs', 'poi', 'alert', 'nowPlaying'];
    public const ICONS = ['list', 'grid', 'search', 'map', 'pin', 'parking', 'charging', 'food', 'music', 'play', 'pause', 'info', 'star', 'home'];

    public static function validate(array $template): void
    {
        self::noNulls($template);
        $ids = [];
        self::node($template, $ids, false);
        if (strlen(json_encode($template, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)) > 262144) {
            self::fail('Template exceeds 256 KiB.');
        }
    }

    private static function node(array $t, array &$ids, bool $tab): void
    {
        self::id($t['id'] ?? null);
        if (isset($ids[$t['id']])) { self::fail('Template IDs must be unique within a tree.'); }
        $ids[$t['id']] = true;
        $type = $t['type'] ?? null;
        if (!in_array($type, self::TYPES, true)) { self::fail('Unknown template type.'); }
        self::text($t['title'] ?? null, 'title');
        if (isset($t['icon']) && !in_array($t['icon'], self::ICONS, true)) { self::fail('Unknown icon.'); }
        if ($tab && !in_array($type, ['list', 'grid'], true)) { self::fail('Unsupported tab child.'); }
        $fields = match ($type) {
            'list' => ['sections', 'loading'], 'grid' => ['items'], 'information' => ['items', 'actions'],
            'message' => ['message', 'actions'], 'search' => ['items', 'hint'],
            'tabs' => ['tabs'], 'poi' => ['points'], 'alert' => ['actions'], default => [],
        };
        self::keys($t, array_merge(['id', 'type', 'title', 'icon'], $fields));
        if (isset($t['loading']) && !is_bool($t['loading'])) { self::fail('loading must be boolean.'); }
        if ($type === 'list') {
            self::sequence($t['sections'] ?? null, 1, 10, 'sections');
            $count = 0; $rowIds = [];
            foreach ($t['sections'] as $section) {
                self::object($section); self::keys($section, ['title', 'items']);
                if (isset($section['title'])) { self::text($section['title'], 'section title', true); }
                self::sequence($section['items'] ?? null, 0, 100, 'items');
                foreach ($section['items'] as $item) { self::item($item, $rowIds); $count++; }
            }
            if ($count > 100) { self::fail('At most 100 list items.'); }
        }
        if (in_array($type, ['grid', 'search', 'information'], true)) {
            self::sequence($t['items'] ?? null, $type === 'search' ? 0 : 1, match ($type) { 'grid' => 8, 'information' => 4, default => 100 }, 'items');
            $rowIds = [];
            foreach ($t['items'] as $item) {
                if ($type === 'information') {
                    self::object($item); self::keys($item, ['title', 'detail']); self::text($item['title'] ?? null, 'item title');
                    if (isset($item['detail'])) { self::text($item['detail'], 'detail', true); }
                } else { self::item($item, $rowIds, $type === 'grid'); }
            }
        }
        if ($type === 'message') { self::text($t['message'] ?? null, 'message'); }
        if (isset($t['hint'])) { self::text($t['hint'], 'hint'); }
        if (isset($t['actions']) || $type === 'alert') {
            self::sequence($t['actions'] ?? null, $type === 'alert' ? 1 : 0, 2, 'actions'); $actionIds = [];
            foreach ($t['actions'] as $action) { self::action($action, $actionIds); }
        }
        if ($type === 'tabs') {
            self::sequence($t['tabs'] ?? null, 2, 4, 'tabs');
            foreach ($t['tabs'] as $child) { self::object($child); self::node($child, $ids, true); }
        }
        if ($type === 'poi') {
            self::sequence($t['points'] ?? null, 1, 6, 'points'); $pointIds = [];
            foreach ($t['points'] as $p) {
                self::object($p); self::keys($p, ['id', 'title', 'subtitle', 'summary', 'latitude', 'longitude', 'actions']);
                self::unique($p['id'] ?? null, $pointIds); self::text($p['title'] ?? null, 'point title');
                foreach (['subtitle', 'summary'] as $field) { if (isset($p[$field])) { self::text($p[$field], $field, true); } }
                if (!is_numeric($p['latitude'] ?? null) || !is_numeric($p['longitude'] ?? null) || is_string($p['latitude']) || is_string($p['longitude'])) { self::fail('Coordinates must be numbers.'); }
                self::coordinate((float) $p['latitude'], (float) $p['longitude']);
                if (isset($p['actions'])) {
                    self::sequence($p['actions'], 0, 2, 'point actions'); $actionIds = [];
                    foreach ($p['actions'] as $action) { self::action($action, $actionIds); }
                }
            }
        }
    }

    private static function item(mixed $item, array &$ids, bool $grid = false): void
    {
        self::object($item); self::keys($item, ['id', 'title', 'detail', 'icon', 'action', 'enabled']);
        self::unique($item['id'] ?? null, $ids); self::text($item['title'] ?? null, 'item title');
        if (isset($item['detail'])) { self::text($item['detail'], 'detail', true); }
        if (isset($item['action'])) { self::id($item['action']); }
        if (isset($item['enabled']) && !is_bool($item['enabled'])) { self::fail('enabled must be boolean.'); }
        if (isset($item['icon']) && !in_array($item['icon'], self::ICONS, true)) { self::fail('Unknown icon.'); }
        if ($grid && !isset($item['icon'])) { self::fail('Grid items require an icon.'); }
    }

    private static function action(mixed $a, array &$ids): void
    {
        self::object($a); self::keys($a, ['id', 'title', 'style']); self::unique($a['id'] ?? null, $ids); self::text($a['title'] ?? null, 'action title');
        if (isset($a['style']) && !in_array($a['style'], ['normal', 'cancel', 'destructive'], true)) { self::fail('Unknown action style.'); }
    }

    public static function coordinate(float $latitude, float $longitude): void
    {
        if (!is_finite($latitude) || !is_finite($longitude) || abs($latitude) > 90 || abs($longitude) > 180) { self::fail('Invalid geographic coordinates.'); }
    }

    private static function noNulls(array $value): void
    {
        foreach ($value as $entry) {
            if ($entry === null) { self::fail('Null is not a template value; omit optional fields.'); }
            if (is_array($entry)) { self::noNulls($entry); }
        }
    }

    private static function unique(mixed $id, array &$ids): void
    {
        self::id($id); if (isset($ids[$id])) { self::fail('Duplicate item or action ID.'); } $ids[$id] = true;
    }
    private static function id(mixed $id): void
    {
        if (!is_string($id) || !preg_match('/^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$/D', $id)) { self::fail('ID must be 1..128 ASCII letters, numbers, _, ., :, or -.'); }
    }
    private static function text(mixed $value, string $field, bool $empty = false): void
    {
        if (!is_string($value) || (!$empty && trim($value) === '') || strlen($value) > 512 || preg_match('//u', $value) !== 1) { self::fail("$field must be valid UTF-8 text, up to 512 bytes."); }
    }
    private static function sequence(mixed $value, int $min, int $max, string $field): void
    {
        if (!is_array($value) || !array_is_list($value) || count($value) < $min || count($value) > $max) { self::fail("$field requires $min..$max entries."); }
    }
    private static function object(mixed $value): void { if (!is_array($value) || array_is_list($value)) { self::fail('Expected an object.'); } }
    private static function keys(array $value, array $allowed): void { if (array_diff(array_keys($value), $allowed)) { self::fail('Unknown template field.'); } }
    private static function fail(string $message): never { throw new \InvalidArgumentException($message); }
}
