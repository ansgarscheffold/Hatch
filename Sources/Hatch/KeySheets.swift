import SwiftUI

extension View {
    @ViewBuilder
    func hatchKeySheets(presented: Binding<KeySheetMode?>, viewModel: AppViewModel) -> some View {
        sheet(item: presented) { mode in
            switch mode {
            case .importKey:
                ImportKeySheet(viewModel: viewModel)
            case .generateKey:
                GenerateKeySheet(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Shared

private struct KeySheetHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(.windowBackgroundColor))
    }
}

private struct KeySheetFooter: View {
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle")
                    Text(LocalizedStrings.cancel)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(action: onSave) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                    Text(LocalizedStrings.save)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

private struct PublicKeyPreview: View {
    let title: String
    let publicKey: String
    let showInstallHint: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                if !publicKey.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(publicKey, forType: .string)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text(LocalizedStrings.copy)
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            if publicKey.isEmpty {
                Text(LocalizedStrings.publicKeyOptional)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.textBackgroundColor).opacity(0.5))
                    .cornerRadius(6)
            } else {
                ScrollView {
                    Text(publicKey)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 72)
                .background(Color(.textBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
            if showInstallHint, !publicKey.isEmpty {
                Text(LocalizedStrings.publicKeyInstallHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Import

struct ImportKeySheet: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var keyName = ""
    @State private var privateKey = ""
    @State private var publicKey = ""
    @State private var passphrase = ""
    @State private var importedFileName = ""
    @State private var isVerifying = false
    @State private var importSucceeded = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !isVerifying
            && !keyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && importSucceeded
            && !privateKey.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            KeySheetHeader(title: LocalizedStrings.importExistingKey)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(LocalizedStrings.importKeyDescription)
                        .font(.callout)
                        .foregroundColor(.secondary)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text(LocalizedStrings.publicKeyHosterHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(action: pickPrivateKeyFile) {
                        HStack {
                            Image(systemName: "folder")
                            Text(LocalizedStrings.importKey)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isVerifying)

                    if !importedFileName.isEmpty {
                        LabeledContent(LocalizedStrings.importedKeyFile) {
                            Text(importedFileName)
                                .font(.system(.body, design: .monospaced))
                        }
                    }

                    if isVerifying {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(LocalizedStrings.keyVerifying)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else if !privateKey.isEmpty {
                        Label(LocalizedStrings.keyReadyToSave, systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    } else {
                        Label(LocalizedStrings.keyNotSelectedYet, systemImage: "key")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStrings.keyName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("", text: $keyName)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStrings.keyPassphrase)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        SecureField("", text: $passphrase)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        Text(LocalizedStrings.keyPassphraseHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    PublicKeyPreview(
                        title: publicKey.isEmpty
                            ? LocalizedStrings.publicKeyOptional
                            : LocalizedStrings.publicKeyDetected,
                        publicKey: publicKey,
                        showInstallHint: false
                    )

                    Text(LocalizedStrings.privateKeysEncrypted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(24)
            }

            Divider()
            KeySheetFooter(canSave: canSave, onCancel: { dismiss() }, onSave: saveKey)
        }
        .frame(width: 520, height: 580)
    }

    private func pickPrivateKeyFile() {
        let panel = NSOpenPanel()
        SSHKeyService.configureOpenPanelForPrivateKey(panel)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        importedFileName = url.lastPathComponent
        errorMessage = nil
        importSucceeded = false
        isVerifying = true

        let pass = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let passphraseForImport = pass.isEmpty ? nil : pass

        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<SSHKeyImportResult, Error> = Result {
                try SSHKeyService.importPrivateKey(from: url, passphrase: passphraseForImport)
            }
            DispatchQueue.main.async {
                isVerifying = false
                switch result {
                case .success(let importResult):
                    privateKey = importResult.privateKey
                    publicKey = importResult.publicKey ?? ""
                    importSucceeded = true
                    if keyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        keyName = importResult.suggestedName
                    }
                case .failure(let error):
                    privateKey = ""
                    publicKey = ""
                    importSucceeded = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func saveKey() {
        let trimmedPassphrase = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let pub = publicKey.isEmpty ? nil : publicKey
        let newKey = SSHKey(
            name: keyName.trimmingCharacters(in: .whitespacesAndNewlines),
            privateKey: privateKey,
            publicKey: pub,
            passphrase: trimmedPassphrase.isEmpty ? nil : trimmedPassphrase,
            keyType: SSHKeyService.detectKeyType(privateKey: privateKey, publicKey: pub),
            origin: .imported,
            importedFileName: importedFileName.isEmpty ? nil : importedFileName
        )
        viewModel.addKey(newKey)
        dismiss()
    }
}

// MARK: - Generate

struct GenerateKeySheet: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var keyName = ""
    @State private var privateKey = ""
    @State private var publicKey = ""
    @State private var keyType: KeyType = .ed25519
    @State private var passphrase = ""
    @State private var comment = ""
    @State private var isGenerating = false
    @State private var generationSucceeded = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !isGenerating
            && !keyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && generationSucceeded
            && !privateKey.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            KeySheetHeader(title: LocalizedStrings.generateNewKey)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(LocalizedStrings.generateKeyDescription)
                        .font(.callout)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStrings.keyName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("", text: $keyName)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStrings.keyType)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("", selection: $keyType) {
                            ForEach(KeyType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: keyType) { _ in
                            generationSucceeded = false
                            privateKey = ""
                            publicKey = ""
                            errorMessage = nil
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStrings.keyPassphrase)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        SecureField("", text: $passphrase)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        Text(LocalizedStrings.keyPassphraseHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStrings.keyComment)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("", text: $comment)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    Button(action: runGeneration) {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text(LocalizedStrings.generate)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if generationSucceeded {
                        Label(LocalizedStrings.keyReadyToSave, systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }

                    PublicKeyPreview(
                        title: LocalizedStrings.publicKeyAutoGenerated,
                        publicKey: publicKey,
                        showInstallHint: true
                    )

                    Text(LocalizedStrings.privateKeysEncrypted)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !canSave, !isGenerating, !generationSucceeded, publicKey.isEmpty {
                        Text(LocalizedStrings.keyGenerateThenSaveHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if !canSave, !isGenerating, generationSucceeded,
                              keyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(LocalizedStrings.keyNameRequiredHint)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(24)
            }

            Divider()
            KeySheetFooter(canSave: canSave, onCancel: { dismiss() }, onSave: saveKey)
        }
        .frame(width: 520, height: 620)
    }

    private func runGeneration() {
        isGenerating = true
        generationSucceeded = false
        errorMessage = nil
        let pass = passphrase
        let note = comment.trimmingCharacters(in: .whitespacesAndNewlines)

        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<SSHKeyImportResult, Error> = Result {
                try SSHKeyService.generateKey(type: keyType, passphrase: pass, comment: note)
            }
            DispatchQueue.main.async {
                isGenerating = false
                switch result {
                case .success(let generated):
                    privateKey = generated.privateKey
                    publicKey = generated.publicKey ?? ""
                    generationSucceeded = true
                    if keyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        keyName = generated.suggestedName
                    }
                case .failure(let error):
                    privateKey = ""
                    publicKey = ""
                    generationSucceeded = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func saveKey() {
        let trimmedPassphrase = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let pub = publicKey.isEmpty ? nil : publicKey
        let newKey = SSHKey(
            name: keyName.trimmingCharacters(in: .whitespacesAndNewlines),
            privateKey: privateKey,
            publicKey: pub,
            passphrase: trimmedPassphrase.isEmpty ? nil : trimmedPassphrase,
            keyType: SSHKeyService.detectKeyType(privateKey: privateKey, publicKey: pub) ?? keyType.rawValue,
            origin: .generated
        )
        viewModel.addKey(newKey)
        dismiss()
    }
}

// MARK: - Edit

struct EditKeySheet: View {
    @ObservedObject var viewModel: AppViewModel
    let key: SSHKey
    @Environment(\.dismiss) private var dismiss

    @State private var keyName = ""
    @State private var publicKey = ""
    @State private var passphrase = ""
    @State private var importedFileName = ""
    @State private var isVerifying = false
    @State private var privateKeyChanged = false
    @State private var privateKey = ""
    @State private var errorMessage: String?

    private var canSave: Bool {
        !isVerifying && !keyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            KeySheetHeader(title: LocalizedStrings.editKey)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStrings.keyName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("", text: $keyName)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    Button(action: replacePrivateKeyFile) {
                        HStack {
                            Image(systemName: "arrow.up.doc")
                            Text(LocalizedStrings.importKey)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isVerifying)

                    if !importedFileName.isEmpty {
                        Text(importedFileName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if isVerifying {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(LocalizedStrings.keyVerifying)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStrings.keyPassphrase)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        SecureField("", text: $passphrase)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    HStack {
                        Button(action: extractPublicKey) {
                            Text(LocalizedStrings.extractPublicKey)
                        }
                        .buttonStyle(.bordered)
                        .disabled(privateKey.isEmpty)
                    }

                    PublicKeyPreview(
                        title: publicKey.isEmpty
                            ? LocalizedStrings.publicKeyOptional
                            : LocalizedStrings.publicKeyDetected,
                        publicKey: publicKey,
                        showInstallHint: false
                    )
                }
                .padding(24)
            }

            Divider()
            KeySheetFooter(canSave: canSave, onCancel: { dismiss() }, onSave: saveKey)
        }
        .frame(width: 520, height: 520)
        .onAppear {
            keyName = key.name
            privateKey = key.privateKey
            publicKey = key.publicKey ?? ""
            passphrase = key.passphrase ?? ""
        }
    }

    private func replacePrivateKeyFile() {
        let panel = NSOpenPanel()
        SSHKeyService.configureOpenPanelForPrivateKey(panel)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        importedFileName = url.lastPathComponent
        errorMessage = nil
        isVerifying = true

        let pass = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let passphraseForImport = pass.isEmpty ? nil : pass

        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<SSHKeyImportResult, Error> = Result {
                try SSHKeyService.importPrivateKey(from: url, passphrase: passphraseForImport)
            }
            DispatchQueue.main.async {
                isVerifying = false
                switch result {
                case .success(let importResult):
                    privateKey = importResult.privateKey
                    if let pub = importResult.publicKey { publicKey = pub }
                    privateKeyChanged = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func extractPublicKey() {
        do {
            let pass = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
            publicKey = try SSHKeyService.extractPublicKey(
                fromPrivateKeyPEM: privateKey,
                passphrase: pass.isEmpty ? nil : pass
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveKey() {
        var updatedKey = key
        updatedKey.name = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
        if privateKeyChanged {
            updatedKey.privateKey = privateKey
            let pub = publicKey.isEmpty ? nil : publicKey
            updatedKey.keyType = SSHKeyService.detectKeyType(privateKey: privateKey, publicKey: pub)
            updatedKey.origin = .imported
            updatedKey.importedFileName = importedFileName.isEmpty ? nil : importedFileName
        }
        updatedKey.publicKey = publicKey.isEmpty ? nil : publicKey
        let trimmed = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedKey.passphrase = trimmed.isEmpty ? nil : trimmed
        viewModel.updateKey(updatedKey)
        dismiss()
    }
}
