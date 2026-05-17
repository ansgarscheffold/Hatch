# Hatch

**Hatch** is a native **SSH client for macOS** built with **SwiftUI**. It combines a server library, SSH key management, and a full **xterm-style terminal** (via embedded [XTerminalUI](https://github.com/Lakr233/XTerminalUI) / WebKit) backed by **[NSRemoteShell](Sources/NSRemoteShell)** (libssh2).

The idea behind Hatch is a **simple, native, and polished SSH server manager**: you **add your servers**, **keep them organized** in one place, and open a **full terminal session** right in the app—no detour through separate config files or extra tools for everyday work. The UI should feel at home on macOS while staying easy to use.

---

## Screenshots

![Hatch screenshot 1](screenshots/screen1.png)

![Hatch screenshot 2](screenshots/screen2.png)

![Hatch screenshot 3](screenshots/screen3.png)

![Hatch screenshot 4](screenshots/screen4.png)

![Hatch screenshot 5](screenshots/screen5.png)

---

## Requirements

- **macOS 13 (Ventura)** or later  
- **Xcode** / **Swift 5.7+** (Swift Package Manager)  
- Building **NSRemoteShell** may require **libssh2** prebuilt binaries—see [Sources/NSRemoteShell/README.md](Sources/NSRemoteShell/README.md) (`git submodule` / CSSH notes).

---

## What it’s useful for

| Use case | How Hatch helps |
|----------|------------------|
| **Homelab & VPS** | Save hosts, users, ports; connect from a sidebar or the menu bar. |
| **Key-based login** | Store keys in-app (encrypted); attach a key to each server; optional passphrase. |
| **Password login** | Passwords are **encrypted** in the local DB; decryption uses a key **protected in the Keychain**. |
| **Quick health checks** | Run **Ping** or **Traceroute** against a host from the server card (**Tools**). |
| **Daily terminal work** | Full interactive shell after connect; themes, fonts, scrollback. |
| **DE/EN UI** | Interface and menus follow **System**, **Deutsch**, or **English** (Preferences). |

---

## Features

### Connections & servers

- **Server profiles**: display name, host, port, username.  
- **Authentication**: password and/or **private key** (managed key or legacy file path).  
- **Overview**: card or list layout; **Recent** connections (by last used).  
- **Active connections** section in the sidebar.  
- **Connect / Disconnect / Reconnect**; status and error hints in the UI.  
- **“Delete all servers”** (with confirmation) for a clean slate.

### SSH keys (`Keys`)

- **Import** PEM/OpenSSH private keys or **generate** new keys with **`ssh-keygen`** (types: **ED25519**, **ECDSA** 256/384/521).  
- **Extract public key** from an existing private key.  
- **Copy** public key text for `~/.ssh/authorized_keys` on the server.  
- Private key material is stored **encrypted** in the local SQLite database; a **master key** is kept in the **macOS Keychain** (with a fallback path for unsigned debug builds—see app logs if relevant).

### Terminal

- **xterm**-compatible terminal via **XTerminalUI**; keyboard focus bridging so typing works reliably with SwiftUI sidebars.  
- **Themes**: Standard (follows window), Light, Dark.  
- **Font family** (e.g. Menlo, JetBrains Mono, Fira Code, …) and **font size**.  
- **Cursor styles** (blinking/steady bar, block, underline).  
- **Scroll buffer** size; option to **keep display active**.  
- Optional **OS detection** (remote `uname` / `/etc/os-release` heuristics) shown in the terminal context when enabled.

### Network tools

- From a server card, open **Tools** → **Ping** or **Traceroute** with parsed tables and raw output where applicable.

### macOS integration

- **Menu bar extra** (SF Symbol): quick list of servers; connect or jump to an active session; **Preferences** and **Quit**.  
- **Keyboard shortcuts** (examples):  
  - **⌘,** — Preferences  
  - **⇧⌘N** — Add Server  
  - **⇧⌘K** — New Key  
- **Unified window toolbar**; optional **status bar** (server counts) and **sidebar** visibility in Preferences.

### Data & security

- SQLite database under **Application Support** (`Hatch/servers.db`): server profiles and SSH keys.  
- **Keychain**: the **master encryption key** (256-bit) is stored in the **macOS Keychain** so the app can encrypt and decrypt secrets on this Mac.  
- **Encrypted database**: **passwords** and **private (and optional public) key PEM text** are written to SQLite **only after AES-GCM encryption**; they are not stored in plain text.  
- For SSH key auth, the app may write a **short-lived key file** with **0600**-style permissions for libssh2, then **delete** it after connecting.

### Preferences (overview)

Grouped settings for **General** (language, toggles such as launch-at-login and notifications—stored as user preferences), **View** (status bar, sidebar), **Terminal**, **Sessions** (e.g. OS detection, keep-alive option), and **Connection** (e.g. default port, connection timeout values in the UI).

---

## How to use

1. **Build and run** (see below), then open **Hatch**.  
2. **Add a server**: **File → Add Server** (or **⇧⌘N**), enter host, port, user, and choose **password** or **key** (pick a saved key or import). Save or **Save & Connect**.  
3. **Connect**: use **Connect** on a card/list row, or pick the server from the **menu bar** icon.  
4. **Terminal**: confirm opening the terminal when prompted; type as in any SSH session.  
5. **Keys**: sidebar **Keys** → **New Key** to generate or import; copy the **public** half to the remote `authorized_keys`.  
6. **Tools**: on a server card, use **Tools** for **Ping** / **Traceroute**.  
7. **Preferences**: **Hatch → Preferences** (**⌘,**) for language, terminal look & feel, and defaults.

---

## Build & run

From the repository root:

```bash
./build_and_run.sh              # Debug build, then open the app
./build_and_run.sh --release    # Release build
./build_and_run.sh --no-run     # Build only
./build_and_run.sh --foreground # Run in foreground (logs in Terminal)
```

Or manually:

```bash
swift build
swift run Hatch
```

Resolve **NSRemoteShell** / **libssh2** setup using [Sources/NSRemoteShell/README.md](Sources/NSRemoteShell/README.md) if the build fails on missing binaries.

### Dependencies (Swift Package)

- [GRDB.swift](https://github.com/groue/GRDB.swift) — SQLite  
- Local packages: **NSRemoteShell**, **XTerminalUI** under `Sources/`

---

## Project layout

| Path | Role |
|------|------|
| `Sources/Hatch/` | App entry (`HatchApp`), SwiftUI views, GRDB models, settings |
| `Sources/Hatch/Terminal/` | Terminal view + session bridge |
| `Sources/NSRemoteShell/` | SSH / libssh2 wrapper |
| `Sources/XTerminalUI/` | xterm front-end |

