import Cocoa

/// The window that stays up while Wakey mode lacks the Accessibility permission.
///
/// Wakey posts cursor-move events, which macOS only delivers from apps
/// approved under Privacy & Security → Accessibility. Without it WakeyWakey
/// still keeps the Mac awake but cannot move the cursor, and nothing on
/// screen would say so. So this window has no close button: it goes away
/// when the permission is granted, or when the mode is switched to Lights,
/// which needs none. `AppDelegate` decides when to show and dismiss it.
final class AccessibilityPermissionWindowController: NSWindowController {

    var onOpenSettings: (() -> Void)?
    var onUseLights: (() -> Void)?

    private var spinner: NSProgressIndicator!
    private var grantedImageView: NSImageView!
    private var statusLabel: NSTextField!
    private var openButton: NSButton!
    private var lightsButton: NSButton!

    private enum Layout {
        static let textWidth: CGFloat = 380
        static let iconSize: CGFloat = 56
        static let screenInset: CGFloat = 24
        static let grantedDismissDelay: TimeInterval = 1.5
    }

    convenience init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "WakeyWakey"
        // Above other windows and on every desktop: it must not get lost
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildContent()
    }

    // MARK: - Content

    private func buildContent() {
        let iconView = NSImageView(image: NSApp.applicationIconImage)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: Layout.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: Layout.iconSize)
        ])

        let titleLabel = NSTextField(wrappingLabelWithString: "Wakey mode needs Accessibility access")
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)

        let bodyLabel = wrappingLabel(
            "Wakey keeps you looking active by nudging the cursor while you\u{2019}re idle. macOS only allows that for apps you approve under Accessibility. Until you do, WakeyWakey keeps the Mac awake but can\u{2019}t move the cursor."
        )

        let stepsLabel = wrappingLabel(
            "1. Click Open Accessibility Settings.\n2. Turn on WakeyWakey in the list.",
            color: .labelColor
        )

        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)

        let grantedImage = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Granted") ?? NSImage()
        grantedImageView = NSImageView(image: grantedImage)
        grantedImageView.contentTintColor = .systemGreen
        grantedImageView.isHidden = true

        statusLabel = NSTextField(labelWithString: "Waiting for permission. This window closes by itself.")
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor

        let statusRow = NSStackView(views: [spinner, grantedImageView, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 6

        let textStack = NSStackView(views: [titleLabel, bodyLabel, stepsLabel, statusRow])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 10
        textStack.setCustomSpacing(14, after: stepsLabel)
        for label in [titleLabel, bodyLabel, stepsLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: Layout.textWidth).isActive = true
        }

        let topRow = NSStackView(views: [iconView, textStack])
        topRow.orientation = .horizontal
        topRow.alignment = .top
        topRow.spacing = 16

        lightsButton = NSButton(title: "Use Lights Instead", target: self, action: #selector(useLightsClicked))
        lightsButton.toolTip = "Lights keeps the Mac awake without moving the cursor, so it needs no permission"

        openButton = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openSettingsClicked))
        openButton.keyEquivalent = "\r"

        let buttonSpacer = NSView()
        buttonSpacer.translatesAutoresizingMaskIntoConstraints = false
        let buttonRow = NSStackView(views: [lightsButton, buttonSpacer, openButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY

        let mainStack = NSStackView(views: [topRow, buttonRow])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 20
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            buttonRow.widthAnchor.constraint(equalTo: mainStack.widthAnchor)
        ])

        window?.contentView = contentView
        contentView.layoutSubtreeIfNeeded()
        window?.setContentSize(contentView.fittingSize)
    }

    private func wrappingLabel(_ text: String, color: NSColor = .secondaryLabelColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = color
        return label
    }

    // MARK: - Showing

    /// Shows the window, or brings it back to the front if it is already up.
    func show() {
        guard let window else { return }
        if !window.isVisible {
            placeTopRight(window)
        }
        // A menu bar app is rarely the active one, so order front regardless
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Top-right corner, clear of the system's own centered permission alert
    /// and of System Settings, which opens mid-screen.
    private func placeTopRight(_ window: NSWindow) {
        guard let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else {
            window.center()
            return
        }
        window.setFrameOrigin(NSPoint(
            x: visible.maxX - window.frame.width - Layout.screenInset,
            y: visible.maxY - window.frame.height - Layout.screenInset
        ))
    }

    /// Confirms the grant, then closes after a moment.
    func showGrantedThenClose() {
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        grantedImageView.isHidden = false
        statusLabel.stringValue = "Accessibility granted. Wakey is ready."
        statusLabel.textColor = .labelColor
        openButton.isEnabled = false
        lightsButton.isEnabled = false

        // Captured strongly on purpose: AppDelegate lets go of this controller
        // as soon as the permission is granted, and it must outlive the delay
        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.grantedDismissDelay) {
            self.close()
        }
    }

    // MARK: - Actions

    @objc private func openSettingsClicked(_ sender: NSButton) {
        onOpenSettings?()
    }

    @objc private func useLightsClicked(_ sender: NSButton) {
        onUseLights?()
    }
}
