import Foundation

struct DockerContainerStats: Equatable {
    var name: String
    var image: String?
    var cpuPercent: Double?
    var memoryPercent: Double?
    var memoryUsage: String?
    var networkIO: String?
    var blockIO: String?
}

enum DockerAvailability: Equatable {
    case unknown
    case notInstalled
    case notAccessible
    case available
}

struct DockerServerSnapshot: Equatable {
    var availability: DockerAvailability = .unknown
    var containers: [DockerContainerStats] = []
    var fetchedAt: Date = Date()
}

enum DockerFetchState: Equatable {
    case idle
    case loading
    case failed(String)
    case ready(DockerServerSnapshot)
}

enum DockerContainerCommand: String, Identifiable {
    case restart
    case stop
    case start

    var id: String { rawValue }

    var isDestructive: Bool {
        switch self {
        case .restart, .stop:
            return true
        case .start:
            return false
        }
    }

    var systemImage: String {
        switch self {
        case .restart: return "arrow.clockwise"
        case .stop: return "stop.fill"
        case .start: return "play.fill"
        }
    }

    var title: String {
        switch self {
        case .restart: return LocalizedStrings.dockerCommandRestart
        case .stop: return LocalizedStrings.dockerCommandStop
        case .start: return LocalizedStrings.dockerCommandStart
        }
    }

    func confirmMessage(containerName: String, serverName: String) -> String {
        switch self {
        case .restart:
            return LocalizedStrings.dockerCommandConfirmRestart(containerName, serverName)
        case .stop:
            return LocalizedStrings.dockerCommandConfirmStop(containerName, serverName)
        case .start:
            return LocalizedStrings.dockerCommandConfirmStart(containerName, serverName)
        }
    }

    func shellCommand(containerName: String) -> String {
        let escaped = Self.shellEscaped(containerName)
        switch self {
        case .restart:
            return """
            if ! command -v docker >/dev/null 2>&1; then
              echo "HATCH_ERR=Docker not installed"; exit 1
            fi
            if docker restart \(escaped) >/dev/null 2>&1; then
              echo "HATCH_OK=Container restarted"
            else
              echo "HATCH_ERR=Failed to restart container"
              exit 1
            fi
            """
        case .stop:
            return """
            if ! command -v docker >/dev/null 2>&1; then
              echo "HATCH_ERR=Docker not installed"; exit 1
            fi
            if docker stop \(escaped) >/dev/null 2>&1; then
              echo "HATCH_OK=Container stopped"
            else
              echo "HATCH_ERR=Failed to stop container"
              exit 1
            fi
            """
        case .start:
            return """
            if ! command -v docker >/dev/null 2>&1; then
              echo "HATCH_ERR=Docker not installed"; exit 1
            fi
            if docker start \(escaped) >/dev/null 2>&1; then
              echo "HATCH_OK=Container started"
            else
              echo "HATCH_ERR=Failed to start container"
              exit 1
            fi
            """
        }
    }

    private static func shellEscaped(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum DockerCollector {
    private static let listScript = """
    echo "HATCH_DOCKER_BEGIN"
    if command -v docker >/dev/null 2>&1; then
      if docker info >/dev/null 2>&1; then
        echo "HATCH_DOCKER_OK"
        echo "HATCH_DOCKER_IMAGES_BEGIN"
        docker ps --filter status=running --format '{{.Names}}|{{.Image}}' 2>/dev/null
        echo "HATCH_DOCKER_IMAGES_END"
        docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemPerc}}|{{.MemUsage}}|{{.NetIO}}|{{.BlockIO}}' 2>/dev/null
      else
        echo "HATCH_DOCKER_DENIED"
      fi
    else
      echo "HATCH_DOCKER_UNAVAILABLE"
    fi
    echo "HATCH_DOCKER_END"
    """

    static func fetch(
        host: String,
        port: Int,
        username: String,
        auth: ServerSSHAuth
    ) -> Result<DockerServerSnapshot, Error> {
        switch ServerSSHExecutor.run(
            host: host,
            port: port,
            username: username,
            auth: auth,
            command: listScript,
            timeout: 15
        ) {
        case .success(let output):
            return .success(parse(output: output))
        case .failure(let error):
            return .failure(error)
        }
    }

    static func run(
        command: DockerContainerCommand,
        containerName: String,
        host: String,
        port: Int,
        username: String,
        auth: ServerSSHAuth
    ) -> Result<String, Error> {
        ServerSSHExecutor.run(
            host: host,
            port: port,
            username: username,
            auth: auth,
            command: command.shellCommand(containerName: containerName),
            timeout: 20
        )
    }

    static func parse(output: String) -> DockerServerSnapshot {
        var imageByName: [String: String] = [:]
        var containerLines: [String] = []
        var availability: DockerAvailability = .unknown
        var inDockerSection = false
        var inImages = false
        var pastImages = false

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            switch trimmed {
            case "HATCH_DOCKER_BEGIN":
                inDockerSection = true
                inImages = false
                pastImages = false
            case "HATCH_DOCKER_IMAGES_BEGIN":
                inImages = true
            case "HATCH_DOCKER_IMAGES_END":
                inImages = false
                pastImages = true
            case "HATCH_DOCKER_OK":
                availability = .available
            case "HATCH_DOCKER_UNAVAILABLE":
                availability = .notInstalled
            case "HATCH_DOCKER_DENIED":
                availability = .notAccessible
            case "HATCH_DOCKER_END":
                inDockerSection = false
                inImages = false
                pastImages = false
            default:
                if inImages {
                    let parts = trimmed.split(separator: "|", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                        imageByName[parts[0]] = parts[1]
                    }
                } else if inDockerSection, pastImages, trimmed.contains("|") {
                    containerLines.append(trimmed)
                }
            }
        }

        if availability == .unknown, !containerLines.isEmpty {
            availability = .available
        }

        let containers = containerLines.compactMap { parseContainerLine($0, images: imageByName) }
        return DockerServerSnapshot(
            availability: availability,
            containers: containers,
            fetchedAt: Date()
        )
    }

    private static func parseContainerLine(_ line: String, images: [String: String]) -> DockerContainerStats? {
        let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 6 else { return nil }
        let name = parts[0]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !name.isEmpty else { return nil }

        return DockerContainerStats(
            name: name,
            image: images[name],
            cpuPercent: parsePercent(parts[1]),
            memoryPercent: parsePercent(parts[2]),
            memoryUsage: parts[3].isEmpty ? nil : parts[3],
            networkIO: parts[4].isEmpty ? nil : parts[4],
            blockIO: parts[5].isEmpty ? nil : parts[5]
        )
    }

    private static func parsePercent(_ raw: String) -> Double? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "%", with: "")
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }
}

struct DockerCommandRequest: Identifiable {
    let id = UUID()
    let server: Server
    let containerName: String
    let command: DockerContainerCommand
}

struct DockerCommandResult: Identifiable {
    let id = UUID()
    let server: Server
    let containerName: String
    let command: DockerContainerCommand
    let success: Bool
    let message: String
}
