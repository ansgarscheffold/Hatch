import AppKit

/// Rendert `Logo.svg` für Dock- und App-Icon (Finder, About-Panel).
enum HatchBrandIcon {
    static let resourceName = "Logo"

    static func logoURL(bundle: Bundle = .module) -> URL? {
        if let url = bundle.url(forResource: resourceName, withExtension: "svg", subdirectory: "Resources") {
            return url
        }
        return bundle.url(forResource: resourceName, withExtension: "svg")
    }

    static func makeImage(pixelSize: CGFloat, logoURL: URL? = nil) -> NSImage? {
        let url = logoURL ?? Self.logoURL()
        guard let url, let source = NSImage(contentsOf: url) else { return nil }

        let canvas = NSSize(width: pixelSize, height: pixelSize)
        let image = NSImage(size: canvas, flipped: false) { bounds in
            NSColor.clear.set()
            NSBezierPath(rect: bounds).fill()

            source.size = bounds.size
            NSGraphicsContext.current?.imageInterpolation = .high
            source.draw(
                in: bounds,
                from: NSRect(origin: .zero, size: source.size),
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
        image.isTemplate = false
        return image
    }

    static func dockImage() -> NSImage? {
        makeImage(pixelSize: 512)
    }
}
