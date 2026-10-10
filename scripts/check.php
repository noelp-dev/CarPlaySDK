<?php

declare(strict_types=1);

$root = dirname(__DIR__);
$manifest = json_decode(file_get_contents($root.'/nativephp.json'), true, 512, JSON_THROW_ON_ERROR);
$composer = json_decode(file_get_contents($root.'/composer.json'), true, 512, JSON_THROW_ON_ERROR);
if ($composer['type'] !== 'nativephp-plugin') { throw new RuntimeException('Wrong Composer type'); }
$swift = implode("\n", array_map('file_get_contents', glob($root.'/resources/ios/Sources/*.swift')));
$kotlin = implode("\n", array_map('file_get_contents', glob($root.'/resources/android/src/*.kt')));
$seen = [];
foreach ($manifest['bridge_functions'] as $function) {
    $name = substr($function['name'], strlen('CarPlay.'));
    if (isset($seen[$name])) { throw new RuntimeException('Duplicate bridge function'); } $seen[$name] = true;
    if ($function['ios'] !== 'CarPlayFunctions.'.$name || $function['android'] !== 'dev.fatsoenlijk.carplay.CarPlayFunctions.'.$name) { throw new RuntimeException('Invalid class mapping'); }
    if (!preg_match('/class '.preg_quote($name, '/').': BridgeFunction/', $swift) || !preg_match('/class '.preg_quote($name, '/').'\(/', $kotlin)) { throw new RuntimeException("Missing native implementation: $name"); }
    if ($function['android_params'] !== [$name === 'BindEvents' ? 'activity' : 'context']) { throw new RuntimeException('Invalid constructor arguments'); }
}
foreach ($manifest['assets']['android'] as $source => $destination) {
    if (!is_file($root.'/resources/'.$source) || !str_starts_with($destination, 'res/')) { throw new RuntimeException('Missing Android resource'); }
}
foreach ($manifest['events'] as $event) {
    $path = $root.'/src/'.str_replace('\\', '/', substr($event, strlen('Fatsoenlijk\\CarPlay\\'))).'.php';
    if (!is_file($path)) { throw new RuntimeException('Missing event class'); }
}
foreach (glob($root.'/resources/android/src/*.kt') as $file) {
    if (!str_starts_with(file_get_contents($file), 'package dev.fatsoenlijk.carplay')) { throw new RuntimeException('Unnamespaced Kotlin file'); }
}
if ($manifest['hooks']['post_compile'] !== 'carplay:configure') { throw new RuntimeException('Missing configuration hook'); }
if (!str_contains($composer['extra']['laravel']['providers'][0], 'CarPlayServiceProvider')) { throw new RuntimeException('Missing provider'); }
echo 'PASS: Composer/manifest, '.count($seen)." native mappings, constructor arguments, assets and event registration\n";

// Optional check against a locally downloaded upstream NativePHP PluginManifest.php.
if (isset($argv[1])) {
    require $argv[1];
    new \Native\Mobile\Plugins\PluginManifest($manifest);
    echo "PASS: upstream NativePHP manifest parser\n";
}
