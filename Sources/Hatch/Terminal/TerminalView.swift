import SwiftUI
import XTerminalUI
import NSRemoteShell
import WebKit
import AppKit

// Custom shape for rounded corner only on bottom-right
struct BottomRightRoundedRectangle: Shape {
    var cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start from top-left (sharp corner)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Top edge to top-right (sharp corner)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Right edge to bottom-right (before rounded corner)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        
        // Bottom-right rounded corner using arc
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        
        // Bottom edge to bottom-left (sharp corner)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        // Left edge back to start (sharp corner)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        path.closeSubpath()
        return path
    }
}

/// Wenn die Sidebar (NSTableView etc.) den First Responder hält, erreichen Tasten die WKWebView nicht —
/// wir leiten keyDown explizit an die WebView weiter (WebKit verarbeitet das im Inhalt).
final class TerminalKeyboardBridge: ObservableObject {
    private var monitor: Any?
    private weak var webView: WKWebView?

    func activate(webView: WKWebView, isTerminalActive: @escaping () -> Bool) {
        deactivate()
        self.webView = webView
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  isTerminalActive(),
                  let wv = self.webView,
                  let myWindow = wv.window
            else { return event }
            // SwiftUI liefert keyDown oft mit event.window == nil; dann würde die Bridge nie greifen.
            guard myWindow.isKeyWindow else { return event }
            if let ew = event.window, ew !== myWindow {
                return event
            }
            if Self.isFirstResponderRelated(to: wv, window: myWindow) {
                return event
            }
            if Self.windowHasNativeTextEditingFocus(myWindow) {
                return event
            }
            // Anderer Tab / andere WKWebView im gleichen Fenster hat Fokus — nicht umhängen.
            if let focusedWK = Self.enclosingWKWebView(startingFrom: myWindow.firstResponder), focusedWK !== wv {
                return event
            }
            myWindow.makeFirstResponder(wv)
            // Synchron: async kann Events unter WebKit verlieren; der Monitor läuft ohnehin auf dem Main-Thread.
            wv.keyDown(with: event)
            return nil
        }
    }

    func deactivate() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        webView = nil
    }

    deinit { deactivate() }

    /// True, wenn der First Responder die WebView selbst ist oder eine View **in** der WebView-Hierarchie (laut AppKit).
    /// Nicht true, wenn nur der Container (`XTerminalView`) den Fokus hat — der leitet `keyDown` nicht weiter; dann
    /// muss die Bridge `makeFirstResponder` + `keyDown` ausführen.
    static func isFirstResponderRelated(to webView: WKWebView, window: NSWindow) -> Bool {
        guard let frView = window.firstResponder as? NSView else {
            return window.firstResponder === webView
        }
        return frView.isDescendant(of: webView)
    }

    private static func windowHasNativeTextEditingFocus(_ window: NSWindow) -> Bool {
        guard let fr = window.firstResponder else { return false }
        var c: AnyClass? = type(of: fr)
        while let cls = c {
            let n = NSStringFromClass(cls)
            if n.contains("NSTextView") || n.contains("NSTextField") || n.contains("NSSearchField") {
                return true
            }
            c = cls.superclass()
        }
        return false
    }

    /// Liefert die WKWebView, in deren View-Hierarchie der First Responder liegt (sonst nil).
    private static func enclosingWKWebView(startingFrom responder: NSResponder?) -> WKWebView? {
        var view: NSView? = responder as? NSView
        while let v = view {
            if let wk = v as? WKWebView {
                return wk
            }
            view = v.superview
        }
        return nil
    }
}

final class TerminalSession: ObservableObject {
    @Published var status: String = "idle"

    let terminalView = STerminalView()
    private var shell: NSRemoteShell = .init()
    private var writeBuffer: String = ""
    private let bufferLock = NSLock()

    func start(host: String, port: Int, username: String, password: String?) {
        status = "connecting"
        terminalView
            .setupBellChain {
                // bell
            }
            .setupBufferChain { [weak self] buffer in
                guard let self = self else { return }
                self.bufferLock.lock()
                self.writeBuffer += buffer
                self.bufferLock.unlock()
                self.shell.explicitRequestStatusPickup()
            }
            .setupTitleChain { _ in }
            .setupSizeChain { _ in }

        DispatchQueue.global(qos: .userInitiated).async {
            self.shell.setupConnectionHost(host)
                .setupConnectionPort(NSNumber(value: port))
                .setupConnectionTimeout(NSNumber(value: 10))
                .requestConnectAndWait()

            guard self.shell.isConnected else {
                DispatchQueue.main.async { self.status = "connect failed" }
                return
            }

            if let pwd = password {
                self.shell.authenticate(with: username, andPassword: pwd)
            } else {
                self.shell.authenticate(with: username, andPassword: "")
            }

            guard self.shell.isConnected, self.shell.isAuthenticated else {
                DispatchQueue.main.async { self.status = "auth failed" }
                return
            }

            DispatchQueue.main.async { self.status = "connected" }

            self.shell.begin(withTerminalType: "xterm",
                withOnCreate: {
                    // noop
                },
                withTerminalSize: { [weak self] in
                    // query terminal size
                    if let size = self?.terminalView.requestTerminalSize() {
                        return size
                    }
                    return CGSize(width: 80, height: 24)
                },
                withWriteDataBuffer: { [weak self] in
                    guard let self = self else { return "" }
                    self.bufferLock.lock()
                    let copy = self.writeBuffer
                    self.writeBuffer = ""
                    self.bufferLock.unlock()
                    return copy
                },
                withOutputDataBuffer: { [weak self] output in
                    guard let self = self else { return }
                    let sem = DispatchSemaphore(value: 0)
                    DispatchQueue.main.async {
                        self.terminalView.write(output)
                        sem.signal()
                    }
                    sem.wait()
                },
                withContinuationHandler: { true }
            )

            DispatchQueue.main.async {
                self.status = "shell closed"
            }
        }
    }

    func stop() {
        shell.requestDisconnectAndWait()
        status = "disconnected"
    }
}

struct TerminalView: View {
    @ObservedObject var manager: ConnectionManager
    /// Pro Server in `AppViewModel.terminalHolders` — muss `@ObservedObject` sein, damit beim Tab-Wechsel
    /// nicht der erste `StateObject`-Holder hängen bleibt (sonst zeigen alle Server dieselbe WebView).
    @ObservedObject var terminalHolder: TerminalHolder
    @ObservedObject private var settings = AppSettings.shared

    init(manager: ConnectionManager, holder: TerminalHolder) {
        self.manager = manager
        self.terminalHolder = holder
    }

    var body: some View {
        TerminalViewInternal(manager: manager, terminalHolder: terminalHolder)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(1)
            .background(Color(settings.terminalTheme.backgroundColor))
            .clipShape(BottomRightRoundedRectangle(cornerRadius: 4))
    }
}

struct TerminalViewInternal: View {
    @ObservedObject var manager: ConnectionManager
    @ObservedObject var terminalHolder: TerminalHolder
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var keyboardBridge = TerminalKeyboardBridge()
    @State private var lastTerminalFocusAt: Date = .distantPast
    /// Terminal-Tab ist sichtbar (onAppear/onDisappear) — Bridge darf nur dann Tasten umleiten.
    @State private var isTerminalVisible = false

    /// Immer die WebView dieser Terminal-Instanz — nie die erste beliebige WKWebView im App-Fenster.
    private var terminalWKWebView: WKWebView {
        terminalHolder.view.terminalWebView
    }

    var body: some View {
        terminalHolder.view
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .background(Color(settings.terminalTheme.backgroundColor))
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        restoreTerminalInput(forceFocus: true)
                    }
                )
                .onAppear {
                        isTerminalVisible = true
                        terminalHolder.isViewVisible = true
                        if !terminalHolder.isInitialized {
                            setupTerminal()
                            terminalHolder.isInitialized = true
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            setTerminalTheme()
                        }

                        if manager.isConnected {
                            DispatchQueue.main.async {
                                restoreTerminalInput(forceFocus: true)
                            }
                        }
                    }
                    .onChange(of: manager.isConnected) { connected in
                        if connected {
                            DispatchQueue.main.async {
                                restoreTerminalInput(forceFocus: true)
                            }
                        } else {
                            keyboardBridge.deactivate()
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
                        guard isTerminalVisible,
                              manager.isConnected,
                              let win = notification.object as? NSWindow,
                              win === terminalWKWebView.window
                        else { return }
                        DispatchQueue.main.async {
                            restoreTerminalInput(forceFocus: false)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .terminalWebViewDidAttachToWindow)) { notification in
                        guard isTerminalVisible,
                              manager.isConnected,
                              let attached = notification.object as? WKWebView,
                              attached === terminalWKWebView
                        else { return }
                        DispatchQueue.main.async {
                            restoreTerminalInput(forceFocus: true)
                        }
                    }
                    .onDisappear {
                        isTerminalVisible = false
                        terminalHolder.isViewVisible = false
                        keyboardBridge.deactivate()
                    }
                    .onChange(of: settings.terminalTheme) { _ in
                        // Update theme immediately when settings change
                        // Try immediately first, then retry if needed
                        if !setTerminalThemeInternal() {
                            setTerminalThemeWithRetry(maxRetries: 3, delay: 0.1)
                        }
                    }
                    .onChange(of: colorScheme) { _ in
                        setTerminalTheme()
                    }
                    .onChange(of: settings.terminalFontSize) { newSize in
                        // Update font size via JavaScript once the terminal is ready
                        updateTerminalSetting("fontSize", value: String(newSize))
                    }
                    .onChange(of: settings.terminalFontFamily) { newFamily in
                        // Update font family via JavaScript
                        updateTerminalSetting("fontFamily", value: newFamily.cssFontFamily)
                    }
                    .onChange(of: settings.terminalCursorStyle) { newStyle in
                        // Update cursor style via JavaScript
                        applyCursorStyle(newStyle)
                    }
                    .onChange(of: settings.terminalScrollBufferSize) { newSize in
                        // Update scroll buffer size via JavaScript
                        updateTerminalSetting("scrollback", value: String(newSize))
                    }
                    .onChange(of: settings.terminalKeepDisplayActive) { _ in
                        forceEnableStdin()
                    }
    }

    private func setupTerminal() {
        // Setup terminal with SSH shell
        terminalHolder.view
            .setupBufferChain { buffer in
                // Handle user input from terminal
                manager.appendToInputBuffer(buffer)
            }
            .setupTitleChain { title in
                print("Terminal title: \(title)")
            }
            .setupBellChain {
                // Bell notification
                NSSound.beep()
            }
            .setupSizeChain { size in
                print("Terminal size: \(size)")
            }

        // Apply initial JS settings only after the embedded xterm is really ready
        waitForTerminalReady {
            injectEmbeddedFontsIfNeeded()
            applyInitialTerminalSettings()
            // When the terminal is ready and the connection is up, ensure focus and input are enabled
            if manager.isConnected {
                forceEnableStdin()
                focusTerminal(force: true)
            }
        }

        // Do not start interactive shell here — wait until manager reports connected.
    }
    
    private func setTerminalTheme() {
        // Try to set terminal theme based on user settings
        _ = setTerminalThemeInternal()
    }
    
    private func setTerminalThemeInternal() -> Bool {
        let webView = terminalWKWebView
        
        let bgColor = settings.terminalTheme.backgroundColor
        let textColor = settings.terminalTheme.textColor
        
        // Convert color to RGB colorspace if needed
        let rgbColor = bgColor.usingColorSpace(.deviceRGB) ?? bgColor
        
        let red = Int(rgbColor.redComponent * 255)
        let green = Int(rgbColor.greenComponent * 255)
        let blue = Int(rgbColor.blueComponent * 255)
        let hexBgColor = String(format: "#%02X%02X%02X", red, green, blue)
        
        // Set terminal theme via JavaScript (xterm CSS defaults to #000 viewport — override via injected style)
        let js = """
        (function() {
            try {
                var bg = '\(hexBgColor)';
                var fg = '\(textColor)';
                var style = document.getElementById('hatch-terminal-theme');
                if (!style) {
                    style = document.createElement('style');
                    style.id = 'hatch-terminal-theme';
                    document.head.appendChild(style);
                }
                style.textContent = [
                    'html, body, #root { background: ' + bg + ' !important; }',
                    '.xterm .xterm-viewport { background-color: ' + bg + ' !important; }',
                    '.xterm .composition-view { background: ' + bg + ' !important; color: ' + fg + ' !important; }'
                ].join('\\n');
                if (!window.term || !window.term.options) {
                    console.warn('setTerminalTheme: term/options not ready');
                    return;
                }
                var theme = {
                    background: bg,
                    foreground: fg,
                    cursor: fg,
                    cursorAccent: bg
                };
                window.term.options.theme = theme;
                if (typeof window.term.setOption === 'function') {
                    window.term.setOption('theme', theme);
                }
                window.term.refresh(0, window.term.rows - 1);
            } catch (e) {
                console.error('setTerminalTheme failed:', e);
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: { _, error in
            if let error = error {
                print("Failed to set terminal theme: \(error)")
            } else {
                print("Terminal theme set: \(settings.terminalTheme.rawValue), background=\(hexBgColor), foreground=\(textColor)")
            }
        })
        return true
    }
    
    private func updateTerminalSetting(_ setting: String, value: String) {
        // Update terminal setting via JavaScript
        _ = setTerminalSettingInternal(setting: setting, value: value)
    }

    /// Tastatur-Bridge, stdin und Fokus nach Tab-Wechsel oder erneutem Einblenden wiederherstellen.
    private func restoreTerminalInput(forceFocus: Bool) {
        guard manager.isConnected, isTerminalVisible else { return }
        manager.startInteractiveShell(with: terminalHolder.view)
        forceEnableStdin()
        keyboardBridge.activate(webView: terminalWKWebView) { [weak terminalHolder] in
            guard let terminalHolder else { return false }
            return manager.isConnected && terminalHolder.isViewVisible
        }
        focusTerminal(force: forceFocus)
    }

    private func setTerminalSettingInternal(setting: String, value: String) -> Bool {
        let webView = terminalWKWebView

        // Prepare a JS-safe representation of the value.
        // For numeric settings like scrollback we pass the raw value,
        // for boolean options we must emit JS booleans (string "false" is truthy in JS).
        // For others we serialize the string to a JSON string literal so
        // embedded quotes (e.g. "'Menlo', monospace") are correctly escaped.
        let jsValue: String
        if setting == "scrollback" || setting == "fontSize" {
            jsValue = value
        } else if value == "true" || value == "false" {
            jsValue = value
        } else if let data = try? JSONEncoder().encode(value),
                  let jsonString = String(data: data, encoding: .utf8) {
            // jsonString is a properly quoted JS string literal, e.g. "\"'Menlo', monospace\""
            jsValue = jsonString
        } else {
            // Fallback: escape single quotes and wrap
            let escaped = value.replacingOccurrences(of: "'", with: "\\'")
            jsValue = "'\(escaped)'"
        }

        // Set terminal setting via JavaScript
        let js = """
        (function() {
            try {
                if (!window.term || !window.term.options) {
                    console.warn('setTerminalSetting: term/options not ready');
                    return;
                }
                window.term.options.\(setting) = \(jsValue);
                window.term.refresh(0, window.term.rows - 1);
            } catch (e) {
                console.error('setTerminalSetting failed:', e);
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: { _, error in
            if let error = error {
                print("Failed to set terminal \(setting): \(error)")
            } else {
                print("Terminal \(setting) set to: \(value)")
            }
        })
        return true
    }

    private func setTerminalThemeWithRetry(maxRetries: Int, delay: TimeInterval) {
        var retryCount = 0
        
        func attempt() {
            if setTerminalThemeInternal() {
                // Success
                return
            }
            
            retryCount += 1
            if retryCount < maxRetries {
                // Increase delay with each retry
                let currentDelay = delay * Double(retryCount)
                DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
                    attempt()
                }
            } else {
                print("Failed to set terminal theme after \(maxRetries) attempts")
            }
        }
        
        attempt()
    }

    private func focusTerminal(force: Bool = false) {
        let now = Date()
        if !force, now.timeIntervalSince(lastTerminalFocusAt) < 0.4 { return }
        lastTerminalFocusAt = now
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.focusTerminalInternal(retryCount: 0, maxRetries: 10)
        }
    }

    private func focusTerminalInternal(retryCount: Int, maxRetries: Int) {
        let webView = terminalWKWebView
        guard let window = webView.window else {
            print("TerminalView: WebView noch ohne Fenster (attempt \(retryCount + 1)/\(maxRetries))")
            if retryCount < maxRetries {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.focusTerminalInternal(retryCount: retryCount + 1, maxRetries: maxRetries)
                }
            }
            return
        }

        if !TerminalKeyboardBridge.isFirstResponderRelated(to: webView, window: window) {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(webView)
        }

        let js = """
        if (window.term) {
            try {
                window.term.options.disableStdin = false;
                window.term.focus();
                if (window.term.textarea) {
                    window.term.textarea.focus();
                }
            } catch(e) {
                console.error('Failed to focus terminal:', e);
            }
        }
        """

        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("TerminalView: JavaScript focus error: \(error)")
            }
        }
    }

    private func forceEnableStdin() {
        let webView = terminalWKWebView
        let js = """
        (function() {
            try {
                if (window.term && window.term.options) {
                    window.term.options.disableStdin = false;
                    if (window.term.textarea) { window.term.textarea.removeAttribute('readonly'); }
                    console.log('forceEnableStdin: disableStdin=' + window.term.options.disableStdin);
                }
            } catch (e) {
                console.error('forceEnableStdin failed:', e);
            }
        })();
        """
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("forceEnableStdin JS error: \(error)")
            }
        }
    }

    private func waitForTerminalReady(maxRetries: Int = 20, delay: TimeInterval = 0.2, onReady: @escaping () -> Void) {
        waitForTerminalReady(attempt: 0, maxRetries: maxRetries, delay: delay, onReady: onReady)
    }

    private func waitForTerminalReady(attempt: Int, maxRetries: Int, delay: TimeInterval, onReady: @escaping () -> Void) {
        let webView = terminalWKWebView

        let readyJS = """
        (function() {
            try {
                return !!(window.term && window.term.options);
            } catch (e) {
                return false;
            }
        })();
        """

        webView.evaluateJavaScript(readyJS) { result, error in
            if let ready = result as? Bool, ready {
                onReady()
            } else if attempt < maxRetries {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.waitForTerminalReady(attempt: attempt + 1, maxRetries: maxRetries, delay: delay, onReady: onReady)
                }
            } else {
                print("TerminalView: terminal JS not ready after \(maxRetries) attempts")
                if let error = error {
                    print("TerminalView: readiness check error: \(error)")
                }
            }
        }
    }

    private func applyInitialTerminalSettings() {
        let settings = AppSettings.shared
        updateTerminalSetting("fontSize", value: String(settings.terminalFontSize))
        updateTerminalSetting("fontFamily", value: settings.terminalFontFamily.cssFontFamily)
        applyCursorStyle(settings.terminalCursorStyle)
        updateTerminalSetting("scrollback", value: String(settings.terminalScrollBufferSize))
        forceEnableStdin()
        setTerminalTheme()
    }

    private func applyCursorStyle(_ style: TerminalCursorStyle) {
        let webView = terminalWKWebView
        let mapping = cursorStyleMapping(style)
        let js = """
        (function() {
            try {
                if (!window.term || !window.term.options) {
                    console.warn('cursorStyle: term/options not ready');
                    return;
                }
                window.term.options.cursorStyle = '\(mapping.style)';
                window.term.options.cursorBlink = \(mapping.blink ? "true" : "false");
                window.term.refresh(0, window.term.rows - 1);
            } catch (e) {
                console.error('cursorStyle failed:', e);
            }
        })();
        """
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("Failed to set cursor style: \(error)")
            } else {
                print("Terminal cursor style set: \(style.rawValue) -> style=\(mapping.style), blink=\(mapping.blink)")
            }
        }
    }

    private func cursorStyleMapping(_ style: TerminalCursorStyle) -> (style: String, blink: Bool) {
        switch style {
        case .blinkBar:
            return ("bar", true)
        case .blinkBlock:
            return ("block", true)
        case .steadyBlock:
            return ("block", false)
        case .blinkUnderline:
            return ("underline", true)
        case .steadyUnderline:
            return ("underline", false)
        case .steadyBar:
            return ("bar", false)
        }
    }

    private func injectEmbeddedFontsIfNeeded() {
        guard !terminalHolder.fontsInjected else { return }
        terminalHolder.fontsInjected = true
        injectEmbeddedFonts()
    }

    private func injectEmbeddedFonts() {
        let webView = terminalWKWebView

        let fonts = embeddedFonts()
        var cssParts: [String] = []

        for font in fonts {
            guard let data = loadFontData(named: font.fileName, ext: font.ext) else {
                print("TerminalView: Font-Datei nicht gefunden: \(font.fileName).\(font.ext)")
                continue
            }
            let base64 = data.base64EncodedString()
            let css = """
            @font-face {
                font-family: '\(font.cssName)';
                src: url(data:\(font.mime);base64,\(base64)) format('\(font.format)');
                font-weight: 400;
                font-style: normal;
                font-display: swap;
            }
            """
            cssParts.append(css)
        }

        let cssString = cssParts.joined(separator: "\n")
        guard let cssData = try? JSONEncoder().encode(cssString),
              let cssLiteral = String(data: cssData, encoding: .utf8) else {
            print("TerminalView: CSS-Encoding für eingebettete Fonts fehlgeschlagen")
            return
        }

        let js = """
        (function() {
            try {
                var css = \(cssLiteral);
                var styleId = 'xterm-embedded-fonts';
                var style = document.getElementById(styleId);
                if (!style) {
                    style = document.createElement('style');
                    style.id = styleId;
                    document.head.appendChild(style);
                }
                style.textContent = css;
            } catch (e) {
                console.error('injectEmbeddedFonts failed:', e);
            }
        })();
        """

        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("TerminalView: Font-Injektion fehlgeschlagen: \(error)")
            } else {
                print("TerminalView: Eingebettete Terminal-Fonts injiziert")
            }
        }
    }

    private func loadFontData(named name: String, ext: String) -> Data? {
        let bundle = Bundle.module
        if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources/Fonts") {
            return try? Data(contentsOf: url)
        }
        if let url = bundle.url(forResource: name, withExtension: ext) {
            return try? Data(contentsOf: url)
        }
        return nil
    }

    private struct EmbeddedFont {
        let cssName: String
        let fileName: String
        let ext: String
        let mime: String
        let format: String
    }

    private func embeddedFonts() -> [EmbeddedFont] {
        return [
            EmbeddedFont(cssName: "Cascadia Code", fileName: "CascadiaCode", ext: "woff2", mime: "font/woff2", format: "woff2"),
            EmbeddedFont(cssName: "Fira Code", fileName: "FiraCode-Regular", ext: "woff2", mime: "font/woff2", format: "woff2"),
            EmbeddedFont(cssName: "JetBrains Mono", fileName: "JetBrainsMono-Regular", ext: "woff2", mime: "font/woff2", format: "woff2"),
            EmbeddedFont(cssName: "Source Code Pro", fileName: "SourceCodePro-Regular", ext: "ttf", mime: "font/ttf", format: "truetype"),
            EmbeddedFont(cssName: "Ubuntu Mono", fileName: "UbuntuMono-Regular", ext: "ttf", mime: "font/ttf", format: "truetype")
        ]
    }
}

class TerminalHolder: ObservableObject {
    let view = STerminalView()
    var isInitialized = false
    var fontsInjected = false
    /// Wird von TerminalViewInternal gesetzt — Keyboard-Bridge liest den Live-Wert.
    var isViewVisible = false
}

struct TerminalView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalView(manager: ConnectionManager(), holder: TerminalHolder())
    }
}


