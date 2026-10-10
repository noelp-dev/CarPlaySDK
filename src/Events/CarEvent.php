<?php

declare(strict_types=1);

namespace Fatsoenlijk\CarPlay\Events;

/** Immediate notification of an event also available through CarPlay::events(). */
final class CarEvent
{
    public function __construct(
        public string $id,
        public string $type,
        public string $platform,
        public float $timestamp,
        public array $payload = [],
    ) {}
}
