---
name: urlsession-networking
description: Networking patterns for this project — URLSession + async/await + Codable, endpoint definitions, error mapping, auth interceptors via delegates, and how networking fits into the repository. Load when adding or editing any API call, request interceptor, or Codable model.
---

# Networking (URLSession + async/await)

## The pipeline

```
Domain.Repository       # domain types only
      ↓
Data.RepositoryImpl     # calls client, maps, throws DomainError
      ↓
Data.Remote.APIClient   # URLSession wrapper, JSON encode/decode
      ↓
URLSession              # system networking
```

Network errors are **mapped to `DomainError` at the repository boundary**. Nothing higher up should know about `URLError` or `DecodingError`.

## APIClient

A small, focused wrapper — not an HTTP framework.

```swift
protocol APIClient: Sendable {
    func get<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> T
    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T
}

final class LiveAPIClient: APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let auth: AuthTokenProvider

    init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = .api,
        encoder: JSONEncoder = .api,
        auth: AuthTokenProvider
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
        self.auth = auth
    }

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        try await addAuth(&request)
        return try await perform(request)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        try await addAuth(&request)
        return try await perform(request)
    }

    private func addAuth(_ request: inout URLRequest) async throws {
        if let token = try await auth.current() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.status(code: http.statusCode, body: data)
        }
        return try decoder.decode(T.self, from: data)
    }
}

extension JSONDecoder {
    static let api: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
```

`APIError` is a data-layer error (leaks `URLError`, status codes). It does **not** cross into the domain.

## DTOs

Separate from domain models. Named `…DTO`. `Codable`, `Sendable`:

```swift
struct OrderDTO: Decodable, Sendable {
    let id: String
    let items: [OrderItemDTO]
    let totalCents: Int
    let createdAt: Date  // decoded via .iso8601
}
```

Rules:
- Nullability reflects the wire format, not what the domain wants.
- Unknown enum values? Use a fallback case or let the decoder throw and handle at the boundary.
- Keep DTOs in the data layer — never expose them upward.

## Mapping DTO → domain

One-way functions as extensions or module-scoped functions:

```swift
extension OrderDTO {
    func toDomain() -> Order {
        Order(
            id: OrderID(id),
            items: items.map { $0.toDomain() },
            total: .cents(totalCents),
            createdAt: createdAt
        )
    }
}
```

## Repository pattern

```swift
final class LiveOrderRepository: OrderRepository {
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    func get(id: OrderID) async throws -> Order {
        do {
            let dto: OrderDTO = try await client.get("/orders/\(id.raw)")
            return dto.toDomain()
        } catch let error as APIError {
            throw map(error)
        } catch is DecodingError {
            throw DomainError.invalidResponse
        }
    }

    private func map(_ error: APIError) -> DomainError {
        switch error {
        case .invalidResponse: return .invalidResponse
        case .status(let code, _):
            switch code {
            case 401: return .unauthorized
            case 404: return .notFound
            case 500...599: return .server
            default: return .unknown("HTTP \(code)")
            }
        }
    }
}
```

## Authentication

An `AuthTokenProvider` protocol, backed by Keychain storage:

```swift
protocol AuthTokenProvider: Sendable {
    func current() async throws -> String?
    func refresh() async throws -> String
    func clear() async throws
}
```

Refresh logic lives in the token provider, not the APIClient. The APIClient asks for a token before every call.

## Logging

- Only in DEBUG builds. Never log request / response bodies in release.
- Redact `Authorization` headers and any body field that might contain PII.
- Use `Logger` from `os`, not `print`.

```swift
#if DEBUG
logger.debug("GET \(request.url?.absoluteString ?? "?", privacy: .public) → \(http.statusCode, privacy: .public)")
#endif
```

## Streaming / pagination

- Cursor-based APIs → `AsyncStream<[Element]>` from the repository. View model collects it.
- Simple offset pagination → the repository takes `page:` / `cursor:` and the view model composes.

## Common pitfalls

- **Using `Data(contentsOf:)` for HTTP.** Never — it's synchronous and swallows errors.
- **Forgetting to map errors.** `URLError` leaking into a view is a bug.
- **Creating a new `JSONDecoder` per call.** It's cheap, but reuse is cheaper.
- **Not setting `Content-Type` on POST / PUT.** Many APIs reject otherwise.
- **Logging `Authorization` headers.** Redact.
- **Treating `URLSession.shared` as untestable.** Inject a `URLSession` — production uses `.shared`, tests use a `URLSession` with a custom `URLProtocol` subclass.
