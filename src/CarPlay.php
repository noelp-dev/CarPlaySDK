<?php

declare(strict_types=1);

namespace Fatsoenlijk\CarPlay;

use Fatsoenlijk\CarPlay\Contracts\Transport;
use Fatsoenlijk\CarPlay\Templates\Template;

final class CarPlay
{
    public function __construct(private readonly Transport $transport = new NativeTransport()) {}

    public function capabilities(): array { return $this->transport->call('CarPlay.Capabilities'); }
    public function status(): array { return $this->transport->call('CarPlay.Status'); }
    public function setRoot(Template $template): array { return $this->transport->call('CarPlay.SetRoot', ['template' => $template->toArray()]); }
    public function push(Template $template): array { return $this->transport->call('CarPlay.Push', ['template' => $template->toArray()]); }
    public function replace(Template $template): array { return $this->transport->call('CarPlay.Replace', ['template' => $template->toArray()]); }
    public function pop(): array { return $this->transport->call('CarPlay.Pop'); }
    public function popToRoot(): array { return $this->transport->call('CarPlay.PopToRoot'); }
    public function present(Template $alert): array
    {
        if ($alert->toArray()['type'] !== 'alert') { throw new \InvalidArgumentException('present requires an alert template.'); }
        return $this->transport->call('CarPlay.Present', ['template' => $alert->toArray()]);
    }
    public function dismiss(): array { return $this->transport->call('CarPlay.Dismiss'); }
    public function clear(): array { return $this->transport->call('CarPlay.Clear'); }

    /** Hand off a destination to Apple Maps or the Android Auto host navigation app. */
    public function navigate(float $latitude, float $longitude, string $name = ''): array
    {
        TemplateValidator::coordinate($latitude, $longitude);
        if (strlen($name) > 512) { throw new \InvalidArgumentException('Destination name exceeds 512 bytes.'); }
        return $this->transport->call('CarPlay.Navigate', compact('latitude', 'longitude', 'name'));
    }

    /** At-least-once queue: acknowledge only after successfully handling an event. */
    public function events(int $limit = 100): array
    {
        if ($limit < 1 || $limit > 256) { throw new \InvalidArgumentException('Event limit must be 1..256.'); }
        return $this->transport->call('CarPlay.Events', ['limit' => $limit]);
    }

    public function acknowledge(array $ids): array
    {
        if (!array_is_list($ids) || count($ids) > 256 || array_filter($ids, fn ($id) => !is_string($id) || $id === '' || strlen($id) > 128)) {
            throw new \InvalidArgumentException('Expected up to 256 event ID strings.');
        }
        return $this->transport->call('CarPlay.Acknowledge', ['ids' => $ids]);
    }

    /** Optional immediate event forwarding; polling works without a foreground Activity. */
    public function bindEvents(): array { return $this->transport->call('CarPlay.BindEvents'); }
}
