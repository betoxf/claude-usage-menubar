//
//  PopoverView.swift
//  ClaudeUsageBar
//

import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var showingSettings = false
    @State private var showingAuthWindow = false

    // Anthropic orange
    private let anthropicOrange = Color(red: 0.83, green: 0.53, blue: 0.30)

    // Display mode label
    private var displayModeLabel: String {
        if viewModel.showOnly5hr { return "5h" }
        if viewModel.showOnlyWeekly { return "W" }
        return "Both"
    }

    // Cycle through display modes: Both → 5h → W → Both
    private func cycleDisplayMode() {
        if !viewModel.showOnly5hr && !viewModel.showOnlyWeekly {
            viewModel.showOnly5hr = true
            viewModel.showOnlyWeekly = false
        } else if viewModel.showOnly5hr {
            viewModel.showOnly5hr = false
            viewModel.showOnlyWeekly = true
        } else {
            viewModel.showOnly5hr = false
            viewModel.showOnlyWeekly = false
        }
        notifySettingsChanged()
    }

    private func notifySettingsChanged() {
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }

    var body: some View {
        VStack(spacing: 8) {
            if !viewModel.hasCredentials {
                // Auto-open auth window
                Text("Loading...")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .onAppear {
                        showingAuthWindow = true
                    }
            } else {
                // 5-Hour
                UsageRowMinimal(
                    title: "5h",
                    percentage: viewModel.usageData.fiveHourPercentage,
                    resetTime: viewModel.usageData.timeUntilFiveHourReset,
                    color: anthropicOrange
                )

                // Weekly
                UsageRowMinimal(
                    title: "7d",
                    percentage: viewModel.usageData.weeklyPercentage,
                    resetTime: viewModel.usageData.timeUntilWeeklyReset,
                    color: anthropicOrange
                )

                Divider()
                    .padding(.vertical, 2)

                // Minimal controls row
                HStack(spacing: 6) {
                    // Auth button
                    Button(action: { showingSettings = true }) {
                        Text("✳︎")
                            .font(.system(size: 8))
                            .foregroundColor(anthropicOrange)
                            .frame(width: 14, height: 14)
                            .background(Circle().stroke(anthropicOrange, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    // Startup toggle
                    Toggle("", isOn: $viewModel.launchAtStartup)
                        .labelsHidden()
                        .scaleEffect(0.6)
                        .tint(anthropicOrange)
                    Text("Start")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)

                    // Icon toggle
                    Toggle("", isOn: Binding(
                        get: { viewModel.showIcon },
                        set: { viewModel.showIcon = $0; notifySettingsChanged() }
                    ))
                        .labelsHidden()
                        .scaleEffect(0.6)
                        .tint(anthropicOrange)
                    Text("Icon")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)

                    // Display mode clicker (cycles: Both → 5h → W → Both)
                    Button(action: { cycleDisplayMode() }) {
                        Text(displayModeLabel)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(anthropicOrange))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .frame(width: 170)
        .onTapGesture(count: 2) {
            showingSettings = true
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAuthWindow) {
            AuthWindowView { sessionKey, orgId in
                viewModel.saveCredentials(sessionKey: sessionKey, organizationId: orgId)
            }
        }
    }
}

// MARK: - Minimal Usage Row

struct UsageRowMinimal: View {
    let title: String
    let percentage: Double
    let resetTime: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(percentage))%")
                    .font(.system(size: 10, weight: .semibold))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * min(percentage / 100, 1.0), height: 4)
                }
            }
            .frame(height: 4)

            Text(resetTime)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PopoverView(viewModel: UsageViewModel.shared)
}
