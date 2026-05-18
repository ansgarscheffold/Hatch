import Foundation

enum ConnectionDropReason {
    case shellClosed
    case networkLost
    case inactivityOrTimeout
}

struct LocalizedStrings {
    private static var isGerman: Bool {
        switch AppSettings.shared.appLanguage {
        case .system:
            guard let preferredLanguage = Locale.preferredLanguages.first else { return false }
            return preferredLanguage.hasPrefix("de")
        case .german:
            return true
        case .english:
            return false
        }
    }
    
    // Navigation
    static var overview: String { isGerman ? "Übersicht" : "Overview" }
    static var stats: String { isGerman ? "Status" : "Status" }
    static var docker: String { "Docker" }
    static var keys: String { isGerman ? "Schlüssel" : "Keys" }

    static var dockerTitle: String { "Docker" }
    static var dockerSubtitle: String {
        isGerman
            ? "Laufende Container auf Ihren Servern – Stats und Befehle per SSH."
            : "Running containers on your servers – stats and commands over SSH."
    }
    static var dockerContainerCommands: String {
        isGerman ? "Container-Befehle" : "Container Commands"
    }
    static var dockerCommandRestart: String { isGerman ? "Neustart" : "Restart" }
    static var dockerCommandStop: String { isGerman ? "Stoppen" : "Stop" }
    static var dockerCommandStart: String { isGerman ? "Starten" : "Start" }
    static var dockerCommandDestructiveHint: String {
        isGerman
            ? "Der Container kann kurz nicht erreichbar sein."
            : "The container may be briefly unavailable."
    }
    static func dockerCommandConfirmRestart(_ container: String, _ server: String) -> String {
        isGerman
            ? "Container „\(container)“ auf „\(server)“ neu starten?"
            : "Restart container \"\(container)\" on \"\(server)\"?"
    }
    static func dockerCommandConfirmStop(_ container: String, _ server: String) -> String {
        isGerman
            ? "Container „\(container)“ auf „\(server)“ stoppen?"
            : "Stop container \"\(container)\" on \"\(server)\"?"
    }
    static func dockerCommandConfirmStart(_ container: String, _ server: String) -> String {
        isGerman
            ? "Container „\(container)“ auf „\(server)“ starten?"
            : "Start container \"\(container)\" on \"\(server)\"?"
    }

    // Server stats
    static var statsTitle: String { isGerman ? "Status" : "Status" }
    static var statsSubtitle: String {
        isGerman
            ? "Live-Kennzahlen per SSH (CPU, RAM, Temperatur, Netzwerk, Festplatte). Linux-Server mit /proc."
            : "Live metrics over SSH (CPU, RAM, temperature, network, disk). Linux hosts with /proc."
    }
    static var statsRefresh: String { isGerman ? "Aktualisieren" : "Refresh" }
    static var statsLoading: String { isGerman ? "Werte werden geladen …" : "Loading metrics…" }
    static var statsCPU: String { "CPU" }
    static var statsMemory: String { isGerman ? "RAM" : "Mem" }
    static var statsUpload: String { isGerman ? "Upload" : "upload" }
    static var statsDownload: String { isGerman ? "Download" : "download" }
    static var statsRead: String { isGerman ? "Lesen" : "Read" }
    static var statsWrite: String { isGerman ? "Schreiben" : "Write" }
    static var statsErrorConnection: String {
        isGerman ? "Verbindung zum Server fehlgeschlagen." : "Could not connect to the server."
    }
    static var statsErrorAuth: String {
        isGerman ? "Authentifizierung fehlgeschlagen." : "Authentication failed."
    }
    static var statsErrorCredentials: String {
        isGerman ? "Keine Zugangsdaten hinterlegt." : "No credentials configured."
    }
    static var statsErrorParse: String {
        isGerman
            ? "Metriken konnten nicht gelesen werden (evtl. kein Linux /proc)."
            : "Could not read metrics (host may not expose Linux /proc)."
    }
    static var statsContainersTitle: String { isGerman ? "Container" : "Containers" }
    static var statsContainersSubtitle: String {
        isGerman
            ? "Laufende Docker-Container auf Ihren Servern (CPU, RAM, Netzwerk, Festplatte)."
            : "Running Docker containers on your servers (CPU, RAM, network, disk)."
    }
    static var statsNoContainers: String {
        isGerman ? "Keine laufenden Container." : "No running containers."
    }
    static var statsDockerNotInstalled: String {
        isGerman ? "Docker nicht installiert" : "Docker not installed"
    }
    static var statsDockerNotAccessible: String {
        isGerman
            ? "Docker nicht erreichbar (Berechtigung?)"
            : "Docker not accessible (permissions?)"
    }
    static var statsNetIO: String { "Net I/O" }
    static var statsBlockIO: String { "Block I/O" }
    static var statsMemoryUsage: String { isGerman ? "Speicher" : "Memory" }
    static var statsBack: String { isGerman ? "Zurück" : "Back" }
    static var statsDetailProcesses: String { isGerman ? "Prozesse" : "Processes" }
    static var statsDetailProcessColumn: String { isGerman ? "Prozess" : "Process" }
    static var statsDetailCores: String { isGerman ? "Kerne" : "Cores" }
    static var statsDetailIdle: String { "Idle" }
    static var statsDetailUptime: String { isGerman ? "Laufzeit" : "Uptime" }
    static var statsDetailLoad: String { "Load" }
    static var statsDetailUser: String { "User" }
    static var statsDetailSystem: String { "Sys" }
    static var statsDetailIOWait: String { "IOW" }
    static var statsDetailSteal: String { "Steal" }
    static var statsDetailFree: String { isGerman ? "Frei" : "Free" }
    static var statsDetailUsed: String { isGerman ? "Belegt" : "Used" }
    static var statsDetailCached: String { isGerman ? "Cache" : "Cache" }
    static var statsDetailInterfaces: String { isGerman ? "Schnittstellen" : "Interfaces" }
    static var statsDetailDisks: String { isGerman ? "Festplatten" : "Disks" }
    static var statsDetailOpenHint: String {
        isGerman ? "Klicken für Detailansicht" : "Click for detail view"
    }

    // Remote server commands
    static var serverCommands: String { isGerman ? "Server-Befehle" : "Server Commands" }
    static var remoteCommandUptime: String { isGerman ? "Betriebszeit" : "Uptime" }
    static var remoteCommandReboot: String { isGerman ? "Neustart" : "Restart" }
    static var remoteCommandShutdown: String { isGerman ? "Herunterfahren" : "Shut Down" }
    static var remoteCommandCancelShutdown: String { isGerman ? "Shutdown abbrechen" : "Cancel Shutdown" }
    static var remoteCommandRun: String { isGerman ? "Ausführen" : "Run" }
    static var remoteCommandSent: String {
        isGerman ? "Befehl gesendet." : "Command sent."
    }
    static var remoteCommandDestructiveHint: String {
        isGerman
            ? "Der Server kann danach kurz nicht erreichbar sein. Aktive SSH-Sitzungen werden getrennt."
            : "The host may be unreachable briefly afterward. Active SSH sessions will be disconnected."
    }
    static func remoteCommandConfirmUptime(_ name: String) -> String {
        isGerman
            ? "Betriebszeit von „\(name)“ per SSH abfragen?"
            : "Query uptime for \"\(name)\" over SSH?"
    }
    static func remoteCommandConfirmReboot(_ name: String) -> String {
        isGerman
            ? "„\(name)“ wirklich neu starten?"
            : "Really restart \"\(name)\"?"
    }
    static func remoteCommandConfirmShutdown(_ name: String) -> String {
        isGerman
            ? "„\(name)“ wirklich herunterfahren?"
            : "Really shut down \"\(name)\"?"
    }
    static func remoteCommandConfirmCancelShutdown(_ name: String) -> String {
        isGerman
            ? "Geplanten Shutdown auf „\(name)“ abbrechen?"
            : "Cancel a scheduled shutdown on \"\(name)\"?"
    }
    static var activeConnections: String { isGerman ? "Aktive Verbindungen" : "Active Connections" }
    static var recent: String { isGerman ? "Letzte Verbindungen" : "Recent" }
    
    // Server Cards
    static var hostIP: String { isGerman ? "Host/IP" : "Host/IP" }
    static var user: String { isGerman ? "Benutzer" : "User" }
    static var port: String { isGerman ? "Port" : "Port" }
    static var lastUsed: String { isGerman ? "Zuletzt verwendet" : "Last used" }
    static var neverUsed: String { isGerman ? "Nie verwendet" : "Never used" }
    static var active: String { isGerman ? "aktiv" : "active" }
    static var connected: String { isGerman ? "Verbunden" : "Connected" }
    static var connect: String { isGerman ? "Verbinden" : "Connect" }
    static var tools: String { isGerman ? "Werkzeuge" : "Tools" }
    static var ping: String { isGerman ? "Ping" : "Ping" }
    static var traceroute: String { isGerman ? "Traceroute" : "Traceroute" }
    static var noPingData: String { isGerman ? "Keine Ping-Daten verfügbar." : "No ping data available." }
    static var noTracerouteData: String { isGerman ? "Keine Traceroute-Daten verfügbar." : "No traceroute data available." }
    static var columnSequence: String { isGerman ? "Nr." : "Seq" }
    static var columnHop: String { "Hop" }
    static var columnHost: String { isGerman ? "Host" : "Host" }
    static var columnTimeMs: String { isGerman ? "Zeit (ms)" : "Time (ms)" }
    static var columnHostnameOrIP: String { isGerman ? "Hostname / IP" : "Hostname / IP" }
    static var toolsRawOutput: String { isGerman ? "Ausgabe" : "Output" }

    static var serverNotFound: String { isGerman ? "Server nicht gefunden" : "Server not found" }
    static var backToOverview: String { isGerman ? "Zurück zur Übersicht" : "Back to Overview" }
    static var keyCreatedLabel: String { isGerman ? "Erstellt" : "Created" }
    static var keyOriginLabel: String { isGerman ? "Herkunft" : "Origin" }
    static var keyImported: String { isGerman ? "Importiert" : "Imported" }
    static var keyGenerated: String { isGerman ? "Erzeugt" : "Generated" }
    static var pickerNone: String { isGerman ? "Keine" : "None" }
    
    // Server Overview
    static var yourServers: String { isGerman ? "Ihre Server" : "Your Servers" }
    static var overviewSubtitle: String {
        isGerman
            ? "SSH-Server verwalten, verbinden und zuletzt genutzte Hosts im Blick behalten."
            : "Manage SSH servers, connect quickly, and keep track of recently used hosts."
    }
    static var noServersYet: String { isGerman ? "Noch keine Server" : "No Servers Yet" }
    static var addFirstServer: String { isGerman ? "Fügen Sie Ihren ersten Server hinzu, um mit SSH-Verbindungen zu beginnen" : "Add your first server to get started with SSH connections" }
    static var addServer: String { isGerman ? "Server hinzufügen" : "Add Server" }
    
    // Modals
    static var editServer: String { isGerman ? "Server bearbeiten" : "Edit Server" }
    static var deleteServer: String { isGerman ? "Server löschen" : "Delete Server" }
    static var deleteAllServers: String { isGerman ? "Alle Server löschen" : "Delete All Servers" }
    static var deleteAllServersDescription: String {
        isGerman
            ? "Alle gespeicherten Server und aktiven Verbindungen werden entfernt. Fortfahren?"
            : "All saved servers and active connections will be removed. Continue?"
    }
    
    // UI / View
    static var viewSettings: String { isGerman ? "Ansicht" : "View" }
    static var showStatusBar: String { isGerman ? "Statusleiste anzeigen" : "Show status bar" }
    static var showSidebar: String { isGerman ? "Seitenleiste anzeigen" : "Show sidebar" }
    static var deleteKey: String { isGerman ? "Schlüssel löschen" : "Delete Key" }
    static func deleteConfirmation(_ name: String) -> String {
        isGerman ? "Möchten Sie '\(name)' wirklich löschen?" : "Are you sure you want to delete '\(name)'?"
    }
    static var deleteWarning: String { isGerman ? "Diese Aktion kann nicht rückgängig gemacht werden." : "This action cannot be undone." }
    static var cancel: String { isGerman ? "Abbrechen" : "Cancel" }
    static var close: String { isGerman ? "Schließen" : "Close" }
    static var delete: String { isGerman ? "Löschen" : "Delete" }
    static var saveOnly: String { isGerman ? "Nur speichern" : "Save Only" }
    static var save: String { isGerman ? "Speichern" : "Save" }
    static var saveAndConnect: String { isGerman ? "Speichern & Verbinden" : "Save & Connect" }
    
    // Server Details Form
    static var serverDetails: String { isGerman ? "Server-Details" : "Server Details" }
    static var nameOptional: String { isGerman ? "Name (optional)" : "Name (optional)" }
    static var authentication: String { isGerman ? "Authentifizierung" : "Authentication" }
    static var username: String { isGerman ? "Benutzername" : "Username" }
    static var usePassword: String { isGerman ? "Anmeldung mit Passwort" : "Log in with password" }
    static var useSSHKey: String { isGerman ? "Anmeldung mit SSH-Schlüssel" : "Log in with SSH key" }
    static var password: String { isGerman ? "Passwort" : "Password" }
    static var privateKey: String { isGerman ? "Privater Schlüssel" : "Private Key" }
    static var choose: String { isGerman ? "Auswählen" : "Choose" }
    static var noKeySelected: String { isGerman ? "Kein Schlüssel ausgewählt" : "No Key Selected" }
    
    // Terminal
    static func startTerminalPrompt(_ name: String) -> String {
        isGerman ? "Terminal für '\(name)' starten?" : "Start terminal for '\(name)'?"
    }
    static var startTerminal: String { isGerman ? "Terminal starten" : "Start Terminal" }
    static func connectionLost(_ name: String) -> String {
        isGerman ? "Verbindung zu '\(name)' verloren" : "Connection lost for '\(name)'"
    }
    static var reconnect: String { isGerman ? "Erneut verbinden" : "Reconnect" }
    static var disconnect: String { isGerman ? "Trennen" : "Disconnect" }
    static func connectingTo(_ name: String) -> String {
        isGerman ? "Verbinde mit '\(name)'..." : "Connecting to '\(name)'..."
    }
    static var connectionFailedTitle: String { isGerman ? "Verbindung fehlgeschlagen" : "Connection failed" }
    static var connectionFailedHint: String {
        isGerman
            ? "Bitte Host, Port, Zugangsdaten und Netzwerkverbindung prüfen."
            : "Please check host, port, credentials, and network connectivity."
    }
    static func connectionFailedDetail(host: String, port: Int) -> String {
        if isGerman {
            return "Konnte keine Verbindung zu \(host):\(port) herstellen; bitte Host, Port, Erreichbarkeit und Firewall prüfen."
        } else {
            return "Could not connect to \(host):\(port); please check host, port, reachability, and firewall."
        }
    }

    /// Verbindungs-Status und Fehlertexte (werden u. a. in Fehler-UI und internen Meldungen genutzt).
    static var statusReadyToConnect: String { isGerman ? "Bereit zum Verbinden" : "Ready to connect" }
    static var statusConnecting: String { isGerman ? "Verbinde …" : "Connecting..." }
    static var statusFailedToCreateShell: String { isGerman ? "Shell konnte nicht erstellt werden" : "Failed to create shell" }
    static var connectionErrorShellInstance: String {
        isGerman
            ? "SSH-Shell-Instanz konnte nicht erstellt werden."
            : "Failed to create SSH shell instance."
    }
    static var statusAuthenticationFailed: String { isGerman ? "Authentifizierung fehlgeschlagen" : "Authentication failed" }
    static var connectionErrorKeyFileUnreadable: String {
        isGerman
            ? "SSH-Schlüsseldatei konnte nicht gelesen werden; bitte Pfad und Berechtigungen prüfen."
            : "Could not read SSH key file; please check path and permissions."
    }
    static var connectionErrorAuthFailed: String {
        isGerman
            ? "Authentifizierung fehlgeschlagen; bitte Benutzername, Passwort oder SSH-Schlüssel prüfen."
            : "Authentication failed; please check username, password, or SSH key."
    }
    static var connectionErrorNoKeyConfigured: String {
        isGerman
            ? "Kein SSH-Schlüssel hinterlegt. Bitte unter Authentifizierung einen Schlüssel auswählen oder importieren."
            : "No SSH key configured. Select or import a key under authentication."
    }
    static func connectionErrorKeyAuthFailed(username: String, lastError: String?) -> String {
        var parts: [String] = []
        let lowerUser = username.lowercased()
        let lowerErr = lastError?.lowercased() ?? ""

        if lowerUser == "root" && (lowerErr.contains("username/publickey") || lowerErr.contains("publickey")) {
            parts.append(isGerman
                ? "Dieser Server erwartet sehr wahrscheinlich den Benutzer „ubuntu“ (nicht „root“). In authorized_keys steht oft ein Hinweis, root zu vermeiden."
                : "This server likely expects the username \"ubuntu\" (not \"root\"). authorized_keys often blocks root explicitly.")
        }

        if lowerErr.contains("username/publickey") {
            parts.append(isGerman
                ? "Benutzername und Schlüssel passen nicht zusammen: Entweder falscher User, oder die importierte id_rsa gehört NICHT zu dem ssh-rsa-Eintrag in authorized_keys (anderes Key-Paar vom Hoster)."
                : "Username and key do not match: wrong user, or your imported id_rsa does NOT belong to the ssh-rsa line in authorized_keys (different key pair from host).")
            parts.append(isGerman
                ? "Prüfen Sie auf dem Server: cat /home/ubuntu/.ssh/authorized_keys (nicht nur root). Test im Terminal: ssh -i id_rsa ubuntu@HOST"
                : "On the server check: cat /home/ubuntu/.ssh/authorized_keys (not only root). Terminal test: ssh -i id_rsa ubuntu@HOST")
        }

        parts.append(isGerman
            ? "Prüfen Sie: Benutzername, private id_rsa, Passphrase, und ob der öffentliche Schlüssel in ~/.ssh/authorized_keys des richtigen Benutzers liegt."
            : "Check: username, private id_rsa, passphrase, and whether the public key is in ~/.ssh/authorized_keys for the correct user.")

        if let lastError, !lastError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let detailLabel = isGerman ? "Technisch" : "Technical"
            parts.append("\(detailLabel): \(lastError.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        return parts.joined(separator: " ")
    }

    static func connectionErrorDerivedPublicKey(_ preview: String) -> String {
        isGerman
            ? "Aus Ihrer id_rsa ermittelter öffentlicher Schlüssel beginnt mit: \(preview) — muss zum ssh-rsa-Block in authorized_keys passen (ssh-keygen -y -f id_rsa)."
            : "Public key derived from your id_rsa starts with: \(preview) — must match the ssh-rsa blob in authorized_keys (ssh-keygen -y -f id_rsa)."
    }
    static var statusConnected: String { isGerman ? "Verbunden" : "Connected" }
    static var statusConnectedOpeningTerminal: String {
        isGerman ? "Verbunden – Terminal wird geöffnet …" : "Connected - Opening terminal..."
    }
    static var statusDisconnected: String { isGerman ? "Getrennt" : "Disconnected" }
    static var terminalNoActiveSSH: String { isGerman ? "Keine aktive SSH-Verbindung" : "No active SSH connection" }
    static var osDetecting: String { isGerman ? "Wird erkannt …" : "Detecting..." }
    static var osUnknown: String { isGerman ? "Unbekannt" : "Unknown" }
    static var statusInteractiveShellClosed: String {
        isGerman ? "Interaktive Shell beendet" : "Interactive shell closed"
    }

    static var connectionLostTitle: String {
        isGerman ? "Verbindung getrennt" : "Connection closed"
    }

    static var connectionLostHint: String {
        isGerman
            ? "Die SSH-Sitzung ist nicht mehr aktiv. Sie können die Verbindung erneut herstellen oder das Fenster schließen."
            : "The SSH session is no longer active. You can reconnect or close this window."
    }

    static func connectionDroppedDetail(reason: ConnectionDropReason, lastError: String?) -> String {
        let base: String
        switch reason {
        case .shellClosed:
            base = isGerman
                ? "Die SSH-Sitzung wurde vom Server beendet."
                : "The SSH session was closed by the server."
        case .networkLost:
            base = isGerman
                ? "Die Netzwerkverbindung zum Server wurde unterbrochen."
                : "The network connection to the server was lost."
        case .inactivityOrTimeout:
            base = isGerman
                ? "Die Verbindung wurde wegen Inaktivität oder Zeitüberschreitung getrennt."
                : "The connection was closed due to inactivity or a timeout."
        }
        guard let lastError, !lastError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return base
        }
        let detailLabel = isGerman ? "Details" : "Details"
        return "\(base) \(detailLabel): \(lastError.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    static func terminalDisconnectBanner(_ detail: String) -> String {
        if isGerman {
            return "── Verbindung getrennt: \(detail) ──"
        }
        return "-- Connection closed: \(detail) --"
    }

    static func statusBarServerCount(_ count: Int) -> String {
        isGerman ? "Server: \(count)" : "Servers: \(count)"
    }
    static func statusBarActiveCount(_ count: Int) -> String {
        isGerman ? "Aktiv: \(count)" : "Active: \(count)"
    }

    static func toolFailedToStartPing(_ detail: String) -> String {
        isGerman ? "Ping konnte nicht gestartet werden: \(detail)" : "Failed to start ping: \(detail)"
    }
    static func toolFailedToStartTraceroute(_ detail: String) -> String {
        isGerman ? "Traceroute konnte nicht gestartet werden: \(detail)" : "Failed to start traceroute: \(detail)"
    }

    static func keyGenerationFailedExitCode(_ code: Int32) -> String {
        isGerman
            ? "SSH-Schlüssel konnte nicht erzeugt werden (Fehlercode \(code))."
            : "Failed to generate SSH key. Error code: \(code)"
    }
    static func keyGenerationFailed(_ detail: String) -> String {
        isGerman
            ? "SSH-Schlüssel konnte nicht erzeugt werden: \(detail)"
            : "Failed to generate SSH key: \(detail)"
    }
    static var keyGenerationMissingFile: String {
        isGerman
            ? "ssh-keygen war erfolgreich, aber die Schlüsseldatei fehlt. Bitte App neu starten und erneut versuchen."
            : "ssh-keygen succeeded but the key file is missing. Please restart the app and try again."
    }
    static var keyGenerationInvalidOutput: String {
        isGerman
            ? "ssh-keygen hat eine unerwartete Datei erzeugt (kein gültiges PEM/OpenSSH-Format)."
            : "ssh-keygen produced an unexpected file (not valid PEM/OpenSSH format)."
    }
    static func keyGenerationReadFailed(_ detail: String) -> String {
        isGerman
            ? "Erzeugte Schlüsseldatei konnte nicht gelesen werden: \(detail)"
            : "Could not read the generated key file: \(detail)"
    }
    
    // Welcome Screen
    static var sshTerminal: String { isGerman ? "SSH Terminal" : "SSH Terminal" }
    static var connectToRemote: String { isGerman ? "Mit einem Remote-Server über SSH verbinden" : "Connect to a remote server using SSH" }
    static var features: String { isGerman ? "Funktionen:" : "Features:" }
    static var secureConnections: String { isGerman ? "Sichere SSH-Verbindungen" : "Secure SSH connections" }
    static var interactiveTerminal: String { isGerman ? "Interaktives Terminal" : "Interactive terminal" }
    static var passwordAndKeyAuth: String { isGerman ? "Passwort- und Schlüssel-Authentifizierung" : "Password and key authentication" }
    
    // Keys
    static var noKeys: String { isGerman ? "Keine Schlüssel" : "No keys" }
    static var savedKeysWillAppear: String {
        isGerman
            ? "Importieren Sie vorhandene Schlüssel (z. B. id_rsa vom Hoster) oder erzeugen Sie ein neues Paar."
            : "Import existing keys (e.g. id_rsa from your host) or generate a new key pair."
    }
    static var newKey: String { isGerman ? "Schlüssel hinzufügen" : "Add Key" }
    static var importExistingKey: String { isGerman ? "Vorhandenen Schlüssel importieren" : "Import Existing Key" }
    static var generateNewKey: String { isGerman ? "Neuen Schlüssel erzeugen" : "Generate New Key" }
    static var editKey: String { isGerman ? "Schlüssel bearbeiten" : "Edit Key" }
    static var keyLabel: String { isGerman ? "Name" : "Label" }
    static var publicKeyOptional: String { isGerman ? "Öffentlicher Schlüssel (optional)" : "Public Key (optional)" }
    static var publicKeyDetected: String { isGerman ? "Öffentlicher Schlüssel" : "Public Key" }
    static var publicKeyAutoGenerated: String { isGerman ? "Öffentlicher Schlüssel (neu erzeugt)" : "Public Key (newly generated)" }
    static var generate: String { isGerman ? "Schlüssel erzeugen" : "Generate Key" }
    static var importKey: String { isGerman ? "Private Schlüsseldatei wählen…" : "Choose Private Key File…" }
    static var importKeyPanelMessage: String {
        isGerman
            ? "Wählen Sie die private Schlüsseldatei (z. B. id_rsa, ohne .pub)."
            : "Choose the private key file (e.g. id_rsa, not the .pub file)."
    }
    static var importKeyDescription: String {
        isGerman
            ? "Wählen Sie die private Datei vom Hoster oder aus ~/.ssh. Die passende .pub-Datei wird automatisch mitgelesen, falls vorhanden."
            : "Select the private file from your host or ~/.ssh. The matching .pub file is loaded automatically when present."
    }
    static var generateKeyDescription: String {
        isGerman
            ? "Erzeugt ein neues Schlüsselpaar. Den öffentlichen Schlüssel tragen Sie danach auf dem Server in authorized_keys ein."
            : "Creates a new key pair. Add the public key to authorized_keys on the server afterward."
    }
    static var keyType: String { isGerman ? "Schlüsseltyp" : "Key Type" }
    static var keyPassphrase: String { isGerman ? "Passphrase (optional)" : "Passphrase (optional)" }
    static var keyPassphraseHint: String {
        isGerman
            ? "Nur nötig, wenn der private Schlüssel passwortgeschützt ist."
            : "Only required if the private key is protected with a passphrase."
    }
    static var keyComment: String { isGerman ? "Kommentar (optional)" : "Comment (optional)" }
    static var importedKeyFile: String { isGerman ? "Importierte Datei" : "Imported File" }
    static var keyVerifying: String { isGerman ? "Wird geprüft…" : "Verifying…" }
    static var keyReadyToSave: String { isGerman ? "Schlüssel bereit zum Speichern" : "Key ready to save" }
    static var keyNotSelectedYet: String { isGerman ? "Noch keine Schlüsseldatei gewählt" : "No key file selected yet" }
    static var keyGenerateThenSaveHint: String {
        isGerman
            ? "Zuerst „Schlüssel erzeugen“ klicken, dann speichern."
            : "Click “Generate Key” first, then save."
    }
    static var keyNameRequiredHint: String {
        isGerman ? "Bitte einen Schlüsselnamen eintragen." : "Please enter a key name."
    }
    static var privateKeysEncrypted: String { isGerman ? "Private Schlüssel werden verschlüsselt in Hatch gespeichert." : "Private keys are stored encrypted in Hatch." }
    static var publicKeyInstallHint: String { isGerman ? "Wichtig: Kopieren Sie den öffentlichen Schlüssel und fügen Sie ihn auf dem Server in ~/.ssh/authorized_keys ein." : "Important: Copy the public key and add it to ~/.ssh/authorized_keys on the server." }
    static var publicKeyHosterHint: String {
        isGerman
            ? "Vom Hoster erhalten? Meist ist der öffentliche Schlüssel bereits auf dem Server — Sie brauchen nur die private Datei (id_rsa) zu importieren."
            : "From your host? The public key is often already on the server — you only need to import the private file (id_rsa)."
    }
    static var copy: String { isGerman ? "Kopieren" : "Copy" }
    static var extractPublicKey: String { isGerman ? "Öffentlichen Schlüssel extrahieren" : "Extract Public Key" }
    static var keyName: String { isGerman ? "Schlüsselname" : "Key Name" }
    static var keyErrorPublicKeySelected: String {
        isGerman
            ? "Das ist eine öffentliche Schlüsseldatei (.pub). Bitte die private Datei wählen (z. B. id_rsa)."
            : "This is a public key file (.pub). Please choose the private file (e.g. id_rsa)."
    }
    static var keyErrorInvalidPrivateKey: String {
        isGerman
            ? "Keine gültige private SSH-Schlüsseldatei. Erwartet wird PEM/OpenSSH (z. B. „-----BEGIN RSA PRIVATE KEY-----“), nicht die .pub-Datei."
            : "Not a valid private SSH key file. Expected PEM/OpenSSH (e.g. \"-----BEGIN RSA PRIVATE KEY-----\"), not the .pub file."
    }
    static func keyErrorCorruptPrivateKey(_ detail: String) -> String {
        if isGerman {
            return "Der private Schlüssel ist unvollständig oder beschädigt. Ein RSA-Key hat normalerweise viele Zeilen Base64 zwischen BEGIN und END. Details: \(detail)"
        }
        return "The private key is incomplete or corrupt. A valid RSA key usually has many lines of Base64 between BEGIN and END. Details: \(detail)"
    }
    static var keyErrorPublicKeyExtractionFailed: String {
        isGerman
            ? "Öffentlicher Schlüssel konnte nicht ermittelt werden."
            : "Could not determine the public key."
    }
    static func keyReadFailed(_ detail: String) -> String {
        isGerman ? "Datei konnte nicht gelesen werden: \(detail)" : "Could not read file: \(detail)"
    }
    static var selectKeyRequired: String {
        isGerman ? "Bitte einen gespeicherten Schlüssel auswählen." : "Please select a saved key."
    }
    
    // Settings
    static var settings: String { isGerman ? "Einstellungen" : "Settings" }
    static var preferences: String { isGerman ? "Einstellungen" : "Preferences" }

    // Menu Bar
    static var noServersInMenu: String { isGerman ? "Keine Server" : "No servers" }
    static func quitApplication(_ appName: String) -> String {
        isGerman ? "\(appName) beenden" : "Quit \(appName)"
    }
    static var terminalTheme: String { isGerman ? "Terminal-Theme" : "Terminal Theme" }
    static var themeStandard: String { isGerman ? "Standard" : "Standard" }
    static var themeLight: String { isGerman ? "Hell" : "Light" }
    static var themeDark: String { isGerman ? "Dunkel" : "Dark" }
    
    // Settings Categories
    static var terminalSettings: String { isGerman ? "Terminal" : "Terminal" }
    static var terminalSettingsDescription: String { isGerman ? "Passen Sie das Aussehen und Verhalten des Terminals an" : "Customize the appearance and behavior of the terminal" }
    static var sessionSettings: String { isGerman ? "Sitzungen" : "Sessions" }
    static var sessionSettingsDescription: String { isGerman ? "Konfigurieren Sie das Verhalten von SSH-Sitzungen" : "Configure SSH session behavior" }
    static var connectionSettings: String { isGerman ? "Verbindung" : "Connection" }
    static var connectionSettingsDescription: String { isGerman ? "Konfigurieren Sie Standardwerte für SSH-Verbindungen" : "Configure default values for SSH connections" }
    static var generalSettings: String { isGerman ? "Allgemein" : "General" }
    static var generalSettingsDescription: String { isGerman ? "Allgemeine App-Einstellungen und Verhalten" : "General app settings and behavior" }
    static var preferencesDescription: String { isGerman ? "Verwalten Sie Ihre App-Einstellungen" : "Manage your app settings" }
    
    // Terminal Settings
    static var fontSize: String { isGerman ? "Schriftgröße" : "Font Size" }
    static var terminalThemeDescription: String { isGerman ? "Wählen Sie das Farbschema für das Terminal" : "Choose the color scheme for the terminal" }
    static var fontSizeDescription: String { isGerman ? "Stellen Sie die Schriftgröße des Terminals ein" : "Set the font size of the terminal" }
    static var fontFamily: String { isGerman ? "Schriftfamilie" : "Font Family" }
    static var cursorStyle: String { isGerman ? "Cursor-Stil" : "Cursor Style" }
    static var scrollBufferSize: String { isGerman ? "Scroll-Puffer Größe" : "Scroll Buffer Size" }
    static var keepDisplayActive: String { isGerman ? "Bildschirm aktiv halten" : "Keep Display Active" }
    static var fontFamilyDescription: String { isGerman ? "Wählen Sie die Schriftart für das Terminal" : "Choose the font family for the terminal" }
    static var cursorStyleDescription: String { isGerman ? "Wählen Sie den Cursor-Stil" : "Choose the cursor style" }
    static var scrollBufferDescription: String { isGerman ? "Anzahl der Zeilen im Scroll-Puffer" : "Number of lines in scroll buffer" }
    static var keepDisplayDescription: String { isGerman ? "Terminal-Bildschirm auch bei Inaktivität aktiv halten" : "Keep terminal display active even when inactive" }

    // Cursor Styles
    static var blinkBar: String { isGerman ? "Blinkender Balken" : "Blink Bar" }
    static var blinkBlock: String { isGerman ? "Blinkender Block" : "Blink Block" }
    static var steadyBlock: String { isGerman ? "Fester Block" : "Steady Block" }
    static var blinkUnderline: String { isGerman ? "Blinkende Unterstreichung" : "Blink Underline" }
    static var steadyUnderline: String { isGerman ? "Feste Unterstreichung" : "Steady Underline" }
    static var steadyBar: String { isGerman ? "Fester Balken" : "Steady Bar" }

    // System Font
    static var systemFont: String { isGerman ? "System" : "System" }

    // Session Settings
    static var detectOperatingSystem: String { isGerman ? "Betriebssystem erkennen" : "Detect Operating System" }
    static var keepSessionsAlive: String { isGerman ? "Sitzungen am Leben erhalten" : "Keep Sessions Alive" }
    static var detectOSDescription: String { isGerman ? "Zeigt das erkannte Betriebssystem in der Terminal-Toolbar" : "Shows detected operating system in terminal toolbar" }
    static var keepAliveDescription: String { isGerman ? "Verhindert automatische Trennung inaktiver SSH-Sitzungen" : "Prevents automatic disconnection of inactive SSH sessions" }

    // Connection Settings
    static var connectionTimeout: String { isGerman ? "Verbindungs-Timeout" : "Connection Timeout" }
    static var connectionTimeoutDescription: String { isGerman ? "Maximale Wartezeit für Verbindungsversuche" : "Maximum wait time for connection attempts" }
    static var defaultPort: String { isGerman ? "Standard-Port" : "Default Port" }
    static var defaultPortDescription: String { isGerman ? "Standard-Port für neue Server-Verbindungen" : "Default port for new server connections" }
    
    // General Settings
    static var launchAtLogin: String { isGerman ? "Beim Anmelden starten" : "Launch at Login" }
    static var launchAtLoginDescription: String { isGerman ? "App automatisch beim Systemstart öffnen" : "Automatically open app when you log in" }
    static var showNotifications: String { isGerman ? "Benachrichtigungen anzeigen" : "Show Notifications" }
    static var showNotificationsDescription: String { isGerman ? "Benachrichtigungen für Verbindungsstatus anzeigen" : "Show notifications for connection status" }

    // Language
    static var language: String { isGerman ? "Sprache" : "Language" }
    static var languageDescription: String { isGerman ? "App-Sprache auswählen" : "Select app language" }
    static var languageSystem: String { isGerman ? "Systemsprache" : "System Language" }
    static var languageGerman: String { "Deutsch" }
    static var languageEnglish: String { "English" }

    // About
    static func aboutApp(_ name: String) -> String {
        isGerman ? "Über \(name)" : "About \(name)"
    }

    static var aboutCredits: String {
        if isGerman {
            return """
Hatch ist ein schlankes SSH-Tool für macOS: Server und Verbindungen verwaltest du an einem Ort, SSH-Schlüssel legst du an oder importierst sie, und im integrierten Terminal passt du Themes, Schriftarten und Cursor-Stile an – alles ohne überladene Oberfläche.
"""
        } else {
            return """
Hatch is a streamlined SSH tool for macOS: manage servers and connections in one place, create or import SSH keys, and use the built-in terminal with customizable themes, fonts, and cursor styles—without a cluttered interface.
"""
        }
    }
}

