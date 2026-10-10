<?php

declare(strict_types=1);

namespace App\Services;

use Fatsoenlijk\CarPlay\CarPlay;
use Fatsoenlijk\CarPlay\Templates\Template;

/** Copy into a NativePHP application's app/Services directory. */
final class ParkingExperience
{
    public function __construct(private readonly CarPlay $car) {}

    public function publishHome(): array
    {
        return $this->car->setRoot(Template::list('parking', 'Nearby parking', [
            ['title' => 'Amsterdam', 'items' => [
                ['id' => 'centrum', 'title' => 'Centrum', 'detail' => '24 spaces', 'icon' => 'parking', 'action' => 'open-centrum'],
            ]],
        ]));
    }

    public function showMap(): array
    {
        return $this->car->push(Template::pointsOfInterest('nearby-map', 'Nearby', [
            ['id' => 'centrum', 'title' => 'Centrum', 'latitude' => 52.37, 'longitude' => 4.89,
             'subtitle' => '24 spaces', 'summary' => 'EV charging available',
             'actions' => [['id' => 'navigate-centrum', 'title' => 'Navigate']]],
        ]));
    }

    /** Call only after the application has deduplicated the native event UUID. */
    public function handleInteraction(array $event): ?array
    {
        $payload = $event['payload'];
        if ($event['type'] === 'itemSelected' && ($payload['actionId'] ?? null) === 'open-centrum') {
            return $this->car->push(Template::information('centrum-details', 'Centrum', [
                ['title' => 'Available', 'detail' => '24 spaces'],
                ['title' => 'Rate', 'detail' => '€ 2.50 per hour'],
            ], [['id' => 'navigate-centrum', 'title' => 'Navigate']]));
        }
        if ($event['type'] === 'actionPressed' && ($payload['actionId'] ?? null) === 'navigate-centrum') {
            return $this->car->navigate(52.37, 4.89, 'Centrum');
        }
        return null;
    }
}
