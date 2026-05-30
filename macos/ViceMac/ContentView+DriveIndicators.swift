import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DriveIndicator: View {
    @State private var isPresented = false

    let drive: DriveActivity

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let blinkOn = Int(context.date.timeIntervalSinceReferenceDate / 0.35).isMultiple(of: 2)

            Button {
                isPresented.toggle()
            } label: {
                HStack(spacing: 6) {
                    if drive.hasMultipleSlots {
                        DriveSlotLEDStack(drive: drive, blinkOn: blinkOn)
                    } else {
                        let color = indicatorColor(blinkOn: blinkOn)

                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                            .shadow(color: color.opacity(drive.isActive ? 0.45 : 0),
                                    radius: 4)
                    }

                    Text("\(drive.unit)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    if drive.isFastAccessEnabled {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.yellow)
                    }

                    if let headPositionText = drive.headPositionText {
                        Text(headPositionText)
                            .font(.system(.caption2, design: .monospaced).weight(.medium))
                            .foregroundStyle(headPositionColor)
                            .frame(minWidth: 24, alignment: .leading)
                            .baselineOffset(-1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .background(isPresented ? Color.secondary.opacity(0.18) : Color.clear, in: Capsule())
            .help("Drive \(drive.unit)")
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                DrivePopover(isPresented: $isPresented, drive: drive)
            }
        }
    }

    private func indicatorColor(blinkOn: Bool) -> Color {
        if drive.hasErrorStatus {
            return blinkOn ? .red : .red.opacity(0.25)
        }

        let color = drive.ledColor.displayColor
        return drive.isActive ? color : color.opacity(0.28)
    }

    private var headPositionColor: Color {
        if drive.hasErrorStatus {
            return .red.opacity(0.9)
        }

        return .secondary
    }
}

private struct DriveSlotLEDStack: View {
    let drive: DriveActivity
    let blinkOn: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(drive.slots) { slot in
                let color = indicatorColor(for: slot)

                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .shadow(color: color.opacity(slot.isActive ? 0.5 : 0),
                            radius: 3)
            }
        }
        .frame(width: 14, alignment: .leading)
    }

    private func indicatorColor(for slot: DriveSlotActivity) -> Color {
        if drive.hasErrorStatus {
            return blinkOn ? .red : .red.opacity(0.25)
        }

        let color = slot.ledColor.displayColor
        return slot.isActive ? color : color.opacity(0.28)
    }
}

private struct DrivePopover: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @Binding var isPresented: Bool
    @State private var autorun = false

    let drive: DriveActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "externaldrive")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Drive \(drive.unit)")
                        .font(.headline)
                    Text("\(drive.driveType.title) • \(drive.driveType.busTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 6) {
                    ForEach(drive.slots) { slot in
                        DriveSlotPopoverRow(slot: slot,
                                            unit: drive.unit,
                                            showsDriveNumber: drive.hasMultipleSlots,
                                            isActive: slot.isActive,
                                            hasError: drive.hasErrorStatus) {
                            openDiskPanel(for: slot.driveNumber)
                        } onDetach: {
                            emulator.detachDisk(from: drive.unit, driveNumber: slot.driveNumber)
                        }
                    }
                }

                VMCInfoRow("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                        Text(statusTitle)
                    }
                }

                VMCInfoRow("Formats") {
                    Text(diskImageFormatDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                VMCInfoRow("Access") {
                    Picker("Access", selection: accessModeBinding) {
                        ForEach(DriveAccessMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .help(accessModeHelp)
                }

                if let headPositionText = drive.headPositionText {
                    VMCInfoRow("Track") {
                        Text(drive.headDetailText ?? headPositionText)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }

            Divider()

            Toggle("Run after attach", isOn: $autorun)

            HStack(spacing: 8) {
                Button {
                    emulator.resetDrive(drive.unit)
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private var statusTitle: String {
        drive.resolvedStatusText
    }

    private var statusColor: Color {
        if drive.hasErrorStatus {
            return .red
        }

        return drive.hasDiskImage ? .green : Color.secondary.opacity(0.45)
    }

    private var accessModeBinding: Binding<DriveAccessMode> {
        Binding {
            emulator.driveAccessMode(for: drive.unit)
        } set: { accessMode in
            emulator.setDriveAccessMode(accessMode, for: drive.unit)
        }
    }

    private var accessModeHelp: String {
        switch emulator.driveAccessMode(for: drive.unit) {
        case .native:
            return "Use true drive emulation without virtual traps"
        case .fast:
            return "Enable virtual traps and disable true drive emulation for faster disk access"
        }
    }

    private func openDiskPanel(for driveNumber: Int) {
        let panel = NSOpenPanel()
        panel.title = "Attach Disk"
        panel.message = "Choose a \(diskImageFormatDescription) image for \(driveAddress(for: driveNumber))."
        panel.prompt = "Attach"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = allowedDiskImageTypes

        isPresented = false
        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        emulator.attachDisk(to: drive.unit, driveNumber: driveNumber, url: url, autorun: autorun)
    }

    private func driveAddress(for driveNumber: Int) -> String {
        drive.hasMultipleSlots ? "drive \(drive.unit):\(driveNumber)" : "drive \(drive.unit)"
    }

    private var diskImageFormatDescription: String {
        drive.driveType.supportedDiskImageDescription
    }

    private var allowedDiskImageTypes: [UTType] {
        let types = drive.driveType.supportedDiskImageTypes.compactMap { type in
            UTType(filenameExtension: type.rawValue)
        }

        return types.isEmpty ? [.data] : types
    }
}

private struct DriveSlotPopoverRow: View {
    let slot: DriveSlotActivity
    let unit: Int
    let showsDriveNumber: Bool
    let isActive: Bool
    let hasError: Bool
    let onAttach: () -> Void
    let onDetach: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
                .shadow(color: indicatorColor.opacity(isActive ? 0.45 : 0),
                        radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))

                Text(diskTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if let diskKind {
                Text(diskKind)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            Button {
                onAttach()
            } label: {
                Label("Attach", systemImage: "externaldrive.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Attach disk to \(title.lowercased())")

            Button {
                onDetach()
            } label: {
                Label("Eject", systemImage: "eject")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!slot.hasDiskImage)
            .help("Detach disk from \(title.lowercased())")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private var title: String {
        showsDriveNumber ? "Drive \(unit):\(slot.driveNumber)" : "Disk"
    }

    private var diskTitle: String {
        guard let imagePath = slot.imagePath,
              !imagePath.isEmpty else {
            return "No disk attached"
        }

        return URL(fileURLWithPath: imagePath).lastPathComponent
    }

    private var diskKind: String? {
        guard let imagePath = slot.imagePath else {
            return nil
        }

        let pathExtension = URL(fileURLWithPath: imagePath).pathExtension
        return pathExtension.isEmpty ? nil : pathExtension.uppercased()
    }

    private var indicatorColor: Color {
        if hasError {
            return .red
        }

        let color = slot.ledColor.displayColor
        return isActive ? color : color.opacity(0.28)
    }
}

private extension DriveLEDColor {
    var displayColor: Color {
        switch self {
        case .red:
            return .red
        case .green:
            return .green
        }
    }
}
