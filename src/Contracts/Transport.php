<?php

declare(strict_types=1);

namespace Fatsoenlijk\CarPlay\Contracts;

interface Transport
{
    /** @return array<string, mixed> */
    public function call(string $method, array $parameters = []): array;
}
