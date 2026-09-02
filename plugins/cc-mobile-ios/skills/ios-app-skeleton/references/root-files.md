# Reference — root files

The Swift package manifest and repo-level tooling config emitted at the root of `{{APP_NAME}}/`. Written before any source file, because `Package.swift` declares the three products (`AppCore`, `AppFeatures`, `App`) every later step compiles into. Loaded at execution-order step 2.

### `Package.swift`

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "{{APP_NAME}}",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "AppCore", targets: ["AppCore"]),
        .library(name: "AppFeatures", targets: ["AppFeatures"]),
    ],
    dependencies: [
        // INCLUDE_FIREBASE:
        // .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "<latest-stable>"),
    ],
    targets: [
        .target(
            name: "AppCore",
            path: "Sources/AppCore"
        ),
        .target(
            name: "AppFeatures",
            dependencies: ["AppCore"],
            path: "Sources/AppFeatures"
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore"],
            path: "Tests/AppCoreTests"
        ),
        .testTarget(
            name: "AppFeaturesTests",
            dependencies: ["AppFeatures"],
            path: "Tests/AppFeaturesTests"
        ),
    ]
)
```

### `.swiftformat`

```
--swiftversion 6.0
--indent 4
--maxwidth 120
--wraparguments before-first
--wrapparameters before-first
--wrapcollections before-first
--stripunusedargs closure-only
```

### `.gitignore`

```
.DS_Store
.build/
.swiftpm/
Package.resolved
*.xcodeproj
*.xcworkspace
xcuserdata/
DerivedData/
*.hmap
*.ipa
*.dSYM.zip
GoogleService-Info.plist
```
