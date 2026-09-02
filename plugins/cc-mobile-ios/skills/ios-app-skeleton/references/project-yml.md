# Reference — `project.yml` (xcodegen)

The thin Xcode shell that embeds the SPM package. The package is the source of truth; this project file exists so the app can be run on a simulator/device and carry signing + Info.plist settings. Loaded at execution-order step 7 — only when `xcodegen` is installed.

Emit this only if the user has `xcodegen` installed (`which xcodegen`). Otherwise print the equivalent manual Xcode steps.

```yaml
name: {{APP_NAME}}
options:
  bundleIdPrefix: {{BUNDLE_ID}}
  deploymentTarget:
    iOS: "18.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    DEVELOPMENT_TEAM: ""
packages:
  Local:
    path: .
targets:
  {{APP_NAME}}:
    type: application
    platform: iOS
    sources:
      - Sources/App
    dependencies:
      - package: Local
        product: AppCore
      - package: Local
        product: AppFeatures
    info:
      path: Sources/App/Info.plist
      properties:
        UILaunchScreen: {}
        CFBundleDisplayName: {{APP_DISPLAY_NAME}}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: {{BUNDLE_ID}}
```
