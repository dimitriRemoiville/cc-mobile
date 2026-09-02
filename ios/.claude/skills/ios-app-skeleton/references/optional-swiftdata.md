# Reference — `INCLUDE_SWIFTDATA` additions

Versioned SwiftData schema in `AppCore` plus the container boot in the app target. Emitted only when the `INCLUDE_SWIFTDATA` flag is on. Loaded at execution-order steps 3 and 5.

Add to `Package.swift` targets only if iOS 17+ (already satisfied by iOS 18 default).

### `Sources/AppCore/Persistence/SchemaV1.swift`

```swift
import Foundation
import SwiftData

public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    public static var models: [any PersistentModel.Type] { [Sample.self] }

    @Model
    public final class Sample {
        @Attribute(.unique) public var id: UUID
        public var label: String
        public init(id: UUID = UUID(), label: String) {
            self.id = id
            self.label = label
        }
    }
}
```

### `Sources/App/PersistenceContainer.swift`

```swift
import Foundation
import SwiftData
import AppCore

enum PersistenceContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration("app", schema: schema)
        return try ModelContainer(for: schema, configurations: config)
    }
}
```
