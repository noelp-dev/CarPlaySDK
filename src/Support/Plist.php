<?php

declare(strict_types=1);

namespace Fatsoenlijk\CarPlay\Support;

/** XML-only property-list editor that preserves unrelated keys and phone scenes. */
final class Plist
{
    private \DOMDocument $document;
    private \DOMElement $root;

    public function __construct(string $xml)
    {
        $this->document = new \DOMDocument('1.0', 'UTF-8');
        $previous = libxml_use_internal_errors(true);
        try {
            if (!$this->document->loadXML($xml, LIBXML_NONET | LIBXML_NOBLANKS)) { throw new \InvalidArgumentException('Expected an XML plist. Convert binary plists first.'); }
        } finally { libxml_clear_errors(); libxml_use_internal_errors($previous); }
        $root = $this->document->documentElement;
        $dict = $root?->firstElementChild;
        if ($root?->tagName !== 'plist' || !$dict || $dict->tagName !== 'dict') { throw new \InvalidArgumentException('Expected a plist dictionary.'); }
        $this->root = $dict;
    }

    public static function empty(): self
    {
        return new self('<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict/></plist>');
    }

    public function get(array $path): mixed
    {
        $node = $this->root;
        foreach ($path as $key) {
            $node = $this->value($node, $key);
            if (!$node) { return null; }
        }
        return match ($node->tagName) { 'true' => true, 'false' => false, 'string' => $node->textContent, default => $node };
    }

    public function set(array $path, mixed $value): void
    {
        $parent = $this->root;
        $key = array_pop($path);
        foreach ($path as $part) {
            $next = $this->value($parent, $part);
            if (!$next) { $next = $this->document->createElement('dict'); $this->put($parent, $part, $next); }
            if ($next->tagName !== 'dict') { throw new \InvalidArgumentException("$part must be a dictionary."); }
            $parent = $next;
        }
        $this->put($parent, $key, $this->element($value));
    }

    /** Add our scene once, keeping other CarPlay scene declarations intact. */
    public function addCarPlayScene(): void
    {
        $path = ['UIApplicationSceneManifest', 'UISceneConfigurations', 'CPTemplateApplicationSceneSessionRoleApplication'];
        $scenes = $this->get($path);
        $scene = ['UISceneClassName' => 'CPTemplateApplicationScene', 'UISceneConfigurationName' => 'NativePHP CarPlay', 'UISceneDelegateClassName' => 'NativeCarPlaySceneDelegate'];
        if ($scenes === null) { $this->set($path, [$scene]); return; }
        if (!$scenes instanceof \DOMElement || $scenes->tagName !== 'array') { throw new \InvalidArgumentException('CarPlay scene configuration must be an array.'); }
        foreach ($scenes->childNodes as $child) {
            if ($child instanceof \DOMElement && $child->tagName === 'dict' && $this->value($child, 'UISceneDelegateClassName')?->textContent === 'NativeCarPlaySceneDelegate') { return; }
        }
        $scenes->appendChild($this->element($scene));
    }

    public function xml(): string { $this->document->formatOutput = true; return $this->document->saveXML(); }

    private function value(\DOMElement $dict, string $key): ?\DOMElement
    {
        if ($dict->tagName !== 'dict') { throw new \InvalidArgumentException('Expected dictionary at path.'); }
        foreach ($dict->childNodes as $child) {
            if ($child instanceof \DOMElement && $child->tagName === 'key' && $child->textContent === $key) { return $child->nextElementSibling; }
        }
        return null;
    }
    private function put(\DOMElement $dict, string $key, \DOMElement $value): void
    {
        $old = $this->value($dict, $key);
        if ($old) { $dict->replaceChild($value, $old); }
        else { $node = $this->document->createElement('key'); $node->appendChild($this->document->createTextNode($key)); $dict->appendChild($node); $dict->appendChild($value); }
    }
    private function element(mixed $value): \DOMElement
    {
        if (is_bool($value)) { return $this->document->createElement($value ? 'true' : 'false'); }
        if (is_array($value)) {
            $list = array_is_list($value); $node = $this->document->createElement($list ? 'array' : 'dict');
            foreach ($value as $key => $entry) { if ($list) { $node->appendChild($this->element($entry)); } else { $this->put($node, $key, $this->element($entry)); } }
            return $node;
        }
        if (!is_string($value)) { throw new \InvalidArgumentException('Unsupported plist value.'); }
        $node = $this->document->createElement('string'); $node->appendChild($this->document->createTextNode($value)); return $node;
    }
}
