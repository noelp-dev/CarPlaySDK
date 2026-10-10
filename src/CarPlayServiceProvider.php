<?php

declare(strict_types=1);

namespace Fatsoenlijk\CarPlay;

use Fatsoenlijk\CarPlay\Contracts\Transport;

final class CarPlayServiceProvider extends \Illuminate\Support\ServiceProvider
{
    public function register(): void
    {
        $this->mergeConfigFrom(__DIR__.'/../config/carplay.php', 'carplay');
        $this->app->singletonIf(Transport::class, NativeTransport::class);
        $this->app->singleton(CarPlay::class, fn ($app) => new CarPlay($app->make(Transport::class)));
    }
    public function boot(): void
    {
        if ($this->app->runningInConsole()) {
            $this->publishes([__DIR__.'/../config/carplay.php' => config_path('carplay.php')], 'carplay-config');
            $this->publishes([__DIR__.'/../resources/js' => resource_path('js/vendor/nativephp-carplay')], 'carplay-js');
            if (class_exists(\Native\Mobile\Plugins\Commands\NativePluginHookCommand::class)) {
                $this->commands([\Fatsoenlijk\CarPlay\Commands\ConfigureCarPlay::class]);
            }
        }
    }
}
