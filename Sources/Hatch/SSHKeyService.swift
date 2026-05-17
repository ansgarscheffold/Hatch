import AppKit
import Foundation

enum KeyType: String, CaseIterable, Codable {
    case ed25519 = "ED25519"
    case rsa = "RSA"
    case ecdsa256 = "ECDSA256"
    case ecdsa384 = "ECDSA384"
    case ecdsa521 = "ECDSA521"
}

enum KeyOrigin: String, Codable {
    case imported
    case generated
}

struct SSHKeyImportResult {
    let privateKey: String
    let publicKey: String?
    let suggestedName: String
}

enum SSHKeyServiceError: LocalizedError {
    case publicKeySelected
    case invalidPrivateKey
    case corruptPrivateKey(String)
    case readFailed(String)
    case generationFailed(exitCode: Int32)
    case generationFailedDetail(String)
    case publicKeyExtractionFailed

    var errorDescription: String? {
        switch self {
        case .publicKeySelected:
            return LocalizedStrings.keyErrorPublicKeySelected
        case .invalidPrivateKey:
            return LocalizedStrings.keyErrorInvalidPrivateKey
        case .corruptPrivateKey(let detail):
            return LocalizedStrings.keyErrorCorruptPrivateKey(detail)
        case .readFailed(let detail):
            return LocalizedStrings.keyReadFailed(detail)
        case .generationFailed(let code):
            return LocalizedStrings.keyGenerationFailedExitCode(code)
        case .generationFailedDetail(let detail):
            return LocalizedStrings.keyGenerationFailed(detail)
        case .publicKeyExtractionFailed:
            return LocalizedStrings.keyErrorPublicKeyExtractionFailed
        }
    }
}

enum SSHKeyService {
    private static let sshKeygenURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")

    private struct SSHKeygenRunResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private static func configureProcessEnvironment(_ process: Process) {
        var env = ProcessInfo.processInfo.environment
        if env["HOME"]?.isEmpty != false {
            env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        }
        if env["TMPDIR"]?.isEmpty != false {
            env["TMPDIR"] = FileManager.default.temporaryDirectory.path
        }
        process.environment = env
    }

    @discardableResult
    private static func runSSHKeygen(arguments: [String], quiet: Bool = false) throws -> SSHKeygenRunResult {
        let process = Process()
        process.executableURL = sshKeygenURL
        process.arguments = quiet ? ["-q"] + arguments : arguments
        configureProcessEnvironment(process)
        process.standardInput = FileHandle.nullDevice

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return SSHKeygenRunResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    private static let privateKeyBeginMarkers = [
        "-----BEGIN OPENSSH PRIVATE KEY-----",
        "-----BEGIN RSA PRIVATE KEY-----",
        "-----BEGIN EC PRIVATE KEY-----",
        "-----BEGIN PRIVATE KEY-----",
        "-----BEGIN DSA PRIVATE KEY-----",
        "-----BEGIN ENCRYPTED PRIVATE KEY-----"
    ]

    // MARK: - Normalization & reading

    static func normalizeKeyContent(_ content: String) -> String {
        var text = content
        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func readTextFile(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let encodings: [String.Encoding] = [.utf8, .isoLatin1, .windowsCP1252, .ascii]
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding), !text.isEmpty {
                return text
            }
        }
        throw SSHKeyServiceError.readFailed("Unbekanntes Dateiformat (kein Text).")
    }

    // MARK: - Detection

    /// Leitet den Schlüsseltyp aus öffentlichem Material oder PEM-Headern ab.
    static func detectKeyType(privateKey: String, publicKey: String?) -> String? {
        if let publicKey {
            let line = normalizeKeyContent(publicKey)
                .split(separator: "\n", omittingEmptySubsequences: true)
                .first
                .map(String.init) ?? ""
            if line.hasPrefix("ssh-ed25519 ") { return KeyType.ed25519.rawValue }
            if line.hasPrefix("ssh-rsa ") { return KeyType.rsa.rawValue }
            if line.hasPrefix("ecdsa-sha2-nistp256 ") { return KeyType.ecdsa256.rawValue }
            if line.hasPrefix("ecdsa-sha2-nistp384 ") { return KeyType.ecdsa384.rawValue }
            if line.hasPrefix("ecdsa-sha2-nistp521 ") { return KeyType.ecdsa521.rawValue }
            if line.hasPrefix("ssh-dss ") { return "DSA" }
        }

        let upper = normalizeKeyContent(privateKey).uppercased()
        if upper.contains("BEGIN RSA PRIVATE KEY") { return KeyType.rsa.rawValue }
        if upper.contains("BEGIN DSA PRIVATE KEY") { return "DSA" }
        if upper.contains("BEGIN EC PRIVATE KEY") { return "EC" }

        if let extracted = try? extractPublicKey(fromPrivateKeyPEM: privateKey, passphrase: nil) {
            return detectKeyType(privateKey: privateKey, publicKey: extracted)
        }

        return nil
    }

    static func isPublicKeyFile(url: URL, content: String) -> Bool {
        if url.pathExtension.lowercased() == "pub" { return true }
        return isPublicKeyOnly(content)
    }

    static func isPublicKeyOnly(_ content: String) -> Bool {
        let normalized = normalizeKeyContent(content)
        guard !normalized.isEmpty else { return false }
        if hasPrivateKeyStructure(normalized) { return false }
        return normalized.hasPrefix("ssh-rsa ")
            || normalized.hasPrefix("ssh-ed25519 ")
            || normalized.hasPrefix("ecdsa-sha2-")
            || normalized.hasPrefix("ssh-dss ")
    }

    static func hasPrivateKeyStructure(_ content: String) -> Bool {
        let upper = normalizeKeyContent(content).uppercased()
        return privateKeyBeginMarkers.contains { upper.contains($0) }
    }

    static func isEncryptedPrivateKey(_ content: String) -> Bool {
        let upper = normalizeKeyContent(content).uppercased()
        if upper.contains("-----BEGIN ENCRYPTED PRIVATE KEY-----") { return true }
        if upper.contains("ENCRYPTED") && upper.contains("PROC-TYPE") { return true }
        if upper.contains("DEK-INFO:") { return true }
        return false
    }

    /// Prüft mit PEM-Struktur und optional `ssh-keygen -y` (wie OpenSSH).
    static func isValidPrivateKey(_ content: String) -> Bool {
        switch validatePrivateKey(content, passphrase: nil) {
        case .valid, .validEncrypted:
            return true
        case .invalid, .publicKeyMaterial:
            return false
        }
    }

    enum PrivateKeyValidation {
        case valid
        case validEncrypted
        case publicKeyMaterial
        case invalid
    }

    static func validatePrivateKey(_ content: String, passphrase: String?) -> PrivateKeyValidation {
        let normalized = normalizeKeyContent(content)
        guard !normalized.isEmpty else { return .invalid }

        if isPublicKeyOnly(normalized) {
            return .publicKeyMaterial
        }

        guard hasPrivateKeyStructure(normalized) else {
            return .invalid
        }

        if isEncryptedPrivateKey(normalized) {
            let pass = passphrase?.isEmpty == false ? passphrase : nil
            if verifyWithSSHKeygen(normalized, passphrase: pass) == nil {
                return .valid
            }
            return .validEncrypted
        }

        if verifyWithSSHKeygen(normalized, passphrase: passphrase) == nil {
            return .valid
        }
        return .invalid
    }

    /// `nil` = gültig, sonst Fehlermeldung von ssh-keygen.
    @discardableResult
    private static func verifyWithSSHKeygen(_ privateKeyPEM: String, passphrase: String?) -> String? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempKeyFile = tempDir.appendingPathComponent("\(UUID().uuidString)_verify")
        defer { try? FileManager.default.removeItem(at: tempKeyFile) }

        do {
            try privateKeyPEM.write(to: tempKeyFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempKeyFile.path)
        } catch {
            return error.localizedDescription
        }

        var args = ["-y", "-f", tempKeyFile.path]
        if let passphrase, !passphrase.isEmpty {
            args.insert(contentsOf: ["-P", passphrase], at: 0)
        }

        do {
            let run = try runSSHKeygen(arguments: args, quiet: true)
            guard run.exitCode == 0 else {
                let message = run.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                return message.isEmpty ? "ssh-keygen exit \(run.exitCode)" : message
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static func suggestedName(from url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        return base.isEmpty ? "SSH Key" : base
    }

    static func companionPublicKeyURL(for privateKeyURL: URL) -> URL {
        let base = privateKeyURL.deletingPathExtension()
        if privateKeyURL.pathExtension.isEmpty {
            return privateKeyURL.appendingPathExtension("pub")
        }
        return base.appendingPathExtension("pub")
    }

    // MARK: - Import / export

    static func importPrivateKey(from url: URL, passphrase: String? = nil) throws -> SSHKeyImportResult {
        let rawContent: String
        do {
            rawContent = try readTextFile(at: url)
        } catch let error as SSHKeyServiceError {
            throw error
        } catch {
            throw SSHKeyServiceError.readFailed(error.localizedDescription)
        }

        let content = normalizeKeyContent(rawContent)

        if isPublicKeyFile(url: url, content: content) {
            throw SSHKeyServiceError.publicKeySelected
        }

        guard hasPrivateKeyStructure(content) else {
            throw SSHKeyServiceError.invalidPrivateKey
        }

        let validation = validatePrivateKey(content, passphrase: passphrase)
        switch validation {
        case .publicKeyMaterial:
            throw SSHKeyServiceError.publicKeySelected
        case .invalid:
            if let detail = verifyWithSSHKeygen(content, passphrase: passphrase) {
                throw SSHKeyServiceError.corruptPrivateKey(detail)
            }
            throw SSHKeyServiceError.invalidPrivateKey
        case .valid, .validEncrypted:
            break
        }

        var publicKey: String?
        let pubURL = companionPublicKeyURL(for: url)
        if FileManager.default.fileExists(atPath: pubURL.path),
           let pubContent = try? readTextFile(at: pubURL) {
            let trimmed = normalizeKeyContent(pubContent)
            if !trimmed.isEmpty, isPublicKeyOnly(trimmed) || trimmed.hasPrefix("ssh-") {
                publicKey = trimmed
            }
        }

        if publicKey == nil {
            publicKey = try? extractPublicKey(fromPrivateKeyPEM: content, passphrase: passphrase)
        }

        return SSHKeyImportResult(
            privateKey: content,
            publicKey: publicKey,
            suggestedName: suggestedName(from: url)
        )
    }

    static func extractPublicKey(fromPrivateKeyPEM privateKey: String, passphrase: String? = nil) throws -> String {
        let normalized = normalizeKeyContent(privateKey)
        let tempDir = FileManager.default.temporaryDirectory
        let tempKeyFile = tempDir.appendingPathComponent("\(UUID().uuidString)_extract")
        defer { try? FileManager.default.removeItem(at: tempKeyFile) }

        try normalized.write(to: tempKeyFile, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempKeyFile.path)

        var args = ["-y", "-f", tempKeyFile.path]
        if let passphrase, !passphrase.isEmpty {
            args.insert(contentsOf: ["-P", passphrase], at: 0)
        }

        let run = try runSSHKeygen(arguments: args, quiet: true)
        guard run.exitCode == 0 else {
            let message = run.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty {
                throw SSHKeyServiceError.corruptPrivateKey(message)
            }
            throw SSHKeyServiceError.publicKeyExtractionFailed
        }

        let trimmed = run.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SSHKeyServiceError.publicKeyExtractionFailed
        }
        return trimmed
    }

    static func generateKey(type: KeyType, passphrase: String, comment: String) throws -> SSHKeyImportResult {
        let tempDir = FileManager.default.temporaryDirectory
        let tempKeyFile = tempDir.appendingPathComponent("hatch_key_\(UUID().uuidString)")
        let tempPubFile = tempKeyFile.appendingPathExtension("pub")
        defer {
            try? FileManager.default.removeItem(at: tempKeyFile)
            try? FileManager.default.removeItem(at: tempPubFile)
        }

        try? FileManager.default.removeItem(at: tempKeyFile)
        try? FileManager.default.removeItem(at: tempPubFile)

        let keyTypeArg: String
        switch type {
        case .ed25519: keyTypeArg = "ed25519"
        case .rsa: keyTypeArg = "rsa"
        case .ecdsa256, .ecdsa384, .ecdsa521: keyTypeArg = "ecdsa"
        }

        var keygenArgs = ["-t", keyTypeArg, "-f", tempKeyFile.path, "-N", passphrase]
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedComment.isEmpty {
            keygenArgs.append(contentsOf: ["-C", trimmedComment])
        }
        switch type {
        case .rsa:
            keygenArgs.append(contentsOf: ["-b", "4096"])
        case .ecdsa256:
            keygenArgs.append(contentsOf: ["-b", "256"])
        case .ecdsa384:
            keygenArgs.append(contentsOf: ["-b", "384"])
        case .ecdsa521:
            keygenArgs.append(contentsOf: ["-b", "521"])
        case .ed25519:
            break
        }

        let run: SSHKeygenRunResult
        do {
            run = try runSSHKeygen(arguments: keygenArgs, quiet: true)
        } catch {
            throw SSHKeyServiceError.generationFailedDetail(error.localizedDescription)
        }

        guard run.exitCode == 0 else {
            let detail = run.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                throw SSHKeyServiceError.generationFailed(exitCode: run.exitCode)
            }
            throw SSHKeyServiceError.generationFailedDetail(detail)
        }

        guard FileManager.default.fileExists(atPath: tempKeyFile.path) else {
            throw SSHKeyServiceError.generationFailedDetail(LocalizedStrings.keyGenerationMissingFile)
        }

        let privateKey: String
        do {
            privateKey = normalizeKeyContent(try readTextFile(at: tempKeyFile))
        } catch {
            throw SSHKeyServiceError.generationFailedDetail(
                LocalizedStrings.keyGenerationReadFailed(error.localizedDescription)
            )
        }

        guard hasPrivateKeyStructure(privateKey) else {
            throw SSHKeyServiceError.generationFailedDetail(LocalizedStrings.keyGenerationInvalidOutput)
        }

        var publicKey: String?
        if FileManager.default.fileExists(atPath: tempPubFile.path),
           let pub = try? readTextFile(at: tempPubFile) {
            let trimmed = normalizeKeyContent(pub)
            if !trimmed.isEmpty {
                publicKey = trimmed
            }
        }
        if publicKey == nil || publicKey?.isEmpty == true {
            publicKey = try extractPublicKey(fromPrivateKeyPEM: privateKey, passphrase: passphrase.isEmpty ? nil : passphrase)
        }

        let suggested = "Generated \(type.rawValue)"
        return SSHKeyImportResult(
            privateKey: privateKey,
            publicKey: publicKey,
            suggestedName: suggested
        )
    }

    /// Konvertiert Legacy-PEM (z. B. phpseclib RSA) ins OpenSSH-Format für libssh2.
    static func normalizePrivateKeyForAuthentication(privateKey: String, passphrase: String?) -> String? {
        let tempKey = FileManager.default.temporaryDirectory
            .appendingPathComponent("hatch_norm_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempKey) }

        do {
            try normalizeKeyContent(privateKey).write(to: tempKey, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: tempKey.path
            )
        } catch {
            return nil
        }

        let pass = passphrase ?? ""
        let run = try? runSSHKeygen(
            arguments: ["-p", "-P", pass, "-N", pass, "-o", "-f", tempKey.path],
            quiet: true
        )
        guard run?.exitCode == 0, let normalized = try? readTextFile(at: tempKey) else {
            return nil
        }
        return normalizeKeyContent(normalized)
    }

    /// Kurze Vorschau der aus dem Private Key abgeleiteten öffentlichen Zeile (zum Abgleich mit authorized_keys).
    static func publicKeyPreview(fromPrivateKey privateKey: String, passphrase: String?) -> String? {
        guard let line = try? extractPublicKey(fromPrivateKeyPEM: privateKey, passphrase: passphrase) else {
            return nil
        }
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return String(line.prefix(48)) + "…" }
        let blob = String(parts[1])
        let prefix = String(blob.prefix(28))
        return "\(parts[0]) \(prefix)…"
    }

    static func configureOpenPanelForPrivateKey(_ panel: NSOpenPanel) {
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = LocalizedStrings.importKeyPanelMessage
        panel.prompt = LocalizedStrings.choose
        let sshDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh", isDirectory: true)
        if FileManager.default.fileExists(atPath: sshDir.path) {
            panel.directoryURL = sshDir
        }
    }
}
