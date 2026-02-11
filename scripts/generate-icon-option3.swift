#!/usr/bin/env swift

import Cocoa
import CoreGraphics
import Foundation

// MARK: - Seeded PRNG (deterministic grain particles)

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

// MARK: - Colors

struct Palette {
    static let background    = (r: 0.110, g: 0.110, b: 0.118, a: 1.0)   // #1C1C1E
    static let cream         = (r: 0.961, g: 0.902, b: 0.827, a: 1.0)   // #F5E6D3
    static let amber         = (r: 1.000, g: 0.549, b: 0.000, a: 1.0)   // #FF8C00
    static let teal          = (r: 0.000, g: 0.831, b: 0.667, a: 1.0)   // #00D4AA
}

func cgColor(_ c: (r: Double, g: Double, b: Double, a: Double)) -> CGColor {
    CGColor(red: c.r, green: c.g, blue: c.b, alpha: c.a)
}

func cgColorAlpha(_ c: (r: Double, g: Double, b: Double, a: Double), _ alpha: Double) -> CGColor {
    CGColor(red: c.r, green: c.g, blue: c.b, alpha: alpha)
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

    let iconRect = CGRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.22

    // MARK: Background

    let bgPath = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    // Solid dark charcoal fill
    ctx.setFillColor(cgColor(Palette.background))
    ctx.fill(iconRect)

    // Subtle radial gradient for depth
    let cs = CGColorSpaceCreateDeviceRGB()
    let bgCenter = CGPoint(x: s * 0.5, y: s * 0.45)
    let bgColors = [
        CGColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 0.3),
        CGColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 0.0),
    ]
    if let grad = CGGradient(colorsSpace: cs, colors: bgColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(grad, startCenter: bgCenter, startRadius: 0,
                               endCenter: bgCenter, endRadius: s * 0.55,
                               options: [.drawsAfterEndLocation])
    }

    // MARK: Dog Head

    let cx = s * 0.5
    // cy is the vertical center of the face -- CoreGraphics origin is bottom-left,
    // so higher cy = higher on screen
    let cy = s * 0.46

    let lineW = max(2.0, 3.5 * scale)

    ctx.setStrokeColor(cgColor(Palette.cream))
    ctx.setLineWidth(lineW)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // --- LEFT EAR (pointed triangle) ---
    let leftEarTip   = CGPoint(x: cx - s * 0.24, y: s * 0.92)
    let leftEarBaseO = CGPoint(x: cx - s * 0.26, y: cy + s * 0.14)
    let leftEarBaseI = CGPoint(x: cx - s * 0.08, y: cy + s * 0.18)

    ctx.beginPath()
    ctx.move(to: leftEarBaseO)
    // Slight curve on outer edge
    ctx.addCurve(to: leftEarTip,
                 control1: CGPoint(x: leftEarBaseO.x - s * 0.02, y: leftEarBaseO.y + s * 0.15),
                 control2: CGPoint(x: leftEarTip.x - s * 0.02, y: leftEarTip.y - s * 0.05))
    // Inner edge
    ctx.addCurve(to: leftEarBaseI,
                 control1: CGPoint(x: leftEarTip.x + s * 0.04, y: leftEarTip.y - s * 0.06),
                 control2: CGPoint(x: leftEarBaseI.x - s * 0.02, y: leftEarBaseI.y + s * 0.10))
    ctx.strokePath()

    // Waveform inside left ear (amber)
    ctx.saveGState()
    ctx.setStrokeColor(cgColorAlpha(Palette.amber, 0.65))
    ctx.setLineWidth(max(1.0, 2.0 * scale))
    ctx.beginPath()
    let waveSteps = 12
    for i in 0...waveSteps {
        let t = CGFloat(i) / CGFloat(waveSteps)
        // Line from base midpoint up toward tip
        let midBaseX = (leftEarBaseO.x + leftEarBaseI.x) * 0.5
        let midBaseY = (leftEarBaseO.y + leftEarBaseI.y) * 0.5
        let lineX = midBaseX + (leftEarTip.x - midBaseX) * t
        let lineY = midBaseY + (leftEarTip.y - midBaseY) * t
        // Perpendicular oscillation (frequency increases toward tip)
        let amp = s * 0.018 * sin(CGFloat(i) * .pi / 2.5) * (1.0 - t * 0.6)
        let px = lineX + amp
        let py = lineY
        if i == 0 { ctx.move(to: CGPoint(x: px, y: py)) }
        else { ctx.addLine(to: CGPoint(x: px, y: py)) }
    }
    ctx.strokePath()
    ctx.restoreGState()

    // --- RIGHT EAR (mirror) ---
    let rightEarTip   = CGPoint(x: cx + s * 0.24, y: s * 0.92)
    let rightEarBaseO = CGPoint(x: cx + s * 0.26, y: cy + s * 0.14)
    let rightEarBaseI = CGPoint(x: cx + s * 0.08, y: cy + s * 0.18)

    ctx.setStrokeColor(cgColor(Palette.cream))
    ctx.setLineWidth(lineW)
    ctx.beginPath()
    ctx.move(to: rightEarBaseO)
    ctx.addCurve(to: rightEarTip,
                 control1: CGPoint(x: rightEarBaseO.x + s * 0.02, y: rightEarBaseO.y + s * 0.15),
                 control2: CGPoint(x: rightEarTip.x + s * 0.02, y: rightEarTip.y - s * 0.05))
    ctx.addCurve(to: rightEarBaseI,
                 control1: CGPoint(x: rightEarTip.x - s * 0.04, y: rightEarTip.y - s * 0.06),
                 control2: CGPoint(x: rightEarBaseI.x + s * 0.02, y: rightEarBaseI.y + s * 0.10))
    ctx.strokePath()

    // Waveform inside right ear (teal)
    ctx.saveGState()
    ctx.setStrokeColor(cgColorAlpha(Palette.teal, 0.65))
    ctx.setLineWidth(max(1.0, 2.0 * scale))
    ctx.beginPath()
    for i in 0...waveSteps {
        let t = CGFloat(i) / CGFloat(waveSteps)
        let midBaseX = (rightEarBaseO.x + rightEarBaseI.x) * 0.5
        let midBaseY = (rightEarBaseO.y + rightEarBaseI.y) * 0.5
        let lineX = midBaseX + (rightEarTip.x - midBaseX) * t
        let lineY = midBaseY + (rightEarTip.y - midBaseY) * t
        let amp = s * 0.018 * sin(CGFloat(i) * .pi / 2.5) * (1.0 - t * 0.6)
        let px = lineX - amp
        let py = lineY
        if i == 0 { ctx.move(to: CGPoint(x: px, y: py)) }
        else { ctx.addLine(to: CGPoint(x: px, y: py)) }
    }
    ctx.strokePath()
    ctx.restoreGState()

    // MARK: Head outline (rounded face)

    ctx.setStrokeColor(cgColor(Palette.cream))
    ctx.setLineWidth(lineW)

    // Draw the face outline connecting ear bases
    ctx.beginPath()
    // Start from outer base of left ear, go down along left cheek
    ctx.move(to: leftEarBaseO)
    // Left cheek
    ctx.addCurve(to: CGPoint(x: cx - s * 0.20, y: cy - s * 0.14),
                 control1: CGPoint(x: cx - s * 0.30, y: cy + s * 0.02),
                 control2: CGPoint(x: cx - s * 0.26, y: cy - s * 0.08))
    // Chin - smooth U
    ctx.addCurve(to: CGPoint(x: cx + s * 0.20, y: cy - s * 0.14),
                 control1: CGPoint(x: cx - s * 0.12, y: cy - s * 0.26),
                 control2: CGPoint(x: cx + s * 0.12, y: cy - s * 0.26))
    // Right cheek
    ctx.addCurve(to: rightEarBaseO,
                 control1: CGPoint(x: cx + s * 0.26, y: cy - s * 0.08),
                 control2: CGPoint(x: cx + s * 0.30, y: cy + s * 0.02))
    ctx.strokePath()

    // Forehead line connecting inner ear bases
    ctx.beginPath()
    ctx.move(to: leftEarBaseI)
    ctx.addCurve(to: rightEarBaseI,
                 control1: CGPoint(x: cx - s * 0.02, y: cy + s * 0.20),
                 control2: CGPoint(x: cx + s * 0.02, y: cy + s * 0.20))
    ctx.strokePath()

    // MARK: Eyes (LED meter dots)

    let eyeY = cy + s * 0.05
    let eyeSpacing = s * 0.105
    let eyeRadius = s * 0.030

    // Left eye - amber LED
    let leftEyeCenter = CGPoint(x: cx - eyeSpacing, y: eyeY)
    ctx.saveGState()
    // Outer glow
    let amberGlow = [
        cgColorAlpha(Palette.amber, 0.5),
        cgColorAlpha(Palette.amber, 0.0),
    ]
    if let g = CGGradient(colorsSpace: cs, colors: amberGlow as CFArray, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(g, startCenter: leftEyeCenter, startRadius: 0,
                               endCenter: leftEyeCenter, endRadius: eyeRadius * 4.0,
                               options: [])
    }
    ctx.setFillColor(cgColor(Palette.amber))
    ctx.fillEllipse(in: CGRect(x: leftEyeCenter.x - eyeRadius, y: leftEyeCenter.y - eyeRadius,
                                width: eyeRadius * 2, height: eyeRadius * 2))
    // Bright center
    let hlR = eyeRadius * 0.35
    ctx.setFillColor(CGColor(red: 1.0, green: 0.88, blue: 0.55, alpha: 0.9))
    ctx.fillEllipse(in: CGRect(x: leftEyeCenter.x - hlR, y: leftEyeCenter.y - hlR + eyeRadius * 0.15,
                                width: hlR * 2, height: hlR * 2))
    ctx.restoreGState()

    // Right eye - teal LED
    let rightEyeCenter = CGPoint(x: cx + eyeSpacing, y: eyeY)
    ctx.saveGState()
    let tealGlow = [
        cgColorAlpha(Palette.teal, 0.5),
        cgColorAlpha(Palette.teal, 0.0),
    ]
    if let g = CGGradient(colorsSpace: cs, colors: tealGlow as CFArray, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(g, startCenter: rightEyeCenter, startRadius: 0,
                               endCenter: rightEyeCenter, endRadius: eyeRadius * 4.0,
                               options: [])
    }
    ctx.setFillColor(cgColor(Palette.teal))
    ctx.fillEllipse(in: CGRect(x: rightEyeCenter.x - eyeRadius, y: rightEyeCenter.y - eyeRadius,
                                width: eyeRadius * 2, height: eyeRadius * 2))
    ctx.setFillColor(CGColor(red: 0.5, green: 1.0, blue: 0.9, alpha: 0.9))
    ctx.fillEllipse(in: CGRect(x: rightEyeCenter.x - hlR, y: rightEyeCenter.y - hlR + eyeRadius * 0.15,
                                width: hlR * 2, height: hlR * 2))
    ctx.restoreGState()

    // MARK: Nose

    let noseCenter = CGPoint(x: cx, y: cy - s * 0.055)
    let noseW = s * 0.055
    let noseH = s * 0.038

    // Rounded inverted triangle nose
    ctx.beginPath()
    ctx.move(to: CGPoint(x: noseCenter.x, y: noseCenter.y - noseH))
    ctx.addCurve(to: CGPoint(x: noseCenter.x - noseW, y: noseCenter.y + noseH * 0.3),
                 control1: CGPoint(x: noseCenter.x - noseW * 0.4, y: noseCenter.y - noseH),
                 control2: CGPoint(x: noseCenter.x - noseW, y: noseCenter.y - noseH * 0.3))
    ctx.addCurve(to: CGPoint(x: noseCenter.x + noseW, y: noseCenter.y + noseH * 0.3),
                 control1: CGPoint(x: noseCenter.x - noseW * 0.3, y: noseCenter.y + noseH * 0.8),
                 control2: CGPoint(x: noseCenter.x + noseW * 0.3, y: noseCenter.y + noseH * 0.8))
    ctx.addCurve(to: CGPoint(x: noseCenter.x, y: noseCenter.y - noseH),
                 control1: CGPoint(x: noseCenter.x + noseW, y: noseCenter.y - noseH * 0.3),
                 control2: CGPoint(x: noseCenter.x + noseW * 0.4, y: noseCenter.y - noseH))
    ctx.closePath()
    ctx.setFillColor(cgColor(Palette.cream))
    ctx.fillPath()

    // Nose shine
    let shineR = noseH * 0.22
    ctx.setFillColor(CGColor(red: 1.0, green: 0.97, blue: 0.94, alpha: 0.45))
    ctx.fillEllipse(in: CGRect(x: noseCenter.x - shineR, y: noseCenter.y + shineR * 0.2,
                                width: shineR * 2, height: shineR * 1.5))

    // MARK: Mouth

    ctx.setStrokeColor(cgColorAlpha(Palette.cream, 0.45))
    ctx.setLineWidth(max(1.0, 1.5 * scale))
    let mouthY = noseCenter.y - noseH * 1.6
    ctx.beginPath()
    // Simple W-shape smile
    ctx.move(to: CGPoint(x: cx - s * 0.04, y: mouthY + s * 0.005))
    ctx.addCurve(to: CGPoint(x: cx, y: mouthY - s * 0.008),
                 control1: CGPoint(x: cx - s * 0.02, y: mouthY - s * 0.008),
                 control2: CGPoint(x: cx - s * 0.008, y: mouthY - s * 0.008))
    ctx.strokePath()
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: mouthY - s * 0.008))
    ctx.addCurve(to: CGPoint(x: cx + s * 0.04, y: mouthY + s * 0.005),
                 control1: CGPoint(x: cx + s * 0.008, y: mouthY - s * 0.008),
                 control2: CGPoint(x: cx + s * 0.02, y: mouthY - s * 0.008))
    ctx.strokePath()

    // Vertical line from nose to mouth
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx, y: noseCenter.y - noseH * 1.05))
    ctx.addLine(to: CGPoint(x: cx, y: mouthY - s * 0.006))
    ctx.strokePath()

    // MARK: Snout circle (very subtle)

    ctx.setStrokeColor(cgColorAlpha(Palette.cream, 0.12))
    ctx.setLineWidth(max(0.8, 1.0 * scale))
    let snoutR = s * 0.085
    ctx.strokeEllipse(in: CGRect(x: cx - snoutR, y: noseCenter.y - snoutR * 1.6,
                                  width: snoutR * 2, height: snoutR * 1.8))

    // MARK: Grain Particles

    var rng = SeededRNG(seed: 42)
    let particleCount = 35
    for i in 0..<particleCount {
        let angle = seededRandom(rng: &rng, min: 0, max: .pi * 2)
        let dist = seededRandom(rng: &rng, min: s * 0.32, max: s * 0.46)
        let px = cx + cos(angle) * dist
        let py = cy + sin(angle) * dist

        // Keep within icon rounded rect
        let margin = s * 0.08
        if px < margin || px > s - margin || py < margin || py > s - margin { continue }

        let particleR = seededRandom(rng: &rng, min: s * 0.003, max: s * 0.011)
        let useAmber = i % 3 != 0
        let alpha = seededRandom(rng: &rng, min: 0.25, max: 0.80)

        if useAmber {
            ctx.setFillColor(cgColorAlpha(Palette.amber, Double(alpha)))
        } else {
            ctx.setFillColor(cgColorAlpha(Palette.teal, Double(alpha)))
        }
        ctx.fillEllipse(in: CGRect(x: px - particleR, y: py - particleR,
                                    width: particleR * 2, height: particleR * 2))

        // Glow for bigger particles
        if particleR > s * 0.007 {
            let glowR = particleR * 2.8
            let gc = useAmber
                ? cgColorAlpha(Palette.amber, Double(alpha * 0.15))
                : cgColorAlpha(Palette.teal, Double(alpha * 0.15))
            ctx.setFillColor(gc)
            ctx.fillEllipse(in: CGRect(x: px - glowR, y: py - glowR,
                                        width: glowR * 2, height: glowR * 2))
        }
    }

    // MARK: EQ bars flanking the head

    let barW = max(2.0, 3.0 * scale)
    let barSpacing = max(3.5, 5.5 * scale)

    // Left side bars (amber)
    let lBarX = cx - s * 0.33
    let barY = cy - s * 0.02
    let lHeights: [CGFloat] = [0.035, 0.065, 0.050, 0.025]
    for (j, h) in lHeights.enumerated() {
        let bx = lBarX + CGFloat(j) * barSpacing
        let bh = s * h
        let a = 0.35 + Double(j) * 0.1
        ctx.setFillColor(cgColorAlpha(Palette.amber, a))
        ctx.fill(CGRect(x: bx, y: barY, width: barW, height: bh))
    }

    // Right side bars (teal)
    let rBarX = cx + s * 0.27
    let rHeights: [CGFloat] = [0.025, 0.055, 0.065, 0.035]
    for (j, h) in rHeights.enumerated() {
        let bx = rBarX + CGFloat(j) * barSpacing
        let bh = s * h
        let a = 0.35 + Double(j) * 0.1
        ctx.setFillColor(cgColorAlpha(Palette.teal, a))
        ctx.fill(CGRect(x: bx, y: barY, width: barW, height: bh))
    }

    // MARK: "GRAINULATOR" text at bottom (subtle, only at larger sizes)

    if size >= 256 {
        let fontSize = max(8.0, 11.0 * scale)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: 0.96, green: 0.90, blue: 0.83, alpha: 0.22),
            .kern: fontSize * 0.32,
        ]
        let text = "GRAINULATOR"
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrStr.size()
        let textX = (s - textSize.width) / 2
        let textY = s * 0.055
        attrStr.draw(at: NSPoint(x: textX, y: textY))
    }

    image.unlockFocus()
    return image
}

// MARK: - Build iconset and .icns

func main() {
    let outputDir = "/Users/andysmith/projects/Grainulator/Resources/Assets"
    let iconsetPath = "\(outputDir)/AppIcon-option3.iconset"
    let icnsPath = "\(outputDir)/AppIcon-option3.icns"

    let fm = FileManager.default
    try? fm.removeItem(atPath: iconsetPath)
    try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

    // All required macOS .icns sizes
    let sizes: [(name: String, size: Int)] = [
        ("icon_16x16",        16),
        ("icon_16x16@2x",     32),
        ("icon_32x32",        32),
        ("icon_32x32@2x",     64),
        ("icon_128x128",      128),
        ("icon_128x128@2x",   256),
        ("icon_256x256",      256),
        ("icon_256x256@2x",   512),
        ("icon_512x512",      512),
        ("icon_512x512@2x",   1024),
    ]

    print("Generating Sound Dog icon (Option 3)...\n")

    for (name, size) in sizes {
        let image = generateIcon(size: size)

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:])
        else {
            fatalError("Failed to create PNG for \(name)")
        }

        let filePath = "\(iconsetPath)/\(name).png"
        try! (pngData as NSData).write(toFile: filePath)
        print("  \(name).png  (\(size)x\(size))")
    }

    // Convert to .icns with iconutil
    print("\nRunning iconutil...")
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    task.arguments = ["-c", "icns", iconsetPath, "-o", icnsPath]

    let pipe = Pipe()
    task.standardError = pipe

    try! task.run()
    task.waitUntilExit()

    if task.terminationStatus == 0 {
        print("  Created: \(icnsPath)")
        try? fm.removeItem(atPath: iconsetPath)
        print("  Cleaned up iconset directory")
    } else {
        let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorStr = String(data: errorData, encoding: .utf8) ?? "unknown error"
        print("  iconutil FAILED: \(errorStr)")
        print("  Iconset kept for debugging: \(iconsetPath)")
    }

    print("\nDone!")
}

main()
