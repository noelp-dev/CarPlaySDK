<?php

declare(strict_types=1);

namespace Fatsoenlijk\CarPlay\Templates;

use Fatsoenlijk\CarPlay\TemplateValidator;

/** Immutable wire-format value object. Native templates never embed HTML. */
final class Template implements \JsonSerializable
{
    private function __construct(private readonly array $value)
    {
        TemplateValidator::validate($value);
    }

    public static function fromArray(array $value): self { return new self($value); }

    public static function list(string $id, string $title, array $sections, bool $loading = false): self
    {
        return new self(compact('id', 'title', 'sections', 'loading') + ['type' => 'list']);
    }

    public static function grid(string $id, string $title, array $items): self
    {
        return new self(compact('id', 'title', 'items') + ['type' => 'grid']);
    }

    public static function information(string $id, string $title, array $items, array $actions = []): self
    {
        return new self(compact('id', 'title', 'items', 'actions') + ['type' => 'information']);
    }

    public static function message(string $id, string $title, string $message, array $actions = []): self
    {
        return new self(compact('id', 'title', 'message', 'actions') + ['type' => 'message']);
    }

    public static function search(string $id, string $title, array $items = [], string $hint = 'Search'): self
    {
        return new self(compact('id', 'title', 'items', 'hint') + ['type' => 'search']);
    }

    public static function tabs(string $id, string $title, array $tabs): self
    {
        return new self(['id' => $id, 'title' => $title, 'type' => 'tabs', 'tabs' => array_map(fn ($tab) => $tab instanceof self ? $tab->toArray() : $tab, $tabs)]);
    }

    public static function pointsOfInterest(string $id, string $title, array $points): self
    {
        return new self(compact('id', 'title', 'points') + ['type' => 'poi']);
    }

    public static function alert(string $id, string $title, array $actions): self
    {
        return new self(compact('id', 'title', 'actions') + ['type' => 'alert']);
    }

    /** Display only; the application must supply a real audio session/player. */
    public static function nowPlaying(string $id = 'now-playing'): self
    {
        return new self(['id' => $id, 'title' => 'Now Playing', 'type' => 'nowPlaying']);
    }

    public function withIcon(string $icon): self { return new self(array_replace($this->value, ['icon' => $icon])); }
    public function toArray(): array { return $this->value; }
    public function jsonSerialize(): array { return $this->value; }
}
