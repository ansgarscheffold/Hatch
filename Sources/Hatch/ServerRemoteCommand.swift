import SwiftUI

enum ServerRemoteCommand: String, Identifiable, CaseIterable {
    case uptime
    case reboot
    case shutdown
    case cancelShutdown

    var id: String { rawValue }

    var isDestructive: Bool {
        switch self {
        case .reboot, .shutdown:
            return true
        case .uptime, .cancelShutdown:
            return false
        }
    }

    var disconnectsAfterSuccess: Bool {
        switch self {
        case .reboot, .shutdown:
            return true
        case .uptime, .cancelShutdown:
            return false
        }
    }

    var systemImage: String {
        switch self {
        case .uptime:
            return "clock"
        case .reboot:
            return "arrow.clockwise"
        case .shutdown:
            return "power"
        case .cancelShutdown:
            return "xmark.circle"
        }
    }

    var title: String {
        switch self {
        case .uptime:
            return LocalizedStrings.remoteCommandUptime
        case .reboot:
            return LocalizedStrings.remoteCommandReboot
        case .shutdown:
            return LocalizedStrings.remoteCommandShutdown
        case .cancelShutdown:
            return LocalizedStrings.remoteCommandCancelShutdown
        }
    }

    func confirmMessage(serverName: String) -> String {
        switch self {
        case .uptime:
            return LocalizedStrings.remoteCommandConfirmUptime(serverName)
        case .reboot:
            return LocalizedStrings.remoteCommandConfirmReboot(serverName)
        case .shutdown:
            return LocalizedStrings.remoteCommandConfirmShutdown(serverName)
        case .cancelShutdown:
            return LocalizedStrings.remoteCommandConfirmCancelShutdown(serverName)
        }
    }

    var shellScript: String {
        switch self {
        case .uptime:
            return """
            if command -v uptime >/dev/null 2>&1; then
              out=$(uptime -p 2>/dev/null || uptime 2>/dev/null)
              echo "HATCH_OK=$out"
            else
              echo "HATCH_ERR=uptime command not available"
              exit 1
            fi
            """
        case .reboot:
            return """
            if [ "$(id -u)" -eq 0 ]; then
              nohup sh -c 'sleep 2; reboot' >/dev/null 2>&1 &
              echo "HATCH_OK=Reboot initiated"
              exit 0
            fi
            if command -v systemctl >/dev/null 2>&1 && sudo -n systemctl reboot >/dev/null 2>&1; then
              echo "HATCH_OK=Reboot initiated"
              exit 0
            fi
            if sudo -n reboot >/dev/null 2>&1; then
              echo "HATCH_OK=Reboot initiated"
              exit 0
            fi
            if sudo -n shutdown -r +1 "Hatch" >/dev/null 2>&1; then
              echo "HATCH_OK=Reboot scheduled in 1 minute"
              exit 0
            fi
            echo "HATCH_ERR=Reboot requires root or passwordless sudo"
            exit 1
            """
        case .shutdown:
            return """
            if [ "$(id -u)" -eq 0 ]; then
              nohup sh -c 'sleep 2; shutdown -h now' >/dev/null 2>&1 &
              echo "HATCH_OK=Shutdown initiated"
              exit 0
            fi
            if command -v systemctl >/dev/null 2>&1 && sudo -n systemctl poweroff >/dev/null 2>&1; then
              echo "HATCH_OK=Shutdown initiated"
              exit 0
            fi
            if sudo -n shutdown -h now >/dev/null 2>&1; then
              echo "HATCH_OK=Shutdown initiated"
              exit 0
            fi
            echo "HATCH_ERR=Shutdown requires root or passwordless sudo"
            exit 1
            """
        case .cancelShutdown:
            return """
            if sudo -n shutdown -c >/dev/null 2>&1; then
              echo "HATCH_OK=Scheduled shutdown cancelled"
              exit 0
            fi
            if [ "$(id -u)" -eq 0 ] && shutdown -c >/dev/null 2>&1; then
              echo "HATCH_OK=Scheduled shutdown cancelled"
              exit 0
            fi
            echo "HATCH_ERR=Could not cancel shutdown (none scheduled or no permission)"
            exit 1
            """
        }
    }
}

enum ServerRemoteCommandExecutor {
    static func run(
        command: ServerRemoteCommand,
        host: String,
        port: Int,
        username: String,
        auth: ServerSSHAuth
    ) -> Result<String, Error> {
        let timeout: TimeInterval = command == .uptime ? 8 : 12
        return ServerSSHExecutor.run(
            host: host,
            port: port,
            username: username,
            auth: auth,
            command: command.shellScript,
            timeout: timeout
        )
    }
}

struct RemoteCommandRequest: Identifiable {
    let id = UUID()
    let server: Server
    let command: ServerRemoteCommand
}

struct RemoteCommandResult: Identifiable {
    let id = UUID()
    let server: Server
    let command: ServerRemoteCommand
    let success: Bool
    let message: String
}

struct ServerCommandsMenuContent: View {
    let server: Server
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Button {
            viewModel.requestRemoteCommand(.uptime, for: server)
        } label: {
            Label(ServerRemoteCommand.uptime.title, systemImage: ServerRemoteCommand.uptime.systemImage)
        }

        Divider()

        Button {
            viewModel.requestRemoteCommand(.reboot, for: server)
        } label: {
            Label(ServerRemoteCommand.reboot.title, systemImage: ServerRemoteCommand.reboot.systemImage)
        }

        Button {
            viewModel.requestRemoteCommand(.shutdown, for: server)
        } label: {
            Label(ServerRemoteCommand.shutdown.title, systemImage: ServerRemoteCommand.shutdown.systemImage)
        }

        Button {
            viewModel.requestRemoteCommand(.cancelShutdown, for: server)
        } label: {
            Label(ServerRemoteCommand.cancelShutdown.title, systemImage: ServerRemoteCommand.cancelShutdown.systemImage)
        }
    }
}

struct RemoteCommandConfirmationSheet: View {
    let request: RemoteCommandRequest
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(request.command.title)
                    .font(.headline)
                Spacer()
                Button(LocalizedStrings.cancel) {
                    viewModel.pendingRemoteCommand = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Text(request.command.confirmMessage(serverName: request.server.displayName))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if request.command.isDestructive {
                    Text(LocalizedStrings.remoteCommandDestructiveHint)
                        .font(.callout)
                        .foregroundColor(.orange)
                }

                HStack {
                    Spacer()
                    Button(LocalizedStrings.cancel) {
                        viewModel.pendingRemoteCommand = nil
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button {
                        viewModel.executePendingRemoteCommand()
                        dismiss()
                    } label: {
                        Text(LocalizedStrings.remoteCommandRun)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(request.command.isDestructive ? .red : nil)
                    .disabled(viewModel.isRunningRemoteCommand)
                }
            }
            .padding(20)
        }
        .frame(width: 420)
    }
}

struct RemoteCommandResultSheet: View {
    let result: RemoteCommandResult
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.success ? .green : .orange)
                Text(result.command.title)
                    .font(.headline)
                Spacer()
                Button(LocalizedStrings.close) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text(result.server.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView {
                    Text(result.message)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 80, maxHeight: 200)
            }
            .padding(20)
        }
        .frame(width: 440)
        .frame(minHeight: 200)
    }
}
