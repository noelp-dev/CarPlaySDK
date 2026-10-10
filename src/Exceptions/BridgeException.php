<?php

declare(strict_types=1);

namespace Fatsoenlijk\CarPlay\Exceptions;

final class BridgeException extends \RuntimeException
{
    public function __construct(public readonly string $errorCode, string $message)
    {
        parent::__construct($message);
    }
}
