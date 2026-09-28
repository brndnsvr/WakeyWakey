import Cocoa
import Combine

final class SettingsViewController: NSViewController, NSTextFieldDelegate {

    // MARK: - Mode Controls

    private var modeControl: NSSegmentedControl!
    private var modeDescriptionLabel: NSTextField!

    // MARK: - Timer Controls

    private var timer1HoursPicker: NSPopUpButton!
    private var timer1MinutesPicker: NSPopUpButton!
    private var timer2HoursPicker: NSPopUpButton!
    private var timer2MinutesPicker: NSPopUpButton!
    private var timer3HoursPicker: NSPopUpButton!
    private var timer3MinutesPicker: NSPopUpButton!

    // MARK: - Jiggle Behavior Controls

    private var behaviorBox: NSBox!
    private var idleThresholdField: NSTextField!
    private var idleThresholdStepper: NSStepper!
    private var minIntervalField: NSTextField!
    private var minIntervalStepper: NSStepper!
    private var maxIntervalField: NSTextField!
    private var maxIntervalStepper: NSStepper!

    // MARK: - Lights Behavior Controls

    private var lightsBox: NSBox!
    private var keepDisplayOnCheckbox: NSButton!
    private var preventSystemSleepCheckbox: NSButton!
    private var wakeDisplayCheckbox: NSButton!
    private var equivalentLabel: NSTextField!

    private var cancellables = Set<AnyCancellable>()

    private enum BehaviorLimit {
        static let idleThreshold = 5...300
        static let jiggleInterval = 10...600
    }

    private enum Layout {
        static let windowWidth: CGFloat = 400
        static let boxWidth: CGFloat = 360
        static let boxContentWidth: CGFloat = 336
        static let jiggleBoxBaseTitle = "Jiggle Behavior"
        static let lightsBoxBaseTitle = "Lights Behavior"
    }

    override func loadView() {
        view = NSView()
        setupUI()
        loadSettings()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        subscribeToSettingsChanges()
    }

    private func setupUI() {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: Layout.windowWidth).isActive = true

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
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])

        // Mode section
        addFullWidthBox(createModeBox(), to: mainStack)

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
        addFullWidthBox(timerBox, to: mainStack)

        // Jiggle Behavior section
        behaviorBox = createSectionBox(title: Layout.jiggleBoxBaseTitle)
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
        addFullWidthBox(behaviorBox, to: mainStack)

        // Lights Behavior section
        addFullWidthBox(createLightsBox(), to: mainStack)

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

    /// Adds a section box to the main stack at a fixed full-content-width (360 pt),
    /// per the mockup: every box is full width regardless of its own content.
    private func addFullWidthBox(_ box: NSBox, to stack: NSStackView) {
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: Layout.boxWidth).isActive = true
        stack.addArrangedSubview(box)
    }

    // MARK: - Mode Box

    private func createModeBox() -> NSBox {
        let box = createSectionBox(title: "Mode")

        let wakeyImage = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: "Wakey")
        let lightsImage = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "Lights")

        modeControl = NSSegmentedControl(
            labels: ["Wakey", "Lights"],
            trackingMode: .selectOne,
            target: self,
            action: #selector(modeChanged(_:))
        )
        modeControl.setImage(wakeyImage, forSegment: 0)
        modeControl.setImage(lightsImage, forSegment: 1)

        modeDescriptionLabel = createWrappingLabel("")

        let contentStack = NSStackView(views: [modeControl, modeDescriptionLabel])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        if let contentView = box.contentView {
            contentView.addSubview(contentStack)
            NSLayoutConstraint.activate([
                contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                contentStack.topAnchor.constraint(equalTo: contentView.topAnchor),
                contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
        return box
    }

    private static func modeDescription(for mode: KeepAwakeMode) -> String {
        switch mode {
        case .wakey:
            return "Keeps the Mac awake and gently moves the cursor while you\u{2019}re idle, so apps that watch for activity still see you."
        case .lights:
            return "Lights on, nobody home. Keeps the Mac and display awake without moving the cursor, same as caffeinate -disu."
        }
    }

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        Settings.shared.mode = sender.selectedSegment == 0 ? .wakey : .lights
    }

    // MARK: - Lights Behavior Box

    private func createLightsBox() -> NSBox {
        let box = createSectionBox(title: Layout.lightsBoxBaseTitle)
        lightsBox = box

        keepDisplayOnCheckbox = NSButton(
            checkboxWithTitle: "Keep the display on",
            target: self,
            action: #selector(lightsOptionChanged(_:))
        )

        preventSystemSleepCheckbox = NSButton(
            checkboxWithTitle: "Prevent system sleep",
            target: self,
            action: #selector(lightsOptionChanged(_:))
        )
        preventSystemSleepCheckbox.attributedTitle = Self.attributedCheckboxTitle(
            main: "Prevent system sleep",
            secondarySuffix: "(AC power only)"
        )

        wakeDisplayCheckbox = NSButton(
            checkboxWithTitle: "Wake the display when enabled",
            target: self,
            action: #selector(lightsOptionChanged(_:))
        )

        let row1 = createFlagRow(control: keepDisplayOnCheckbox, flag: "-d")
        let row2 = createFlagRow(control: preventSystemSleepCheckbox, flag: "-s")
        let row3 = createFlagRow(control: wakeDisplayCheckbox, flag: "-u")

        let rowsStack = NSStackView(views: [row1, row2, row3])
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 8

        let footnoteLabel = createWrappingLabel(
            "Always prevents idle sleep (-i). No cursor movement, so no Accessibility access needed. Chat apps may show you as Away."
        )
        equivalentLabel = createWrappingLabel("")

        let contentStack = NSStackView(views: [rowsStack, footnoteLabel, equivalentLabel])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        if let contentView = box.contentView {
            contentView.addSubview(contentStack)
            NSLayoutConstraint.activate([
                contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                contentStack.topAnchor.constraint(equalTo: contentView.topAnchor),
                contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
        return box
    }

    private func createFlagRow(control: NSButton, flag: String) -> NSView {
        let flagLabel = NSTextField(labelWithString: flag)
        flagLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        flagLabel.textColor = .secondaryLabelColor

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [control, spacer, flagLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: Layout.boxContentWidth).isActive = true
        return row
    }

    private static func attributedCheckboxTitle(main: String, secondarySuffix: String) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let result = NSMutableAttributedString(string: main, attributes: [.font: font])
        result.append(NSAttributedString(
            string: " " + secondarySuffix,
            attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
        ))
        return result
    }

    @objc private func lightsOptionChanged(_ sender: NSButton) {
        let isOn = sender.state == .on
        switch sender {
        case keepDisplayOnCheckbox:
            Settings.shared.lightsKeepDisplayOn = isOn
        case preventSystemSleepCheckbox:
            Settings.shared.lightsPreventSystemSleep = isOn
        case wakeDisplayCheckbox:
            Settings.shared.lightsWakeDisplay = isOn
        default:
            break
        }
    }

    // MARK: - Mode-Dependent UI Sync

    private func subscribeToSettingsChanges() {
        let settings = Settings.shared
        Publishers.CombineLatest4(
            settings.$mode,
            settings.$lightsKeepDisplayOn,
            settings.$lightsPreventSystemSleep,
            settings.$lightsWakeDisplay
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] mode, keepDisplayOn, preventSystemSleep, wakeDisplay in
            self?.refreshModeDependentUI(
                mode: mode,
                keepDisplayOn: keepDisplayOn,
                preventSystemSleep: preventSystemSleep,
                wakeDisplay: wakeDisplay
            )
        }
        .store(in: &cancellables)
    }

    private func refreshModeDependentUI(
        mode: KeepAwakeMode,
        keepDisplayOn: Bool,
        preventSystemSleep: Bool,
        wakeDisplay: Bool
    ) {
        modeControl.selectedSegment = (mode == .wakey) ? 0 : 1
        modeDescriptionLabel.stringValue = Self.modeDescription(for: mode)

        keepDisplayOnCheckbox.state = keepDisplayOn ? .on : .off
        preventSystemSleepCheckbox.state = preventSystemSleep ? .on : .off
        wakeDisplayCheckbox.state = wakeDisplay ? .on : .off

        let lightsPlan = PowerPlan.make(
            mode: .lights,
            keepDisplayOn: keepDisplayOn,
            preventSystemSleep: preventSystemSleep,
            wakeDisplay: wakeDisplay
        )
        equivalentLabel.stringValue = "Equivalent: " + (lightsPlan.caffeinateEquivalent ?? "")

        applyDimState(for: mode)
    }

    private func applyDimState(for mode: KeepAwakeMode) {
        setSection(
            box: behaviorBox,
            baseTitle: Layout.jiggleBoxBaseTitle,
            inactiveSuffix: " \u{00B7} Wakey only",
            active: mode == .wakey,
            controls: jiggleControls
        )
        setSection(
            box: lightsBox,
            baseTitle: Layout.lightsBoxBaseTitle,
            inactiveSuffix: " \u{00B7} Lights only",
            active: mode == .lights,
            controls: lightsControls
        )
    }

    /// Dims a section box for the mode it does not apply to.
    ///
    /// `NSBox.alphaValue` cannot be used here: its modern "grouped" fill and
    /// title render through a system material that goes fully transparent
    /// (not just faded) once the box's own layer opacity drops below 1.0.
    /// Instead, the box itself stays fully opaque (so its background and
    /// border draw normally) and only its `contentView` is faded, while the
    /// title is recolored to secondaryLabelColor via its title cell.
    private func setSection(box: NSBox, baseTitle: String, inactiveSuffix: String, active: Bool, controls: [NSControl]) {
        let titleText = active ? baseTitle : baseTitle + inactiveSuffix
        // Setting `.title` first resets the cell to the box's normal (plain,
        // full-color) title rendering; only override it for the inactive case.
        box.title = titleText
        if !active {
            (box.titleCell as? NSCell)?.attributedStringValue = NSAttributedString(
                string: titleText,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        }
        box.contentView?.alphaValue = active ? 1.0 : 0.45
        for control in controls {
            control.isEnabled = active
        }

        // Changing the title string/cell above does not, by itself, invalidate
        // NSBox's layout: its internal title text field keeps its old frame
        // (sized for the old text) until something marks the box as needing
        // layout again. Without this, a live mode change (segment, menu, CLI,
        // or Restore Defaults) on an already-open window leaves the title
        // clipped or oddly positioned until the window is closed and reopened.
        box.needsLayout = true
    }

    private var jiggleControls: [NSControl] {
        [idleThresholdField, idleThresholdStepper, minIntervalField, minIntervalStepper, maxIntervalField, maxIntervalStepper]
    }

    private var lightsControls: [NSControl] {
        [keepDisplayOnCheckbox, preventSystemSleepCheckbox, wakeDisplayCheckbox]
    }

    // MARK: - Shared Label Factory

    private func createWrappingLabel(_ text: String, fontSize: CGFloat = 12, color: NSColor = .secondaryLabelColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: fontSize)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: Layout.boxContentWidth).isActive = true
        return label
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

        let trailingSpacer = NSView()
        trailingSpacer.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [labelView, hoursPicker, hrLabel, minutesPicker, minLabel, trailingSpacer])
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
        let idleTrailingSpacer = NSView()
        idleTrailingSpacer.translatesAutoresizingMaskIntoConstraints = false

        let idleRow = NSStackView(views: [idleLabel, idleFieldStack, idleSuffix, idleTrailingSpacer])
        idleRow.orientation = .horizontal
        idleRow.alignment = .centerY
        idleRow.spacing = 6

        // Jiggle interval row
        let intervalLabel = createLabel("Repeat every")
        intervalLabel.alignment = .right
        intervalLabel.translatesAutoresizingMaskIntoConstraints = false
        intervalLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true

        minIntervalField = createNumberField(width: 55)
        minIntervalStepper = createStepper(min: 10, max: 600, value: 12)
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
        let intervalTrailingSpacer = NSView()
        intervalTrailingSpacer.translatesAutoresizingMaskIntoConstraints = false

        let intervalRow = NSStackView(views: [intervalLabel, minFieldStack, toLabel, maxFieldStack, secLabel, intervalTrailingSpacer])
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
        field.isSelectable = true
        field.isEditable = true
        field.usesSingleLineMode = true
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        field.delegate = self
        field.target = self
        field.action = #selector(behaviorValueChanged)
        return field
    }

    private func createNumberFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
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

    // MARK: - Text Field Editing

    func controlTextDidBeginEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, isBehaviorField(field) else { return }

        DispatchQueue.main.async { [weak field] in
            guard let field = field, let editor = field.currentEditor() else { return }
            editor.selectedRange = NSRange(location: field.stringValue.count, length: 0)
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, isBehaviorField(field) else { return }
        commitBehaviorValues(changedField: field)
    }

    private func isBehaviorField(_ field: NSTextField) -> Bool {
        field === idleThresholdField || field === minIntervalField || field === maxIntervalField
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
        syncBehaviorUI()

        // Mode + Lights
        refreshModeDependentUI(
            mode: settings.mode,
            keepDisplayOn: settings.lightsKeepDisplayOn,
            preventSystemSleep: settings.lightsPreventSystemSleep,
            wakeDisplay: settings.lightsWakeDisplay
        )
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
        commitBehaviorValues(changedField: sender)
    }

    private func commitBehaviorValues(changedField: NSTextField?) {
        let settings = Settings.shared

        let idleThreshold = clamped(idleThresholdField.integerValue, to: BehaviorLimit.idleThreshold)
        var minInterval = clamped(minIntervalField.integerValue, to: BehaviorLimit.jiggleInterval)
        var maxInterval = clamped(maxIntervalField.integerValue, to: BehaviorLimit.jiggleInterval)

        if maxInterval < minInterval {
            if changedField === maxIntervalField {
                minInterval = maxInterval
            } else {
                maxInterval = minInterval
            }
        }

        settings.idleThreshold = TimeInterval(idleThreshold)
        settings.jiggleIntervalMin = TimeInterval(minInterval)
        settings.jiggleIntervalMax = TimeInterval(maxInterval)

        // Sync UI with validated values from Settings
        syncBehaviorUI()
    }

    private func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    }

    private func syncBehaviorUI() {
        let settings = Settings.shared

        let idleThreshold = clamped(Int(settings.idleThreshold), to: BehaviorLimit.idleThreshold)
        let minInterval = clamped(Int(settings.jiggleIntervalMin), to: BehaviorLimit.jiggleInterval)
        let maxInterval = Swift.max(
            minInterval,
            clamped(Int(settings.jiggleIntervalMax), to: BehaviorLimit.jiggleInterval)
        )

        idleThresholdField.integerValue = idleThreshold
        idleThresholdStepper.integerValue = idleThreshold
        minIntervalField.integerValue = minInterval
        minIntervalStepper.integerValue = minInterval
        maxIntervalField.integerValue = maxInterval
        maxIntervalStepper.integerValue = maxInterval
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
