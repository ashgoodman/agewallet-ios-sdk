import SwiftUI
import AgeWalletSDK

struct ContentView: View {
    @State private var isVerified = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var ageWallet = AgeWallet(config: AgeWalletConfig(
        clientId: "239472f9-3398-47ea-ad13-fe9502a0eb33",
        redirectUri: "https://agewallet-sdk-demo.netlify.app/callback"
    ))

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if isVerified {
                VerifiedView(onClear: clearVerification)
            } else {
                UnverifiedView(onVerify: startVerification)
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
        isLoading = false
    }

    private func startVerification() {
        do {
            let url = try ageWallet.buildVerificationURL()
            UIApplication.shared.open(url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearVerification() {
        ageWallet.clearVerification()
        isVerified = false
    }
}

struct UnverifiedView: View {
    let onVerify: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.indigo)
            }

            VStack(spacing: 8) {
                Text("Age Verification Required")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You must verify your age to access this content.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
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
        }
        .padding(32)
    }
}

struct VerifiedView: View {
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
