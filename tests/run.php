<?php

declare(strict_types=1);

require __DIR__.'/bootstrap.php';

use Fatsoenlijk\CarPlay\CarPlay;
use Fatsoenlijk\CarPlay\Contracts\Transport;
use Fatsoenlijk\CarPlay\Exceptions\BridgeException;
use Fatsoenlijk\CarPlay\NativeTransport;
use Fatsoenlijk\CarPlay\Support\IosConfigurator;
use Fatsoenlijk\CarPlay\Support\Plist;
use Fatsoenlijk\CarPlay\Templates\Template;

$passed = 0;
function check(bool $condition, string $name): void { global $passed; if (!$condition) { throw new RuntimeException($name); } $passed++; }
function rejects(callable $callback, string $name, string $class = InvalidArgumentException::class): void {
    try { $callback(); } catch (Throwable $e) { check($e instanceof $class, $name.' threw '.get_class($e)); return; }
    throw new RuntimeException($name.' did not reject');
}

foreach (json_decode(file_get_contents(__DIR__.'/Fixtures/templates.json'), true, 512, JSON_THROW_ON_ERROR) as $case) {
    try { $template = Template::fromArray($case['template']); $valid = true; }
    catch (InvalidArgumentException) { $valid = false; }
    check($valid === $case['valid'], $case['name']);
    if ($valid) { check($template->toArray() === $case['template'], 'Lossless template serialization'); }
}

$transport = new class implements Transport {
    public array $calls = [];
    public function call(string $method, array $parameters = []): array {
        $this->calls[] = [$method, $parameters]; return ['accepted' => true, 'operationId' => 'op-1'];
    }
};
$car = new CarPlay($transport);
$list = Template::list('root', 'Parking', [['items' => [['id' => 'garage', 'title' => 'Garage']]]]);
$car->setRoot($list); $car->push($list); $car->replace($list); $car->pop(); $car->popToRoot();
$car->present(Template::alert('confirm', 'Confirm', [['id' => 'ok', 'title' => 'OK']]));
$car->dismiss(); $car->clear(); $car->navigate(52.37, 4.89, 'Garage'); $car->events(20); $car->acknowledge(['event-1']); $car->bindEvents(); $car->status(); $car->capabilities();
$manifest = json_decode(file_get_contents(__DIR__.'/../nativephp.json'), true, 512, JSON_THROW_ON_ERROR);
$names = array_column($manifest['bridge_functions'], 'name');
check(count(array_unique(array_column($transport->calls, 0))) === count($names), 'PHP covers all registered bridge methods');
foreach ($transport->calls as [$name]) { check(in_array($name, $names, true), "$name registration"); }
check($transport->calls[0][1]['template'] === $list->toArray(), 'Root payload');
check($transport->calls[8][1] === ['latitude' => 52.37, 'longitude' => 4.89, 'name' => 'Garage'], 'Navigation payload');
rejects(fn () => $car->present($list), 'Wrong modal type');
rejects(fn () => $car->navigate(NAN, 0), 'NaN latitude');
rejects(fn () => $car->navigate(0, INF), 'Infinite longitude');
rejects(fn () => $car->events(0), 'Zero limit');
rejects(fn () => $car->events(257), 'Oversized limit');
rejects(fn () => $car->acknowledge([5]), 'Numeric event IDs');
rejects(fn () => $car->acknowledge(['id' => 'value']), 'Associative event IDs');
rejects(fn () => (new NativeTransport())->call('CarPlay.Status'), 'Unavailable runtime', BridgeException::class);

$plist = new Plist('<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleName</key><string>App &amp; Car</string><key>UIApplicationSceneManifest</key><dict><key>UISceneConfigurations</key><dict><key>UIWindowSceneSessionRoleApplication</key><array><dict><key>UISceneDelegateClassName</key><string>PhoneScene</string></dict></array></dict></dict></dict></plist>');
$plist->addCarPlayScene(); $once = $plist->xml(); $plist->addCarPlayScene();
check($once === $plist->xml(), 'Idempotent scene insertion');
check($plist->get(['CFBundleName']) === 'App & Car', 'Preserves XML escaping and app metadata');
check(str_contains($plist->xml(), 'PhoneScene'), 'Preserves phone scene');
rejects(fn () => new Plist('not xml'), 'Malformed plist');
$project = sys_get_temp_dir().'/carplay-config-test-'.bin2hex(random_bytes(6)); mkdir($project.'/NativePHP', 0777, true);
try {
    file_put_contents($project.'/NativePHP/Info.plist', $plist->xml());
    file_put_contents($project.'/NativePHP-simulator-Info.plist', $plist->xml());
    $original = file_get_contents($project.'/NativePHP/Info.plist');
    $changes = IosConfigurator::prepare($project, 'parking');
    check(file_get_contents($project.'/NativePHP/Info.plist') === $original, 'Prepare does not write');
    IosConfigurator::write($changes);
    $entitlements = new Plist(file_get_contents($project.'/NativePHP/NativePHP.entitlements'));
    check($entitlements->get(['com.apple.developer.carplay-parking']) === true, 'Parking entitlement');
    $updated = new Plist(file_get_contents($project.'/NativePHP/Info.plist'));
    check($updated->get(['NativeCarPlayCategory']) === 'parking', 'Native category configuration');
    check(str_contains($updated->xml(), 'PhoneScene'), 'Configure preserves phone scenes');
    check(IosConfigurator::prepare($project, 'parking') === $changes, 'Idempotent build configuration');
    rejects(fn () => IosConfigurator::prepare($project, 'communication'), 'Unimplemented category');
    rejects(fn () => IosConfigurator::prepare($project, 'audio'), 'Conflicting entitlements', RuntimeException::class);
} finally {
    foreach (glob($project.'/NativePHP/*') as $file) { unlink($file); }
    unlink($project.'/NativePHP-simulator-Info.plist'); rmdir($project.'/NativePHP'); rmdir($project);
}

echo "PASS: $passed PHP checks\n";
