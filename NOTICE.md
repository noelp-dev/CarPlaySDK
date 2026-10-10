# Third-party references and dependencies

AndroidX Car App and related AndroidX runtime libraries are supplied by the host build through Google Maven and are licensed under Apache License 2.0. Their binaries are not committed to this repository. The compiler-check fixtures download explicitly pinned archives; see `tests/native/dependencies.json`.

The Android release host certificate digests are sourced from the AndroidX Car App 1.7.0 `hosts_allowlist_sample` resource. These public digests identify Google Android Auto hosts; they are not private signing keys. See the [official AndroidX 1.7.0 archive](https://dl.google.com/android/maven2/androidx/car/app/app/1.7.0/app-1.7.0.aar).

The JVM-only contract tests use `org.json:json:20250517`. That library is not bundled into the Android plugin: Android supplies `org.json`. Its license is included in the downloaded artifact's Maven metadata/source repository.

NativePHP host protocol stand-ins in `tests/native` are used only for compilation/tests and follow the public bridge contract. They do not replace the real host at runtime. Apple SDK/frameworks are supplied by Xcode and are not redistributed.
