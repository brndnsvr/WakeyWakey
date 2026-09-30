import Cocoa

extension KeepAwakeMode {
    var scheduleSymbolName: String {
        switch self {
        case .wakey: return "cup.and.saucer"
        case .lights: return "lightbulb"
        }
    }

    /// Timeline fill. Brown and yellow differ in lightness as well as hue.
    var scheduleColor: NSColor {
        switch self {
        case .wakey: return .systemBrown
        case .lights: return .systemYellow
        }
    }
}

// MARK: - Week Timeline

/// A compact week-at-a-glance: one bar per weekday, midnight to midnight,
/// filled where a block runs and marked at the current time.
final class ScheduleTimelineView: NSView {

    var blocks: [ScheduleBlock] = [] {
        didSet { needsDisplay = true }
    }

    var calendar = Calendar.current {
        didSet { needsDisplay = true }
    }

    private enum Metrics {
        static let labelGutter: CGFloat = 34
        static let headerHeight: CGFloat = 16
        static let rowHeight: CGFloat = 10
        static let rowSpacing: CGFloat = 5
        static let hourLabelStep = 3
    }

    /// One painted stretch of a block on one weekday row, in minutes of that day.
    private struct Segment {
        let start: Int
        let end: Int
        /// When the run began, in minutes of the week; negative for a
        /// Saturday-night run spilling into Sunday.
        let runStart: Int
        let order: Int
        let mode: KeepAwakeMode
        let isEnabled: Bool
    }

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("j")
        return formatter
    }()

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: NSView.noIntrinsicMetric,
            height: Metrics.headerHeight + 7 * Metrics.rowHeight + 6 * Metrics.rowSpacing
        )
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Week at a glance")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Weekdays (1…7) top to bottom, starting on the locale's first day.
    private var weekdayOrder: [Int] {
        (0..<7).map { ((calendar.firstWeekday - 1 + $0) % 7) + 1 }
    }

    private var barWidth: CGFloat {
        bounds.width - Metrics.labelGutter
    }

    private func x(forMinuteOfDay minute: Int) -> CGFloat {
        Metrics.labelGutter + barWidth * CGFloat(minute) / CGFloat(ScheduleBlock.minutesPerDay)
    }

    private func rowRect(at index: Int) -> NSRect {
        NSRect(
            x: Metrics.labelGutter,
            y: Metrics.headerHeight + CGFloat(index) * (Metrics.rowHeight + Metrics.rowSpacing),
            width: barWidth,
            height: Metrics.rowHeight
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        drawHourLabels()

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        for (index, weekday) in weekdayOrder.enumerated() {
            let row = rowRect(at: index)

            let label = calendar.shortStandaloneWeekdaySymbols[weekday - 1] as NSString
            let labelSize = label.size(withAttributes: labelAttributes)
            label.draw(
                at: NSPoint(x: Metrics.labelGutter - 6 - labelSize.width, y: row.midY - labelSize.height / 2),
                withAttributes: labelAttributes
            )

            let track = NSBezierPath(roundedRect: row, xRadius: 2.5, yRadius: 2.5)
            NSColor.quaternaryLabelColor.setFill()
            track.fill()

            NSGraphicsContext.saveGraphicsState()
            track.addClip()
            for segment in segments(onWeekday: weekday) {
                segment.mode.scheduleColor.withAlphaComponent(segment.isEnabled ? 1.0 : 0.3).setFill()
                let x0 = x(forMinuteOfDay: segment.start)
                let x1 = x(forMinuteOfDay: segment.end)
                NSRect(x: x0, y: row.minY, width: x1 - x0, height: row.height).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
        }

        drawNowMarker()
    }

    /// The stretches to paint on one weekday row, in the order runs take
    /// charge: disabled blocks underneath, then by start time, so a later
    /// start (which wins an overlap) lands on top.
    private func segments(onWeekday weekday: Int) -> [Segment] {
        let dayStart = (weekday - 1) * ScheduleBlock.minutesPerDay
        let day = dayStart..<(dayStart + ScheduleBlock.minutesPerDay)
        var result: [Segment] = []

        for (order, block) in blocks.enumerated() {
            for run in block.weekOccurrences {
                // A Saturday-night run also lands on Sunday morning
                for shift in [0, -ScheduleBlock.minutesPerWeek] {
                    let range = (run.lowerBound + shift)..<(run.upperBound + shift)
                    guard range.overlaps(day) else { continue }
                    result.append(Segment(
                        start: max(range.lowerBound, day.lowerBound) - dayStart,
                        end: min(range.upperBound, day.upperBound) - dayStart,
                        runStart: range.lowerBound,
                        order: order,
                        mode: block.mode,
                        isEnabled: block.isEnabled
                    ))
                }
            }
        }

        return result.sorted { a, b in
            if a.isEnabled != b.isEnabled { return !a.isEnabled }
            if a.runStart != b.runStart { return a.runStart < b.runStart }
            return a.order < b.order
        }
    }

    private func drawHourLabels() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let reference = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 10 * 86_400))

        for hour in stride(from: 0, through: 24, by: Metrics.hourLabelStep) {
            guard let date = calendar.date(byAdding: .hour, value: hour % 24, to: reference) else { continue }
            let text = Self.hourFormatter.string(from: date) as NSString
            let size = text.size(withAttributes: attributes)
            let centerX = x(forMinuteOfDay: hour * 60)
            let originX: CGFloat
            switch hour {
            case 0: originX = centerX
            case 24: originX = centerX - size.width
            default: originX = centerX - size.width / 2
            }
            text.draw(at: NSPoint(x: originX, y: 0), withAttributes: attributes)

            if hour != 0 && hour != 24 {
                let line = NSBezierPath()
                line.move(to: NSPoint(x: centerX, y: Metrics.headerHeight - 2))
                line.line(to: NSPoint(x: centerX, y: rowRect(at: 6).maxY))
                line.lineWidth = 1
                NSColor.separatorColor.setStroke()
                line.stroke()
            }
        }
    }

    private func drawNowMarker() {
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: Date())
        guard let weekday = parts.weekday, let hour = parts.hour, let minute = parts.minute,
              let index = weekdayOrder.firstIndex(of: weekday) else { return }

        let row = rowRect(at: index)
        let x = x(forMinuteOfDay: hour * 60 + minute)
        let marker = NSBezierPath()
        marker.move(to: NSPoint(x: x, y: row.minY - 3))
        marker.line(to: NSPoint(x: x, y: row.maxY + 3))
        marker.lineWidth = 2
        marker.lineCapStyle = .round
        NSColor.systemRed.setStroke()
        marker.stroke()
    }
}

// MARK: - Block Row

/// One editable schedule block: on/off, weekdays, start and end, mode, remove.
final class ScheduleRowView: NSStackView {

    private(set) var block: ScheduleBlock
    var onChange: ((ScheduleBlock) -> Void)?
    var onRemove: ((UUID) -> Void)?

    private let calendar: Calendar
    private let weekdayOrder: [Int]
    private var enabledCheckbox: NSButton!
    private var daysControl: NSSegmentedControl!
    private var startPicker: NSDatePicker!
    private var endPicker: NSDatePicker!
    private var modePopUp: NSPopUpButton!

    /// A fixed, DST-free day to hang time-of-day values on.
    private lazy var referenceDay = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 10 * 86_400))

    init(block: ScheduleBlock, width: CGFloat, calendar: Calendar = .current) {
        self.block = block
        self.calendar = calendar
        self.weekdayOrder = (0..<7).map { ((calendar.firstWeekday - 1 + $0) % 7) + 1 }
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        spacing = 8
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        buildControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildControls() {
        enabledCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(controlChanged))
        enabledCheckbox.state = block.isEnabled ? .on : .off
        enabledCheckbox.setAccessibilityLabel("Block on")

        let dayLabels = weekdayOrder.map { calendar.veryShortStandaloneWeekdaySymbols[$0 - 1] }
        daysControl = NSSegmentedControl(
            labels: dayLabels,
            trackingMode: .selectAny,
            target: self,
            action: #selector(controlChanged)
        )
        for (segment, weekday) in weekdayOrder.enumerated() {
            daysControl.setWidth(24, forSegment: segment)
            daysControl.setSelected(block.weekdays.contains(weekday), forSegment: segment)
            daysControl.setToolTip(calendar.standaloneWeekdaySymbols[weekday - 1], forSegment: segment)
        }
        daysControl.setAccessibilityLabel("Days")

        startPicker = makeTimePicker(minute: block.startMinute, label: "Start time")
        endPicker = makeTimePicker(minute: block.endMinute, label: "End time")

        let toLabel = NSTextField(labelWithString: "to")
        toLabel.font = NSFont.systemFont(ofSize: 12)
        toLabel.textColor = .secondaryLabelColor

        modePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
        for mode in [KeepAwakeMode.wakey, .lights] {
            modePopUp.addItem(withTitle: mode.displayName)
            modePopUp.lastItem?.image = NSImage(systemSymbolName: mode.scheduleSymbolName, accessibilityDescription: nil)
        }
        modePopUp.selectItem(at: block.mode == .wakey ? 0 : 1)
        modePopUp.target = self
        modePopUp.action = #selector(controlChanged)
        modePopUp.setAccessibilityLabel("Mode")

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false

        let removeImage = NSImage(systemSymbolName: "minus.circle", accessibilityDescription: "Remove block") ?? NSImage()
        let removeButton = NSButton(image: removeImage, target: self, action: #selector(removeClicked))
        removeButton.isBordered = false
        removeButton.contentTintColor = .secondaryLabelColor
        removeButton.toolTip = "Remove block"

        for view in [enabledCheckbox, daysControl, startPicker, toLabel, endPicker, modePopUp, spacer, removeButton] as [NSView] {
            addArrangedSubview(view)
        }
        setCustomSpacing(16, after: daysControl)
        setCustomSpacing(4, after: startPicker)
        setCustomSpacing(4, after: toLabel)
        setCustomSpacing(16, after: endPicker)
    }

    private func makeTimePicker(minute: Int, label: String) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        picker.datePickerMode = .single
        picker.isBezeled = true
        picker.dateValue = date(forMinute: minute)
        picker.target = self
        picker.action = #selector(controlChanged)
        picker.setAccessibilityLabel(label)
        return picker
    }

    private func date(forMinute minute: Int) -> Date {
        calendar.date(byAdding: .minute, value: minute, to: referenceDay) ?? referenceDay
    }

    /// Reads a picker as minutes after midnight, snapped to the 5-minute grid.
    ///
    /// Values on the grid only ever move by one minute via the stepper, so a
    /// remainder of 1 means "stepped up" and 4 means "stepped down". Snap in
    /// that direction so the stepper moves a whole step each click; anything
    /// else (typed) snaps to the nearest step.
    private func snappedMinute(from picker: NSDatePicker) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: picker.dateValue)
        let raw = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let step = ScheduleBlock.minuteStep
        let snapped: Int
        switch raw % step {
        case 0: snapped = raw
        case 1: snapped = raw + (step - 1)
        case step - 1: snapped = raw - (step - 1)
        default: snapped = Int((Double(raw) / Double(step)).rounded()) * step
        }
        return snapped % ScheduleBlock.minutesPerDay
    }

    @objc private func controlChanged(_ sender: Any) {
        block.isEnabled = enabledCheckbox.state == .on
        block.weekdays = Set(weekdayOrder.enumerated().compactMap { segment, weekday in
            daysControl.isSelected(forSegment: segment) ? weekday : nil
        })
        block.startMinute = snappedMinute(from: startPicker)
        block.endMinute = snappedMinute(from: endPicker)
        block.mode = modePopUp.indexOfSelectedItem == 0 ? .wakey : .lights

        startPicker.dateValue = date(forMinute: block.startMinute)
        endPicker.dateValue = date(forMinute: block.endMinute)
        onChange?(block)
    }

    @objc private func removeClicked(_ sender: NSButton) {
        onRemove?(block.id)
    }
}

// MARK: - Section

/// The Settings window's Schedule section, editing `Settings.scheduleEnabled`
/// and `Settings.scheduleBlocks`. `AppDelegate` follows them each tick.
final class ScheduleSectionView: NSView {

    /// Called after a block is added or removed, so the window can refit.
    var onHeightChange: (() -> Void)?

    private let settings = Settings.shared
    private var blocks: [ScheduleBlock] = []
    private let contentWidth: CGFloat

    private var enableCheckbox: NSButton!
    private var statusLabel: NSTextField!
    private var detailStack: NSStackView!
    private var timelineView: ScheduleTimelineView!
    private var rowsStack: NSStackView!
    private var overlapLabel: NSTextField!
    private var clockTimer: Timer?

    init(contentWidth: CGFloat) {
        self.contentWidth = contentWidth
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        buildUI()
        reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Re-reads the schedule from Settings (after Restore Defaults, say).
    func reload() {
        enableCheckbox.state = settings.scheduleEnabled ? .on : .off
        let rowCountChanged = blocks.count != settings.scheduleBlocks.count
        blocks = settings.scheduleBlocks
        reloadRows()
        refresh()
        if rowCountChanged {
            onHeightChange?()
        }
    }

    // Keep the status line and the "now" marker current while the window is open
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        clockTimer?.invalidate()
        clockTimer = nil
        guard window != nil else { return }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func buildUI() {
        enableCheckbox = NSButton(
            checkboxWithTitle: "Follow a weekly schedule",
            target: self,
            action: #selector(scheduleToggled)
        )

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .right

        let headerSpacer = NSView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false
        let headerRow = NSStackView(views: [enableCheckbox, headerSpacer, statusLabel])
        headerRow.orientation = .horizontal
        headerRow.alignment = .firstBaseline
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        timelineView = ScheduleTimelineView()
        timelineView.translatesAutoresizingMaskIntoConstraints = false
        timelineView.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        let legendSpacer = NSView()
        legendSpacer.translatesAutoresizingMaskIntoConstraints = false
        let legendRow = NSStackView(views: [legendSpacer, legendItem(for: .wakey), legendItem(for: .lights), nowLegendItem()])
        legendRow.orientation = .horizontal
        legendRow.alignment = .centerY
        legendRow.spacing = 14
        legendRow.translatesAutoresizingMaskIntoConstraints = false
        legendRow.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        rowsStack = NSStackView()
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 8

        let addImage = NSImage(systemSymbolName: "plus", accessibilityDescription: nil) ?? NSImage()
        let addButton = NSButton(title: "Add Block", image: addImage, target: self, action: #selector(addBlock))
        addButton.imagePosition = .imageLeading

        overlapLabel = NSTextField(labelWithString: "")
        overlapLabel.font = NSFont.systemFont(ofSize: 12)
        overlapLabel.textColor = .secondaryLabelColor

        let addRow = NSStackView(views: [addButton, overlapLabel])
        addRow.orientation = .horizontal
        addRow.alignment = .centerY
        addRow.spacing = 12

        let footnote = NSTextField(wrappingLabelWithString:
            "Outside these blocks WakeyWakey stays off unless you turn it on. Turning it off during a block skips the rest of that block, and your own timers or Enable run to their end. Where blocks overlap, the one that starts later wins. Times step by 5 minutes; an end before the start runs past midnight."
        )
        footnote.font = NSFont.systemFont(ofSize: 12)
        footnote.textColor = .secondaryLabelColor
        footnote.translatesAutoresizingMaskIntoConstraints = false
        footnote.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        detailStack = NSStackView(views: [timelineView, legendRow, rowsStack, addRow, footnote])
        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 10
        detailStack.setCustomSpacing(4, after: timelineView)
        detailStack.setCustomSpacing(14, after: legendRow)
        detailStack.setCustomSpacing(12, after: addRow)

        let contentStack = NSStackView(views: [headerRow, detailStack])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func legendItem(for mode: KeepAwakeMode) -> NSView {
        let swatch = NSImageView(image: NSImage(systemSymbolName: "square.fill", accessibilityDescription: nil) ?? NSImage())
        swatch.contentTintColor = mode.scheduleColor
        swatch.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 9, weight: .regular)
        return legendStack(swatch, mode.displayName)
    }

    private func nowLegendItem() -> NSView {
        let swatch = NSImageView(image: NSImage(systemSymbolName: "poweron", accessibilityDescription: nil) ?? NSImage())
        swatch.contentTintColor = .systemRed
        swatch.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        return legendStack(swatch, "Now")
    }

    private func legendStack(_ swatch: NSImageView, _ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [swatch, label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        return stack
    }

    // MARK: Rows

    private func reloadRows() {
        for view in rowsStack.arrangedSubviews {
            rowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for block in blocks {
            let row = ScheduleRowView(block: block, width: contentWidth)
            row.onChange = { [weak self] updated in
                guard let self, let index = self.blocks.firstIndex(where: { $0.id == updated.id }) else { return }
                self.blocks[index] = updated
                self.saveBlocks()
            }
            row.onRemove = { [weak self] id in
                guard let self else { return }
                self.blocks.removeAll { $0.id == id }
                self.reloadRows()
                self.saveBlocks()
                self.onHeightChange?()
            }
            rowsStack.addArrangedSubview(row)
        }
        applyEnabledState()
    }

    @objc private func addBlock(_ sender: NSButton) {
        if let last = blocks.last {
            // Pick up where the last block ends, for an hour
            blocks.append(ScheduleBlock(
                weekdays: last.weekdays,
                startMinute: last.endMinute,
                endMinute: last.endMinute + 60,
                mode: .wakey
            ))
        } else {
            blocks.append(.starter())
        }
        reloadRows()
        saveBlocks()
        onHeightChange?()
    }

    private func saveBlocks() {
        settings.scheduleBlocks = blocks
        refresh()
    }

    // MARK: State

    @objc private func scheduleToggled(_ sender: NSButton) {
        settings.scheduleEnabled = sender.state == .on
        applyEnabledState()
        refresh()
    }

    private func applyEnabledState() {
        let isOn = enableCheckbox.state == .on
        detailStack.alphaValue = isOn ? 1.0 : 0.45
        setControlsEnabled(isOn, in: detailStack)
    }

    private func setControlsEnabled(_ enabled: Bool, in view: NSView) {
        for subview in view.subviews {
            if let control = subview as? NSControl, !(control is NSTextField) {
                control.isEnabled = enabled
            }
            setControlsEnabled(enabled, in: subview)
        }
    }

    private func refresh() {
        timelineView.blocks = blocks
        timelineView.needsDisplay = true
        statusLabel.stringValue = statusText()

        let overlaps = ScheduleBlock.overlapWeekdays(in: blocks)
        if overlaps.isEmpty {
            overlapLabel.stringValue = ""
        } else {
            let calendar = Calendar.current
            let order = (0..<7).map { ((calendar.firstWeekday - 1 + $0) % 7) + 1 }
            let names = order.filter(overlaps.contains).map { calendar.shortStandaloneWeekdaySymbols[$0 - 1] }
            overlapLabel.stringValue = "Overlap on \(names.joined(separator: ", ")): the later start wins"
        }
    }

    /// The schedule on its own terms; a manual off or your own timer can
    /// override it at runtime, and the menu shows that.
    private func statusText() -> String {
        guard enableCheckbox.state == .on else { return "Schedule off" }
        let schedule = WeeklySchedule(blocks: blocks)
        let now = Date()
        if let current = schedule.current(at: now) {
            let until = schedule.nextChange(after: now, from: current)
            return "Now: \(current.mode.displayName) until \(ScheduleText.time(until))"
        }
        if let next = schedule.nextStart(after: now) {
            return "Next: \(next.mode.displayName) \(ScheduleText.dayAndTime(next.start))"
        }
        return blocks.isEmpty ? "Add a block to get started" : "No blocks on"
    }
}
