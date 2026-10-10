<?php

declare(strict_types=1);

namespace Fatsoenlijk\CarPlay;

use Fatsoenlijk\CarPlay\Contracts\Transport;
use Fatsoenlijk\CarPlay\Exceptions\BridgeException;

final class NativeTransport implements Transport
{
    public function call(string $method, array $parameters = []): array
    {
        if (!function_exists('nativephp_call')) {
            throw new BridgeException('RUNTIME_UNAVAILABLE', 'CarPlay requires a NativePHP Mobile runtime. Inject a Transport in desktop tests.');
        }
        $raw = nativephp_call($method, json_encode((object) $parameters, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
        try {
            $result = is_string($raw) ? json_decode($raw, true, 512, JSON_THROW_ON_ERROR) : $raw;
        } catch (\JsonException $e) {
            throw new BridgeException('INVALID_RESPONSE', $e->getMessage());
        }
        if (!is_array($result)) {
            throw new BridgeException('INVALID_RESPONSE', 'Native bridge must return a JSON object.');
        }
        if (($result['status'] ?? null) === 'error') {
            throw new BridgeException((string) ($result['code'] ?? 'NATIVE_ERROR'), (string) ($result['message'] ?? 'Native bridge failed.'));
        }
        // NativePHP 4 returns data directly. Older bridge envelopes are accepted too.
        if (($result['status'] ?? null) === 'success' && isset($result['data']) && is_array($result['data'])) {
            return $result['data'];
        }
        return $result;
    }
}
