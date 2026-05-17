import AppKit
import SwiftUI

struct MenuBarExtraRootView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private var sortedServers: [Server] {
        viewModel.servers.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var body: some View {
        if sortedServers.isEmpty {
            Button(LocalizedStrings.noServersInMenu) {}
                .disabled(true)
        } else {
            ForEach(sortedServers) { server in
                Button {
                    viewModel.connectOrFocusFromMenuBar(to: server)
                    Self.activateMainWindow()
                } label: {
                    if viewModel.connectedServers[server.id]?.isConnected == true {
                        Label(server.displayName, systemImage: "checkmark.circle.fill")
                    } else {
                        Text(server.displayName)
                    }
                }
            }
        }

        Divider()

        Button(LocalizedStrings.preferences + "...") {
            HatchApp.openSettingsWindow()
        }

        Button(LocalizedStrings.quitApplication(HatchApp.bundleDisplayName)) {
            NSApp.terminate(nil)
        }
    }

    private static func activateMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.level == .normal && $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
