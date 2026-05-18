import Foundation

struct ServerStatsCPUBreakdown: Equatable {
    var totalPercent: Int?
    var userPercent: Int?
    var systemPercent: Int?
    var iowaitPercent: Int?
    var stealPercent: Int?
    var idlePercent: Int?
    var cores: Int?
    var load1: Double?
    var load5: Double?
    var load15: Double?
    var uptimeSeconds: Int?
}

struct ServerStatsMemoryDetail: Equatable {
    var totalBytes: Int64?
    var freeBytes: Int64?
    var usedBytes: Int64?
    var cachedBytes: Int64?
    var usedPercent: Int?
}

struct ServerStatsNetworkInterface: Equatable, Identifiable {
    var id: String { name }
    var name: String
    var isWireless: Bool
    var downloadPerSec: Int64?
    var uploadPerSec: Int64?
    var totalDownload: Int64?
    var totalUpload: Int64?
}

struct ServerStatsDiskMount: Equatable, Identifiable {
    var id: String { mountPoint }
    var mountPoint: String
    var fileSystem: String?
    var usedBytes: Int64?
    var totalBytes: Int64?
    var usedPercent: Int?
    var readPerSec: Int64?
    var writePerSec: Int64?
}

struct ServerStatsProcess: Equatable, Identifiable {
    var id: String { "\(name)-\(cpuPercent ?? 0)-\(memoryPercent ?? 0)" }
    var name: String
    var cpuPercent: Double?
    var memoryPercent: Double?
}

struct ServerStatsDetailSnapshot: Equatable {
    var cpu: ServerStatsCPUBreakdown
    var memory: ServerStatsMemoryDetail
    var temperatureCelsius: Int?
    var networkInterfaces: [ServerStatsNetworkInterface]
    var disks: [ServerStatsDiskMount]
    var processes: [ServerStatsProcess]
    var fetchedAt: Date = Date()
}

enum ServerStatsDetailFetchState: Equatable {
    case idle
    case loading
    case failed(String)
    case ready(ServerStatsDetailSnapshot)
}

enum ServerStatsDetailCollector {
    private static let detailScript = """
    cpu_total=; cpu_user=; cpu_sys=; cpu_iow=; cpu_steal=; cpu_idle=; cores=1; l1=; l5=; l15=; up=
    mem_total=0; mem_free=0; mem_used=0; mem_cached=0; mem_pct=
    temp=-1

  if [ -r /proc/cpuinfo ]; then
    cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
  fi
  if [ -r /proc/loadavg ]; then
    read l1 l5 l15 _ </proc/loadavg
  fi
  if [ -r /proc/uptime ]; then
    read up _ </proc/uptime
    up=${up%.*}
  fi
  if [ -r /proc/meminfo ]; then
    eval $(awk '/MemTotal:/{t=$2} /MemFree:/{f=$2} /MemAvailable:/{a=$2} /Cached:/{c=$2} END{
      used=t-a; if(used<0) used=t-f; pct=0; if(t>0) pct=int(used*100/t);
      printf "mem_total=%s mem_free=%s mem_used=%s mem_cached=%s mem_pct=%s", t*1024, f*1024, used*1024, c*1024, pct
    }' /proc/meminfo)
  fi
  if [ -r /sys/class/thermal/thermal_zone0/temp ]; then
    raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    case "$raw" in ''|*[!0-9]*) ;; *) temp=$((raw/1000)) ;; esac
  fi

  net_sample() {
    awk 'NR>2 && $1 !~ /^(lo|docker|veth|br-|virbr)/ {
      gsub(/:/,"",$1); print $1"|"$2"|"$10
    }' /proc/net/dev
  }
  disk_sample() {
    awk '$3 ~ /^(sd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+|vd[a-z]+)$/ {
      r+=$6; w+=$10; found=1
    } END{if(found) printf "%s|%s", r+0, w+0; else print "0|0"}' /proc/diskstats 2>/dev/null
  }

  if [ -r /proc/stat ]; then
    read _ u1 n1 s1 i1 iw1 irq1 sirq1 st1 _ </proc/stat
    idle1=$((i1+iw1)); total1=$((u1+n1+s1+i1+iw1+irq1+sirq1+st1))
  fi
  n1_net=$(net_sample)
  d1_disk=$(disk_sample)
  sleep 1
  if [ -r /proc/stat ]; then
    read _ u2 n2 s2 i2 iw2 irq2 sirq2 st2 _ </proc/stat
    idle2=$((i2+iw2)); total2=$((u2+n2+s2+i2+iw2+irq2+sirq2+st2))
    dt=$((total2-total1)); di=$((idle2-idle1))
    if [ "$dt" -gt 0 ]; then
      cpu_total=$(( (100*(dt-di))/dt ))
      du=$((u2-u1)); dn=$((n2-n1)); ds=$((s2-s1)); diw=$((iw2-iw1)); dst=$((st2-st1))
      cpu_user=$(( du*100/dt )); cpu_sys=$(( (ds+dn)*100/dt ))
      cpu_iow=$(( diw*100/dt )); cpu_steal=$(( dst*100/dt ))
      cpu_idle=$(( di*100/dt ))
    fi
  fi
  n2_net=$(net_sample)
  d2_disk=$(disk_sample)
  dr=0; dw=0
  if [ -n "$d1_disk" ] && [ -n "$d2_disk" ]; then
  set -- $(echo "$d1_disk" | tr '|' ' '); dr1=$1; dw1=$2
  set -- $(echo "$d2_disk" | tr '|' ' '); dr2=$1; dw2=$2
  dr=$(( (dr2-dr1)*512 )); dw=$(( (dw2-dw1)*512 ))
  fi

  while IFS='|' read -r ifn rx1 tx1; do
    [ -z "$ifn" ] && continue
    rx2=0; tx2=0
    line=$(echo "$n2_net" | awk -F'|' -v n="$ifn" '$1==n{print $0}')
    [ -n "$line" ] && IFS='|' read -r _ rx2 tx2 <<< "$line"
    nd=$((rx2-rx1)); nu=$((tx2-tx1))
    wl=0; case "$ifn" in wlan*|wl*) wl=1 ;; esac
    echo "IF|${ifn}|${wl}|${nd}|${nu}|${rx2}|${tx2}"
  done <<< "$n1_net"

  if command -v df >/dev/null 2>&1; then
    df -P -B1 2>/dev/null | awk 'NR>1 && $1 !~ /^tmpfs|^devtmpfs|^overlay/ {print}' | while IFS= read -r line; do
      set -- $line
      mp=$6; fs=$1; total=$2; used=$3; pct=$5
      pct=${pct%%%}
      echo "DISK|${mp}|${fs}|${used}|${total}|${pct}"
    done
  fi

  if command -v ps >/dev/null 2>&1; then
    ps -eo comm=,pcpu=,pmem= --sort=-pcpu 2>/dev/null | head -20 | while read -r name cpu mem; do
      [ -z "$name" ] && continue
      echo "PROC|${name}|${cpu}|${mem}"
    done
  fi

  printf 'CPU_TOTAL=%s\\nCPU_USER=%s\\nCPU_SYS=%s\\nCPU_IOW=%s\\nCPU_STEAL=%s\\nCPU_IDLE=%s\\n' \\
    "${cpu_total:-}" "${cpu_user:-}" "${cpu_sys:-}" "${cpu_iow:-}" "${cpu_steal:-}" "${cpu_idle:-}"
  printf 'CORES=%s\\nLOAD1=%s\\nLOAD5=%s\\nLOAD15=%s\\nUPTIME=%s\\n' \\
    "${cores:-1}" "${l1:-}" "${l5:-}" "${l15:-}" "${up:-}"
  printf 'MEM_TOTAL=%s\\nMEM_FREE=%s\\nMEM_USED=%s\\nMEM_CACHED=%s\\nMEM_PCT=%s\\nTEMP=%s\\n' \\
    "${mem_total:-}" "${mem_free:-}" "${mem_used:-}" "${mem_cached:-}" "${mem_pct:-}" "$temp"
  printf 'DISK_READ=%s\\nDISK_WRITE=%s\\n' "$dr" "$dw"
  """

    static func fetch(
        host: String,
        port: Int,
        username: String,
        auth: ServerSSHAuth
    ) -> Result<ServerStatsDetailSnapshot, Error> {
        switch ServerSSHExecutor.run(
            host: host,
            port: port,
            username: username,
            auth: auth,
            command: detailScript,
            timeout: 15
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

    private static func parse(output: String) -> ServerStatsDetailSnapshot? {
        var values: [String: String] = [:]
        var interfaces: [ServerStatsNetworkInterface] = []
        var disks: [ServerStatsDiskMount] = []
        var processes: [ServerStatsProcess] = []

        func intVal(_ key: String) -> Int? {
            guard let raw = values[key], !raw.isEmpty else { return nil }
            return Int(raw)
        }
        func int64Val(_ key: String) -> Int64? {
            guard let raw = values[key], !raw.isEmpty else { return nil }
            return Int64(raw)
        }
        func doubleVal(_ key: String) -> Double? {
            guard let raw = values[key], !raw.isEmpty else { return nil }
            return Double(raw)
        }

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("IF|") {
                let parts = trimmed.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                guard parts.count >= 7 else { continue }
                interfaces.append(ServerStatsNetworkInterface(
                    name: parts[1],
                    isWireless: parts[2] == "1",
                    downloadPerSec: Int64(parts[3]),
                    uploadPerSec: Int64(parts[4]),
                    totalDownload: Int64(parts[5]),
                    totalUpload: Int64(parts[6])
                ))
                continue
            }
            if trimmed.hasPrefix("DISK|") {
                let parts = trimmed.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                guard parts.count >= 6 else { continue }
                disks.append(ServerStatsDiskMount(
                    mountPoint: parts[1],
                    fileSystem: parts[2],
                    usedBytes: Int64(parts[3]),
                    totalBytes: Int64(parts[4]),
                    usedPercent: Int(parts[5])
                ))
                continue
            }
            if trimmed.hasPrefix("PROC|") {
                let parts = trimmed.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                guard parts.count >= 4 else { continue }
                processes.append(ServerStatsProcess(
                    name: parts[1],
                    cpuPercent: Double(parts[2]),
                    memoryPercent: Double(parts[3])
                ))
                continue
            }

            guard let eq = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[..<eq])
            let value = String(trimmed[trimmed.index(after: eq)...])
            values[key] = value
        }

        guard values["CPU_TOTAL"] != nil || values["MEM_TOTAL"] != nil || !interfaces.isEmpty else {
            return nil
        }

        let diskRead = int64Val("DISK_READ")
        let diskWrite = int64Val("DISK_WRITE")
        if !disks.isEmpty, diskRead != nil || diskWrite != nil {
            var root = disks[0]
            root.readPerSec = diskRead
            root.writePerSec = diskWrite
            disks[0] = root
        }

        let temp = intVal("TEMP")
        return ServerStatsDetailSnapshot(
            cpu: ServerStatsCPUBreakdown(
                totalPercent: intVal("CPU_TOTAL"),
                userPercent: intVal("CPU_USER"),
                systemPercent: intVal("CPU_SYS"),
                iowaitPercent: intVal("CPU_IOW"),
                stealPercent: intVal("CPU_STEAL"),
                idlePercent: intVal("CPU_IDLE"),
                cores: intVal("CORES"),
                load1: doubleVal("LOAD1"),
                load5: doubleVal("LOAD5"),
                load15: doubleVal("LOAD15"),
                uptimeSeconds: intVal("UPTIME")
            ),
            memory: ServerStatsMemoryDetail(
                totalBytes: int64Val("MEM_TOTAL"),
                freeBytes: int64Val("MEM_FREE"),
                usedBytes: int64Val("MEM_USED"),
                cachedBytes: int64Val("MEM_CACHED"),
                usedPercent: intVal("MEM_PCT")
            ),
            temperatureCelsius: (temp != nil && temp! >= 0) ? temp : nil,
            networkInterfaces: interfaces,
            disks: disks,
            processes: processes
        )
    }
}
