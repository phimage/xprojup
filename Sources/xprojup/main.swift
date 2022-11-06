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

        if url.pathExtension == "xcodeproj" {
            try manageXcodeProj(url)
        } else {
           
            try manageFolder(url)
        }
    }

    fileprivate func manageFolder(_ url: URL) throws {
        guard url.isDirectory else { return }
        for url in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) {
            if url.pathExtension == "xcodeproj" {
                try manageXcodeProj(url)
            } else  if recursive {
                try manageFolder(url)
            }
        }
    }

    fileprivate func manageXcodeProj(_ url: URL) throws {
        print("📖 Reading \(url)")
        let xcodeProj = try XcodeProj(url: url)
        
        // upgrade last check
        let wantedVersion = PBXProject.Version(major: 13, minor: 20)
        let originVersion = xcodeProj.project.lastUpgradeCheck ?? wantedVersion
        if originVersion < wantedVersion {
            print("⬆ lastUpgradeCheck: \(originVersion) → \(wantedVersion)")
            xcodeProj.project.lastUpgradeCheck = wantedVersion
            
            // add missing warning
            for buildConfiguration in xcodeProj.project.buildConfigurationList?.buildConfigurations ?? [] {
                print("⚙️ \(buildConfiguration.fields["name"] ?? "")")
                // new warns
                if originVersion < PBXProject.Version(major: 13, minor: 0) {
                    for (key, value) in ["CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES"] {
                        if buildConfiguration.buildSettings?[key] == nil {
                            print("＋ ⚠️ \(key) = \(value)")
                            buildConfiguration.buildSettings?[key] = value
                        }
                    }
                }
                
                if let target = buildConfiguration.buildSettings?["IPHONEOS_DEPLOYMENT_TARGET"] as? String, let num = Double(target) {
                    let value = "12.0"
                    if num < Double(value)! { // swiftlint:disable:this force_cast
                        print("⬆ 📱 IPHONEOS_DEPLOYMENT_TARGET = \(value)")
                        buildConfiguration.buildSettings?["IPHONEOS_DEPLOYMENT_TARGET"] = value
                    }
                }
                
            }
            
            // change minimum version deploy target
            //  IPHONEOS_DEPLOYMENT_TARGET = 12.0;
            
            // TODO: modify xxx.xcodeproj/xcshareddata/xcschemes/xxx.xcscheme
            
            print("💾 Writing \(url)")
            try xcodeProj.write(to: url, format: .openStep )
        }
    }
}
extension URL {
    var isDirectory: Bool {
       (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
Cmd.main()
