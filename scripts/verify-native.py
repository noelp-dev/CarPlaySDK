#!/usr/bin/env python3
"""Compile with real platform SDKs; run shared contracts without a car or phone.

The only stand-ins are NativePHP BridgeFunction/BridgeResponse and its event sink.
This is deliberately not an end-to-end app/device test.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def run(args, env=None):
    subprocess.run([str(a) for a in args], cwd=ROOT, env=env, check=True)


def swift(build):
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    sources = sorted((ROOT / 'resources/ios/Sources').glob('*.swift'))
    cache = build / 'swift-module-cache'
    run(['xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-typecheck', '-swift-version', '5', '-target', 'arm64-apple-ios18.0-simulator', '-sdk', sdk, '-module-cache-path', cache, ROOT / 'tests/native/BridgeHost.swift', *sources])
    print('PASS: all Swift bridge/renderers against the real iOS SDK', flush=True)
    run(['swiftc', '-swift-version', '5', '-module-cache-path', cache, ROOT / 'resources/ios/Sources/CarContract.swift', ROOT / 'tests/native/ContractTests.swift', '-o', build / 'swift-contract-tests'])
    run([build / 'swift-contract-tests', ROOT / 'tests/Fixtures/templates.json'])
    run(['swiftc', '-swift-version', '5', '-module-cache-path', cache, ROOT / 'resources/ios/Sources/CarEventStore.swift', ROOT / 'tests/native/BridgeHost.swift', ROOT / 'tests/native/QueueTests.swift', '-o', build / 'swift-queue-tests'])
    run([build / 'swift-queue-tests', build])


def android(build, args):
    cache = Path(args.dependencies).resolve() if args.dependencies else build / 'android-dependencies'
    cache.mkdir(parents=True, exist_ok=True)
    dependencies = json.loads((ROOT / 'tests/native/dependencies.json').read_text())
    jars = []
    for d in dependencies:
        path = cache / d['file']
        if not path.exists():
            if args.no_download:
                raise RuntimeError(f'Missing {path}; omit --no-download to fetch pinned dependencies.')
            run(['curl', '--fail', '--location', '--silent', '--show-error', '--retry', '2', '--connect-timeout', '15', '--max-time', '120', d['url'], '-o', path])
        if hashlib.sha256(path.read_bytes()).hexdigest() != d['sha256']:
            raise RuntimeError(f'Checksum mismatch: {path}')
        if path.suffix == '.aar':
            jar = path.with_suffix('.jar')
            with zipfile.ZipFile(path) as archive:
                jar.write_bytes(archive.read('classes.jar'))
        else:
            jar = path
        jars.append(jar)
    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or Path.home() / 'Library/Android/sdk')
    android_jar = sdk / 'platforms/android-36/android.jar'
    if not android_jar.exists():
        raise RuntimeError('Install Android SDK Platform 36 or set ANDROID_HOME.')
    bundled = Path('/Applications/Android Studio.app/Contents/plugins/Kotlin/kotlinc/bin/kotlinc')
    compiler = os.environ.get('KOTLINC') or shutil.which('kotlinc') or str(bundled)
    env = dict(os.environ)
    bundled_java = Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home')
    if not env.get('JAVA_HOME') and bundled_java.exists():
        env['JAVA_HOME'] = str(bundled_java)
    java = Path(env['JAVA_HOME']) / 'bin/java' if env.get('JAVA_HOME') else 'java'
    classpath = os.pathsep.join(str(p) for p in [android_jar, *jars])
    sources = sorted((ROOT / 'resources/android/src').glob('*.kt'))
    run([compiler, '-jvm-target', '17', '-classpath', classpath, '-d', build / 'android-bridge.jar', *sources, ROOT / 'tests/native/BridgeHost.kt', ROOT / 'tests/native/EventHost.kt'], env)
    print('PASS: all Kotlin bridge/service/renderers against Android and AndroidX 1.7.0', flush=True)
    json_jar = next(p for p in jars if p.name == 'json-jvm.jar')
    run([compiler, '-jvm-target', '17', '-classpath', json_jar, '-include-runtime', '-d', build / 'kotlin-contract-tests.jar', ROOT / 'resources/android/src/CarContract.kt', ROOT / 'tests/native/ContractTests.kt'], env)
    run([java, '-cp', os.pathsep.join([str(build / 'kotlin-contract-tests.jar'), str(json_jar)]), 'dev.fatsoenlijk.carplay.ContractTestsKt', ROOT / 'tests/Fixtures/templates.json'], env)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['all', 'ios', 'android'], default='all')
    parser.add_argument('--dependencies', help='Directory containing the pinned Android archives')
    parser.add_argument('--no-download', action='store_true')
    args = parser.parse_args()
    build = ROOT / 'build/verification'
    build.mkdir(parents=True, exist_ok=True)
    if args.platform in ['all', 'ios']:
        swift(build)
    if args.platform in ['all', 'android']:
        android(build, args)


if __name__ == '__main__':
    main()
