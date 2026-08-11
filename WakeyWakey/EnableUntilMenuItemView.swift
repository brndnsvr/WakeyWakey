import Cocoa

final class EnableUntilMenuItemView: NSView, NSTextFieldDelegate {
    var onSubmit: ((String) -> Void)?

    private let timeField = NSTextField()
    private let defaultTextColor = NSColor.labelColor

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 36))

        let label = NSTextField(labelWithString: "Enable until")
        label.font = NSFont.menuFont(ofSize: 0)
        label.translatesAutoresizingMaskIntoConstraints = false

        timeField.placeholderString = "5pm, 5:00"
        timeField.controlSize = .small
        timeField.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        timeField.target = self
        timeField.action = #selector(submitTime)
        timeField.delegate = self
        timeField.translatesAutoresizingMaskIntoConstraints = false
        timeField.setAccessibilityLabel("Enable until time")
        timeField.setAccessibilityHelp(
            "Enter a time such as 5pm, 5:00, or 5:30pm, then press Return"
        )

        addSubview(label)
        addSubview(timeField)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            timeField.leadingAnchor.constraint(
                equalTo: label.trailingAnchor,
                constant: 8
            ),
            timeField.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -14
            ),
            timeField.centerYAnchor.constraint(equalTo: centerYAnchor),
            timeField.widthAnchor.constraint(greaterThanOrEqualToConstant: 130),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }

        DispatchQueue.main.async { [weak self, weak window] in
            guard let self else { return }
            window?.makeFirstResponder(self.timeField)
        }
    }

    @objc private func submitTime() {
        onSubmit?(timeField.stringValue)
    }

    func showValidationError() {
        timeField.textColor = .systemRed
        timeField.toolTip = "Use a time such as 5pm, 5:00, or 5:30pm"
        window?.makeFirstResponder(timeField)
        NSSound.beep()
    }

    func clearAfterSubmission() {
        timeField.stringValue = ""
        timeField.textColor = defaultTextColor
        timeField.toolTip = nil
    }

    func controlTextDidChange(_ notification: Notification) {
        timeField.textColor = defaultTextColor
        timeField.toolTip = nil
    }
}
