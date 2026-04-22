---
name: android-security
description: Android security patterns — Android Keystore, EncryptedSharedPreferences / Tink, network security config, OkHttp cert pinning, Play Integrity, biometric gating. Load whenever adding auth, secrets, or network calls that cross a trust boundary.
---

# Android security

## Secrets at rest

**Keystore-backed** from the first line of code. Never `SharedPreferences` + a BuildConfig key.

Preferred: Jetpack `Tink` wrapped around Keystore.

```kotlin
// One-time bootstrap in a @Singleton
private val aead: Aead = AndroidKeysetManager.Builder()
    .withSharedPref(context, "keyset_name", "keyset_prefs")
    .withKeyTemplate(AeadKeyTemplates.AES256_GCM)
    .withMasterKeyUri("android-keystore://app_master_key")
    .build()
    .keysetHandle
    .getPrimitive(Aead::class.java)

fun encrypt(plaintext: ByteArray, aad: ByteArray = byteArrayOf()): ByteArray = aead.encrypt(plaintext, aad)
fun decrypt(ciphertext: ByteArray, aad: ByteArray = byteArrayOf()): ByteArray = aead.decrypt(ciphertext, aad)
```

Secrets are stored as the ciphertext blob; the key never leaves the Keystore.

`EncryptedSharedPreferences` is fine for flag-style secrets but avoid it for tokens — it's deprecated as of AndroidX Security 1.1.

## Network trust

### Network Security Config

Never trust user CAs in release. `res/xml/network_security_config.xml`:

```xml
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system"/>
        </trust-anchors>
    </base-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">10.0.2.2</domain>
    </domain-config>
</network-security-config>
```

Wire it in `AndroidManifest.xml`:

```xml
<application android:networkSecurityConfig="@xml/network_security_config" />
```

### OkHttp certificate pinning

Pin your API domain. Never pin the root CA (rotates too often); pin the intermediate or leaf SPKI and ship at least two pins (current + next).

```kotlin
val pinner = CertificatePinner.Builder()
    .add("api.example.com", "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
    .add("api.example.com", "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=")
    .build()

val client = OkHttpClient.Builder()
    .certificatePinner(pinner)
    .build()
```

Ship the rotation pin **before** the server rotates. Otherwise a cert rotation bricks the app.

## Biometric / user-presence

Use `androidx.biometric` and gate by a keystore key bound to biometric prompt:

```kotlin
val prompt = BiometricPrompt(
    activity,
    ContextCompat.getMainExecutor(activity),
    object : BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
            val cipher = result.cryptoObject?.cipher ?: return
            // Use cipher to decrypt stored token
        }
    },
)
prompt.authenticate(
    BiometricPrompt.PromptInfo.Builder()
        .setTitle("Confirm to continue")
        .setAllowedAuthenticators(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
        .build(),
    BiometricPrompt.CryptoObject(cipherBoundToKey),
)
```

Always use `setAllowedAuthenticators(...)` — `setDeviceCredentialAllowed` is deprecated.

## Play Integrity

For anti-tamper / anti-bot, use Play Integrity. Don't roll your own `SafetyNet` — it's shut down.

```kotlin
val manager = IntegrityManagerFactory.create(context)
val tokenResponse = manager.requestIntegrityToken(
    IntegrityTokenRequest.builder()
        .setNonce(nonce)
        .setCloudProjectNumber(CLOUD_PROJECT_NUMBER)
        .build()
).await()
val token = tokenResponse.token() // send to backend for verification
```

Server verifies via the Play Integrity decryption + verification API. Never trust the token locally.

## Input and WebView

- `WebView` with user content: `settings.javaScriptEnabled = false` unless you need it; if you do, use `WebViewAssetLoader` to serve local assets and never `setAllowUniversalAccessFromFileURLs`.
- HTML content from server? Use `CustomTabsIntent` instead of `WebView`.
- All user input validated server-side; client validation is UX only.

## Intent hardening

- Never `getIntent()?.extras?.get("token")` and trust it. Validate type + origin.
- `android:exported="false"` by default for every `Activity`, `Service`, `Receiver`.
- `FLAG_IMMUTABLE` on every `PendingIntent` (required target SDK 31+).

## Debug / release discipline

- `BuildConfig.DEBUG`-gated verbose logging; no `Log.d(tag, json)` on release.
- `proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")` on release.
- `minifyEnabled = true` + `shrinkResources = true` on release.
- Remove `android:debuggable` overrides before shipping. Gradle handles this; don't force.

## Hard nos

- No storing tokens in `SharedPreferences` (not encrypted ones, not the plain kind, not "just for dev").
- No shipping with `allowBackup="true"` unless you've excluded sensitive files via `android:fullBackupContent`.
- No `TrustAllCerts` / `HostnameVerifier { _, _ -> true }` — not even behind a debug flag. Use Network Security Config for localhost exceptions.
- No logging PII or tokens.
- No dynamic code loading from network.
