# AgeWallet iOS SDK

Native iOS SDK for AgeWallet age verification using OIDC/PKCE flow.

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ashgoodman/agewallet-ios-sdk.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Usage

### Initialize the SDK

```swift
import AgeWalletSDK

let ageWallet = AgeWallet(config: AgeWalletConfig(
    clientId: "your-client-id",
    redirectUri: "https://yourapp.com/callback"
))
```

### Check Verification Status

```swift
if ageWallet.isVerified() {
    // User is verified
} else {
    // User needs verification
}
```

### Start Verification

```swift
// In a SwiftUI View or UIKit ViewController
Task {
    do {
        let verified = try await ageWallet.startVerification(from: window)
        if verified {
            // Verification successful
        }
    } catch {
        // Handle error
    }
}
```

### Clear Verification (Logout)

```swift
ageWallet.clearVerification()
```

## Configuration

### Custom Endpoints

```swift
let config = AgeWalletConfig(
    clientId: "your-client-id",
    redirectUri: "https://yourapp.com/callback",
    endpoints: AgeWalletEndpoints(
        auth: "https://custom.agewallet.io/authorize",
        token: "https://custom.agewallet.io/token",
        userinfo: "https://custom.agewallet.io/userinfo"
    )
)
```

### Metadata (optional)

Attach an opaque per-verification string (max 4096 UTF-8 bytes) that round-trips through `/userinfo` and is visible to your backend and the AgeWallet dashboard. Useful for tagging build, environment, or user-flow context.

```swift
// Set as the instance default at construction
let ageWallet = AgeWallet(config: AgeWalletConfig(
    clientId: "your-client-id",
    redirectUri: "https://yourapp.com/callback",
    metadata: "checkout-flow"
))

// Update the default at runtime
try ageWallet.setMetadata("new-default")

// Override for a single verification only (does not change the default)
let url = try ageWallet.buildVerificationURL(metadata: "one-shot")

// Read the metadata that round-tripped with the current verification
let received = ageWallet.getMetadata()
```

Maximum size is `AgeWallet.metadataMaxBytes` (4096). `setMetadata`/`buildVerificationURL` throw `AgeWalletError.invalidMetadata` if the value exceeds the limit.

## Universal Links Setup

To handle the OAuth callback via Universal Links:

1. Add the Associated Domains capability to your app
2. Add your domain: `applinks:yourapp.com`
3. Host an `apple-app-site-association` file at `https://yourapp.com/.well-known/apple-app-site-association`:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.io.agewallet.sdk.demo.ios",
        "paths": ["/callback"]
      }
    ]
  }
}
```

## Requirements

- iOS 14.0+
- macOS 11.0+
- Swift 5.9+

## Security

- Uses `ASWebAuthenticationSession` for secure OAuth browser flow
- Stores tokens in iOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- Implements PKCE (S256) for public client security
- All network requests use HTTPS

## License

MIT
