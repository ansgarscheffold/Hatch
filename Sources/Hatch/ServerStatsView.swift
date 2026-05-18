import SwiftUI

struct OverviewViewModeToggle: View {
    @Binding var viewMode: OverviewViewMode

    var body: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewMode = .grid
                }
            } label: {
                Image(systemName: "square.grid.2x2")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.bordered)
            .frame(width: 28, height: 28)
            .foregroundColor(viewMode == .grid ? .accentColor : .secondary)
            .background(viewMode == .grid ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewMode = .list
                }
            } label: {
                Image(systemName: "list.dash")
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.bordered)
            .frame(width: 28, height: 28)
            .foregroundColor(viewMode == .list ? .accentColor : .secondary)
            .background(viewMode == .list ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
    }
}

struct ServerStatsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var viewMode: OverviewViewMode
    @State private var detailServer: Server?

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

    var body: some View {
        Group {
            if let server = detailServer {
                ServerStatsDetailView(
                    server: server,
                    viewModel: viewModel,
                    onBack: { detailServer = nil }
                )
            } else if viewModel.servers.isEmpty {
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
                                title: LocalizedStrings.statsTitle,
                                subtitle: LocalizedStrings.statsSubtitle
                            )
                            .padding(.top, 24)

                            if viewMode == .grid {
                                LazyVGrid(columns: columns(for: geometry.size.width), spacing: 20) {
                                    ForEach(viewModel.servers) { server in
                                        ServerStatsCardView(
                                            server: server,
                                            viewModel: viewModel,
                                            state: viewModel.serverStatsState[server.id] ?? .idle,
                                            snapshot: viewModel.serverStats[server.id],
                                            onOpenDetail: { detailServer = server }
                                        )
                                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 200, alignment: .leading)
                                    }
                                }
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(viewModel.servers) { server in
                                        ServerStatsListRowView(
                                            server: server,
                                            viewModel: viewModel,
                                            state: viewModel.serverStatsState[server.id] ?? .idle,
                                            snapshot: viewModel.serverStats[server.id],
                                            onOpenDetail: { detailServer = server }
                                        )
                                    }
                                }
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
            if detailServer == nil {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        OverviewViewModeToggle(viewMode: $viewMode)

                        Button {
                            viewModel.refreshAllServerStats()
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
        }
        .onAppear {
            viewModel.startStatsPolling()
        }
        .onDisappear {
            viewModel.stopStatsPolling()
        }
    }
}

struct ServerStatsListRowView: View {
    let server: Server
    @ObservedObject var viewModel: AppViewModel
    let state: ServerStatsFetchState
    let snapshot: ServerStatsSnapshot?
    var onOpenDetail: (() -> Void)?

    @State private var isHovered = false

    private var displaySnapshot: ServerStatsSnapshot? {
        if case .ready(let snap) = state { return snap }
        return snapshot
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Text(server.connectionString)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            statsSummary

            Button {
                viewModel.connect(to: server)
            } label: {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help(LocalizedStrings.connect)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .serverGridCardChrome(isHovered: $isHovered, cornerRadius: 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenDetail?()
        }
        .help(LocalizedStrings.statsDetailOpenHint)
    }

    @ViewBuilder
    private var statsSummary: some View {
        if case .failed(let message) = state {
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.orange)
                .lineLimit(1)
        } else if case .loading = state, displaySnapshot == nil {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(LocalizedStrings.statsLoading)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        } else {
            HStack(spacing: 14) {
                summaryChip(LocalizedStrings.statsCPU, displaySnapshot?.cpuPercent.map { "\($0)%" } ?? "—")
                summaryChip(LocalizedStrings.statsMemory, displaySnapshot?.memoryPercent.map { "\($0)%" } ?? "—")
                summaryChip("°C", ServerStatsFormat.temperature(displaySnapshot?.temperatureCelsius))
            }
        }
    }

    private func summaryChip(_ label: String, _ value: String) -> some View {
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

struct ServerStatsCardView: View {
    let server: Server
    @ObservedObject var viewModel: AppViewModel
    let state: ServerStatsFetchState
    let snapshot: ServerStatsSnapshot?
    var onOpenDetail: (() -> Void)?

    @State private var isHovered = false
    @State private var isTerminalHovered = false

    private var displaySnapshot: ServerStatsSnapshot? {
        if case .ready(let snap) = state { return snap }
        return snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                    .padding(.top, 2)

                Text(server.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                if viewModel.connectedServers[server.id]?.isConnected == true {
                    Text(LocalizedStrings.active)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                } else if let temp = displaySnapshot?.temperatureCelsius, temp >= 0 {
                    Text(ServerStatsFormat.temperature(temp))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Button {
                    onOpenDetail?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(LocalizedStrings.statsDetailOpenHint)

                Button {
                    viewModel.connect(to: server)
                } label: {
                    Image(systemName: "terminal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red.opacity(isTerminalHovered ? 1 : 0.85))
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(LocalizedStrings.connect)
                .onHover { isTerminalHovered = $0 }
            }

            Divider()
                .padding(.horizontal, -16)

            Group {
                if case .failed(let message) = state {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .lineLimit(2)
                } else if case .loading = state, displaySnapshot == nil {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(LocalizedStrings.statsLoading)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    HStack(alignment: .center, spacing: 20) {
                        HStack(spacing: 16) {
                            CircularGaugeView(
                                label: LocalizedStrings.statsCPU,
                                percent: displaySnapshot?.cpuPercent
                            )
                            CircularGaugeView(
                                label: LocalizedStrings.statsMemory,
                                percent: displaySnapshot?.memoryPercent
                            )
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .leading, spacing: 14) {
                            MonitoringMetricPairRow(
                                uploadLabel: LocalizedStrings.statsUpload,
                                uploadValue: ServerStatsFormat.bytesPerSecond(displaySnapshot?.networkUploadPerSec),
                                downloadLabel: LocalizedStrings.statsDownload,
                                downloadValue: ServerStatsFormat.bytesPerSecond(displaySnapshot?.networkDownloadPerSec)
                            )
                            MonitoringMetricPairRow(
                                uploadLabel: LocalizedStrings.statsRead,
                                uploadValue: ServerStatsFormat.bytesPerSecond(displaySnapshot?.diskReadPerSec),
                                downloadLabel: LocalizedStrings.statsWrite,
                                downloadValue: ServerStatsFormat.bytesPerSecond(displaySnapshot?.diskWritePerSec)
                            )
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onOpenDetail?()
            }
        }
        .padding(16)
        .serverGridCardChrome(isHovered: $isHovered)
        .contextMenu {
            Button {
                onOpenDetail?()
            } label: {
                Label(LocalizedStrings.statsDetailProcesses, systemImage: "chart.bar.doc.horizontal")
            }
            Divider()
            if viewModel.connectedServers[server.id]?.isConnected == true {
                Button {
                    viewModel.disconnect(from: server)
                } label: {
                    Label(LocalizedStrings.disconnect, systemImage: "stop.circle")
                }
            } else {
                Button {
                    viewModel.connect(to: server)
                } label: {
                    Label(LocalizedStrings.connect, systemImage: "globe")
                }
            }
        }
    }
}
