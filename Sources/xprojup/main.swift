import XcodeProjKit
import ArgumentParser
import Foundation

struct Cmd: ParsableCommand {

    // Keep this in sync with the git tag: bump it in the same commit that will be tagged/released.
    static let version = "0.1.0"

    static let configuration = CommandConfiguration(
        commandName: "xprojup",
        abstract: "Update Xcode project files to a target Xcode's recommended settings.",
        version: Cmd.version
    )

    @Option(name: .long, help: "Specify an alternate Xcode version")
    var xcode: String?

    @Flag(help: "Look recursively for proj file")
    var recursive: Bool = false

    @Flag(name: .long, help: "Raise deployment targets that are below the target Xcode's minimum (default: only warn)")
    var fixDeploymentTarget: Bool = false

    @Argument(help: "File or folder to update")
    var path: String

    mutating func run() throws {
        let url = URL(fileURLWithPath: self.path)

        if url.pathExtension == "xcodeproj" || url.pathExtension == "pbxproj" {
            try manageXcodeProj(url)
        } else {
            try manageFolder(url)
        }
    }

    fileprivate func manageFolder(_ url: URL) throws {
        guard url.isDirectory else { return }
        for url in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) {
            if url.pathExtension == "xcodeproj" || url.pathExtension == "pbxproj" {
                try manageXcodeProj(url)
            } else  if recursive {
                try manageFolder(url)
            }
        }
    }

    fileprivate var wantedVersion: PBXProject.Version {
        if let xcode = self.xcode, let version = PBXProject.Version(xcode) {
            return version
        }
        return ._2600
    }

    fileprivate func warns(_ originVersion: PBXProject.Version, _ wantedVersion: PBXProject.Version) -> [String: String] {
        var warns: [String: String] = [:]

        // The list of recommended settings per Xcode version can be regenerated from the
        // Xcode you target using `scripts/extract-recommended.sh` (it dumps the default build
        // settings baked into `Base_ProjectSettings.xctemplate`). Add any new keys below.
        // Note: targeting Xcode 26 (._2600, the default) mainly bumps `LastUpgradeCheck`, which
        // is what silences the "Update to recommended settings" prompt; no new generic build
        // settings were introduced between Xcode 16 and 26.

        if originVersion < PBXProject.Version._1600 && wantedVersion >= PBXProject.Version._1600 {
            // Xcode 16 prefers String Catalogs (`.xcstrings`) for localization; this is the
            // default for new projects since Xcode 16.
            warns["LOCALIZATION_PREFERS_STRING_CATALOGS"] = "YES"
            // Confirmed from a real Xcode 26 "Update to recommended settings" migration diff:
            // it enables String Catalog symbol generation.
            warns["STRING_CATALOG_GENERATE_SYMBOLS"] = "YES"
        }

        if originVersion < PBXProject.Version._1500 && wantedVersion >= PBXProject.Version._1500 {
            warns["ENABLE_USER_SCRIPT_SANDBOXING"] = "YES"
            // Xcode 15 recommended setting: type-safe Swift symbols for asset-catalog images/colors.
            warns["ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS"] = "YES"
        }

        if originVersion < PBXProject.Version._1400 && wantedVersion >= PBXProject.Version._1400 {
            warns["DEAD_CODE_STRIPPING"] = "YES"
        }

        if originVersion < PBXProject.Version._1300 && wantedVersion >= PBXProject.Version._1300 {
            warns["CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER"] = "YES"
        }

        if originVersion < PBXProject.Version._1000 && wantedVersion >= PBXProject.Version._1000 {
            warns["CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED"] = "YES"
        }

        if originVersion < PBXProject.Version._0930 && wantedVersion >= PBXProject.Version._0930 {
            warns["CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS"] = "YES"
            warns["CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF"] = "YES"
        }

        if originVersion < PBXProject.Version._0900 && wantedVersion >= PBXProject.Version._0900 {
            warns["CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING"] = "YES"
            warns["CLANG_WARN_COMMA"] = "YES"
            warns["CLANG_WARN_NON_LITERAL_NULL_CONVERSION"] = "YES"
            warns["CLANG_WARN_OBJC_LITERAL_CONVERSION"] = "YES"
            warns["CLANG_WARN_RANGE_LOOP_ANALYSIS"] = "YES"
            warns["CLANG_WARN_STRICT_PROTOTYPES"] = "YES"
        }

        if originVersion < PBXProject.Version._0820 && wantedVersion >= PBXProject.Version._0820 {
            warns["CLANG_WARN_BOOL_CONVERSION"] = "YES"
            warns["CLANG_WARN_CONSTANT_CONVERSION"] = "YES"
            warns["CLANG_WARN_EMPTY_BODY"] = "YES"
            warns["CLANG_WARN_ENUM_CONVERSION"] = "YES"
            warns["CLANG_WARN_INFINITE_RECURSION"] = "YES"
            warns["CLANG_WARN_INT_CONVERSION"] = "YES"
            warns["CLANG_WARN_SUSPICIOUS_MOVE"] = "YES"
            warns["CLANG_WARN_UNREACHABLE_CODE"] = "YES"
            warns["CLANG_WARN__DUPLICATE_METHOD_MATCH"] = "YES"

            warns["ENABLE_STRICT_OBJC_MSGSEND"] = "YES"
            warns["ENABLE_TESTABILITY"] = "YES"

            warns["GCC_NO_COMMON_BLOCKS"] = "YES"
            warns["GCC_WARN_64_TO_32_BIT_CONVERSION"] = "YES"
            warns["GCC_WARN_UNDECLARED_SELECTOR"] = "YES"
            warns["GCC_WARN_UNINITIALIZED_AUTOS"] = "YES"
            warns["GCC_WARN_UNUSED_FUNCTION"] = "YES"
        }

        return warns
    }

    // Minimum *deployment* targets the toolchain will accept, per Xcode version.
    // Unlike `warns()`, these are NOT part of Xcode's "Update to recommended settings" — a value
    // below the floor is a hard build failure ("… minimum deployment target … is less than …").
    // Only ever raise up to the floor, never to the latest OS. Values below the smallest threshold
    // are left untouched. Numbers come from Apple's Xcode release notes / each SDK's SDKSettings.plist;
    // when unsure prefer a lower value (under-raising is safe, over-raising drops OS support silently).
    fileprivate func deploymentFloors(_ wantedVersion: PBXProject.Version) -> [String: String] {
        var floors: [String: String] = [:]

        // iOS — Xcode 14: 11.0, Xcode 15/16: 12.0, Xcode 26: 15.0
        if wantedVersion >= PBXProject.Version._2600 {
            floors["IPHONEOS_DEPLOYMENT_TARGET"] = "15.0"
        } else if wantedVersion >= PBXProject.Version._1500 {
            floors["IPHONEOS_DEPLOYMENT_TARGET"] = "12.0"
        } else if wantedVersion >= PBXProject.Version._1400 {
            floors["IPHONEOS_DEPLOYMENT_TARGET"] = "11.0"
        }

        // macOS — Xcode 15/16: 10.13, Xcode 26: 12.0
        if wantedVersion >= PBXProject.Version._2600 {
            floors["MACOSX_DEPLOYMENT_TARGET"] = "12.0"
        } else if wantedVersion >= PBXProject.Version._1500 {
            floors["MACOSX_DEPLOYMENT_TARGET"] = "10.13"
        }

        // tvOS — Xcode 15/16: 12.0, Xcode 26: 15.0
        if wantedVersion >= PBXProject.Version._2600 {
            floors["TVOS_DEPLOYMENT_TARGET"] = "15.0"
        } else if wantedVersion >= PBXProject.Version._1500 {
            floors["TVOS_DEPLOYMENT_TARGET"] = "12.0"
        }

        // watchOS — Xcode 15/16: 4.0, Xcode 26: 8.0
        if wantedVersion >= PBXProject.Version._2600 {
            floors["WATCHOS_DEPLOYMENT_TARGET"] = "8.0"
        } else if wantedVersion >= PBXProject.Version._1500 {
            floors["WATCHOS_DEPLOYMENT_TARGET"] = "4.0"
        }

        // visionOS — 1.0 since it first shipped (Xcode 15.2+)
        if wantedVersion >= PBXProject.Version._2600 {
            floors["XROS_DEPLOYMENT_TARGET"] = "1.0"
        }

        return floors
    }

    // Semantic version compare on dotted strings. NOT a Double compare: as doubles "10.9" > "10.13",
    // but as macOS versions 10.9 < 10.13. Missing components are treated as 0 ("12" == "12.0").
    fileprivate func isVersion(_ lhs: String, lessThan rhs: String) -> Bool {
        let lhsParts = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let rhsParts = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(lhsParts.count, rhsParts.count) {
            let left = index < lhsParts.count ? lhsParts[index] : 0
            let right = index < rhsParts.count ? rhsParts[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    // Warn about (or, with --fix-deployment-target, raise) any deployment target below the floor on a
    // single build configuration. Returns true if it rewrote a value. Deployment targets below the
    // toolchain floor are a hard build failure; raising one drops OS/device support (a product
    // decision Xcode's own "Update to recommended settings" does not make), so warn unless opted in.
    fileprivate func applyDeploymentFloors(_ buildConfiguration: XCBuildConfiguration,
                                           _ floors: [String: String],
                                           _ wantedVersion: PBXProject.Version) -> Bool {
        var changed = false
        for (key, floor) in floors {
            guard let current = buildConfiguration.buildSettings?[key] as? String,
                  isVersion(current, lessThan: floor) else { continue }
            if fixDeploymentTarget {
                print("⬆ 📱 \(key) \(current) → \(floor)")
                buildConfiguration.buildSettings?[key] = floor
                changed = true
            } else {
                print("⚠️ 📱 \(key) \(current) is below Xcode \(wantedVersion) minimum \(floor) — won't build. Pass --fix-deployment-target to raise it.")
            }
        }
        return changed
    }

    fileprivate func manageXcodeProj(_ url: URL) throws {
        print("📖 Reading \(url)")
        let xcodeProj = try XcodeProj(url: url)

        let wantedVersion: PBXProject.Version = self.wantedVersion
        let originVersion = xcodeProj.project.lastUpgradeCheck ?? wantedVersion

        // Recommended settings (the `warns`) only make sense as the delta between the project's last
        // upgrade check and the target Xcode; deployment-target floors depend solely on the target
        // Xcode, so they are checked even when the project already claims to be up to date — otherwise
        // a single (even warn-only) run bumps lastUpgradeCheck and locks out a later --fix.
        let warns = originVersion < wantedVersion ? warns(originVersion, wantedVersion) : [:]
        let floors = deploymentFloors(wantedVersion)
        var didChange = false

        if originVersion < wantedVersion {
            // upgrade last check
            print("⬆ lastUpgradeCheck: \(originVersion) → \(wantedVersion)")
            xcodeProj.project.lastUpgradeCheck = wantedVersion
            didChange = true
        }

        // Project-level build settings: recommended settings (warns) + deployment-target floors.
        for buildConfiguration in xcodeProj.project.buildConfigurationList?.buildConfigurations ?? [] {
            print("⚙️ \(buildConfiguration.fields["name"] ?? "")")
            // new warns

            for (key, value) in warns {
                if buildConfiguration.buildSettings?[key] == nil {
                    print("＋ ⚠️ \(key) = \(value)")
                    buildConfiguration.buildSettings?[key] = value
                    didChange = true
                }
            }

            // TODO: splitted prop?
            // - SWIFT_OPTIMIZATION_LEVEL = "-Owholemodule";
            // + SWIFT_COMPILATION_MODE = wholemodule;
            // + SWIFT_OPTIMIZATION_LEVEL = "-O";

            // TODO: LD_RUNPATH_SEARCH_PATHS on one line

            if applyDeploymentFloors(buildConfiguration, floors, wantedVersion) { didChange = true }
        }

        // Target-level build settings: deployment targets are usually overridden per target, and it is
        // those per-target values that win at build time — so they must be checked too, otherwise only
        // the (often unused) project-level value gets raised. Recommended settings stay at the project
        // level, matching Xcode's "Update to recommended settings".
        for target in xcodeProj.project.targets {
            for buildConfiguration in target.buildConfigurationList?.buildConfigurations ?? [] {
                print("⚙️ \(target.name) / \(buildConfiguration.fields["name"] ?? "")")
                if applyDeploymentFloors(buildConfiguration, floors, wantedVersion) { didChange = true }
            }
        }

        /*TODO: developmentRegion = English to en;
         knownRegions = (
         -                English,*/

        // if originVersion < PBXProject.Version._1500 && wantedVersion >= PBXProject.Version._1500 {
            // objectVersion = 54
            // Project object / attributes  BuildIndependentTargetsInParallel = YES;
        // }

        if didChange {
            print("💾 Writing \(url)")
            try xcodeProj.write(to: url, format: .openStep )
        }

        // TODO: modify xxx.xcodeproj/xcshareddata/xcschemes/xxx.xcscheme
    }
}

extension URL {
    var isDirectory: Bool {
       (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}

// `PBXProject.Version` is an immutable value type (two Ints); safe to treat as Sendable
// so the static version constants below are usable from Swift 6 concurrency-checked code.
extension PBXProject.Version: @retroactive @unchecked Sendable {}

extension PBXProject.Version {
    static let _2600 = PBXProject.Version(major: 26, minor: 00)
    static let _1600 = PBXProject.Version(major: 16, minor: 00)
    static let _1500 = PBXProject.Version(major: 15, minor: 00)
    static let _1410 = PBXProject.Version(major: 14, minor: 10)
    static let _1400 = PBXProject.Version(major: 14, minor: 00)
    static let _1320 = PBXProject.Version(major: 13, minor: 20)
    static let _1300 = PBXProject.Version(major: 13, minor: 00)
    static let _1200 = PBXProject.Version(major: 12, minor: 00)
    static let _1100 = PBXProject.Version(major: 11, minor: 00)
    static let _1000 = PBXProject.Version(major: 10, minor: 00)
    static let _0930 = PBXProject.Version(major: 09, minor: 30)
    static let _0900 = PBXProject.Version(major: 09, minor: 00)
    static let _0820 = PBXProject.Version(major: 08, minor: 20)
}

Cmd.main()
