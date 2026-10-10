<?php

declare(strict_types=1);

namespace Fatsoenlijk\CarPlay\Facades;

/** @mixin \Fatsoenlijk\CarPlay\CarPlay */
final class CarPlay extends \Illuminate\Support\Facades\Facade
{
    protected static function getFacadeAccessor(): string { return \Fatsoenlijk\CarPlay\CarPlay::class; }
}
