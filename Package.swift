// swift-tools-version:5.9
// Personal build without Xcode: compiles the app binary with SwiftPM. See PersonalBuild/build.sh, which
// assembles the .app using the compiled storyboard and assets of the matching upstream release.

import PackageDescription

let package = Package(
  name: "MonitorControl",
  platforms: [.macOS(.v10_15)],
  dependencies: [
    .package(url: "https://github.com/rnine/SimplyCoreAudio", revision: "75970285e2470f12a569cdff68ef5a75498a4646"),
    .package(url: "https://github.com/MonitorControl/MediaKeyTap", revision: "22293b608bb9e7072960a2002d77ebbbdb3ba859"),
    .package(path: "PersonalBuild/Settings"), // sindresorhus/Settings 879ea83, Localizable.xcstrings converted to .strings (xcstringstool needs Xcode)
    .package(url: "https://github.com/sparkle-project/Sparkle", revision: "9042c8dbd9c6f6a1bebc2e4c4b878eac6984ddbd"),
  ],
  targets: [
    .executableTarget(
      name: "MonitorControl",
      dependencies: ["SimplyCoreAudio", "MediaKeyTap", "Settings", "Sparkle"],
      path: "MonitorControl",
      exclude: ["Info.plist", "MonitorControl.entitlements", "MonitorControlDebug.entitlements", "InternetAccessPolicy.plist", "Assets.xcassets", "UI", "Support/Bridging-Header.h"],
      swiftSettings: [.unsafeFlags(["-import-objc-header", Context.packageDirectory + "/MonitorControl/Support/Bridging-Header.h", "-swift-version", "5"])],
      linkerSettings: [
        .unsafeFlags(["-F", "/System/Library/PrivateFrameworks", "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
        .linkedFramework("CoreDisplay"),
        .linkedFramework("OSD"),
        .linkedFramework("DisplayServices"),
      ]
    ),
  ]
)
