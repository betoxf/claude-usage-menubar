//
//  AppDelegate.swift
//  ClaudeUsageBar
//

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var viewModel = UsageViewModel.shared
    private var lastStatusLength: CGFloat = 0
    private var credentialsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()
        observeChanges()

        // Hide dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)

        // Only update status bar if we have credentials
        if viewModel.hasCredentials {
            updateStatusImage()
        } else {
            showSetupStatus()
        }
    }

    private func observeChanges() {
        // Update when system appearance changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        // Update when settings change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: NSNotification.Name("SettingsChanged"),
            object: nil
        )

        // Update when usage data changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(usageDataChanged),
            name: NSNotification.Name("UsageDataChanged"),
            object: nil
        )
    }

    @objc private func appearanceChanged() {
        if viewModel.hasCredentials {
            updateStatusImage()
        }
    }

    @objc private func settingsChanged() {
        if viewModel.hasCredentials {
            updateStatusImage()
        }
        rebuildMenu()
    }

    @objc private func usageDataChanged() {
        updateStatusImage()
        rebuildMenu()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
    }

    private func showSetupStatus() {
        guard let button = statusItem.button else { return }

        let width: CGFloat = 50
        let height: CGFloat = 22

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        let isDarkMode: Bool = {
            return button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }()

        let anthropicOrange = NSColor(red: 0.83, green: 0.53, blue: 0.30, alpha: 1.0)
        let textColor = isDarkMode ? NSColor.white : NSColor(white: 0.25, alpha: 1.0)

        // Draw "✳︎ Claude" on top
        let starAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7, weight: .bold),
            .foregroundColor: anthropicOrange
        ]
        let starString = NSAttributedString(string: "✳︎", attributes: starAttributes)

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7, weight: .medium),
            .foregroundColor: textColor
        ]
        let labelString = NSAttributedString(string: "Claude", attributes: labelAttributes)

        let totalLabelWidth = starString.size().width + 1 + labelString.size().width
        let labelStartX = (width - totalLabelWidth) / 2

        starString.draw(at: NSPoint(x: labelStartX, y: 12))
        labelString.draw(at: NSPoint(x: labelStartX + starString.size().width + 1, y: 12))

        // Draw "Setup" below
        let setupAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: anthropicOrange
        ]
        let setupString = NSAttributedString(string: "Setup", attributes: setupAttributes)
        let setupX = (width - setupString.size().width) / 2
        setupString.draw(at: NSPoint(x: setupX, y: 0))

        image.unlockFocus()
        image.isTemplate = false

        statusItem.length = width
        button.image = image
    }

    private func setupMenu() {
        menu = NSMenu()
        rebuildMenu()
        statusItem.menu = menu
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        if !viewModel.hasCredentials {
            // Setup menu
            let setupItem = NSMenuItem(title: "Setup Claude Usage", action: #selector(showCredentialsWindow), keyEquivalent: "")
            setupItem.target = self
            menu.addItem(setupItem)
        } else {
            // Usage info (non-clickable)
            let fiveHour = viewModel.usageData.fiveHourUsed
            let weekly = viewModel.usageData.weeklyUsed
            let fiveHourReset = viewModel.usageData.timeUntilFiveHourReset
            let weeklyReset = viewModel.usageData.timeUntilWeeklyReset

            let fiveHourItem = NSMenuItem(title: "5h: \(fiveHour)%  •  \(fiveHourReset)", action: nil, keyEquivalent: "")
            fiveHourItem.isEnabled = false
            menu.addItem(fiveHourItem)

            let weeklyItem = NSMenuItem(title: "7d: \(weekly)%  •  \(weeklyReset)", action: nil, keyEquivalent: "")
            weeklyItem.isEnabled = false
            menu.addItem(weeklyItem)

            menu.addItem(NSMenuItem.separator())

            // Refresh
            let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshData), keyEquivalent: "r")
            refreshItem.target = self
            menu.addItem(refreshItem)

            // Display mode
            let displayMenu = NSMenu()
            let bothItem = NSMenuItem(title: "Show Both", action: #selector(showBoth), keyEquivalent: "")
            bothItem.target = self
            bothItem.state = (!viewModel.showOnly5hr && !viewModel.showOnlyWeekly) ? .on : .off
            displayMenu.addItem(bothItem)

            let only5hItem = NSMenuItem(title: "Show 5h Only", action: #selector(showOnly5h), keyEquivalent: "")
            only5hItem.target = self
            only5hItem.state = viewModel.showOnly5hr ? .on : .off
            displayMenu.addItem(only5hItem)

            let onlyWeeklyItem = NSMenuItem(title: "Show Weekly Only", action: #selector(showOnlyWeekly), keyEquivalent: "")
            onlyWeeklyItem.target = self
            onlyWeeklyItem.state = viewModel.showOnlyWeekly ? .on : .off
            displayMenu.addItem(onlyWeeklyItem)

            let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
            displayItem.submenu = displayMenu
            menu.addItem(displayItem)

            // Icon toggle
            let iconItem = NSMenuItem(title: "Show Icon", action: #selector(toggleIcon), keyEquivalent: "")
            iconItem.target = self
            iconItem.state = viewModel.showIcon ? .on : .off
            menu.addItem(iconItem)

            menu.addItem(NSMenuItem.separator())

            // Sign out
            let signOutItem = NSMenuItem(title: "Sign Out", action: #selector(signOut), keyEquivalent: "")
            signOutItem.target = self
            menu.addItem(signOutItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    // MARK: - Menu Actions

    @objc private func showCredentialsWindow() {
        if credentialsWindow == nil {
            let contentView = CredentialsView(onSave: { [weak self] sessionKey, orgId in
                self?.viewModel.saveCredentials(sessionKey: sessionKey, organizationId: orgId)
                self?.credentialsWindow?.close()
                self?.credentialsWindow = nil
                self?.updateStatusImage()
                self?.rebuildMenu()
            })

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = ""
            window.titlebarAppearsTransparent = true
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            window.isReleasedWhenClosed = false
            credentialsWindow = window
        }

        credentialsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func refreshData() {
        Task {
            await viewModel.refresh()
        }
    }

    @objc private func showBoth() {
        viewModel.showOnly5hr = false
        viewModel.showOnlyWeekly = false
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }

    @objc private func showOnly5h() {
        viewModel.showOnly5hr = true
        viewModel.showOnlyWeekly = false
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }

    @objc private func showOnlyWeekly() {
        viewModel.showOnly5hr = false
        viewModel.showOnlyWeekly = true
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }

    @objc private func toggleIcon() {
        viewModel.showIcon.toggle()
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }

    @objc private func signOut() {
        viewModel.clearCredentials()
        showSetupStatus()
        rebuildMenu()
    }

    // MARK: - Status Bar Image

    private func updateStatusImage() {
        guard let button = statusItem.button else { return }

        let fiveHour = viewModel.usageData.fiveHourUsed
        let weekly = viewModel.usageData.weeklyUsed
        let (image, width) = createStatusImage(fiveHour: fiveHour, weekly: weekly)

        if lastStatusLength != width {
            lastStatusLength = width
            statusItem.length = width
        }

        button.image = image
    }

    private func createStatusImage(fiveHour: Int, weekly: Int) -> (NSImage, CGFloat) {
        let showIcon = viewModel.showIcon
        let showOnly5hr = viewModel.showOnly5hr
        let showOnlyWeekly = viewModel.showOnlyWeekly

        var width: CGFloat = 80
        if showOnly5hr || showOnlyWeekly { width = 50 }

        let height: CGFloat = showIcon ? 22 : 16

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        let isDarkMode: Bool = {
            if let button = statusItem.button {
                return button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            }
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }()

        let anthropicOrange = NSColor(red: 0.83, green: 0.53, blue: 0.30, alpha: 1.0)
        let textColor = isDarkMode ? NSColor.white : NSColor(white: 0.25, alpha: 1.0)

        var yOffset: CGFloat = 0

        if showIcon {
            let starAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 7, weight: .bold),
                .foregroundColor: anthropicOrange
            ]
            let starString = NSAttributedString(string: "✳︎", attributes: starAttributes)

            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 7, weight: .medium),
                .foregroundColor: textColor
            ]
            let labelString = NSAttributedString(string: "Claude", attributes: labelAttributes)

            let totalLabelWidth = starString.size().width + 1 + labelString.size().width
            let labelStartX = (width - totalLabelWidth) / 2

            starString.draw(at: NSPoint(x: labelStartX, y: 12))
            labelString.draw(at: NSPoint(x: labelStartX + starString.size().width + 1, y: 12))
            yOffset = 0
        } else {
            yOffset = 3
        }

        let fiveHourColor: NSColor = (fiveHour == 0 || fiveHour >= 90) ? anthropicOrange : textColor
        let weeklyColor: NSColor = (weekly == 0 || weekly >= 80) ? anthropicOrange : textColor

        let tinyLabelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 6, weight: .regular),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]

        let number5hAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: fiveHourColor
        ]
        let percent5hAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: fiveHourColor
        ]
        let numberWAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: weeklyColor
        ]
        let percentWAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: weeklyColor
        ]

        let valuesString = NSMutableAttributedString()

        if !showOnlyWeekly {
            valuesString.append(NSAttributedString(string: "5h ", attributes: tinyLabelAttributes))
            valuesString.append(NSAttributedString(string: "\(fiveHour)", attributes: number5hAttributes))
            valuesString.append(NSAttributedString(string: "%", attributes: percent5hAttributes))
        }

        if !showOnly5hr {
            if !showOnlyWeekly {
                valuesString.append(NSAttributedString(string: "  ", attributes: tinyLabelAttributes))
            }
            valuesString.append(NSAttributedString(string: "W ", attributes: tinyLabelAttributes))
            valuesString.append(NSAttributedString(string: "\(weekly)", attributes: numberWAttributes))
            valuesString.append(NSAttributedString(string: "%", attributes: percentWAttributes))
        }

        valuesString.draw(at: NSPoint(x: (width - valuesString.size().width) / 2, y: yOffset))

        image.unlockFocus()
        image.isTemplate = false
        return (image, width)
    }
}

// MARK: - Credentials View (for setup window)

struct CredentialsView: View {
    let onSave: (String, String) -> Void

    @State private var step = 1
    @State private var sessionKey = ""
    @State private var organizationId = ""

    private let anthropicOrange = Color(red: 0.83, green: 0.53, blue: 0.30)

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 4) {
                Text("✳︎")
                    .foregroundColor(anthropicOrange)
                    .font(.title2)
                Text("Claude Usage")
                    .font(.headline)
            }
            .padding(.top, 8)

            if step == 1 {
                Spacer()
                VStack(spacing: 12) {
                    Text("Step 1: Sign in to Claude")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Button(action: {
                        if let url = URL(string: "https://claude.ai/settings/usage") {
                            NSWorkspace.shared.open(url)
                        }
                        step = 2
                    }) {
                        Text("Open Claude.ai")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(anthropicOrange)

                    Text("Skip →")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .onTapGesture { step = 2 }
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Step 2: Get credentials")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    // Organization ID instructions
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Organization ID")
                            .font(.caption)
                            .fontWeight(.medium)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("In Safari: ⌥⌘I → Network tab")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Find \"usage\" request, copy UUID from URL:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("/organizations/{this-id}/usage")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(anthropicOrange)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.08)))

                        TextField("263e9fcb-52b9-4372-8842-...", text: $organizationId)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Session Key instructions
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session Key")
                            .font(.caption)
                            .fontWeight(.medium)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("⌘F search \"sessionKey\" in cookies")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Copy value until the ;")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.08)))

                        SecureField("sk-ant-sid01-...", text: $sessionKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("← Back")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .onTapGesture { step = 1 }

                        Spacer()

                        Button("Save") {
                            onSave(sessionKey.trimmingCharacters(in: .whitespacesAndNewlines),
                                   organizationId.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(anthropicOrange)
                        .disabled(sessionKey.isEmpty || organizationId.isEmpty)
                    }
                }
            }

            Spacer()

            Text("Not affiliated with Anthropic.\nCredentials stored locally in Keychain.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(width: 300, height: 400)
    }
}
