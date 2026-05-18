import SwiftUI

struct DockerView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var viewMode: OverviewViewMode

    private func columns(for width: CGFloat) -> [GridItem] {
        let padding: CGFloat = 48
        let spacing: CGFloat = 20
        let minCardWidth: CGFloat = 320
        let maxColumns = 4
        let available = max(width - padding, 0)
        let calculated = Int((available + spacing) / (minCardWidth + spacing))
        let count = max(1, min(maxColumns, calculated))
        return Array(
            repeating: GridItem(.flexible(minimum: minCardWidth), spacing: spacing, alignment: .top),
            count: count
        )
    }

    private struct ContainerRow: Identifiable {
        let id: String
        let server: Server
        let container: DockerContainerStats
    }

    private var containerRows: [ContainerRow] {
        viewModel.servers.flatMap { server -> [ContainerRow] in
            let containers = viewModel.serverDocker[server.id]?.containers ?? []
            return containers.map { container in
                ContainerRow(
                    id: "\(server.id.uuidString)-\(container.name)",
                    server: server,
                    container: container
                )
            }
        }
    }

    private var serversWithDockerNotes: [(Server, DockerAvailability)] {
        viewModel.servers.compactMap { server in
            guard let snapshot = viewModel.serverDocker[server.id] else { return nil }
            switch snapshot.availability {
            case .notInstalled, .notAccessible:
                return (server, snapshot.availability)
            default:
                return nil
            }
        }
    }

    private var isLoading: Bool {
        viewModel.servers.contains { server in
            if case .loading = viewModel.serverDockerState[server.id] { return true }
            return false
        }
    }

    var body: some View {
        Group {
            if viewModel.servers.isEmpty {
                VStack {
                    Spacer()
                    EmptyStateView(viewModel: viewModel)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            StatsPageHeader(
                                title: LocalizedStrings.dockerTitle,
                                subtitle: LocalizedStrings.dockerSubtitle
                            )
                            .padding(.top, 24)

                            if containerRows.isEmpty {
                                if isLoading {
                                    HStack(spacing: 8) {
                                        ProgressView().controlSize(.small)
                                        Text(LocalizedStrings.statsLoading)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text(LocalizedStrings.statsNoContainers)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            } else if viewMode == .grid {
                                LazyVGrid(columns: columns(for: geometry.size.width), spacing: 20) {
                                    ForEach(containerRows) { row in
                                        DockerContainerCardView(
                                            server: row.server,
                                            container: row.container,
                                            viewModel: viewModel
                                        )
                                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 200, alignment: .leading)
                                    }
                                }
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(containerRows) { row in
                                        DockerContainerListRowView(
                                            server: row.server,
                                            container: row.container,
                                            viewModel: viewModel
                                        )
                                    }
                                }
                            }

                            if !serversWithDockerNotes.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(serversWithDockerNotes, id: \.0.id) { server, availability in
                                        HStack(spacing: 6) {
                                            Image(systemName: "shippingbox")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(server.displayName)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("—")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(dockerNote(for: availability))
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    OverviewViewModeToggle(viewMode: $viewMode)
                    Button {
                        viewModel.refreshAllServerDocker()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.bordered)
                    .help(LocalizedStrings.statsRefresh)
                }
                .padding(.horizontal, 12)
            }
        }
        .onAppear { viewModel.startDockerPolling() }
        .onDisappear { viewModel.stopDockerPolling() }
    }

    private func dockerNote(for availability: DockerAvailability) -> String {
        switch availability {
        case .notInstalled: return LocalizedStrings.statsDockerNotInstalled
        case .notAccessible: return LocalizedStrings.statsDockerNotAccessible
        default: return ""
        }
    }
}

struct DockerContainerCommandsMenu: View {
    let server: Server
    let containerName: String
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Button {
            viewModel.requestDockerCommand(.restart, containerName: containerName, on: server)
        } label: {
            Label(DockerContainerCommand.restart.title, systemImage: DockerContainerCommand.restart.systemImage)
        }
        Button {
            viewModel.requestDockerCommand(.stop, containerName: containerName, on: server)
        } label: {
            Label(DockerContainerCommand.stop.title, systemImage: DockerContainerCommand.stop.systemImage)
        }
        Button {
            viewModel.requestDockerCommand(.start, containerName: containerName, on: server)
        } label: {
            Label(DockerContainerCommand.start.title, systemImage: DockerContainerCommand.start.systemImage)
        }
    }
}

struct DockerContainerCardView: View {
    let server: Server
    let container: DockerContainerStats
    @ObservedObject var viewModel: AppViewModel
    @State private var isHovered = false
    @State private var isMenuHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(container.name)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(server.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let image = container.image, !image.isEmpty {
                            Text("·")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(image)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Menu {
                    DockerContainerCommandsMenu(
                        server: server,
                        containerName: container.name,
                        viewModel: viewModel
                    )
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundColor(isMenuHovered ? .accentColor : .secondary)
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .onHover { isMenuHovered = $0 }
                .help(LocalizedStrings.dockerContainerCommands)
            }

            Divider()
                .padding(.horizontal, -16)

            HStack(alignment: .center, spacing: 20) {
                HStack(spacing: 16) {
                    CircularGaugeView(
                        label: LocalizedStrings.statsCPU,
                        percent: ServerStatsFormat.gaugePercent(container.cpuPercent)
                    )
                    CircularGaugeView(
                        label: LocalizedStrings.statsMemory,
                        percent: ServerStatsFormat.gaugePercent(container.memoryPercent)
                    )
                }

                Spacer(minLength: 8)

                VStack(alignment: .leading, spacing: 14) {
                    MonitoringMetricLine(
                        label: LocalizedStrings.statsMemoryUsage,
                        value: ServerStatsFormat.optionalText(container.memoryUsage)
                    )
                    MonitoringMetricLine(
                        label: LocalizedStrings.statsNetIO,
                        value: ServerStatsFormat.optionalText(container.networkIO)
                    )
                    MonitoringMetricLine(
                        label: LocalizedStrings.statsBlockIO,
                        value: ServerStatsFormat.optionalText(container.blockIO)
                    )
                }
            }
        }
        .padding(16)
        .serverGridCardChrome(isHovered: $isHovered)
        .contextMenu {
            DockerContainerCommandsMenu(server: server, containerName: container.name, viewModel: viewModel)
        }
    }
}

struct DockerContainerListRowView: View {
    let server: Server
    let container: DockerContainerStats
    @ObservedObject var viewModel: AppViewModel

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(container.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(server.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    if let image = container.image, !image.isEmpty {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(image)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            HStack(spacing: 14) {
                listChip(LocalizedStrings.statsCPU, ServerStatsFormat.percent(container.cpuPercent))
                listChip(LocalizedStrings.statsMemory, ServerStatsFormat.percent(container.memoryPercent))
                listChip(LocalizedStrings.statsMemoryUsage, ServerStatsFormat.optionalText(container.memoryUsage))
            }

            Menu {
                DockerContainerCommandsMenu(server: server, containerName: container.name, viewModel: viewModel)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            .help(LocalizedStrings.dockerContainerCommands)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .serverGridCardChrome(isHovered: $isHovered, cornerRadius: 8)
        .contextMenu {
            DockerContainerCommandsMenu(server: server, containerName: container.name, viewModel: viewModel)
        }
    }

    private func listChip(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

struct DockerCommandConfirmationSheet: View {
    let request: DockerCommandRequest
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(request.command.title)
                    .font(.headline)
                Spacer()
                Button(LocalizedStrings.cancel) {
                    viewModel.pendingDockerCommand = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                Text(request.command.confirmMessage(containerName: request.containerName, serverName: request.server.displayName))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if request.command.isDestructive {
                    Text(LocalizedStrings.dockerCommandDestructiveHint)
                        .font(.callout)
                        .foregroundColor(.orange)
                }
                HStack {
                    Spacer()
                    Button(LocalizedStrings.cancel) {
                        viewModel.pendingDockerCommand = nil
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    Button {
                        viewModel.executePendingDockerCommand()
                        dismiss()
                    } label: {
                        Text(LocalizedStrings.remoteCommandRun)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(request.command.isDestructive ? .red : nil)
                    .disabled(viewModel.isRunningDockerCommand)
                }
            }
            .padding(20)
        }
        .frame(width: 420)
    }
}

struct DockerCommandResultSheet: View {
    let result: DockerCommandResult
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.success ? .green : .orange)
                Text(result.command.title)
                    .font(.headline)
                Spacer()
                Button(LocalizedStrings.close) { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("\(result.containerName) · \(result.server.displayName)")
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
