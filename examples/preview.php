<?php

declare(strict_types=1);

require __DIR__.'/../tests/bootstrap.php';

use Fatsoenlijk\CarPlay\Templates\Template;

// Runs without Laravel or a native runtime, to inspect the portable document.
$template = Template::pointsOfInterest('parking-map', 'Nearby parking', [
    ['id' => 'centrum', 'title' => 'Centrum', 'latitude' => 52.37, 'longitude' => 4.89,
     'subtitle' => '24 spaces', 'actions' => [['id' => 'navigate', 'title' => 'Navigate']]],
]);
echo json_encode($template, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR).PHP_EOL;
