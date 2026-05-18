import Foundation
import NSRemoteShell

struct ServerSSHAuth {
    let password: String?
    let privateKeyPEM: String?
    let publicKeyPEM: String?
    let keyPassphrase: String?
    let usePassword: Bool
}

enum ServerSSHExecutor {
    static func run(
        host: String,
        port: Int,
        username: String,
        auth: ServerSSHAuth,
        command: String,
        timeout: TimeInterval = 15
    ) -> Result<String, Error> {
        let shell = NSRemoteShell()

        shell.setupConnectionHost(host)
            .setupConnectionPort(NSNumber(value: port))
            .setupConnectionTimeout(NSNumber(value: min(timeout, 10)))
            .requestConnectAndWait()

        defer { shell.requestDisconnectAndWait() }

        guard shell.isConnected else {
            return .failure(ServerSSHError.connectionFailed)
        }

        guard authenticate(shell: shell, username: username, auth: auth) else {
            return .failure(ServerSSHError.authenticationFailed)
        }

        var buffer = ""
        _ = shell.beginExecute(
            withCommand: command,
            withTimeout: NSNumber(value: timeout),
            withOnCreate: {},
            withOutput: { line in
                buffer.append(line)
                if !line.hasSuffix("\n") {
                    buffer.append("\n")
                }
            },
            withContinuationHandler: { true }
        )

        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = parseHatchError(from: trimmed) {
            return .failure(ServerSSHError.remoteError(error))
        }
        if let ok = parseHatchOK(from: trimmed) {
            return .success(ok)
        }
        return .success(trimmed.isEmpty ? LocalizedStrings.remoteCommandSent : trimmed)
    }

    private static func authenticate(shell: NSRemoteShell, username: String, auth: ServerSSHAuth) -> Bool {
        let usingKey = auth.privateKeyPEM?.isEmpty == false
        if usingKey, let privateKey = auth.privateKeyPEM {
            let unlock = auth.keyPassphrase?.trimmingCharacters(in: .whitespacesAndNewlines)
            let passForAuth = (unlock?.isEmpty == false) ? unlock : nil
            let keyMaterial = SSHKeyService.normalizePrivateKeyForAuthentication(
                privateKey: privateKey,
                passphrase: passForAuth
            ) ?? privateKey

            var derivedPublic: String?
            if let line = try? SSHKeyService.extractPublicKey(
                fromPrivateKeyPEM: keyMaterial,
                passphrase: passForAuth
            ) {
                derivedPublic = line
            }

            shell.authenticate(
                with: username,
                andPublicKey: derivedPublic,
                andPrivateKey: keyMaterial,
                andPassword: passForAuth
            )
            if !shell.isAuthenticated {
                shell.authenticate(
                    with: username,
                    andPublicKey: nil,
                    andPrivateKey: keyMaterial,
                    andPassword: passForAuth
                )
            }
        } else if auth.usePassword {
            shell.authenticate(with: username, andPassword: auth.password ?? "")
        } else {
            return false
        }
        return shell.isAuthenticated
    }

    private static func parseHatchError(from output: String) -> String? {
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("HATCH_ERR=") {
                return String(trimmed.dropFirst("HATCH_ERR=".count))
            }
        }
        return nil
    }

    private static func parseHatchOK(from output: String) -> String? {
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("HATCH_OK=") {
                return String(trimmed.dropFirst("HATCH_OK=".count))
            }
        }
        return nil
    }
}

enum ServerSSHError: LocalizedError {
    case connectionFailed
    case authenticationFailed
    case remoteError(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return LocalizedStrings.statsErrorConnection
        case .authenticationFailed:
            return LocalizedStrings.statsErrorAuth
        case .remoteError(let message):
            return message
        }
    }
}
