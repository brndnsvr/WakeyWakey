import Cocoa

final class DurationMenuItemView: NSView, NSTextFieldDelegate {
    var onSubmit: ((String) -> Void)?

    private let durationField = NSTextField()
    private let defaultTextColor = NSColor.labelColor

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 36))

        let label = NSTextField(labelWithString: "Enable until")
        label.font = NSFont.menuFont(ofSize: 0)
        label.translatesAutoresizingMaskIntoConstraints = false

        durationField.placeholderString = "20m, 4h, 3.5h"
        durationField.controlSize = .small
        durationField.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        durationField.target = self
        durationField.action = #selector(submitDuration)
        durationField.delegate = self
        durationField.translatesAutoresizingMaskIntoConstraints = false
        durationField.setAccessibilityLabel("Enable until duration")
        durationField.setAccessibilityHelp(
            "Enter a duration such as 20m, 4h, or 3.5h, then press Return"
        )

        addSubview(label)
        addSubview(durationField)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            durationField.leadingAnchor.constraint(
                equalTo: label.trailingAnchor,
                constant: 8
            ),
            durationField.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -14
            ),
            durationField.centerYAnchor.constraint(equalTo: centerYAnchor),
            durationField.widthAnchor.constraint(greaterThanOrEqualToConstant: 130),
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
            window?.makeFirstResponder(self.durationField)
        }
    }

    @objc private func submitDuration() {
        onSubmit?(durationField.stringValue)
    }

    func showValidationError() {
        durationField.textColor = .systemRed
        durationField.toolTip =
            "Use a positive duration such as 20m, 4h, or 3.5h"
        window?.makeFirstResponder(durationField)
        NSSound.beep()
    }

    func clearAfterSubmission() {
        durationField.stringValue = ""
        durationField.textColor = defaultTextColor
        durationField.toolTip = nil
    }

    func controlTextDidChange(_ notification: Notification) {
        durationField.textColor = defaultTextColor
        durationField.toolTip = nil
    }
}
