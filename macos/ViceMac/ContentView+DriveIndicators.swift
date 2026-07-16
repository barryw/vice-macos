import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DriveIndicator: View {
    @State private var isPresented = false

    let drive: DriveActivity

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let blinkOn = Int(context.date.timeIntervalSinceReferenceDate / 0.35).isMultiple(of: 2)

            VMCIndicatorChip(isPresented: $isPresented,
                             help: drive.isSharedFolder ? "Drive \(drive.unit) Shared Mac Folder" : "Drive \(drive.unit)") {
                HStack(spacing: 6) {
                    if drive.isSharedFolder {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(drive.sharedFolderPath == nil ? Color.secondary : Color.blue)
                    } else if drive.hasMultipleSlots {
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
            } popover: {
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
            VMCPopoverHeader(systemImage: drive.isSharedFolder ? "folder" : "externaldrive",
                             title: "Drive \(drive.unit)",
                             subtitle: subtitle)

            if drive.isSharedFolder {
                sharedFolderContent
            } else {
                diskDriveContent
            }

            Divider()

            if !drive.isSharedFolder {
                Toggle("Run after attach", isOn: $autorun)
            }

            HStack(spacing: 8) {
                if drive.isSharedFolder,
                   let url = drive.sharedFolderURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Label("Reveal in Finder", systemImage: "finder")
                    }
                }

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

    private var diskDriveContent: some View {
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
    }

    private var sharedFolderContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            VMCInfoRow("Folder") {
                Text(drive.sharedFolderPath ?? "Choose a folder in Storage settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            VMCInfoRow("Status") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(statusTitle)
                }
            }

            VMCInfoRow("Works") {
                HStack(spacing: 6) {
                    VMCStatusBadge("LOAD", color: .green)
                    VMCStatusBadge("SAVE", color: .green)
                    VMCStatusBadge("Directory", color: .green)
                }
            }

            VMCInfoRow("Limits") {
                HStack(spacing: 6) {
                    VMCStatusBadge("No format", color: .orange)
                    VMCStatusBadge("No raw blocks", color: .orange)
                }
            }
        }
    }

    private var subtitle: String {
        if drive.isSharedFolder {
            return "Shared Mac Folder"
        }

        return "\(drive.driveType.title) • \(drive.driveType.busTitle)"
    }

    private var statusTitle: String {
        drive.resolvedStatusText
    }

    private var statusColor: Color {
        if drive.hasErrorStatus {
            return .red
        }

        if drive.isSharedFolder {
            return drive.sharedFolderPath == nil ? Color.secondary.opacity(0.45) : .green
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
        isPresented = false

        guard let url = AppFilePanel.chooseFiles(title: drive.storageKind == .hardDriveImage ? "Attach Hard Drive Image" : "Attach Disk",
                                                  message: "Choose a \(diskImageFormatDescription) image for \(driveAddress(for: driveNumber)).",
                                                  prompt: "Attach",
                                                  allowedContentTypes: allowedDiskImageTypes)?.first else {
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
                VMCStatusBadge(diskKind)
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
