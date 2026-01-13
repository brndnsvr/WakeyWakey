import Cocoa

final class SettingsViewController: NSViewController {

    // MARK: - Timer Controls

    private var timer1HoursPicker: NSPopUpButton!
    private var timer1MinutesPicker: NSPopUpButton!
    private var timer2HoursPicker: NSPopUpButton!
    private var timer2MinutesPicker: NSPopUpButton!
    private var timer3HoursPicker: NSPopUpButton!
    private var timer3MinutesPicker: NSPopUpButton!

    // MARK: - Behavior Controls

    private var idleThresholdField: NSTextField!
    private var idleThresholdStepper: NSStepper!
    private var minIntervalField: NSTextField!
    private var minIntervalStepper: NSStepper!
    private var maxIntervalField: NSTextField!
    private var maxIntervalStepper: NSStepper!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        setupUI()
        loadSettings()
    }

    private func setupUI() {
        // Main vertical stack
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])

        // Quick Timers section
        let timerBox = createSectionBox(title: "Quick Timers")
        let timerGrid = createTimerGrid()
        timerGrid.translatesAutoresizingMaskIntoConstraints = false
        timerBox.contentView?.addSubview(timerGrid)
        if let contentView = timerBox.contentView {
            NSLayoutConstraint.activate([
                timerGrid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                timerGrid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                timerGrid.topAnchor.constraint(equalTo: contentView.topAnchor),
                timerGrid.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
        mainStack.addArrangedSubview(timerBox)

        // Jiggle Behavior section
        let behaviorBox = createSectionBox(title: "Jiggle Behavior")
        let behaviorGrid = createBehaviorGrid()
        behaviorGrid.translatesAutoresizingMaskIntoConstraints = false
        behaviorBox.contentView?.addSubview(behaviorGrid)
        if let contentView = behaviorBox.contentView {
            NSLayoutConstraint.activate([
                behaviorGrid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                behaviorGrid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                behaviorGrid.topAnchor.constraint(equalTo: contentView.topAnchor),
                behaviorGrid.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
        mainStack.addArrangedSubview(behaviorBox)

        // Button container (right-aligned)
        let buttonContainer = NSStackView()
        buttonContainer.orientation = .horizontal
        buttonContainer.alignment = .centerY

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addArrangedSubview(spacer)

        let restoreButton = NSButton(title: "Restore Defaults", target: self, action: #selector(restoreDefaults))
        restoreButton.bezelStyle = .rounded
        buttonContainer.addArrangedSubview(restoreButton)

        mainStack.addArrangedSubview(buttonContainer)
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
    }

    // MARK: - Section Box Factory

    private func createSectionBox(title: String) -> NSBox {
        let box = NSBox()
        box.title = title
        box.titlePosition = .atTop
        box.titleFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
        box.contentViewMargins = NSSize(width: 12, height: 12)
        return box
    }

    // MARK: - Timer Grid

    private func createTimerGrid() -> NSView {
        // Create controls
        timer1HoursPicker = createHoursPicker()
        timer1MinutesPicker = createMinutesPicker()
        timer2HoursPicker = createHoursPicker()
        timer2MinutesPicker = createMinutesPicker()
        timer3HoursPicker = createHoursPicker()
        timer3MinutesPicker = createMinutesPicker()

        // Row 1
        let row1 = createTimerRow(
            label: "Preset 1",
            hoursPicker: timer1HoursPicker,
            minutesPicker: timer1MinutesPicker
        )

        // Row 2
        let row2 = createTimerRow(
            label: "Preset 2",
            hoursPicker: timer2HoursPicker,
            minutesPicker: timer2MinutesPicker
        )

        // Row 3
        let row3 = createTimerRow(
            label: "Preset 3",
            hoursPicker: timer3HoursPicker,
            minutesPicker: timer3MinutesPicker
        )

        let stack = NSStackView(views: [row1, row2, row3])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }

    private func createTimerRow(label: String, hoursPicker: NSPopUpButton, minutesPicker: NSPopUpButton) -> NSView {
        let labelView = createLabel(label)
        labelView.alignment = .right
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(equalToConstant: 70).isActive = true

        hoursPicker.target = self
        hoursPicker.action = #selector(timerValueChanged)

        let hrLabel = createSmallLabel("hr")

        minutesPicker.target = self
        minutesPicker.action = #selector(timerValueChanged)

        let minLabel = createSmallLabel("min")

        let row = NSStackView(views: [labelView, hoursPicker, hrLabel, minutesPicker, minLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        return row
    }

    // MARK: - Behavior Grid

    private func createBehaviorGrid() -> NSView {
        // Idle threshold row
        let idleLabel = createLabel("Start after")
        idleLabel.alignment = .right
        idleLabel.translatesAutoresizingMaskIntoConstraints = false
        idleLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true

        idleThresholdField = createNumberField(width: 55)
        idleThresholdStepper = createStepper(min: 5, max: 300, value: 42)
        idleThresholdStepper.target = self
        idleThresholdStepper.action = #selector(idleStepperChanged)

        let idleFieldStack = createStepperField(field: idleThresholdField, stepper: idleThresholdStepper)
        let idleSuffix = createSmallLabel("seconds of idle")

        let idleRow = NSStackView(views: [idleLabel, idleFieldStack, idleSuffix])
        idleRow.orientation = .horizontal
        idleRow.alignment = .centerY
        idleRow.spacing = 6

        // Jiggle interval row
        let intervalLabel = createLabel("Repeat every")
        intervalLabel.alignment = .right
        intervalLabel.translatesAutoresizingMaskIntoConstraints = false
        intervalLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true

        minIntervalField = createNumberField(width: 55)
        minIntervalStepper = createStepper(min: 10, max: 600, value: 42)
        minIntervalStepper.target = self
        minIntervalStepper.action = #selector(minIntervalStepperChanged)

        let minFieldStack = createStepperField(field: minIntervalField, stepper: minIntervalStepper)

        let toLabel = createSmallLabel("to")

        maxIntervalField = createNumberField(width: 55)
        maxIntervalStepper = createStepper(min: 10, max: 600, value: 79)
        maxIntervalStepper.target = self
        maxIntervalStepper.action = #selector(maxIntervalStepperChanged)

        let maxFieldStack = createStepperField(field: maxIntervalField, stepper: maxIntervalStepper)

        let secLabel = createSmallLabel("seconds")

        let intervalRow = NSStackView(views: [intervalLabel, minFieldStack, toLabel, maxFieldStack, secLabel])
        intervalRow.orientation = .horizontal
        intervalRow.alignment = .centerY
        intervalRow.spacing = 6

        let stack = NSStackView(views: [idleRow, intervalRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        return stack
    }

    // MARK: - Control Factories

    private func createLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13)
        return label
    }

    private func createSmallLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func createHoursPicker() -> NSPopUpButton {
        let picker = NSPopUpButton(frame: .zero, pullsDown: false)
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.widthAnchor.constraint(equalToConstant: 55).isActive = true
        for h in 0...24 {
            picker.addItem(withTitle: "\(h)")
        }
        return picker
    }

    private func createMinutesPicker() -> NSPopUpButton {
        let picker = NSPopUpButton(frame: .zero, pullsDown: false)
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.widthAnchor.constraint(equalToConstant: 55).isActive = true
        for m in stride(from: 0, through: 55, by: 5) {
            picker.addItem(withTitle: String(format: "%02d", m))
        }
        return picker
    }

    private func createNumberField(width: CGFloat) -> NSTextField {
        let field = NSTextField()
        field.formatter = createNumberFormatter()
        field.alignment = .right
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        field.target = self
        field.action = #selector(behaviorValueChanged)
        return field
    }

    private func createNumberFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 600
        formatter.allowsFloats = false
        return formatter
    }

    private func createStepper(min: Double, max: Double, value: Double) -> NSStepper {
        let stepper = NSStepper()
        stepper.minValue = min
        stepper.maxValue = max
        stepper.doubleValue = value
        stepper.increment = 1
        stepper.valueWraps = false
        stepper.translatesAutoresizingMaskIntoConstraints = false
        return stepper
    }

    private func createStepperField(field: NSTextField, stepper: NSStepper) -> NSView {
        // Stack field and stepper together with no gap
        let stack = NSStackView(views: [field, stepper])
        stack.orientation = .horizontal
        stack.spacing = 1
        stack.alignment = .centerY
        return stack
    }

    // MARK: - Load/Save

    private func loadSettings() {
        let settings = Settings.shared

        // Timer 1
        let t1Hours = Int(settings.timerDuration1) / 3600
        let t1Minutes = (Int(settings.timerDuration1) % 3600) / 60
        timer1HoursPicker.selectItem(at: t1Hours)
        selectMinutes(picker: timer1MinutesPicker, minutes: t1Minutes)

        // Timer 2
        let t2Hours = Int(settings.timerDuration2) / 3600
        let t2Minutes = (Int(settings.timerDuration2) % 3600) / 60
        timer2HoursPicker.selectItem(at: t2Hours)
        selectMinutes(picker: timer2MinutesPicker, minutes: t2Minutes)

        // Timer 3
        let t3Hours = Int(settings.timerDuration3) / 3600
        let t3Minutes = (Int(settings.timerDuration3) % 3600) / 60
        timer3HoursPicker.selectItem(at: t3Hours)
        selectMinutes(picker: timer3MinutesPicker, minutes: t3Minutes)

        // Behavior
        idleThresholdField.integerValue = Int(settings.idleThreshold)
        idleThresholdStepper.integerValue = Int(settings.idleThreshold)

        minIntervalField.integerValue = Int(settings.jiggleIntervalMin)
        minIntervalStepper.integerValue = Int(settings.jiggleIntervalMin)

        maxIntervalField.integerValue = Int(settings.jiggleIntervalMax)
        maxIntervalStepper.integerValue = Int(settings.jiggleIntervalMax)
    }

    private func selectMinutes(picker: NSPopUpButton, minutes: Int) {
        // Round to nearest 5 minutes
        let rounded = (minutes / 5) * 5
        let index = rounded / 5
        if index < picker.numberOfItems {
            picker.selectItem(at: index)
        }
    }

    // MARK: - Actions

    @objc private func timerValueChanged(_ sender: NSPopUpButton) {
        let settings = Settings.shared

        let t1Seconds = TimeInterval(timer1HoursPicker.indexOfSelectedItem * 3600 +
                                      timer1MinutesPicker.indexOfSelectedItem * 5 * 60)
        let t2Seconds = TimeInterval(timer2HoursPicker.indexOfSelectedItem * 3600 +
                                      timer2MinutesPicker.indexOfSelectedItem * 5 * 60)
        let t3Seconds = TimeInterval(timer3HoursPicker.indexOfSelectedItem * 3600 +
                                      timer3MinutesPicker.indexOfSelectedItem * 5 * 60)

        // Minimum 5 minutes for timers
        settings.timerDuration1 = max(300, t1Seconds)
        settings.timerDuration2 = max(300, t2Seconds)
        settings.timerDuration3 = max(300, t3Seconds)
    }

    @objc private func behaviorValueChanged(_ sender: NSTextField) {
        let settings = Settings.shared

        settings.idleThreshold = TimeInterval(idleThresholdField.integerValue)
        settings.jiggleIntervalMin = TimeInterval(minIntervalField.integerValue)
        settings.jiggleIntervalMax = TimeInterval(maxIntervalField.integerValue)

        // Sync UI with validated values from Settings
        syncBehaviorUI()
    }

    private func syncBehaviorUI() {
        let settings = Settings.shared
        idleThresholdField.integerValue = Int(settings.idleThreshold)
        idleThresholdStepper.integerValue = Int(settings.idleThreshold)
        minIntervalField.integerValue = Int(settings.jiggleIntervalMin)
        minIntervalStepper.integerValue = Int(settings.jiggleIntervalMin)
        maxIntervalField.integerValue = Int(settings.jiggleIntervalMax)
        maxIntervalStepper.integerValue = Int(settings.jiggleIntervalMax)
    }

    @objc private func idleStepperChanged(_ sender: NSStepper) {
        Settings.shared.idleThreshold = TimeInterval(sender.integerValue)
        syncBehaviorUI()
    }

    @objc private func minIntervalStepperChanged(_ sender: NSStepper) {
        Settings.shared.jiggleIntervalMin = TimeInterval(sender.integerValue)
        syncBehaviorUI()
    }

    @objc private func maxIntervalStepperChanged(_ sender: NSStepper) {
        Settings.shared.jiggleIntervalMax = TimeInterval(sender.integerValue)
        syncBehaviorUI()
    }

    @objc private func restoreDefaults(_ sender: NSButton) {
        Settings.shared.resetToDefaults()
        loadSettings()
    }
}
