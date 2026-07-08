import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var infoMessage: String?

    private var auth: AuthManager { env.auth }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))

                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding()
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))

                    PrimaryButton(
                        title: isSignUp ? "Create Account" : "Sign In",
                        isLoading: auth.isWorking,
                        isEnabled: isFormValid
                    ) {
                        Task { await submitEmail() }
                    }

                    Button(isSignUp ? "Have an account? Sign in" : "New here? Create an account") {
                        withAnimation { isSignUp.toggle() }
                        infoMessage = nil
                    }
                    .font(.footnote)

                    if !isSignUp {
                        Button("Forgot password?") {
                            Task { await forgotPassword() }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                dividerRow

                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        auth.prepareAppleRequest(request)
                    } onCompletion: { result in
                        Task { await auth.completeAppleSignIn(result.mapError { $0 as Error }) }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: Theme.Metrics.controlHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button {
                        Task { await auth.signInWithGoogle() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "g.circle.fill")
                            Text("Continue with Google").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Metrics.controlHeight)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .foregroundStyle(.primary)
                }

                messages
                legalFooter
            }
            .padding(24)
        }
        .background(backgroundGradient.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "flag.checkered.2.crossed")
                .font(.system(size: 52))
                .foregroundStyle(.white)
            Text("Scratch Score")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Score smarter with the scoring-zone method")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
        .padding(.bottom, 8)
    }

    private var dividerRow: some View {
        HStack {
            line; Text("or").font(.footnote).foregroundStyle(.secondary); line
        }
    }
    private var line: some View { Rectangle().fill(.quaternary).frame(height: 1) }

    @ViewBuilder private var messages: some View {
        if let error = auth.lastErrorMessage {
            Text(error).font(.footnote).foregroundStyle(.ssBad).multilineTextAlignment(.center)
        }
        if let infoMessage {
            Text(infoMessage).font(.footnote).foregroundStyle(.ssFairway).multilineTextAlignment(.center)
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 4) {
            Text("By continuing you agree to our")
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Link("Terms", destination: LegalLinks.terms)
                Text("and").font(.caption2).foregroundStyle(.secondary)
                Link("Privacy Policy", destination: LegalLinks.privacy)
            }
            .font(.caption2)
        }
        .padding(.top, 8)
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color.ssFairwayDark, Color.ssFairway.opacity(0.6)],
            startPoint: .top, endPoint: .center
        )
    }

    private var isFormValid: Bool {
        email.contains("@") && password.count >= 6
    }

    private func submitEmail() async {
        infoMessage = nil
        if isSignUp {
            let needsConfirmation = await auth.signUp(email: email, password: password)
            if needsConfirmation {
                infoMessage = "Check your inbox to confirm your email, then sign in."
                isSignUp = false
            }
        } else {
            await auth.signIn(email: email, password: password)
        }
    }

    private func forgotPassword() async {
        guard email.contains("@") else {
            infoMessage = "Enter your email above first."
            return
        }
        await auth.resetPassword(email: email)
        infoMessage = "If that email exists, a reset link is on its way."
    }
}

enum LegalLinks {
    static let privacy = URL(string: "https://blkfoxio.github.io/scratch-score/privacy.html")!
    static let terms = URL(string: "https://blkfoxio.github.io/scratch-score/terms.html")!
    static let support = URL(string: "https://blkfoxio.github.io/scratch-score/support.html")!
}
