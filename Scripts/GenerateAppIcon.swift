import AppKit

private func makeIcon(from logoURL: URL, pixelSize: CGFloat) -> NSImage? {
    guard let source = NSImage(contentsOf: logoURL) else { return nil }

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

private func savePNG(_ image: NSImage, path: String) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else {
        throw NSError(domain: "GenerateAppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "tiff"])
    }
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "GenerateAppIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "png"])
    }
    try data.write(to: URL(fileURLWithPath: path))
}

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: GenerateAppIcon <out.png> [logo.svg]\n".utf8))
    exit(64)
}

autoreleasepool {
    _ = NSApplication.shared
    NSApplication.shared.setActivationPolicy(.prohibited)

    let outPath = CommandLine.arguments[1]
    let logoPath = CommandLine.arguments.count >= 3
        ? CommandLine.arguments[2]
        : "Sources/Hatch/Resources/Logo.svg"

    let logoURL = URL(fileURLWithPath: logoPath)
    guard FileManager.default.fileExists(atPath: logoURL.path) else {
        FileHandle.standardError.write(Data("logo not found: \(logoURL.path)\n".utf8))
        exit(1)
    }

    guard let image = makeIcon(from: logoURL, pixelSize: 1024) else {
        FileHandle.standardError.write(Data("failed to render logo\n".utf8))
        exit(1)
    }
    do {
        try savePNG(image, path: outPath)
    } catch {
        FileHandle.standardError.write(Data("\(error)\n".utf8))
        exit(1)
    }
}
