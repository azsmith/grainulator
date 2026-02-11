#!/usr/bin/env swift

import Cocoa
import CoreGraphics
import Foundation

// MARK: - Seeded PRNG (deterministic results)

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

func seededRandom(rng: inout SeededRNG, min: CGFloat = 0, max: CGFloat = 1) -> CGFloat {
    let val = CGFloat(rng.next() % 10000) / 10000.0
    return min + val * (max - min)
}

// MARK: - Icon Generator

func generateIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let scale = s / 1024.0

    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        fatalError("Could not get CGContext")
    }

    let center = CGPoint(x: s / 2, y: s / 2)
    let radius = s / 2

    // --- Background: dark circular icon ---
    let iconRect = CGRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.22
    let bgPath = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    // Deep dark background gradient (radial)
    let bgColorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(colorSpace: bgColorSpace, components: [0.12, 0.10, 0.22, 1.0])!,
        CGColor(colorSpace: bgColorSpace, components: [0.06, 0.05, 0.12, 1.0])!,
    ]
    if let bgGradient = CGGradient(colorsSpace: bgColorSpace, colors: bgColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(bgGradient,
                               startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: radius,
                               options: [.drawsAfterEndLocation])
    }

    // --- Subtle grid pattern in background ---
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(colorSpace: bgColorSpace, components: [0.15, 0.13, 0.25, 0.3])!)
    ctx.setLineWidth(0.5 * scale)
    let gridSpacing = 32.0 * scale
    var gx = gridSpacing
    while gx < s {
        ctx.move(to: CGPoint(x: gx, y: 0))
        ctx.addLine(to: CGPoint(x: gx, y: s))
        ctx.move(to: CGPoint(x: 0, y: gx))
        ctx.addLine(to: CGPoint(x: s, y: gx))
        gx += gridSpacing
    }
    ctx.strokePath()
    ctx.restoreGState()

    // --- Central glow ring ---
    ctx.saveGState()
    let ringRadius = s * 0.30
    let glowColors = [
        CGColor(colorSpace: bgColorSpace, components: [1.0, 0.55, 0.0, 0.0])!,
        CGColor(colorSpace: bgColorSpace, components: [1.0, 0.55, 0.0, 0.15])!,
        CGColor(colorSpace: bgColorSpace, components: [1.0, 0.55, 0.0, 0.0])!,
    ]
    if let glowGrad = CGGradient(colorsSpace: bgColorSpace, colors: glowColors as CFArray, locations: [0.0, 0.5, 1.0]) {
        ctx.drawRadialGradient(glowGrad,
                               startCenter: center, startRadius: ringRadius * 0.6,
                               endCenter: center, endRadius: ringRadius * 1.8,
                               options: [])
    }
    ctx.restoreGState()

    // --- Grain particles emanating from center ---
    let particleLayers: [(countBase: Int, minR: CGFloat, maxR: CGFloat, minSize: CGFloat, maxSize: CGFloat, baseAlpha: CGFloat)] = [
        (180, 0.08, 0.22, 1.5, 4.0, 0.9),
        (140, 0.18, 0.35, 2.0, 6.0, 0.7),
        (100, 0.30, 0.44, 1.5, 4.5, 0.5),
        (60,  0.40, 0.48, 1.0, 3.0, 0.3),
    ]

    let particleColors: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
        (1.0, 0.55, 0.0),    // #FF8C00 dark orange
        (1.0, 0.65, 0.0),    // #FFA500 orange
        (1.0, 0.75, 0.2),    // warm yellow-orange
        (1.0, 0.45, 0.1),    // deeper orange
        (0.0, 0.83, 0.67),   // #00D4AA teal accent
        (0.0, 0.75, 0.85),   // cyan accent
    ]

    var rng = SeededRNG(seed: 42)

    for layer in particleLayers {
        let count = Int(CGFloat(layer.countBase) * Swift.max(scale, 0.3))
        for _ in 0..<count {
            let angle = seededRandom(rng: &rng, min: 0, max: CGFloat.pi * 2)
            let dist = seededRandom(rng: &rng, min: layer.minR, max: layer.maxR) * s

            let burstBias = (sin(angle * 3) * 0.5 + 0.5) * 0.3 + 0.7
            let adjustedDist = dist * burstBias

            let px = center.x + cos(angle) * adjustedDist
            let py = center.y + sin(angle) * adjustedDist

            let particleSize = seededRandom(rng: &rng, min: layer.minSize, max: layer.maxSize) * scale
            let alpha = layer.baseAlpha * seededRandom(rng: &rng, min: 0.4, max: 1.0)

            let colorIdx: Int
            if seededRandom(rng: &rng) < 0.12 {
                colorIdx = Int(seededRandom(rng: &rng, min: 4, max: 5.99))
            } else {
                colorIdx = Int(seededRandom(rng: &rng, min: 0, max: 3.99))
            }
            let pc = particleColors[colorIdx]

            // Soft glow around particle
            let glowSize = particleSize * 3.0
            let particleGlowColors = [
                CGColor(colorSpace: bgColorSpace, components: [pc.r, pc.g, pc.b, alpha * 0.6])!,
                CGColor(colorSpace: bgColorSpace, components: [pc.r, pc.g, pc.b, 0.0])!,
            ]
            if let pg = CGGradient(colorsSpace: bgColorSpace, colors: particleGlowColors as CFArray, locations: [0.0, 1.0]) {
                ctx.drawRadialGradient(pg,
                                       startCenter: CGPoint(x: px, y: py), startRadius: 0,
                                       endCenter: CGPoint(x: px, y: py), endRadius: glowSize,
                                       options: [])
            }

            // Core bright dot
            ctx.setFillColor(CGColor(colorSpace: bgColorSpace, components: [pc.r, pc.g, pc.b, alpha])!)
            let particleRect = CGRect(x: px - particleSize / 2, y: py - particleSize / 2, width: particleSize, height: particleSize)
            ctx.fillEllipse(in: particleRect)
        }
    }

    // --- Central waveform circle (oscilloscope-style) ---
    ctx.saveGState()
    let waveSegments = 360
    let waveRadius = s * 0.25
    let waveAmplitude = s * 0.04

    let waveConfigs: [(amp: CGFloat, freq: CGFloat, phase: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat, lw: CGFloat)] = [
        (1.0,  8, 0.0,   1.0, 0.55, 0.0, 0.2,  3.0),
        (0.8, 12, 1.2,   1.0, 0.65, 0.0, 0.3,  2.0),
        (1.0,  8, 0.0,   1.0, 0.75, 0.2, 0.8,  1.5),
        (0.4, 20, 2.5,   0.0, 0.83, 0.67, 0.4, 1.0),
    ]

    for wc in waveConfigs {
        ctx.saveGState()
        ctx.setStrokeColor(CGColor(colorSpace: bgColorSpace, components: [wc.r, wc.g, wc.b, wc.a])!)
        ctx.setLineWidth(wc.lw * scale)
        ctx.setLineCap(.round)

        let path = CGMutablePath()
        for i in 0...waveSegments {
            let angle = CGFloat(i) / CGFloat(waveSegments) * CGFloat.pi * 2
            let wave = sin(angle * wc.freq + wc.phase) * waveAmplitude * wc.amp
            let r = waveRadius + wave
            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }
    ctx.restoreGState()

    // --- Radial lines (grain streams) ---
    ctx.saveGState()
    var streamRng = SeededRNG(seed: 99)
    let streamCount = 24
    for _ in 0..<streamCount {
        let angle = seededRandom(rng: &streamRng, min: 0, max: CGFloat.pi * 2)
        let innerR = s * seededRandom(rng: &streamRng, min: 0.28, max: 0.32)
        let outerR = s * seededRandom(rng: &streamRng, min: 0.36, max: 0.46)
        let alpha = seededRandom(rng: &streamRng, min: 0.08, max: 0.25)

        let x1 = center.x + cos(angle) * innerR
        let y1 = center.y + sin(angle) * innerR
        let x2 = center.x + cos(angle) * outerR
        let y2 = center.y + sin(angle) * outerR

        if seededRandom(rng: &streamRng) < 0.2 {
            ctx.setStrokeColor(CGColor(colorSpace: bgColorSpace, components: [0.0, 0.83, 0.67, alpha])!)
        } else {
            ctx.setStrokeColor(CGColor(colorSpace: bgColorSpace, components: [1.0, 0.6, 0.1, alpha])!)
        }
        ctx.setLineWidth(1.5 * scale)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: x1, y: y1))
        ctx.addLine(to: CGPoint(x: x2, y: y2))
        ctx.strokePath()
    }
    ctx.restoreGState()

    // --- Stylized "G" letterform in center ---
    ctx.saveGState()
    let gRadius = s * 0.10
    let gLineWidth = s * 0.025
    let gCenter = CGPoint(x: center.x + s * 0.005, y: center.y)

    // G glow behind
    let gGlowColors = [
        CGColor(colorSpace: bgColorSpace, components: [1.0, 0.65, 0.0, 0.4])!,
        CGColor(colorSpace: bgColorSpace, components: [1.0, 0.65, 0.0, 0.0])!,
    ]
    if let gGlow = CGGradient(colorsSpace: bgColorSpace, colors: gGlowColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(gGlow,
                               startCenter: gCenter, startRadius: 0,
                               endCenter: gCenter, endRadius: gRadius * 2.5,
                               options: [])
    }

    // G arc (about 300 degrees)
    ctx.setStrokeColor(CGColor(colorSpace: bgColorSpace, components: [1.0, 0.75, 0.2, 0.95])!)
    ctx.setLineWidth(gLineWidth)
    ctx.setLineCap(.round)

    let gStartAngle: CGFloat = -CGFloat.pi * 0.15
    let gEndAngle: CGFloat = CGFloat.pi * 1.55

    let gPath = CGMutablePath()
    gPath.addArc(center: gCenter, radius: gRadius, startAngle: gStartAngle, endAngle: gEndAngle, clockwise: true)
    ctx.addPath(gPath)
    ctx.strokePath()

    // Horizontal bar of the G
    let barY = gCenter.y
    let barStartX = gCenter.x
    let barEndX = gCenter.x + gRadius * cos(gStartAngle)
    ctx.move(to: CGPoint(x: barStartX, y: barY))
    ctx.addLine(to: CGPoint(x: barEndX, y: barY))
    ctx.strokePath()
    ctx.restoreGState()

    // --- Outer vignette ---
    ctx.saveGState()
    let vignetteColors = [
        CGColor(colorSpace: bgColorSpace, components: [0.0, 0.0, 0.0, 0.0])!,
        CGColor(colorSpace: bgColorSpace, components: [0.0, 0.0, 0.0, 0.0])!,
        CGColor(colorSpace: bgColorSpace, components: [0.0, 0.0, 0.0, 0.5])!,
    ]
    if let vignetteGrad = CGGradient(colorsSpace: bgColorSpace, colors: vignetteColors as CFArray, locations: [0.0, 0.6, 1.0]) {
        ctx.drawRadialGradient(vignetteGrad,
                               startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: radius,
                               options: [.drawsAfterEndLocation])
    }
    ctx.restoreGState()

    // --- Subtle border ---
    ctx.saveGState()
    let borderPath = CGPath(roundedRect: iconRect.insetBy(dx: 1 * scale, dy: 1 * scale),
                            cornerWidth: cornerRadius - 1 * scale,
                            cornerHeight: cornerRadius - 1 * scale,
                            transform: nil)
    ctx.addPath(borderPath)
    ctx.setStrokeColor(CGColor(colorSpace: bgColorSpace, components: [1.0, 0.6, 0.1, 0.15])!)
    ctx.setLineWidth(1.5 * scale)
    ctx.strokePath()
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String, size: Int) {
    let s = CGFloat(size)

    guard let newRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: size,
                                         pixelsHigh: size,
                                         bitsPerSample: 8,
                                         samplesPerPixel: 4,
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0) else {
        print("ERROR: Could not create target bitmap")
        return
    }

    newRep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: newRep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: s, height: s),
               from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
               operation: .copy,
               fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = newRep.representation(using: .png, properties: [:]) else {
        print("ERROR: Could not create PNG data")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Wrote \(size)x\(size) -> \(path)")
    } catch {
        print("ERROR writing \(path): \(error)")
    }
}

// MARK: - Main

let basePath = "/Users/andysmith/projects/Grainulator"
let iconsetPath = "\(basePath)/Resources/Assets/AppIcon.iconset"
let icnsPath = "\(basePath)/Resources/Assets/AppIcon.icns"

let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizeSpecs: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

let uniqueSizes = Set(sizeSpecs.map { $0.pixels }).sorted()
var images: [Int: NSImage] = [:]

print("Generating icon images...")
for size in uniqueSizes {
    print("  Rendering \(size)x\(size)...")
    images[size] = generateIcon(size: size)
}

print("\nSaving PNGs to iconset...")
for spec in sizeSpecs {
    guard let img = images[spec.pixels] else { continue }
    let path = "\(iconsetPath)/\(spec.name)"
    savePNG(img, to: path, size: spec.pixels)
}

print("\nDone generating PNGs.")
print("Iconset path: \(iconsetPath)")
