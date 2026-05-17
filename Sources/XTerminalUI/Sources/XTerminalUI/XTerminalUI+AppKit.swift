//
//  XTerminalUI+AppKit.swift
//
//
//  Created by Lakr Aream on 2022/2/6.
//

import Foundation

#if canImport(AppKit)
    import AppKit
    import WebKit

    public class XTerminalView: NSView, XTerminal {
        private let associatedCore = XTerminalCore()
        private var lastFittedBoundsSize: CGSize = .zero

        public required init() {
            super.init(frame: CGRect())
            addSubview(associatedCore.associatedWebView)
            associatedCore.associatedWebView.bindFrameToSuperviewBounds()
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("unavailable")
        }

        public override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            NotificationCenter.default.post(
                name: .terminalWebViewDidAttachToWindow,
                object: associatedCore.associatedWebView
            )
        }

        /// SwiftUI/NSHostingView setzt oft den Container als First Responder; Tastatur muss zur WKWebView.
        public override var acceptsFirstResponder: Bool { true }

        public override func becomeFirstResponder() -> Bool {
            guard let win = window else { return false }
            return win.makeFirstResponder(associatedCore.associatedWebView)
        }

        public override func layout() {
            super.layout()
            let size = bounds.size
            guard size.width > 1, size.height > 1 else { return }
            if abs(size.width - lastFittedBoundsSize.width) > 0.5
                || abs(size.height - lastFittedBoundsSize.height) > 0.5
            {
                lastFittedBoundsSize = size
                associatedCore.fitToHostView()
            }
        }

        public func fitToHostView() {
            associatedCore.fitToHostView()
        }

        @discardableResult
        public func setupBufferChain(callback: ((String) -> Void)?) -> Self {
            associatedCore.setupBufferChain(callback: callback)
            return self
        }

        @discardableResult
        public func setupTitleChain(callback: ((String) -> Void)?) -> Self {
            associatedCore.setupTitleChain(callback: callback)
            return self
        }

        @discardableResult
        public func setupBellChain(callback: (() -> Void)?) -> Self {
            associatedCore.setupBellChain(callback: callback)
            return self
        }

        @discardableResult
        public func setupSizeChain(callback: ((CGSize) -> Void)?) -> Self {
            associatedCore.setupSizeChain(callback: callback)
            return self
        }

        public func write(_ str: String) {
            associatedCore.write(str)
        }

        public func setTerminalFontSize(with size: Int) {
            associatedCore.setTerminalFontSize(with: size)
        }

        public func requestTerminalSize() -> CGSize {
            associatedCore.requestTerminalSize()
        }

        /// Die eingebettete WebView — für gezieltes First-Responder / Fokus (nicht global suchen).
        public var terminalWebView: WKWebView {
            associatedCore.associatedWebView
        }
    }

    public extension Notification.Name {
        static let terminalWebViewDidAttachToWindow = Notification.Name("terminalWebViewDidAttachToWindow")
    }

    extension NSView {
        /// Adds constraints to this `NSView` instances `superview` object to make sure this always has the same size as the superview.
        /// Please note that this has no effect if its `superview` is `nil` – add this `UIView` instance as a subview before calling this.
        func bindFrameToSuperviewBounds() {
            guard let superview = superview else {
                print("Error! `superview` was nil – call `addSubview(view: UIView)` before calling `bindFrameToSuperviewBounds()` to fix this.")
                return
            }

            translatesAutoresizingMaskIntoConstraints = false
            topAnchor.constraint(equalTo: superview.topAnchor, constant: 0).isActive = true
            bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: 0).isActive = true
            leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: 0).isActive = true
            trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: 0).isActive = true
        }
    }

#endif
