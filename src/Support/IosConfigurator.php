<?php

declare(strict_types=1);

namespace Fatsoenlijk\CarPlay\Support;

final class IosConfigurator
{
    public const ENTITLEMENTS = [
        'parking' => 'com.apple.developer.carplay-parking',
        'charging' => 'com.apple.developer.carplay-charging',
        'food' => 'com.apple.developer.carplay-quick-ordering',
        'audio' => 'com.apple.developer.carplay-audio',
    ];

    /** Prepare every edit before writing. The caller owns the generated build directory. */
    public static function prepare(string $project, string $category): array
    {
        if (!isset(self::ENTITLEMENTS[$category])) { throw new \InvalidArgumentException('CARPLAY_CATEGORY must be parking, charging, food, or audio. Use the category Apple approved.'); }
        $main = $project.'/NativePHP/Info.plist';
        if (!is_file($main)) { throw new \RuntimeException('NativePHP/Info.plist is missing. Run native:install first.'); }
        $entitlements = $project.'/NativePHP/NativePHP.entitlements';
        $plist = is_file($entitlements) ? new Plist(file_get_contents($entitlements)) : Plist::empty();
        foreach (self::ENTITLEMENTS as $other => $key) {
            if ($other !== $category && $plist->get([$key]) === true) { throw new \RuntimeException("Existing $other CarPlay entitlement conflicts with $category. Resolve the application category before rebuilding."); }
        }
        $plist->set([self::ENTITLEMENTS[$category]], true);
        $changes = [$entitlements => $plist->xml()];
        foreach ([$main, $project.'/NativePHP-simulator-Info.plist'] as $path) {
            if (!is_file($path)) { continue; }
            $plist = new Plist(file_get_contents($path)); $plist->set(['NativeCarPlayCategory'], $category);
            $plist->set(['UIApplicationSceneManifest', 'UIApplicationSupportsMultipleScenes'], true); $plist->addCarPlayScene();
            $changes[$path] = $plist->xml();
        }
        return $changes;
    }

    public static function write(array $changes): void
    {
        foreach ($changes as $path => $xml) {
            $temporary = tempnam(dirname($path), '.carplay-');
            if ($temporary === false) { throw new \RuntimeException("Cannot prepare $path."); }
            try {
                if (file_put_contents($temporary, $xml, LOCK_EX) === false || !rename($temporary, $path)) { throw new \RuntimeException("Cannot write $path."); }
            } finally { if (is_file($temporary)) { unlink($temporary); } }
        }
    }
}
