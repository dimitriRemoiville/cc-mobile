# Reference — `INCLUDE_FIREBASE` additions

Firebase SPM wiring, the `FirebaseApp.configure()` call, and the per-scheme `GoogleService-Info.plist` copy phase. Emitted only when the `INCLUDE_FIREBASE` flag is on. Loaded at execution-order step 2 (package dependency) and step 10 (manual plist note).

In `Package.swift`, add Firebase SPM as a dependency and attach `FirebaseAnalytics`, `FirebaseCrashlytics` products to the `App` target.

In `{{APP_NAME}}App.swift`, the `FirebaseApp.configure()` call in `init()` is active (uncommented).

Per-scheme `GoogleService-Info.plist`:
- dev → `GoogleService-Info-Dev.plist`.
- prod → `GoogleService-Info-Prod.plist`.
- Use a build-phase copy script that picks the right plist per configuration:

```sh
cp "${SRCROOT}/Config/GoogleService-Info-${CONFIGURATION}.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
```
