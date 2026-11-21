import SwiftUI
import SwiftData

struct SchedulesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LEDDevice.name) private var devices: [LEDDevice]
    @State private var showingAddSchedule = false
    @State private var selectedDeviceForSchedule: LEDDevice?

    var body: some View {
        NavigationStack {
            Group {
                if devices.isEmpty {
                    ContentUnavailableView(
                        "No Devices",
                        systemImage: "lightbulb.slash",
                        description: Text("Add LED devices first to create schedules")
                    )
                } else if allSchedules.isEmpty {
                    ContentUnavailableView(
                        "No Schedules",
                        systemImage: "calendar.badge.plus",
                        description: Text("Create schedules to automate your lights")
                    ) {
                        Button("Add Schedule") {
                            selectedDeviceForSchedule = devices.first
                            showingAddSchedule = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(devices) { device in
                            let deviceSchedules = device.schedules.sorted { $0.name < $1.name }
                            if !deviceSchedules.isEmpty {
                                Section(device.name) {
                                    ForEach(deviceSchedules) { schedule in
                                        ScheduleRow(schedule: schedule)
                                    }
                                    .onDelete { indices in
                                        deleteSchedules(deviceSchedules, at: indices)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Schedules")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        selectedDeviceForSchedule = devices.first
                        showingAddSchedule = true
                    } label: {
                        Label("Add Schedule", systemImage: "plus")
                    }
                    .disabled(devices.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddSchedule) {
                if let device = selectedDeviceForSchedule {
                    NavigationStack {
                        ScheduleEditorView(device: device)
                    }
                }
            }
        }
    }

    private var allSchedules: [WeeklySchedule] {
        devices.flatMap { $0.schedules }
    }

    private func deleteSchedules(_ schedules: [WeeklySchedule], at indices: IndexSet) {
        for index in indices {
            modelContext.delete(schedules[index])
        }
        try? modelContext.save()
    }
}

struct ScheduleRow: View {
    let schedule: WeeklySchedule

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(schedule.name)
                        .font(.subheadline)
                    HStack(spacing: 12) {
                        Label(
                            "\(timeFormatter.string(from: schedule.weekdaysOn)) – \(timeFormatter.string(from: schedule.weekdaysOff))",
                            systemImage: "calendar"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Label(
                            "\(timeFormatter.string(from: schedule.weekendOn)) – \(timeFormatter.string(from: schedule.weekendOff))",
                            systemImage: "calendar.badge.clock"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { schedule.isEnabled },
                    set: { newValue in
                        schedule.isEnabled = newValue
                        schedule.updatedAt = Date()
                    }
                ))
                .labelsHidden()
            }

            // Target state preview
            if let state = RGBCCT.from(data: schedule.targetColor) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(state.swiftUIColor)
                        .frame(width: 24, height: 24)
                    Text("\(Int(schedule.targetIntensity * 100))% · \(Int(schedule.targetColorTemp))K")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let device: LEDDevice

    @State private var name = ""
    @State private var weekdaysOn = Calendar.current.date(from: DateComponents(hour: 7, minute: 0))!
    @State private var weekdaysOff = Calendar.current.date(from: DateComponents(hour: 23, minute: 0))!
    @State private var weekendOn = Calendar.current.date(from: DateComponents(hour: 8, minute: 0))!
    @State private var weekendOff = Calendar.current.date(from: DateComponents(hour: 22, minute: 0))!
    @State private var targetRGBCCT: RGBCCT = .warmWhite
    @State private var targetIntensity: Double = 0.8
    @State private var targetColorTemp: Double = 3000
    @State private var isColorMode: Bool = false

    var body: some View {
        Form {
            Section("Schedule") {
                TextField("Name", text: $name)

                DatePicker("Weekdays On", selection: $weekdaysOn, displayedComponents: .hourAndMinute)
                DatePicker("Weekdays Off", selection: $weekdaysOff, displayedComponents: .hourAndMinute)
                DatePicker("Weekend On", selection: $weekendOn, displayedComponents: .hourAndMinute)
                DatePicker("Weekend Off", selection: $weekendOff, displayedComponents: .hourAndMinute)
            }

            Section("Target State") {
                Picker("Mode", selection: $isColorMode) {
                    Label("Color", systemImage: "paintpalette").tag(true)
                    Label("White", systemImage: "lightbulb").tag(false)
                }
                .pickerStyle(.segmented)

                if isColorMode {
                    // Simplified color picker for schedule
                    HStack {
                        Text("Color")
                        Spacer()
                        Circle()
                            .fill(targetRGBCCT.swiftUIColor)
                            .frame(width: 30, height: 30)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("\(Int(targetColorTemp))K")
                            Slider(value: $targetColorTemp, in: 2000...6500, step: 100)
                                .tint(.orange)
                        }

                        HStack {
                            Text("Intensity")
                            Text("\(Int(targetIntensity * 100))%")
                                .foregroundStyle(.secondary)
                                .frame(width: 50)
                            Slider(value: $targetIntensity, in: 0...1)
                                .tint(.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle("New Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveSchedule()
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
    }

    private func saveSchedule() {
        let targetColor: Data
        if isColorMode {
            targetColor = targetRGBCCT.data
        } else {
            let warmRatio = (6500 - targetColorTemp) / 4500.0
            let totalWhite = targetIntensity * 255
            let warm = UInt8(totalWhite * warmRatio)
            let cool = UInt8(totalWhite * (1 - warmRatio))
            targetColor = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: warm, coolWhite: cool).data
        }

        let schedule = WeeklySchedule(
            name: name,
            weekdaysOn: weekdaysOn,
            weekdaysOff: weekdaysOff,
            weekendOn: weekendOn,
            weekendOff: weekendOff,
            targetColor: targetColor,
            targetIntensity: targetIntensity,
            targetColorTemp: targetColorTemp,
            isEnabled: true
        )
        schedule.device = device
        modelContext.insert(schedule)
        try? modelContext.save()
    }
}