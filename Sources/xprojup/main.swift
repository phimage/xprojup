import XcodeProjKit
import ArgumentParser
import Foundation

struct Cmd: ParsableCommand {

    @Option(name: .long, help: "Specify an alternate Xcode version")
    var xcode: String?

    @Flag(help: "Look recursively for proj file")
    var recursive: Bool = false

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
        return ._1400
    }

    fileprivate func warns(_ originVersion: PBXProject.Version, _ wantedVersion: PBXProject.Version) -> [String: String] {
        var warns: [String: String] = [:]
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

    fileprivate func manageXcodeProj(_ url: URL) throws {
        print("📖 Reading \(url)")
        let xcodeProj = try XcodeProj(url: url)

        let wantedVersion: PBXProject.Version = self.wantedVersion
        let originVersion = xcodeProj.project.lastUpgradeCheck ?? wantedVersion
        if originVersion < wantedVersion {
            // upgrade last check
            print("⬆ lastUpgradeCheck: \(originVersion) → \(wantedVersion)")
            xcodeProj.project.lastUpgradeCheck = wantedVersion

            // add missing warning

            let warns = warns(originVersion, wantedVersion)

            for buildConfiguration in xcodeProj.project.buildConfigurationList?.buildConfigurations ?? [] {
                print("⚙️ \(buildConfiguration.fields["name"] ?? "")")
                // new warns

                for (key, value) in warns {
                    if buildConfiguration.buildSettings?[key] == nil {
                        print("＋ ⚠️ \(key) = \(value)")
                        buildConfiguration.buildSettings?[key] = value
                    }
                }

                // TODO: splitted prop?
                // - SWIFT_OPTIMIZATION_LEVEL = "-Owholemodule";
                // + SWIFT_COMPILATION_MODE = wholemodule;
                // + SWIFT_OPTIMIZATION_LEVEL = "-O";

                // TODO: LD_RUNPATH_SEARCH_PATHS on one line

                if let target = buildConfiguration.buildSettings?["IPHONEOS_DEPLOYMENT_TARGET"] as? String, let current = Double(target) {
                    let wantedVersionString: String
                    if wantedVersion >= PBXProject.Version ._1300 {
                        wantedVersionString = "12.0"
                    } else if wantedVersion >= PBXProject.Version ._1100 {
                        wantedVersionString = "10.0"
                    } else  {
                        wantedVersionString = "10.0"
                    }
                    if current < Double(wantedVersionString)! {
                        print("⬆ 📱 IPHONEOS_DEPLOYMENT_TARGET \(target) → \(wantedVersionString)")
                        buildConfiguration.buildSettings?["IPHONEOS_DEPLOYMENT_TARGET"] = wantedVersionString
                    }
                }
            }

            /*TODO: developmentRegion = English to en;
             knownRegions = (
             -                English,*/

            print("💾 Writing \(url)")
            try xcodeProj.write(to: url, format: .openStep )

            // TODO: modify xxx.xcodeproj/xcshareddata/xcschemes/xxx.xcscheme
        }
    }
}

extension URL {
    var isDirectory: Bool {
       (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}

extension PBXProject.Version {
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
