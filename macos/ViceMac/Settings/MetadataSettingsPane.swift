import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MetadataSettingsPane: View {
    @EnvironmentObject private var metadataSettings: MetadataIngestionSettings
    @State private var selectedProviderID: MetadataProviderID?

    var body: some View {
        SettingsCustomPane {
            HStack(spacing: 0) {
                sourceList
                    .frame(width: 292)

                Divider()
                    .padding(.horizontal, 18)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let snapshot = selectedSnapshot {
                            MetadataProviderDetailPane(snapshot: snapshot)
                        }

                        MetadataMatchingSettingsSection()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear(perform: normalizeSelection)
        .onChange(of: metadataSettings.providerSnapshots) { _, _ in
            normalizeSelection()
        }
    }

    private var sourceList: some View {
        SettingsTableContainer(minHeight: 524) {
            List(selection: $selectedProviderID) {
                ForEach(metadataSettings.providerSnapshots) { snapshot in
                    MetadataProviderListRow(snapshot: snapshot)
                        .tag(snapshot.providerID)
                }
            }
            .listStyle(.sidebar)
        } footer: {
            HStack(spacing: 8) {
                Label("\(metadataSettings.configuredSourceCount) ready", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Label("No scraping", systemImage: "checkmark.shield")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.caption)
        }
    }

    private var selectedSnapshot: MetadataProviderSnapshot? {
        let snapshots = metadataSettings.providerSnapshots
        guard let selectedProviderID else {
            return snapshots.first
        }

        return snapshots.first { $0.providerID == selectedProviderID } ?? snapshots.first
    }

    private func normalizeSelection() {
        let snapshots = metadataSettings.providerSnapshots
        guard !snapshots.isEmpty else {
            selectedProviderID = nil
            return
        }

        if let selectedProviderID,
           snapshots.contains(where: { $0.providerID == selectedProviderID }) {
            return
        }

        selectedProviderID = snapshots.first?.providerID
    }
}

private struct MetadataProviderListRow: View {
    let snapshot: MetadataProviderSnapshot

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: snapshot.providerID.systemImage)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 22)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.providerID.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(snapshot.providerID.connectionKind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VMCStatusBadge(snapshot.statusTitle, color: statusColor)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        guard snapshot.providerID.isConfigurable else {
            return .secondary
        }

        if snapshot.configuration.isEnabled {
            return snapshot.isReady ? .green : .orange
        }

        return snapshot.isReady ? .blue : .secondary
    }
}

private struct MetadataProviderDetailPane: View {
    @EnvironmentObject private var metadataSettings: MetadataIngestionSettings

    let snapshot: MetadataProviderSnapshot

    var body: some View {
        Form {
            Section("Source") {
                LabeledContent("Provider") {
                    Label(snapshot.providerID.title, systemImage: snapshot.providerID.systemImage)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Mode") {
                    Label(snapshot.providerID.connectionKind.title,
                          systemImage: snapshot.providerID.connectionKind.systemImage)
                    .foregroundStyle(.secondary)
                }

                LabeledContent("Scope") {
                    SettingsValueText(snapshot.providerID.machineScopeTitle)
                }

                LabeledContent("Notes") {
                    SettingsValueText(snapshot.providerID.summaryTitle, lineLimit: 2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LabeledContent("Status") {
                    MetadataProviderStatusLabel(snapshot: snapshot)
                }

                if snapshot.providerID.isConfigurable {
                    Toggle("Enabled", isOn: enabledBinding)
                }
            }

            switch snapshot.providerID.connectionKind {
            case .importedDatabase:
                MetadataImportedDatabaseSection(snapshot: snapshot)
            case .documentedAPI:
                MetadataAPISettingsSection(snapshot: snapshot)
            case .unavailable:
                Section("Policy") {
                    LabeledContent("Retrieval") {
                        SettingsValueText("Not configured for import or API access", lineLimit: 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    LabeledContent("Scraping") {
                        Label("Disabled", systemImage: "nosign")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var enabledBinding: Binding<Bool> {
        Binding {
            snapshot.configuration.isEnabled
        } set: { isEnabled in
            metadataSettings.setEnabled(isEnabled, for: snapshot.providerID)
        }
    }
}

private struct MetadataProviderStatusLabel: View {
    let snapshot: MetadataProviderSnapshot

    var body: some View {
        Label(snapshot.statusTitle, systemImage: systemImage)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
    }

    private var systemImage: String {
        guard snapshot.providerID.isConfigurable else {
            return "nosign"
        }

        if snapshot.configuration.isEnabled {
            return snapshot.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        }

        return snapshot.isReady ? "checkmark.circle" : "circle"
    }

    private var color: Color {
        guard snapshot.providerID.isConfigurable else {
            return .secondary
        }

        if snapshot.configuration.isEnabled {
            return snapshot.isReady ? .green : .orange
        }

        return snapshot.isReady ? .blue : .secondary
    }
}

private struct MetadataImportedDatabaseSection: View {
    @EnvironmentObject private var metadataSettings: MetadataIngestionSettings
    @State private var importErrorMessage: String?

    let snapshot: MetadataProviderSnapshot

    var body: some View {
        Section("Database") {
            SettingsFilePathRow(
                title: "File",
                value: databaseTitle,
                onChoose: chooseDatabase,
                trailing: [
                    .init(title: "Clear", isEnabled: snapshot.configuration.databasePath != nil) {
                        metadataSettings.setDatabaseURL(nil, for: snapshot.providerID)
                    }
                ]
            )

            LabeledContent("Last import") {
                SettingsValueText(lastImportTitle)
            }
        }
        .alert("Import Failed",
               isPresented: Binding {
                   importErrorMessage != nil
               } set: { isPresented in
                   if !isPresented {
                       importErrorMessage = nil
                   }
               }) {
            Button("OK", role: .cancel) {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private var databaseTitle: String {
        guard let databasePath = snapshot.configuration.databasePath else {
            return "None"
        }

        return URL(fileURLWithPath: databasePath).lastPathComponent
    }

    private var lastImportTitle: String {
        guard let lastImportedAt = snapshot.configuration.lastImportedAt else {
            return "Never"
        }

        return lastImportedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func chooseDatabase() {
        let contentTypes = snapshot.providerID.importFilenameExtensions
            .compactMap { UTType(filenameExtension: $0) }

        guard let url = AppFilePanel.chooseFiles(title: "Choose \(snapshot.providerID.title) Source",
                                                  message: importPanelMessage,
                                                  prompt: "Choose",
                                                  allowedContentTypes: contentTypes,
                                                  directoryURL: snapshot.configuration.databasePath.map { URL(fileURLWithPath: $0).deletingLastPathComponent() })?.first else {
            return
        }

        do {
            try metadataSettings.importDatabasePackage(url, for: snapshot.providerID)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private var importPanelMessage: String {
        switch snapshot.providerID {
        case .gameBase64:
            return "Choose a GameBase64 MDB database, ZIP archive, or Inno Setup installer."
        case .igdb, .theGamesDB, .csdb:
            return "Choose a \(snapshot.providerID.title) database file."
        }
    }
}

private struct MetadataAPISettingsSection: View {
    @EnvironmentObject private var metadataSettings: MetadataIngestionSettings

    let snapshot: MetadataProviderSnapshot

    var body: some View {
        Section("Authentication") {
            ForEach(snapshot.providerID.credentialFields) { field in
                LabeledContent(field.title) {
                    HStack(spacing: 8) {
                        credentialField(field)
                            .textFieldStyle(.roundedBorder)

                        VMCIconButton("xmark.circle", help: "Clear \(field.title)") {
                            metadataSettings.setCredential("", providerID: snapshot.providerID, field: field)
                        }
                        .disabled(metadataSettings.credential(providerID: snapshot.providerID, field: field).isEmpty)
                    }
                }
            }

            LabeledContent("Credentials") {
                SettingsValueText(credentialsTitle)
            }
        }
    }

    @ViewBuilder
    private func credentialField(_ field: MetadataCredentialField) -> some View {
        if field.isSecret {
            SecureField(field.placeholder, text: credentialBinding(for: field))
        } else {
            TextField(field.placeholder, text: credentialBinding(for: field))
        }
    }

    private var credentialsTitle: String {
        let requiredFields = Set(snapshot.providerID.credentialFields)
        let configuredFields = snapshot.configuredCredentialFields

        guard !requiredFields.isEmpty else {
            return "No credentials required"
        }

        if requiredFields.isSubset(of: configuredFields) {
            return "Configured"
        }

        let missingFields = snapshot.providerID.credentialFields
            .filter { !configuredFields.contains($0) }
            .map(\.title)
        return "Missing \(missingFields.joined(separator: ", "))"
    }

    private func credentialBinding(for field: MetadataCredentialField) -> Binding<String> {
        Binding {
            metadataSettings.credential(providerID: snapshot.providerID, field: field)
        } set: { credential in
            metadataSettings.setCredential(credential, providerID: snapshot.providerID, field: field)
        }
    }
}

private struct MetadataMatchingSettingsSection: View {
    @EnvironmentObject private var metadataSettings: MetadataIngestionSettings

    var body: some View {
        Form {
            Section("Matching") {
                Toggle("Match new library items", isOn: $metadataSettings.matchesNewLibraryItems)

                Picker("Strategy", selection: $metadataSettings.matchStrategy) {
                    ForEach(MetadataMatchStrategy.allCases) { strategy in
                        Text(strategy.title).tag(strategy)
                    }
                }

                Toggle("Cache artwork locally", isOn: $metadataSettings.cachesArtworkLocally)

                Picker("Artwork", selection: $metadataSettings.artworkPreference) {
                    ForEach(MetadataArtworkPreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .disabled(!metadataSettings.cachesArtworkLocally)
            }

            Section("Retrieval Policy") {
                LabeledContent("Allowed") {
                    Label("Supported database imports and documented APIs", systemImage: "checkmark.shield")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Scraping") {
                    Label("Disabled", systemImage: "nosign")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
