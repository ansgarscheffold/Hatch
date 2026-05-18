import SwiftUI

struct ServerStatsDetailView: View {
    let server: Server
    @ObservedObject var viewModel: AppViewModel
    let onBack: () -> Void

    @State private var detailPollTimer: Timer?

    private var state: ServerStatsDetailFetchState {
        viewModel.serverStatsDetailState[server.id] ?? .idle
    }

    private var snapshot: ServerStatsDetailSnapshot? {
        if case .ready(let snap) = state { return snap }
        return viewModel.serverStatsDetail[server.id]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if case .failed(let message) = state {
                    Text(message)
                        .font(.body)
                        .foregroundColor(.orange)
                } else if case .loading = state, snapshot == nil {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(LocalizedStrings.statsLoading)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else if let snapshot {
                    detailContent(snapshot)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    onBack()
                } label: {
                    Label(LocalizedStrings.statsBack, systemImage: "chevron.left")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        viewModel.refreshServerStatsDetail(for: server)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.bordered)
                    .help(LocalizedStrings.statsRefresh)

                    Button {
                        viewModel.connect(to: server)
                    } label: {
                        Image(systemName: "terminal")
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.bordered)
                    .help(LocalizedStrings.connect)
                }
            }
        }
        .onAppear {
            viewModel.refreshServerStatsDetail(for: server)
            detailPollTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
                viewModel.refreshServerStatsDetail(for: server)
            }
        }
        .onDisappear {
            detailPollTimer?.invalidate()
            detailPollTimer = nil
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 28))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(server.displayName)
                    .font(.system(size: 28, weight: .bold))
                Text(server.connectionString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if viewModel.connectedServers[server.id]?.isConnected == true {
                Text(LocalizedStrings.active)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            } else if let temp = snapshot?.temperatureCelsius, temp >= 0 {
                Text(ServerStatsFormat.temperature(temp))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func detailContent(_ snapshot: ServerStatsDetailSnapshot) -> some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                cpuCard(snapshot.cpu, temperature: snapshot.temperatureCelsius)
                memoryCard(snapshot.memory)
                if !snapshot.networkInterfaces.isEmpty {
                    networkSection(snapshot.networkInterfaces)
                }
                if !snapshot.disks.isEmpty {
                    disksSection(snapshot.disks)
                }
            }
            .frame(minWidth: 280, maxWidth: 380)

            processesCard(snapshot.processes)
                .frame(maxWidth: .infinity)
        }
    }

    private func cpuCard(_ cpu: ServerStatsCPUBreakdown, temperature: Int?) -> some View {
        StatsDetailCard(title: LocalizedStrings.statsCPU) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(cpu.totalPercent.map { "\($0)%" } ?? "—")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        breakdownChip(LocalizedStrings.statsDetailUser, cpu.userPercent, color: .green)
                        breakdownChip(LocalizedStrings.statsDetailSystem, cpu.systemPercent, color: .red)
                        breakdownChip(LocalizedStrings.statsDetailIOWait, cpu.iowaitPercent, color: .purple)
                        breakdownChip(LocalizedStrings.statsDetailSteal, cpu.stealPercent, color: .yellow)
                    }

                    Divider()

                    HStack(spacing: 16) {
                        miniStat(LocalizedStrings.statsDetailCores, cpu.cores.map { "\($0)" } ?? "—")
                        miniStat(LocalizedStrings.statsDetailIdle, cpu.idlePercent.map { "\($0)%" } ?? "—")
                        miniStat(LocalizedStrings.statsDetailUptime, formatUptime(cpu.uptimeSeconds))
                        miniStat(LocalizedStrings.statsDetailLoad, formatLoad(cpu))
                    }
                }

                Spacer(minLength: 0)

                CircularGaugeView(
                    label: LocalizedStrings.statsCPU,
                    percent: cpu.totalPercent
                )
            }
        }
    }

    private func memoryCard(_ memory: ServerStatsMemoryDetail) -> some View {
        StatsDetailCard(title: LocalizedStrings.statsMemory) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    miniStat(LocalizedStrings.statsDetailFree, formatBytes(memory.freeBytes))
                    miniStat(LocalizedStrings.statsDetailUsed, formatBytes(memory.usedBytes))
                    miniStat(LocalizedStrings.statsDetailCached, formatBytes(memory.cachedBytes))
                }
                Spacer(minLength: 0)
                CircularGaugeView(
                    label: LocalizedStrings.statsMemory,
                    percent: memory.usedPercent
                )
            }
        }
    }

    private func networkSection(_ interfaces: [ServerStatsNetworkInterface]) -> some View {
        StatsDetailCard(title: LocalizedStrings.statsDetailInterfaces) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(interfaces) { iface in
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: iface.isWireless ? "wifi" : "cable.connector")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(iface.name)
                                .font(.system(size: 13, weight: .semibold))
                            MonitoringMetricPairRow(
                                uploadLabel: LocalizedStrings.statsUpload,
                                uploadValue: ServerStatsFormat.bytesPerSecond(iface.uploadPerSec),
                                downloadLabel: LocalizedStrings.statsDownload,
                                downloadValue: ServerStatsFormat.bytesPerSecond(iface.downloadPerSec)
                            )
                        }

                        Spacer(minLength: 0)

                        interfaceGaugePercent(iface)
                    }
                    if iface.id != interfaces.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func disksSection(_ disks: [ServerStatsDiskMount]) -> some View {
        StatsDetailCard(title: LocalizedStrings.statsDetailDisks) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(disks) { disk in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(disk.mountPoint)
                                .font(.system(size: 13, weight: .semibold))
                            if let fs = disk.fileSystem {
                                Text(fs.uppercased())
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.primary.opacity(0.06))
                                    .cornerRadius(4)
                            }
                            Spacer()
                            Text(diskCapacityLabel(disk))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        if let pct = disk.usedPercent {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.primary.opacity(0.08))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.primary.opacity(0.35))
                                        .frame(width: geo.size.width * CGFloat(min(max(pct, 0), 100)) / 100)
                                }
                            }
                            .frame(height: 6)
                        }
                        if disk.readPerSec != nil || disk.writePerSec != nil {
                            MonitoringMetricPairRow(
                                uploadLabel: LocalizedStrings.statsRead,
                                uploadValue: ServerStatsFormat.bytesPerSecond(disk.readPerSec),
                                downloadLabel: LocalizedStrings.statsWrite,
                                downloadValue: ServerStatsFormat.bytesPerSecond(disk.writePerSec)
                            )
                        }
                    }
                    if disk.id != disks.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func processesCard(_ processes: [ServerStatsProcess]) -> some View {
        StatsDetailCard(title: LocalizedStrings.statsDetailProcesses) {
            if processes.isEmpty {
                Text(LocalizedStrings.statsLoading)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text(LocalizedStrings.statsDetailProcessColumn)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(LocalizedStrings.statsCPU)
                            .frame(width: 64, alignment: .trailing)
                        Text(LocalizedStrings.statsMemory)
                            .frame(width: 64, alignment: .trailing)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)

                    Divider()

                    ForEach(Array(processes.enumerated()), id: \.offset) { index, process in
                        HStack {
                            Text(process.name)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(ServerStatsFormat.percent(process.cpuPercent))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                                .frame(width: 64, alignment: .trailing)
                            Text(ServerStatsFormat.percent(process.memoryPercent))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 64, alignment: .trailing)
                        }
                        .padding(.vertical, 6)
                        if index < processes.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func breakdownChip(_ label: String, _ percent: Int?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
            Text(percent.map { "\($0)%" } ?? "—")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }

    private func formatBytes(_ bytes: Int64?) -> String {
        guard let bytes, bytes >= 0 else { return "—" }
        return ServerStatsFormat.formatByteCount(bytes)
    }

    private func formatUptime(_ seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "—" }
        let hours = seconds / 3600
        if hours >= 48 {
            return "\(hours / 24) d"
        }
        if hours >= 1 {
            return "\(hours) h"
        }
        return "\(seconds / 60) m"
    }

    private func formatLoad(_ cpu: ServerStatsCPUBreakdown) -> String {
        guard let l1 = cpu.load1 else { return "—" }
        let l5 = cpu.load5.map { String(format: "%.1f", $0) } ?? "—"
        return String(format: "%.1f", l1) + " · " + l5
    }

    private func diskCapacityLabel(_ disk: ServerStatsDiskMount) -> String {
        let used = disk.usedBytes.map { ServerStatsFormat.formatByteCount($0) } ?? "?"
        let total = disk.totalBytes.map { ServerStatsFormat.formatByteCount($0) } ?? "?"
        let pct = disk.usedPercent.map { " (\($0)%)" } ?? ""
        return "\(used) / \(total)\(pct)"
    }

    private func interfaceGaugePercent(_ iface: ServerStatsNetworkInterface) -> some View {
        let total = (iface.downloadPerSec ?? 0) + (iface.uploadPerSec ?? 0)
        let mbps = Double(total) / (1024 * 1024)
        let pct = min(Int(mbps * 10), 100)
        return CircularGaugeView(label: "", percent: pct > 0 ? pct : nil)
            .scaleEffect(0.75)
    }
}

private struct StatsDetailCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .serverGridCardChrome(isHovered: $isHovered)
    }
}
