import SwiftUI
import AgeWalletSDK

// Auto-detected default metadata identifies the demo build to the dev/QA team
// when verifications land on the server.
private let AUTO_DEFAULT_METADATA = "iOS Native"

struct ContentView: View {
    @State private var isVerified = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var customAppend: String = ""
    @State private var lastMetadata: String? = nil

    @State private var ageWallet = AgeWallet(config: AgeWalletConfig(
        clientId: "your-client-id",
        redirectUri: "https://agewallet-sdk-demo.netlify.app/callback",
        endpoints: AgeWalletEndpoints(
            auth: "https://app.agewallet.io/user/authorize",
            token: "https://app.agewallet.io/user/token",
            userinfo: "https://app.agewallet.io/user/userinfo"
        ),
        metadata: AUTO_DEFAULT_METADATA
    ))

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if isVerified {
                VerifiedView(lastMetadata: lastMetadata, onClear: clearVerification)
            } else {
                UnverifiedView(
                    autoDefault: AUTO_DEFAULT_METADATA,
                    customAppend: $customAppend,
                    onVerify: startVerification
                )
            }
        }
        .onAppear {
            checkVerification()
        }
        .onOpenURL { url in
            guard url.host == "agewallet-sdk-demo.netlify.app",
                  url.path.hasPrefix("/callback") else { return }
            isLoading = true
            Task {
                let result = await ageWallet.handleCallback(url: url)
                await MainActor.run {
                    isVerified = result == .success
                    isLoading = false
                    lastMetadata = ageWallet.getMetadata()
                    if result == .denied {
                        errorMessage = "Age verification was cancelled."
                    } else if result == .failed {
                        errorMessage = "Verification could not be completed. Please try again."
                    }
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func checkVerification() {
        isVerified = ageWallet.isVerified()
        if isVerified {
            lastMetadata = ageWallet.getMetadata()
        }
        isLoading = false
    }

    private func startVerification() {
        // If the user typed something in "Custom metadata", append it to the auto-default
        // for THIS verification only. Otherwise the instance default kicks in.
        let custom = customAppend.trimmingCharacters(in: .whitespaces)
        let override = custom.isEmpty ? nil : "\(AUTO_DEFAULT_METADATA) | \(custom)"
        do {
            let url = try ageWallet.buildVerificationURL(metadata: override)
            UIApplication.shared.open(url)
        } catch AgeWalletError.invalidMetadata {
            errorMessage = "Metadata too long (max 4096 bytes)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearVerification() {
        ageWallet.clearVerification()
        isVerified = false
        lastMetadata = nil
    }
}

struct UnverifiedView: View {
    let autoDefault: String
    @Binding var customAppend: String
    let onVerify: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.indigo)
                }

                VStack(spacing: 8) {
                    Text("Age Verification Required")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("You must verify your age to access this content.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Auto-detected default metadata — informational, baked in at build time.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default metadata (auto)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(autoDefault)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding(.top, 8)

                // Optional per-call append — concatenated to the default for THIS verification only.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom metadata (optional, appended for this call only)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    TextField("e.g. order-1234", text: $customAppend)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Text("If populated, sent as \"\(autoDefault) | <your text>\" for this verification only.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Button(action: onVerify) {
                    Text("Verify with AgeWallet")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
    }
}

struct VerifiedView: View {
    let lastMetadata: String?
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.green)
            }

            VStack(spacing: 8) {
                Text("Age Verified")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You have successfully verified your age.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Metadata attached to current verification:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text(lastMetadata ?? "(none)")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            Button(action: onClear) {
                Text("Clear Verification")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
            }
        }
        .padding(32)
    }
}

#Preview {
    ContentView()
}
