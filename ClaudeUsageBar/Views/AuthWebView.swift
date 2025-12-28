//
//  AuthWebView.swift
//  ClaudeUsageBar
//

import SwiftUI

struct AuthWindowView: View {
    @Environment(\.dismiss) private var dismiss
    let onAuthenticated: (String, String) -> Void

    @State private var sessionKey: String = ""
    @State private var organizationId: String = ""
    @State private var showDisclosure: Bool = true

    private let anthropicOrange = Color(red: 0.83, green: 0.53, blue: 0.30)

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(spacing: 2) {
                Text("✳︎")
                    .foregroundColor(anthropicOrange)
                Text("Claude")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Button("×") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }

            // Open browser button
            Button(action: openBrowser) {
                Text("Open claude.ai")
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint(anthropicOrange)

            // Beta auto extract (placeholder for future)
            Text("Beta: Auto Sign-in coming soon")
                .font(.system(size: 7))
                .foregroundColor(.secondary.opacity(0.6))

            Divider()

            // Credentials form
            VStack(alignment: .leading, spacing: 8) {
                Text("Paste your credentials")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Session Key")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                    SecureField("sk-ant-sid01-...", text: $sessionKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 9))
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.3)))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Organization ID")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                    TextField("uuid from URL", text: $organizationId)
                        .textFieldStyle(.plain)
                        .font(.system(size: 9))
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.3)))
                }

                Button("Done") {
                    onAuthenticated(sessionKey, organizationId)
                    dismiss()
                }
                .font(.system(size: 10))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(sessionKey.isEmpty || organizationId.isEmpty ? Color.secondary.opacity(0.3) : anthropicOrange)
                .foregroundColor(.white)
                .cornerRadius(4)
                .disabled(sessionKey.isEmpty || organizationId.isEmpty)
                .buttonStyle(.plain)
            }

            Divider()

            // Disclosure
            VStack(spacing: 4) {
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showDisclosure.toggle() } }) {
                    HStack(spacing: 3) {
                        Text("Not affiliated with Anthropic")
                            .font(.system(size: 7))
                        Text(showDisclosure ? "▼" : "▶")
                            .font(.system(size: 5))
                    }
                    .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)

                if showDisclosure {
                    Text("Your credentials are stored locally in macOS Keychain. We do not send or store your data on any server. Sign in at your own risk.")
                        .font(.system(size: 6))
                        .foregroundColor(.secondary.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(width: 220)
    }

    private func openBrowser() {
        if let url = URL(string: "https://claude.ai/settings/usage") {
            NSWorkspace.shared.open(url)
        }
    }
}
