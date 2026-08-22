# xprojup

[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://mit-license.org)
[![Platform](http://img.shields.io/badge/platform-macOS_Linux-lightgrey.svg?style=flat)](https://developer.apple.com/resources/)
[![Language](http://img.shields.io/badge/language-swift-orange.svg?style=flat)](https://developer.apple.com/swift)
[![build](https://github.com/phimage/xprojup/actions/workflows/build.yml/badge.svg)](https://github.com/phimage/xprojup/actions/workflows/build.yml)
[![Sponsor](https://img.shields.io/badge/Sponsor-%F0%9F%A7%A1-white.svg?style=flat)](https://github.com/sponsors/phimage)

Update project files to latest Xcode needs to avoid warnings such as `⚠️ Update to recommended settings`

## Usage

```bash
    xprojup /path/to/my.xcodeproj
```

```bash
    xprojup --recursive /path/to/a/folder/that/contains/some/proj
```

Print the installed version (also shown in `--help`):

```bash
    xprojup --version
```

💡 Current Xcode target version is `26.0` ie. `2600`

You could choose a specific version using `--xcode <4 digits>`
```bash
    xprojup --xcode 1600 /path/to/my.xcodeproj
```

### Deployment targets

A deployment target below the target Xcode's supported minimum is a *hard build failure*
(e.g. Xcode 26 refuses `IPHONEOS_DEPLOYMENT_TARGET = 9.0`, whose minimum is `15.0`). Because
raising it drops OS/device support — a product decision, and not something Xcode's own
"Update to recommended settings" touches — xprojup only **warns** about it by default:

```
⚠️ 📱 IPHONEOS_DEPLOYMENT_TARGET 9.0 is below Xcode 26.0 minimum 15.0 — won't build. Pass --fix-deployment-target to raise it.
```

Pass `--fix-deployment-target` to actually raise below-floor targets (iOS / macOS / tvOS /
watchOS / visionOS) up to that minimum — never higher:

```bash
    xprojup --fix-deployment-target /path/to/my.xcodeproj
```

> Note: deployment targets are checked on both the project *and* every target's build
> configurations (per-target overrides are what actually win at build time). Recommended
> settings, by contrast, are applied at the project level, matching Xcode. The floors are a
> best-effort map keyed on the target Xcode; when unsure it under-raises rather than dropping
> OS support silently.

## Install

Just download from release if any, or build it (and move it to `PATH`)

or alternatively execute install script

```bash
sudo curl -sL https://phimage.github.io/xprojup/install.sh | bash
```

### On linux for dynamic binary

Some dependencies lib must be installed if you install the dynamic binary

so if you have not already added the swiftlang repo:

```bash
curl -s https://archive.swiftlang.xyz/install.sh | sudo bash
```

then you can install just the minimum package `slim` (or the full one see build chapter)

```bash
sudo apt install swiftlang-slim
```

#### current dependencies info for dynamic executable 

linked to swift lib and os lib

```bash
$ ldd xprojup 
	linux-vdso.so.1 (0x00007ffe977fb000)
	libswiftGlibc.so => /usr/lib/swift/linux/libswiftGlibc.so (0x00007fe95fcb7000)
	libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007fe95fb61000)
	libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007fe95fb3e000)
	libutil.so.1 => /lib/x86_64-linux-gnu/libutil.so.1 (0x00007fe95fb39000)
	libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007fe95fb33000)
	libFoundation.so => /usr/lib/swift/linux/libFoundation.so (0x00007fe95f28b000)
	libswiftDispatch.so => /usr/lib/swift/linux/libswiftDispatch.so (0x00007fe95f259000)
	libdispatch.so => /usr/lib/swift/linux/libdispatch.so (0x00007fe95f1f8000)
	libBlocksRuntime.so => /usr/lib/swift/linux/libBlocksRuntime.so (0x00007fe95f1f3000)
	libswift_Concurrency.so => /usr/lib/swift/linux/libswift_Concurrency.so (0x00007fe95f191000)
	libswiftCore.so => /usr/lib/swift/linux/libswiftCore.so (0x00007fe95eb34000)
	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007fe95e942000)
	libstdc++.so.6 => /lib/x86_64-linux-gnu/libstdc++.so.6 (0x00007fe95e75e000)
	libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x00007fe95e743000)
	/lib64/ld-linux-x86-64.so.2 (0x00007fe95fded000)
	libicuucswift.so.65 => /usr/lib/swift/linux/libicuucswift.so.65 (0x00007fe95e540000)
	libicui18nswift.so.65 => /usr/lib/swift/linux/libicui18nswift.so.65 (0x00007fe95e226000)
	librt.so.1 => /lib/x86_64-linux-gnu/librt.so.1 (0x00007fe95e21c000)
	libicudataswift.so.65 => /usr/lib/swift/linux/libicudataswift.so.65 (0x00007fe95c769000)

$ du -sh /usr/lib/swift/
124M	/usr/lib/swift/
```

## Build yourself

```bash
swift build -c release
```

or if we want without swift runtime dependencies (ie static executable)

```bash
swift build -c release -Xswiftc -static-executable
```

### Install swift on linux (needed to build)

#### Download from 

[Swift official website](https://www.swift.org/download/)

#### Download with apt on swiftlang.xyz

```bash
curl -s https://archive.swiftlang.xyz/install.sh | sudo bash
```

Then install the full swiftlang package to install `swift` command

```bash
sudo apt install swiftlang
```

#### or use swiftenv

## Updating for a new Xcode version

When a new Xcode ships, the recommended build settings it applies live inside
`Xcode.app` (in `Base_ProjectSettings.xctemplate`). To refresh xprojup:

1. Dump the authoritative default build settings from the Xcode you target:

```bash
    ./scripts/extract-recommended.sh            # SharedSettings as JSON
    ./scripts/extract-recommended.sh --all      # + Debug/Release configs
    ./scripts/extract-recommended.sh --keys      # just the keys
```

   It uses `DEVELOPER_DIR` / `xcode-select`, falling back to
   `/Applications/Xcode.app`. Point it at a specific Xcode with:

```bash
    DEVELOPER_DIR=/Applications/Xcode-16.app/Contents/Developer ./scripts/extract-recommended.sh
```

2. Diff that output against the `warns(...)` map in
   [`Sources/xprojup/main.swift`](Sources/xprojup/main.swift).
3. Add a new `PBXProject.Version` constant (e.g. `._2700`) and, under a new
   `if originVersion < ._2700 && wantedVersion >= ._2700 { ... }` threshold, add
   only the keys that are genuinely *new* recommended settings for that version.
4. Bump the default returned by `wantedVersion` to the new constant.

> Note: bumping `LastUpgradeCheck` is what actually silences Xcode's
> "Update to recommended settings" prompt; the settings are applied to match what
> Xcode's "Perform Changes" would do.
