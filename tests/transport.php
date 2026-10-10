<?php

declare(strict_types=1);

require __DIR__.'/bootstrap.php';

use Fatsoenlijk\CarPlay\Exceptions\BridgeException;
use Fatsoenlijk\CarPlay\NativeTransport;

$reply = '{}'; $calls = [];
function nativephp_call(string $method, string $parameters): mixed {
    global $reply, $calls; $calls[] = [$method, $parameters]; return $reply;
}

$transport = new NativeTransport(); $passed = 0;
foreach ([['{"connected":false}', ['connected' => false]], ['{"accepted":true,"operationId":"op"}', ['accepted' => true, 'operationId' => 'op']], ['{"status":"success","data":{"connected":true}}', ['connected' => true]], ['{}', []]] as [$reply, $expected]) {
    if ($transport->call('CarPlay.Status') !== $expected) { throw new RuntimeException('Response mismatch'); } $passed++;
}
if ($calls[0] !== ['CarPlay.Status', '{}']) { throw new RuntimeException('Empty parameters must be an object.'); } $passed++;
foreach ([['{"status":"error","code":"UNSUPPORTED","message":"No modal"}', 'UNSUPPORTED'], ['null', 'INVALID_RESPONSE'], ['not json', 'INVALID_RESPONSE'], [false, 'INVALID_RESPONSE']] as [$reply, $code]) {
    try { $transport->call('CarPlay.Status'); } catch (BridgeException $e) {
        if ($e->errorCode !== $code) { throw new RuntimeException('Wrong response error code'); } $passed++; continue;
    }
    throw new RuntimeException('Expected bridge exception');
}
echo "PASS: $passed native transport checks\n";
