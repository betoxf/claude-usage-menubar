//
//  AppDelegate.swift
//  ClaudeUsageBar
//

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var viewModel = UsageViewModel.shared
    private var appearanceObserver: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        observeViewModel()
        observeAppearanceChanges()

        // Hide dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)
    }

    private func observeAppearanceChanges() {
        // Update when system appearance changes (light/dark mode)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        // Observe status bar button appearance directly
        if let button = statusItem.button {
            appearanceObserver = button.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.updateStatusImage()
                }
            }
        }

        // Update when settings change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: NSNotification.Name("SettingsChanged"),
            object: nil
        )
    }

    @objc private func appearanceChanged() {
        updateStatusImage()
    }

    @objc private func settingsChanged() {
        // Close popover if open (since bar width may change)
        if popover.isShown {
            popover.performClose(nil)
        }
        updateStatusImage()
    }

    private func setupStatusItem() {
        // Use fixed length for stacked layout
        statusItem = NSStatusBar.system.statusItem(withLength: 75)
        statusItem.isVisible = true

        if let button = statusItem.button {
            button.image = createStatusImage(fiveHour: 30, weekly: 10)
            button.imagePosition = .imageOnly
            button.action = #selector(togglePopover)
            button.target = self
            print("Status item created with image")
        } else {
            print("ERROR: Could not create status item button")
        }
    }

    private func createStatusImage(fiveHour: Int, weekly: Int) -> NSImage {
        let showIcon = viewModel.showIcon
        let showOnly5hr = viewModel.showOnly5hr
        let showOnlyWeekly = viewModel.showOnlyWeekly

        // Adjust width based on what's shown
        var width: CGFloat = 80
        if showOnly5hr || showOnlyWeekly { width = 50 }

        let height: CGFloat = showIcon ? 22 : 16

        // Update status item length
        statusItem.length = width

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        // Detect dark mode from status bar button's appearance
        let isDarkMode: Bool = {
            if let button = statusItem.button {
                return button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            }
            // Fallback: check system appearance
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }()

        // Colors that adapt to light/dark mode
        let anthropicOrange = NSColor(red: 0.83, green: 0.53, blue: 0.30, alpha: 1.0)
        let textColor = isDarkMode ? NSColor.white : NSColor(white: 0.25, alpha: 1.0)

        var yOffset: CGFloat = 0

        // Draw icon row if enabled
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

        // Determine colors based on thresholds
        // 0% = orange (no data?), 5h >= 90% = orange (warning), weekly >= 80% = orange (warning)
        let fiveHourColor: NSColor = (fiveHour == 0 || fiveHour >= 90) ? anthropicOrange : textColor
        let weeklyColor: NSColor = (weekly == 0 || weekly >= 80) ? anthropicOrange : textColor

        // Tiny labels for 5h and W - always use normal text color
        let tinyLabelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 6, weight: .regular),
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]

        // Numbers and percentages with conditional colors
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

        // Show 5h if not showing only weekly
        if !showOnlyWeekly {
            valuesString.append(NSAttributedString(string: "5h ", attributes: tinyLabelAttributes))
            valuesString.append(NSAttributedString(string: "\(fiveHour)", attributes: number5hAttributes))
            valuesString.append(NSAttributedString(string: "%", attributes: percent5hAttributes))
        }

        // Show weekly if not showing only 5hr
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
        return image
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(viewModel: viewModel)
        )
    }

    private func observeViewModel() {
        // Update immediately and then every 5 seconds
        updateStatusImage()

        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateStatusImage()
        }
    }

    private func updateStatusImage() {
        guard let button = statusItem.button else { return }
        let fiveHour = viewModel.usageData.fiveHourUsed
        let weekly = viewModel.usageData.weeklyUsed
        button.image = createStatusImage(fiveHour: fiveHour, weekly: weekly)
        print("Updated status bar: 5h=\(fiveHour)% weekly=\(weekly)%")
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

                // Make popover key window to receive keyboard events
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}
