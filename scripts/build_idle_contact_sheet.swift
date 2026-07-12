#!/usr/bin/env swift
import AppKit

guard CommandLine.arguments.count == 3 else {
    fputs("usage: build_idle_contact_sheet.swift INPUT_DIR OUTPUT_PNG\n", stderr)
    exit(2)
}

let input = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let cell = NSSize(width: 256, height: 256)
let canvas = NSImage(size: NSSize(width: cell.width * 4, height: cell.height * 2))
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvas.size.width),
    pixelsHigh: Int(canvas.size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap)
else { exit(4) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
NSRect(origin: .zero, size: canvas.size).fill()

for index in 0..<8 {
    let name = String(format: "frame-%03d.png", index)
    guard let image = NSImage(contentsOf: input.appending(path: name)) else {
        fputs("missing \(name)\n", stderr)
        exit(3)
    }
    let column = index % 4
    let row = 1 - index / 4
    image.draw(
        in: NSRect(
            x: CGFloat(column) * cell.width,
            y: CGFloat(row) * cell.height,
            width: cell.width,
            height: cell.height
        ),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
}
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:])
else { exit(4) }
try png.write(to: output)
