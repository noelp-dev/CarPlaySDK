<?php

declare(strict_types=1);

namespace Fatsoenlijk\CarPlay\Commands;

use Fatsoenlijk\CarPlay\Support\IosConfigurator;
use Native\Mobile\Plugins\Commands\NativePluginHookCommand;

final class ConfigureCarPlay extends NativePluginHookCommand
{
    protected $signature = 'carplay:configure {--dry-run : Report changes without writing}';
    protected $description = 'Configure the generated CarPlay scenes and the selected application entitlement';

    public function handle(): int
    {
        if ($this->isAndroid()) { return self::SUCCESS; }
        if (!$this->isIos() || $this->buildPath() === '') { $this->error('Pass --platform=ios --build-path=/path/to/nativephp/ios.'); return self::FAILURE; }
        try {
            $changes = IosConfigurator::prepare($this->buildPath(), (string) config('carplay.category'));
            foreach (array_keys($changes) as $file) { $this->line($file); }
            if (!$this->option('dry-run')) { IosConfigurator::write($changes); }
            $this->info('CarPlay configuration prepared. Provisioning must include the selected entitlement.');
            return self::SUCCESS;
        } catch (\Throwable $e) { $this->error($e->getMessage()); return self::FAILURE; }
    }
}
