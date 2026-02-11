#!/usr/bin/env swift

// generate-icon-option2.swift
// Generates the "Headphones Dog" app icon for Grainulator
// A front-facing dog head silhouette with DJ headphones, synthwave aesthetic

import Cocoa
import CoreGraphics

// MARK: - Color Palette

let bgColor      = NSColor(red: 0x12/255.0, green: 0x10/255.0, blue: 0x1F/255.0, alpha: 1.0)
let cyan1         = NSColor(red: 0x00/255.0, green: 0xE5/255.0, blue: 0xCC/255.0, alpha: 1.0)
let cyan2         = NSColor(red: 0x00/255.0, green: 0xD4/255.0, blue: 0xAA/255.0, alpha: 1.0)
let amber1        = NSColor(red: 0xFF/255.0, green: 0x8C/255.0, blue: 0x00/255.0, alpha: 1.0)
let amber2        = NSColor(red: 0xFF/255.0, green: 0xA5/255.0, blue: 0x00/255.0, alpha: 1.0)
let gridColor     = NSColor(red: 0x1E/255.0, green: 0x1A/255.0, blue: 0x35/255.0, alpha: 1.0)

// MARK: - Drawing Helpers

func drawBackground(_ ctx: CGContext, size: CGFloat) {
    // Solid dark background
    ctx.setFillColor(bgColor.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // Subtle grid pattern
    ctx.setStrokeColor(gridColor.cgColor)
    ctx.setLineWidth(size * 0.002)
    let gridSpacing = size / 24.0
    for i in 0...24 {
        let pos = CGFloat(i) * gridSpacing
        ctx.move(to: CGPoint(x: pos, y: 0))
        ctx.addLine(to: CGPoint(x: pos, y: size))
        ctx.move(to: CGPoint(x: 0, y: pos))
        ctx.addLine(to: CGPoint(x: size, y: pos))
    }
    ctx.strokePath()

    // Radial glow behind where the dog will be
    let center = CGPoint(x: size * 0.5, y: size * 0.48)
    let glowRadius = size * 0.42
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [
                                    NSColor(red: 0x00/255.0, green: 0xE5/255.0, blue: 0xCC/255.0, alpha: 0.18).cgColor,
                                    NSColor(red: 0x8B/255.0, green: 0x00/255.0, blue: 0xFF/255.0, alpha: 0.06).cgColor,
                                    NSColor.clear.cgColor
                                  ] as CFArray,
                                  locations: [0.0, 0.5, 1.0]) {
        ctx.drawRadialGradient(gradient,
                               startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: glowRadius,
                               options: [])
    }
}

/// Build a front-facing dog head silhouette path.
/// Coordinates in normalized 0..1 space, scaled by rect.
func dogHeadPath(in rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    let s = rect.width
    let ox = rect.origin.x
    let oy = rect.origin.y

    func p(_ xn: CGFloat, _ yn: CGFloat) -> CGPoint {
        CGPoint(x: ox + xn * s, y: oy + yn * s)
    }

    // Start at the bottom center (chin)
    path.move(to: p(0.50, 0.05))

    // Right side of jaw
    path.addCurve(to: p(0.62, 0.12),
                  control1: p(0.54, 0.05),
                  control2: p(0.58, 0.07))

    // Right cheek
    path.addCurve(to: p(0.72, 0.25),
                  control1: p(0.66, 0.16),
                  control2: p(0.70, 0.20))

    // Right side of face
    path.addCurve(to: p(0.76, 0.42),
                  control1: p(0.74, 0.30),
                  control2: p(0.76, 0.36))

    // Right temple
    path.addCurve(to: p(0.74, 0.55),
                  control1: p(0.76, 0.47),
                  control2: p(0.75, 0.52))

    // Right ear base
    path.addCurve(to: p(0.78, 0.62),
                  control1: p(0.74, 0.58),
                  control2: p(0.76, 0.60))

    // Right ear outer edge going up
    path.addCurve(to: p(0.85, 0.80),
                  control1: p(0.81, 0.67),
                  control2: p(0.84, 0.74))

    // Right ear tip
    path.addCurve(to: p(0.82, 0.90),
                  control1: p(0.86, 0.84),
                  control2: p(0.85, 0.88))

    // Right ear inner edge
    path.addCurve(to: p(0.68, 0.68),
                  control1: p(0.78, 0.86),
                  control2: p(0.72, 0.75))

    // Right ear base inner to forehead
    path.addCurve(to: p(0.60, 0.62),
                  control1: p(0.66, 0.65),
                  control2: p(0.63, 0.63))

    // Forehead right to center
    path.addCurve(to: p(0.50, 0.60),
                  control1: p(0.57, 0.61),
                  control2: p(0.53, 0.60))

    // Forehead center to left
    path.addCurve(to: p(0.40, 0.62),
                  control1: p(0.47, 0.60),
                  control2: p(0.43, 0.61))

    // Left ear base inner
    path.addCurve(to: p(0.32, 0.68),
                  control1: p(0.37, 0.63),
                  control2: p(0.34, 0.65))

    // Left ear inner edge going up
    path.addCurve(to: p(0.18, 0.90),
                  control1: p(0.28, 0.75),
                  control2: p(0.22, 0.86))

    // Left ear tip
    path.addCurve(to: p(0.15, 0.80),
                  control1: p(0.15, 0.88),
                  control2: p(0.14, 0.84))

    // Left ear outer edge
    path.addCurve(to: p(0.22, 0.62),
                  control1: p(0.16, 0.74),
                  control2: p(0.19, 0.67))

    // Left ear base
    path.addCurve(to: p(0.26, 0.55),
                  control1: p(0.24, 0.60),
                  control2: p(0.25, 0.58))

    // Left temple
    path.addCurve(to: p(0.24, 0.42),
                  control1: p(0.25, 0.52),
                  control2: p(0.24, 0.47))

    // Left cheek
    path.addCurve(to: p(0.28, 0.25),
                  control1: p(0.24, 0.36),
                  control2: p(0.26, 0.30))

    // Left jowl
    path.addCurve(to: p(0.38, 0.12),
                  control1: p(0.30, 0.20),
                  control2: p(0.34, 0.16))

    // Left jaw back to chin
    path.addCurve(to: p(0.50, 0.05),
                  control1: p(0.42, 0.07),
                  control2: p(0.46, 0.05))

    path.closeSubpath()
    return path
}

/// Draw dog facial features (eyes, nose, muzzle) in outline style
func drawDogFace(_ ctx: CGContext, rect: CGRect, lineWidth: CGFloat) {
    let s = rect.width
    let ox = rect.origin.x
    let oy = rect.origin.y

    // --- Eyes ---
    let eyeW = s * 0.09
    let eyeH = s * 0.055
    let eyeY = oy + 0.44 * s

    // Right eye
    let rEC = CGPoint(x: ox + 0.61 * s, y: eyeY)
    let rEyePath = CGMutablePath()
    rEyePath.move(to: CGPoint(x: rEC.x - eyeW/2, y: rEC.y))
    rEyePath.addCurve(to: CGPoint(x: rEC.x + eyeW/2, y: rEC.y),
                      control1: CGPoint(x: rEC.x - eyeW * 0.25, y: rEC.y + eyeH * 0.8),
                      control2: CGPoint(x: rEC.x + eyeW * 0.25, y: rEC.y + eyeH * 0.8))
    rEyePath.addCurve(to: CGPoint(x: rEC.x - eyeW/2, y: rEC.y),
                      control1: CGPoint(x: rEC.x + eyeW * 0.25, y: rEC.y - eyeH * 0.8),
                      control2: CGPoint(x: rEC.x - eyeW * 0.25, y: rEC.y - eyeH * 0.8))
    rEyePath.closeSubpath()

    // Left eye
    let lEC = CGPoint(x: ox + 0.39 * s, y: eyeY)
    let lEyePath = CGMutablePath()
    lEyePath.move(to: CGPoint(x: lEC.x - eyeW/2, y: lEC.y))
    lEyePath.addCurve(to: CGPoint(x: lEC.x + eyeW/2, y: lEC.y),
                      control1: CGPoint(x: lEC.x - eyeW * 0.25, y: lEC.y + eyeH * 0.8),
                      control2: CGPoint(x: lEC.x + eyeW * 0.25, y: lEC.y + eyeH * 0.8))
    lEyePath.addCurve(to: CGPoint(x: lEC.x - eyeW/2, y: lEC.y),
                      control1: CGPoint(x: lEC.x + eyeW * 0.25, y: lEC.y - eyeH * 0.8),
                      control2: CGPoint(x: lEC.x - eyeW * 0.25, y: lEC.y - eyeH * 0.8))
    lEyePath.closeSubpath()

    // Glow behind eyes
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.025, color: cyan1.cgColor)
    ctx.setFillColor(cyan1.withAlphaComponent(0.6).cgColor)
    ctx.addPath(rEyePath)
    ctx.fillPath()
    ctx.addPath(lEyePath)
    ctx.fillPath()
    ctx.restoreGState()

    // Eye outlines
    ctx.setStrokeColor(cyan1.cgColor)
    ctx.setLineWidth(lineWidth * 0.8)
    ctx.addPath(rEyePath)
    ctx.strokePath()
    ctx.addPath(lEyePath)
    ctx.strokePath()

    // Pupils
    let pupilR = s * 0.018
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
    ctx.fillEllipse(in: CGRect(x: rEC.x - pupilR, y: rEC.y - pupilR, width: pupilR * 2, height: pupilR * 2))
    ctx.fillEllipse(in: CGRect(x: lEC.x - pupilR, y: lEC.y - pupilR, width: pupilR * 2, height: pupilR * 2))

    // --- Nose ---
    let noseCenter = CGPoint(x: ox + 0.50 * s, y: oy + 0.28 * s)
    let noseW = s * 0.10
    let noseH = s * 0.06
    let nosePath = CGMutablePath()
    nosePath.move(to: CGPoint(x: noseCenter.x, y: noseCenter.y - noseH * 0.5))
    nosePath.addCurve(to: CGPoint(x: noseCenter.x + noseW * 0.5, y: noseCenter.y + noseH * 0.3),
                      control1: CGPoint(x: noseCenter.x + noseW * 0.35, y: noseCenter.y - noseH * 0.5),
                      control2: CGPoint(x: noseCenter.x + noseW * 0.55, y: noseCenter.y))
    nosePath.addCurve(to: CGPoint(x: noseCenter.x, y: noseCenter.y + noseH * 0.5),
                      control1: CGPoint(x: noseCenter.x + noseW * 0.4, y: noseCenter.y + noseH * 0.55),
                      control2: CGPoint(x: noseCenter.x + noseW * 0.15, y: noseCenter.y + noseH * 0.55))
    nosePath.addCurve(to: CGPoint(x: noseCenter.x - noseW * 0.5, y: noseCenter.y + noseH * 0.3),
                      control1: CGPoint(x: noseCenter.x - noseW * 0.15, y: noseCenter.y + noseH * 0.55),
                      control2: CGPoint(x: noseCenter.x - noseW * 0.4, y: noseCenter.y + noseH * 0.55))
    nosePath.addCurve(to: CGPoint(x: noseCenter.x, y: noseCenter.y - noseH * 0.5),
                      control1: CGPoint(x: noseCenter.x - noseW * 0.55, y: noseCenter.y),
                      control2: CGPoint(x: noseCenter.x - noseW * 0.35, y: noseCenter.y - noseH * 0.5))
    nosePath.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.02, color: cyan1.cgColor)
    ctx.setFillColor(cyan1.withAlphaComponent(0.5).cgColor)
    ctx.addPath(nosePath)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.setStrokeColor(cyan1.cgColor)
    ctx.setLineWidth(lineWidth * 0.8)
    ctx.addPath(nosePath)
    ctx.strokePath()

    // Muzzle line
    let muzzlePath = CGMutablePath()
    muzzlePath.move(to: CGPoint(x: noseCenter.x, y: noseCenter.y - noseH * 0.5))
    muzzlePath.addLine(to: CGPoint(x: noseCenter.x, y: oy + 0.14 * s))
    ctx.setStrokeColor(cyan2.withAlphaComponent(0.4).cgColor)
    ctx.setLineWidth(lineWidth * 0.5)
    ctx.addPath(muzzlePath)
    ctx.strokePath()

    // Mouth
    let mouthPath = CGMutablePath()
    mouthPath.move(to: CGPoint(x: noseCenter.x - s * 0.06, y: oy + 0.16 * s))
    mouthPath.addCurve(to: CGPoint(x: noseCenter.x, y: oy + 0.13 * s),
                       control1: CGPoint(x: noseCenter.x - s * 0.03, y: oy + 0.14 * s),
                       control2: CGPoint(x: noseCenter.x - s * 0.01, y: oy + 0.13 * s))
    mouthPath.addCurve(to: CGPoint(x: noseCenter.x + s * 0.06, y: oy + 0.16 * s),
                       control1: CGPoint(x: noseCenter.x + s * 0.01, y: oy + 0.13 * s),
                       control2: CGPoint(x: noseCenter.x + s * 0.03, y: oy + 0.14 * s))
    ctx.setStrokeColor(cyan2.withAlphaComponent(0.5).cgColor)
    ctx.setLineWidth(lineWidth * 0.6)
    ctx.addPath(mouthPath)
    ctx.strokePath()
}

/// Draw headphones on the dog
func drawHeadphones(_ ctx: CGContext, rect: CGRect, lineWidth: CGFloat) {
    let s = rect.width
    let ox = rect.origin.x
    let oy = rect.origin.y

    func p(_ xn: CGFloat, _ yn: CGFloat) -> CGPoint {
        CGPoint(x: ox + xn * s, y: oy + yn * s)
    }

    // Headband arc over top of head between ears
    let bandPath = CGMutablePath()
    bandPath.move(to: p(0.20, 0.60))
    bandPath.addCurve(to: p(0.35, 0.74),
                      control1: p(0.20, 0.66),
                      control2: p(0.26, 0.72))
    bandPath.addCurve(to: p(0.50, 0.77),
                      control1: p(0.40, 0.76),
                      control2: p(0.45, 0.77))
    bandPath.addCurve(to: p(0.65, 0.74),
                      control1: p(0.55, 0.77),
                      control2: p(0.60, 0.76))
    bandPath.addCurve(to: p(0.80, 0.60),
                      control1: p(0.74, 0.72),
                      control2: p(0.80, 0.66))

    // Band with glow
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.025, color: amber1.cgColor)
    ctx.setStrokeColor(amber1.cgColor)
    ctx.setLineWidth(lineWidth * 3.5)
    ctx.setLineCap(.round)
    ctx.addPath(bandPath)
    ctx.strokePath()
    ctx.restoreGState()

    // Inner highlight
    ctx.setStrokeColor(amber2.withAlphaComponent(0.6).cgColor)
    ctx.setLineWidth(lineWidth * 1.5)
    ctx.setLineCap(.round)
    ctx.addPath(bandPath)
    ctx.strokePath()

    // Left ear cup
    drawEarCup(ctx, center: p(0.19, 0.48), size: s, lineWidth: lineWidth)

    // Right ear cup
    drawEarCup(ctx, center: p(0.81, 0.48), size: s, lineWidth: lineWidth)

    // Left connector arm
    let leftArm = CGMutablePath()
    leftArm.move(to: p(0.20, 0.60))
    leftArm.addCurve(to: p(0.19, 0.52),
                     control1: p(0.19, 0.58),
                     control2: p(0.19, 0.55))
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.015, color: amber1.cgColor)
    ctx.setStrokeColor(amber1.cgColor)
    ctx.setLineWidth(lineWidth * 2.5)
    ctx.setLineCap(.round)
    ctx.addPath(leftArm)
    ctx.strokePath()
    ctx.restoreGState()

    // Right connector arm
    let rightArm = CGMutablePath()
    rightArm.move(to: p(0.80, 0.60))
    rightArm.addCurve(to: p(0.81, 0.52),
                      control1: p(0.81, 0.58),
                      control2: p(0.81, 0.55))
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.015, color: amber1.cgColor)
    ctx.setStrokeColor(amber1.cgColor)
    ctx.setLineWidth(lineWidth * 2.5)
    ctx.setLineCap(.round)
    ctx.addPath(rightArm)
    ctx.strokePath()
    ctx.restoreGState()
}

func drawEarCup(_ ctx: CGContext, center: CGPoint, size s: CGFloat, lineWidth: CGFloat) {
    let cupW = s * 0.10
    let cupH = s * 0.14
    let cupRect = CGRect(x: center.x - cupW/2, y: center.y - cupH/2, width: cupW, height: cupH)
    let cupPath = CGPath(roundedRect: cupRect, cornerWidth: cupW * 0.35, cornerHeight: cupH * 0.25, transform: nil)

    // Glow
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.035, color: amber1.cgColor)
    ctx.setFillColor(NSColor(red: 0xFF/255.0, green: 0x8C/255.0, blue: 0x00/255.0, alpha: 0.25).cgColor)
    ctx.addPath(cupPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Fill
    ctx.setFillColor(NSColor(red: 0x2A/255.0, green: 0x1A/255.0, blue: 0x05/255.0, alpha: 0.9).cgColor)
    ctx.addPath(cupPath)
    ctx.fillPath()

    // Border
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.015, color: amber1.cgColor)
    ctx.setStrokeColor(amber1.cgColor)
    ctx.setLineWidth(lineWidth * 1.8)
    ctx.addPath(cupPath)
    ctx.strokePath()
    ctx.restoreGState()

    // Speaker grille circle
    let innerR = min(cupW, cupH) * 0.28
    let innerRect = CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)
    ctx.setStrokeColor(amber2.withAlphaComponent(0.6).cgColor)
    ctx.setLineWidth(lineWidth * 0.7)
    ctx.strokeEllipse(in: innerRect)

    // Inner dot
    let dotR = innerR * 0.35
    ctx.setFillColor(amber2.withAlphaComponent(0.4).cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - dotR, y: center.y - dotR, width: dotR * 2, height: dotR * 2))
}

/// Draw EQ bars at the bottom
func drawEQBars(_ ctx: CGContext, size: CGFloat) {
    let barCount = 15
    let totalWidth = size * 0.55
    let barWidth = totalWidth / CGFloat(barCount) * 0.6
    let barGap = totalWidth / CGFloat(barCount) * 0.4
    let startX = (size - totalWidth) / 2.0
    let baseY = size * 0.06

    let heights: [CGFloat] = [0.20, 0.35, 0.55, 0.75, 0.90, 1.0, 0.85, 0.70, 0.90, 1.0, 0.80, 0.60, 0.45, 0.30, 0.18]

    for i in 0..<barCount {
        let x = startX + CGFloat(i) * (barWidth + barGap)
        let maxH = size * 0.06
        let h = maxH * heights[i % heights.count]

        let t = CGFloat(i) / CGFloat(barCount - 1)
        let r = t * 0x00/255.0 + (1 - t) * 0x00/255.0
        let g = t * 0xE5/255.0 + (1 - t) * 0xFF/255.0
        let b = t * 0xCC/255.0 + (1 - t) * 0x88/255.0
        let barColor = NSColor(red: r, green: g, blue: b, alpha: 0.7)

        let barRect = CGRect(x: x, y: baseY, width: barWidth, height: h)

        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: size * 0.008, color: barColor.withAlphaComponent(0.5).cgColor)
        ctx.setFillColor(barColor.cgColor)
        ctx.fill(barRect)
        ctx.restoreGState()
    }
}

/// Main render function
func renderIcon(size: Int) -> NSBitmapImageRep {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    cg.setAllowsAntialiasing(true)
    cg.setShouldAntialias(true)
    cg.interpolationQuality = .high

    // 1. Background with grid and glow
    drawBackground(cg, size: s)

    // 2. Dog head placement
    let dogMargin = s * 0.12
    let dogSize = s - dogMargin * 2
    let dogRect = CGRect(x: dogMargin, y: s * 0.10, width: dogSize, height: dogSize)

    let headPath = dogHeadPath(in: dogRect)
    let lineW = max(s * 0.006, 1.5)

    // 3. Outer glow
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: s * 0.05, color: cyan1.withAlphaComponent(0.4).cgColor)
    cg.setStrokeColor(cyan1.withAlphaComponent(0.3).cgColor)
    cg.setLineWidth(lineW * 3)
    cg.addPath(headPath)
    cg.strokePath()
    cg.restoreGState()

    // 4. Fill silhouette
    cg.saveGState()
    cg.addPath(headPath)
    cg.clip()
    if let fillGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [
                                    NSColor(red: 0x0A/255.0, green: 0x12/255.0, blue: 0x18/255.0, alpha: 0.95).cgColor,
                                    NSColor(red: 0x08/255.0, green: 0x0E/255.0, blue: 0x14/255.0, alpha: 0.95).cgColor
                                  ] as CFArray,
                                  locations: [0.0, 1.0]) {
        cg.drawLinearGradient(fillGrad,
                              start: CGPoint(x: s/2, y: dogRect.maxY),
                              end: CGPoint(x: s/2, y: dogRect.minY),
                              options: [])
    }
    cg.restoreGState()

    // 5. Neon cyan outline
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: s * 0.02, color: cyan1.cgColor)
    cg.setStrokeColor(cyan1.cgColor)
    cg.setLineWidth(lineW * 1.8)
    cg.setLineJoin(.round)
    cg.addPath(headPath)
    cg.strokePath()
    cg.restoreGState()

    // Brighter core line
    cg.setStrokeColor(cyan2.cgColor)
    cg.setLineWidth(lineW * 0.9)
    cg.addPath(headPath)
    cg.strokePath()

    // 6. Facial features
    drawDogFace(cg, rect: dogRect, lineWidth: lineW)

    // 7. Headphones
    drawHeadphones(cg, rect: dogRect, lineWidth: lineW)

    // 8. EQ bars
    drawEQBars(cg, size: s)

    NSGraphicsContext.current = nil
    return rep
}

// MARK: - Icon Generation

let outputDir = "/Users/andysmith/projects/Grainulator/Resources/Assets"
let iconsetPath = "\(outputDir)/AppIcon-option2.iconset"

let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let iconSizes: [(String, Int)] = [
    ("icon_16x16",          16),
    ("icon_16x16@2x",       32),
    ("icon_32x32",          32),
    ("icon_32x32@2x",       64),
    ("icon_128x128",       128),
    ("icon_128x128@2x",   256),
    ("icon_256x256",       256),
    ("icon_256x256@2x",   512),
    ("icon_512x512",       512),
    ("icon_512x512@2x",  1024),
]

print("Generating Headphones Dog icon images...")

for (name, pixels) in iconSizes {
    let rep = renderIcon(size: pixels)
    let pngData = rep.representation(using: .png, properties: [:])!
    let filePath = "\(iconsetPath)/\(name).png"
    try pngData.write(to: URL(fileURLWithPath: filePath))
    print("  \(name).png (\(pixels)x\(pixels))")
}

print("Converting iconset to .icns...")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", "\(outputDir)/AppIcon-option2.icns"]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Success! Icon saved to \(outputDir)/AppIcon-option2.icns")
    try? fm.removeItem(atPath: iconsetPath)
} else {
    print("Error: iconutil failed with status \(process.terminationStatus)")
    exit(1)
}
