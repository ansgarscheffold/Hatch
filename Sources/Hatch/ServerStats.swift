import Foundation

struct ServerStatsSnapshot: Equatable {
    var cpuPercent: Int?
    var memoryPercent: Int?
    var temperatureCelsius: Int?
    /// Bytes per second
    var networkDownloadPerSec: Int64?
    var networkUploadPerSec: Int64?
    var diskReadPerSec: Int64?
    var diskWritePerSec: Int64?
    var fetchedAt: Date = Date()
}

enum ServerStatsFetchState: Equatable {
    case idle
    case loading
    case failed(String)
    case ready(ServerStatsSnapshot)
}

enum ServerStatsFormat {
    static func bytesPerSecond(_ value: Int64?) -> String {
        guard let value, value >= 0 else { return "—" }
        return formatByteCount(value) + "/s"
    }

    static func formatByteCount(_ bytes: Int64) -> String {
        let units = ["B", "K", "M", "G", "T"]
        var amount = Double(bytes)
        var index = 0
        while amount >= 1024, index < units.count - 1 {
            amount /= 1024
            index += 1
        }
        if index == 0 {
            return "\(bytes) \(units[0])"
        }
        let formatted = amount >= 100 || amount.truncatingRemainder(dividingBy: 1) < 0.05
            ? String(format: "%.0f", amount)
            : String(format: "%.1f", amount)
        return "\(formatted) \(units[index])"
    }

    static func temperature(_ celsius: Int?) -> String {
        guard let celsius, celsius >= 0 else { return "—" }
        return "\(celsius)°C"
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value.truncatingRemainder(dividingBy: 1) < 0.05 {
            return String(format: "%.0f%%", value)
        }
        return String(format: "%.1f%%", value)
    }

    static func optionalText(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "—" }
        return value
    }

    static func gaugePercent(_ value: Double?) -> Int? {
        guard let value else { return nil }
        return Int(min(max(value.rounded(), 0), 100))
    }
}

enum ServerStatsCollector {
    private static let statsScript = """
    cpu=; mem=; temp=-1; nd=0; nu=0; dr=0; dw=0
    if [ -r /proc/meminfo ]; then
      mem=$(awk '/MemTotal:/{t=$2} /MemAvailable:/{a=$2} END{if(t>0) printf "%d", (t-a)*100/t; else print "0"}' /proc/meminfo)
    elif command -v free >/dev/null 2>&1; then
      mem=$(free 2>/dev/null | awk '/Mem:/ {if ($2>0) printf "%d", $3*100/$2; else print "0"}')
    fi
    if [ -r /sys/class/thermal/thermal_zone0/temp ]; then
      raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
      case "$raw" in ''|*[!0-9]*) ;; *) temp=$((raw/1000)) ;; esac
    elif command -v vcgencmd >/dev/null 2>&1; then
      raw=$(vcgencmd measure_temp 2>/dev/null | tr -cd '0-9.')
      case "$raw" in ''|*[!0-9.]*) ;; *) temp=${raw%.*} ;; esac
    fi
    net_sum() { awk 'NR>2 && $1 !~ /^(lo|docker|veth|br-|virbr)/ {gsub(/:/,"",$1); rx+=$2; tx+=$10} END{printf "%s %s", rx+0, tx+0}' /proc/net/dev; }
    disk_sample() {
      awk '$3 ~ /^(sd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+|vd[a-z]+)$/ {
        r+=$6; w+=$10; found=1
      } END{if(found) printf "%s %s", r+0, w+0; else print "0 0"}' /proc/diskstats 2>/dev/null
    }
    if [ -r /proc/stat ]; then
      read _ u1 n1 s1 i1 iw1 irq1 sirq1 st1 _ </proc/stat
      idle1=$((i1+iw1)); total1=$((u1+n1+s1+i1+iw1+irq1+sirq1+st1))
    fi
    if [ -r /proc/net/dev ]; then set -- $(net_sum); r1=$1; t1=$2; fi
    if [ -r /proc/diskstats ]; then set -- $(disk_sample); dr1=$1; dw1=$2; fi
    sleep 1
    if [ -r /proc/stat ]; then
      read _ u2 n2 s2 i2 iw2 irq2 sirq2 st2 _ </proc/stat
      idle2=$((i2+iw2)); total2=$((u2+n2+s2+i2+iw2+irq2+sirq2+st2))
      dt=$((total2-total1)); di=$((idle2-idle1))
      if [ "$dt" -gt 0 ]; then cpu=$(( (100*(dt-di))/dt )); fi
    fi
    if [ -r /proc/net/dev ]; then
      set -- $(net_sum); r2=$1; t2=$2
      nd=$((r2-r1)); nu=$((t2-t1))
    fi
    if [ -r /proc/diskstats ]; then
      set -- $(disk_sample); dr2=$1; dw2=$2
      dr=$(( (dr2-dr1)*512 )); dw=$(( (dw2-dw1)*512 ))
    fi
    printf 'CPU=%s\\nMEM=%s\\nTEMP=%s\\nNET_DOWN=%s\\nNET_UP=%s\\nDISK_READ=%s\\nDISK_WRITE=%s\\n' \\
      "${cpu:-}" "${mem:-}" "$temp" "$nd" "$nu" "$dr" "$dw"
    """

    static func fetch(
        host: String,
        port: Int,
        username: String,
        auth: ServerSSHAuth
    ) -> Result<ServerStatsSnapshot, Error> {
        switch ServerSSHExecutor.run(
            host: host,
            port: port,
            username: username,
            auth: auth,
            command: statsScript,
            timeout: 10
        ) {
        case .success(let output):
            guard let snapshot = parse(output: output) else {
                return .failure(StatsError.parseFailed)
            }
            return .success(snapshot)
        case .failure(let error):
            return .failure(error)
        }
    }

    private static func parse(output: String) -> ServerStatsSnapshot? {
        var values: [String: String] = [:]
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let eq = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[..<eq])
            let value = String(trimmed[trimmed.index(after: eq)...])
            values[key] = value
        }
        guard !values.isEmpty else { return nil }

        func intValue(_ key: String) -> Int? {
            guard let raw = values[key], !raw.isEmpty else { return nil }
            return Int(raw)
        }
        func int64Value(_ key: String) -> Int64? {
            guard let raw = values[key], !raw.isEmpty else { return nil }
            return Int64(raw)
        }

        let temp = intValue("TEMP")
        return ServerStatsSnapshot(
            cpuPercent: intValue("CPU"),
            memoryPercent: intValue("MEM"),
            temperatureCelsius: (temp != nil && temp! >= 0) ? temp : nil,
            networkDownloadPerSec: int64Value("NET_DOWN"),
            networkUploadPerSec: int64Value("NET_UP"),
            diskReadPerSec: int64Value("DISK_READ"),
            diskWritePerSec: int64Value("DISK_WRITE"),
            fetchedAt: Date()
        )
    }
}

enum StatsError: LocalizedError {
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .parseFailed:
            return LocalizedStrings.statsErrorParse
        }
    }
}
