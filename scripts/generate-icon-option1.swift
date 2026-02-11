#!/usr/bin/env swift

import Cocoa
import CoreGraphics
import Foundation

// MARK: - Geometric Dog Head Icon Generator
// "Synth Dog" — a low-poly geometric dog head (German Shepherd / pointy-eared breed)
// rendered in warm amber/orange tones against a dark synth-inspired background.

// MARK: - Triangle Helper

struct Triangle {
    let p1: CGPoint
    let p2: CGPoint
    let p3: CGPoint
    let color: CGColor
}

func makeColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> CGColor {
    return CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                   components: [r, g, b, a])!
}

func lerpPoint(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
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

    // --- Background: rounded rect clip ---
    let iconRect = CGRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.22
    let bgPath = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    // Deep dark background gradient (radial) — #1A1A2E to #0F0D1E
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        makeColor(0.102, 0.102, 0.180, 1.0),  // #1A1A2E
        makeColor(0.059, 0.051, 0.118, 1.0),  // #0F0D1E
    ]
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(bgGradient,
                               startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: radius,
                               options: [.drawsAfterEndLocation])
    }

    // --- Subtle grid pattern ---
    ctx.saveGState()
    ctx.setStrokeColor(makeColor(0.15, 0.13, 0.25, 0.15))
    ctx.setLineWidth(0.5 * scale)
    let gridSpacing = 40.0 * scale
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

    // --- Subtle radial glow behind the dog ---
    ctx.saveGState()
    let glowColors = [
        makeColor(1.0, 0.55, 0.0, 0.15),
        makeColor(1.0, 0.42, 0.0, 0.05),
        makeColor(1.0, 0.42, 0.0, 0.0),
    ]
    if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors as CFArray,
                                  locations: [0.0, 0.5, 1.0]) {
        let glowCenter = CGPoint(x: s * 0.50, y: s * 0.52)
        ctx.drawRadialGradient(glowGrad,
                               startCenter: glowCenter, startRadius: 0,
                               endCenter: glowCenter, endRadius: s * 0.45,
                               options: [.drawsAfterEndLocation])
    }
    ctx.restoreGState()

    // --- Sound wave elements (subtle, behind the dog) ---
    drawSoundWaves(ctx: ctx, size: s, scale: scale)

    // --- Build the geometric dog head from triangles ---
    let triangles = buildDogTriangles(size: s, scale: scale)

    // Draw all triangles
    for tri in triangles {
        ctx.saveGState()
        ctx.setFillColor(tri.color)
        ctx.beginPath()
        ctx.move(to: tri.p1)
        ctx.addLine(to: tri.p2)
        ctx.addLine(to: tri.p3)
        ctx.closePath()
        ctx.fillPath()
        ctx.restoreGState()
    }

    // --- Draw subtle triangle edges for the faceted look ---
    ctx.saveGState()
    ctx.setStrokeColor(makeColor(0.0, 0.0, 0.0, 0.15))
    ctx.setLineWidth(0.5 * scale)
    for tri in triangles {
        ctx.beginPath()
        ctx.move(to: tri.p1)
        ctx.addLine(to: tri.p2)
        ctx.addLine(to: tri.p3)
        ctx.closePath()
        ctx.strokePath()
    }
    ctx.restoreGState()

    // --- Draw eyes ---
    drawEyes(ctx: ctx, size: s, scale: scale)

    // --- Draw nose ---
    drawNose(ctx: ctx, size: s, scale: scale)

    // --- Outer vignette ---
    ctx.saveGState()
    let vigColors = [
        makeColor(0.0, 0.0, 0.0, 0.0),
        makeColor(0.0, 0.0, 0.0, 0.0),
        makeColor(0.0, 0.0, 0.0, 0.5),
    ]
    if let vigGrad = CGGradient(colorsSpace: colorSpace, colors: vigColors as CFArray,
                                 locations: [0.0, 0.6, 1.0]) {
        ctx.drawRadialGradient(vigGrad,
                               startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: radius * 1.1,
                               options: [.drawsAfterEndLocation])
    }
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

// MARK: - Sound Waves

func drawSoundWaves(ctx: CGContext, size s: CGFloat, scale: CGFloat) {
    ctx.saveGState()

    // Waveform arcs emanating outward from center-bottom (dog's mouth area)
    let waveOrigin = CGPoint(x: s * 0.5, y: s * 0.28)

    for i in 0..<5 {
        let arcRadius = s * (0.32 + CGFloat(i) * 0.045)
        let alpha: CGFloat = 0.08 - CGFloat(i) * 0.012
        if alpha <= 0 { continue }

        ctx.setStrokeColor(makeColor(1.0, 0.55, 0.0, alpha))
        ctx.setLineWidth((2.0 - CGFloat(i) * 0.3) * scale)

        let startAngle: CGFloat = .pi * 0.15
        let endAngle: CGFloat = .pi * 0.85

        ctx.beginPath()
        ctx.addArc(center: waveOrigin, radius: arcRadius,
                   startAngle: startAngle, endAngle: endAngle, clockwise: false)
        ctx.strokePath()
    }

    // Small horizontal waveform lines at the sides
    for side in [-1.0, 1.0] as [CGFloat] {
        for i in 0..<4 {
            let y = s * (0.42 + CGFloat(i) * 0.04)
            let xBase = s * 0.5 + side * s * (0.34 + CGFloat(i) * 0.03)
            let waveLen = s * 0.06
            let amp = s * 0.008 * (1.0 - CGFloat(i) * 0.2)
            let alpha: CGFloat = 0.1 - CGFloat(i) * 0.02

            ctx.setStrokeColor(makeColor(1.0, 0.55, 0.0, alpha))
            ctx.setLineWidth(1.0 * scale)

            ctx.beginPath()
            let steps = 20
            for j in 0...steps {
                let t = CGFloat(j) / CGFloat(steps)
                let px = xBase + t * waveLen * side
                let py = y + sin(t * .pi * 4) * amp
                if j == 0 {
                    ctx.move(to: CGPoint(x: px, y: py))
                } else {
                    ctx.addLine(to: CGPoint(x: px, y: py))
                }
            }
            ctx.strokePath()
        }
    }

    ctx.restoreGState()
}

// MARK: - Build Dog Triangles (Low-Poly Geometric Head)

func buildDogTriangles(size s: CGFloat, scale: CGFloat) -> [Triangle] {
    var tris: [Triangle] = []

    // All coordinates defined relative to size `s`.
    // CoreGraphics origin is bottom-left; y increases upward.
    // Dog faces forward, head centered.

    // --- TOP OF HEAD / CROWN ---
    let crownTop       = CGPoint(x: s * 0.50, y: s * 0.82)
    let crownLeft      = CGPoint(x: s * 0.36, y: s * 0.78)
    let crownRight     = CGPoint(x: s * 0.64, y: s * 0.78)

    // --- EARS (pointy, prominent) ---
    let earLeftTip     = CGPoint(x: s * 0.18, y: s * 0.95)
    let earLeftOuter   = CGPoint(x: s * 0.20, y: s * 0.78)
    let earLeftInner   = CGPoint(x: s * 0.34, y: s * 0.82)
    let earLeftMidOuter = CGPoint(x: s * 0.17, y: s * 0.87)
    let earLeftMidInner = CGPoint(x: s * 0.27, y: s * 0.87)

    let earRightTip    = CGPoint(x: s * 0.82, y: s * 0.95)
    let earRightOuter  = CGPoint(x: s * 0.80, y: s * 0.78)
    let earRightInner  = CGPoint(x: s * 0.66, y: s * 0.82)
    let earRightMidOuter = CGPoint(x: s * 0.83, y: s * 0.87)
    let earRightMidInner = CGPoint(x: s * 0.73, y: s * 0.87)

    // --- FOREHEAD ---
    let foreheadCenter = CGPoint(x: s * 0.50, y: s * 0.76)
    let foreheadLeft   = CGPoint(x: s * 0.34, y: s * 0.72)
    let foreheadRight  = CGPoint(x: s * 0.66, y: s * 0.72)
    let browLeft       = CGPoint(x: s * 0.30, y: s * 0.68)
    let browRight      = CGPoint(x: s * 0.70, y: s * 0.68)
    let browCenter     = CGPoint(x: s * 0.50, y: s * 0.70)

    // --- CHEEKS / SIDES ---
    let cheekLeft      = CGPoint(x: s * 0.24, y: s * 0.58)
    let cheekRight     = CGPoint(x: s * 0.76, y: s * 0.58)
    let cheekLowLeft   = CGPoint(x: s * 0.28, y: s * 0.48)
    let cheekLowRight  = CGPoint(x: s * 0.72, y: s * 0.48)
    let sideLeft       = CGPoint(x: s * 0.26, y: s * 0.65)
    let sideRight      = CGPoint(x: s * 0.74, y: s * 0.65)

    // --- EYE AREA ---
    let eyeAreaTopLeft  = CGPoint(x: s * 0.35, y: s * 0.66)
    let eyeAreaTopRight = CGPoint(x: s * 0.65, y: s * 0.66)
    let eyeAreaBotLeft  = CGPoint(x: s * 0.34, y: s * 0.60)
    let eyeAreaBotRight = CGPoint(x: s * 0.66, y: s * 0.60)
    let eyeInnerLeft    = CGPoint(x: s * 0.42, y: s * 0.62)
    let eyeInnerRight   = CGPoint(x: s * 0.58, y: s * 0.62)
    let noseBridge      = CGPoint(x: s * 0.50, y: s * 0.60)

    // --- MUZZLE ---
    let muzzleTopLeft   = CGPoint(x: s * 0.38, y: s * 0.52)
    let muzzleTopRight  = CGPoint(x: s * 0.62, y: s * 0.52)
    let muzzleTopCenter = CGPoint(x: s * 0.50, y: s * 0.54)
    let muzzleSideLeft  = CGPoint(x: s * 0.34, y: s * 0.46)
    let muzzleSideRight = CGPoint(x: s * 0.66, y: s * 0.46)
    let muzzleMidLeft   = CGPoint(x: s * 0.40, y: s * 0.44)
    let muzzleMidRight  = CGPoint(x: s * 0.60, y: s * 0.44)
    let muzzleMidCenter = CGPoint(x: s * 0.50, y: s * 0.46)

    // --- NOSE ---
    let noseTop         = CGPoint(x: s * 0.50, y: s * 0.48)
    let noseLeft        = CGPoint(x: s * 0.44, y: s * 0.44)
    let noseRight       = CGPoint(x: s * 0.56, y: s * 0.44)
    let noseBottom      = CGPoint(x: s * 0.50, y: s * 0.42)

    // --- MOUTH / CHIN ---
    let mouthLeft       = CGPoint(x: s * 0.42, y: s * 0.38)
    let mouthRight      = CGPoint(x: s * 0.58, y: s * 0.38)
    let mouthCenter     = CGPoint(x: s * 0.50, y: s * 0.39)
    let chinCenter      = CGPoint(x: s * 0.50, y: s * 0.32)
    let chinLeft        = CGPoint(x: s * 0.40, y: s * 0.34)
    let chinRight       = CGPoint(x: s * 0.60, y: s * 0.34)
    let jawLeft         = CGPoint(x: s * 0.32, y: s * 0.40)
    let jawRight        = CGPoint(x: s * 0.68, y: s * 0.40)

    // --- Color Palette ---
    let brightAmber     = makeColor(1.00, 0.55, 0.00)  // #FF8C00
    let gold            = makeColor(1.00, 0.70, 0.28)  // #FFB347
    let deepOrange      = makeColor(1.00, 0.42, 0.00)  // #FF6B00
    let darkAmber       = makeColor(0.75, 0.38, 0.00)
    let darkOrangeBrown = makeColor(0.55, 0.28, 0.05)
    let shadowBrown     = makeColor(0.40, 0.20, 0.05)
    let lightGold       = makeColor(1.00, 0.80, 0.40)
    let midAmber        = makeColor(0.90, 0.50, 0.05)
    let warmHighlight   = makeColor(1.00, 0.85, 0.50)
    let darkShadow      = makeColor(0.30, 0.15, 0.05)
    let earInnerPink    = makeColor(0.80, 0.40, 0.25)
    let noseDark        = makeColor(0.15, 0.10, 0.08)
    let noseHighlight   = makeColor(0.30, 0.22, 0.18)

    // ============================================================
    // LEFT EAR
    // ============================================================
    tris.append(Triangle(p1: earLeftOuter, p2: earLeftMidOuter, p3: earLeftMidInner,
                          color: darkOrangeBrown))
    tris.append(Triangle(p1: earLeftOuter, p2: earLeftMidInner, p3: crownLeft,
                          color: shadowBrown))
    tris.append(Triangle(p1: earLeftMidOuter, p2: earLeftTip, p3: earLeftMidInner,
                          color: darkAmber))
    tris.append(Triangle(p1: earLeftMidInner, p2: earLeftTip, p3: earLeftInner,
                          color: earInnerPink))
    tris.append(Triangle(p1: earLeftMidInner, p2: earLeftInner, p3: crownLeft,
                          color: darkAmber))

    // ============================================================
    // RIGHT EAR
    // ============================================================
    tris.append(Triangle(p1: earRightOuter, p2: earRightMidOuter, p3: earRightMidInner,
                          color: darkOrangeBrown))
    tris.append(Triangle(p1: earRightOuter, p2: earRightMidInner, p3: crownRight,
                          color: shadowBrown))
    tris.append(Triangle(p1: earRightMidOuter, p2: earRightTip, p3: earRightMidInner,
                          color: darkAmber))
    tris.append(Triangle(p1: earRightMidInner, p2: earRightTip, p3: earRightInner,
                          color: earInnerPink))
    tris.append(Triangle(p1: earRightMidInner, p2: earRightInner, p3: crownRight,
                          color: darkAmber))

    // ============================================================
    // CROWN / TOP OF HEAD
    // ============================================================
    tris.append(Triangle(p1: crownLeft, p2: crownTop, p3: foreheadCenter,
                          color: brightAmber))
    tris.append(Triangle(p1: crownTop, p2: crownRight, p3: foreheadCenter,
                          color: gold))
    tris.append(Triangle(p1: crownLeft, p2: earLeftInner, p3: crownTop,
                          color: midAmber))
    tris.append(Triangle(p1: crownRight, p2: earRightInner, p3: crownTop,
                          color: midAmber))

    // ============================================================
    // FOREHEAD
    // ============================================================
    tris.append(Triangle(p1: crownLeft, p2: foreheadCenter, p3: foreheadLeft,
                          color: deepOrange))
    tris.append(Triangle(p1: crownRight, p2: foreheadCenter, p3: foreheadRight,
                          color: brightAmber))
    tris.append(Triangle(p1: foreheadLeft, p2: foreheadCenter, p3: browCenter,
                          color: gold))
    tris.append(Triangle(p1: foreheadRight, p2: foreheadCenter, p3: browCenter,
                          color: lightGold))
    tris.append(Triangle(p1: foreheadLeft, p2: browCenter, p3: browLeft,
                          color: midAmber))
    tris.append(Triangle(p1: foreheadRight, p2: browCenter, p3: browRight,
                          color: brightAmber))

    // ============================================================
    // SIDES OF HEAD
    // ============================================================
    tris.append(Triangle(p1: crownLeft, p2: foreheadLeft, p3: sideLeft,
                          color: darkAmber))
    tris.append(Triangle(p1: crownLeft, p2: sideLeft, p3: earLeftOuter,
                          color: shadowBrown))
    tris.append(Triangle(p1: sideLeft, p2: browLeft, p3: foreheadLeft,
                          color: darkOrangeBrown))
    tris.append(Triangle(p1: sideLeft, p2: cheekLeft, p3: browLeft,
                          color: darkAmber))

    tris.append(Triangle(p1: crownRight, p2: foreheadRight, p3: sideRight,
                          color: darkAmber))
    tris.append(Triangle(p1: crownRight, p2: sideRight, p3: earRightOuter,
                          color: shadowBrown))
    tris.append(Triangle(p1: sideRight, p2: browRight, p3: foreheadRight,
                          color: darkOrangeBrown))
    tris.append(Triangle(p1: sideRight, p2: cheekRight, p3: browRight,
                          color: darkAmber))

    // ============================================================
    // EYE REGION
    // ============================================================
    tris.append(Triangle(p1: browLeft, p2: eyeAreaTopLeft, p3: browCenter,
                          color: darkAmber))
    tris.append(Triangle(p1: browLeft, p2: cheekLeft, p3: eyeAreaBotLeft,
                          color: darkOrangeBrown))
    tris.append(Triangle(p1: browLeft, p2: eyeAreaBotLeft, p3: eyeAreaTopLeft,
                          color: shadowBrown))
    tris.append(Triangle(p1: eyeAreaTopLeft, p2: eyeInnerLeft, p3: browCenter,
                          color: darkAmber))
    tris.append(Triangle(p1: eyeAreaTopLeft, p2: eyeAreaBotLeft, p3: eyeInnerLeft,
                          color: darkOrangeBrown))
    tris.append(Triangle(p1: eyeInnerLeft, p2: eyeAreaBotLeft, p3: noseBridge,
                          color: shadowBrown))
    tris.append(Triangle(p1: eyeInnerLeft, p2: noseBridge, p3: browCenter,
                          color: midAmber))

    tris.append(Triangle(p1: browRight, p2: eyeAreaTopRight, p3: browCenter,
                          color: darkAmber))
    tris.append(Triangle(p1: browRight, p2: cheekRight, p3: eyeAreaBotRight,
                          color: darkOrangeBrown))
    tris.append(Triangle(p1: browRight, p2: eyeAreaBotRight, p3: eyeAreaTopRight,
                          color: shadowBrown))
    tris.append(Triangle(p1: eyeAreaTopRight, p2: eyeInnerRight, p3: browCenter,
                          color: darkAmber))
    tris.append(Triangle(p1: eyeAreaTopRight, p2: eyeAreaBotRight, p3: eyeInnerRight,
                          color: darkOrangeBrown))
    tris.append(Triangle(p1: eyeInnerRight, p2: eyeAreaBotRight, p3: noseBridge,
                          color: shadowBrown))
    tris.append(Triangle(p1: eyeInnerRight, p2: noseBridge, p3: browCenter,
                          color: midAmber))

    // ============================================================
    // MUZZLE / SNOUT
    // ============================================================
    tris.append(Triangle(p1: noseBridge, p2: eyeAreaBotLeft, p3: muzzleTopLeft,
                          color: gold))
    tris.append(Triangle(p1: noseBridge, p2: muzzleTopLeft, p3: muzzleTopCenter,
                          color: lightGold))
    tris.append(Triangle(p1: noseBridge, p2: muzzleTopCenter, p3: muzzleTopRight,
                          color: warmHighlight))
    tris.append(Triangle(p1: noseBridge, p2: muzzleTopRight, p3: eyeAreaBotRight,
                          color: gold))

    tris.append(Triangle(p1: cheekLeft, p2: cheekLowLeft, p3: eyeAreaBotLeft,
                          color: darkAmber))
    tris.append(Triangle(p1: cheekLowLeft, p2: muzzleTopLeft, p3: eyeAreaBotLeft,
                          color: midAmber))
    tris.append(Triangle(p1: cheekRight, p2: cheekLowRight, p3: eyeAreaBotRight,
                          color: darkAmber))
    tris.append(Triangle(p1: cheekLowRight, p2: muzzleTopRight, p3: eyeAreaBotRight,
                          color: midAmber))

    tris.append(Triangle(p1: muzzleTopLeft, p2: muzzleSideLeft, p3: muzzleMidLeft,
                          color: brightAmber))
    tris.append(Triangle(p1: muzzleTopLeft, p2: muzzleMidLeft, p3: muzzleMidCenter,
                          color: gold))
    tris.append(Triangle(p1: muzzleTopLeft, p2: muzzleMidCenter, p3: muzzleTopCenter,
                          color: lightGold))
    tris.append(Triangle(p1: muzzleTopCenter, p2: muzzleMidCenter, p3: muzzleTopRight,
                          color: warmHighlight))
    tris.append(Triangle(p1: muzzleTopRight, p2: muzzleMidCenter, p3: muzzleMidRight,
                          color: gold))
    tris.append(Triangle(p1: muzzleTopRight, p2: muzzleMidRight, p3: muzzleSideRight,
                          color: brightAmber))

    tris.append(Triangle(p1: cheekLowLeft, p2: muzzleSideLeft, p3: muzzleTopLeft,
                          color: deepOrange))
    tris.append(Triangle(p1: cheekLowLeft, p2: jawLeft, p3: muzzleSideLeft,
                          color: darkAmber))
    tris.append(Triangle(p1: cheekLowRight, p2: muzzleSideRight, p3: muzzleTopRight,
                          color: deepOrange))
    tris.append(Triangle(p1: cheekLowRight, p2: jawRight, p3: muzzleSideRight,
                          color: darkAmber))

    // Nose area
    tris.append(Triangle(p1: muzzleMidCenter, p2: noseTop, p3: muzzleMidLeft,
                          color: lightGold))
    tris.append(Triangle(p1: muzzleMidCenter, p2: muzzleMidRight, p3: noseTop,
                          color: lightGold))
    tris.append(Triangle(p1: noseTop, p2: noseLeft, p3: noseBottom,
                          color: noseDark))
    tris.append(Triangle(p1: noseTop, p2: noseBottom, p3: noseRight,
                          color: noseHighlight))
    tris.append(Triangle(p1: muzzleMidLeft, p2: noseTop, p3: noseLeft,
                          color: gold))
    tris.append(Triangle(p1: muzzleMidRight, p2: noseRight, p3: noseTop,
                          color: gold))

    // ============================================================
    // LOWER MUZZLE / MOUTH / CHIN
    // ============================================================
    tris.append(Triangle(p1: noseLeft, p2: noseBottom, p3: mouthLeft,
                          color: midAmber))
    tris.append(Triangle(p1: noseRight, p2: noseBottom, p3: mouthRight,
                          color: brightAmber))
    tris.append(Triangle(p1: noseBottom, p2: mouthLeft, p3: mouthCenter,
                          color: darkAmber))
    tris.append(Triangle(p1: noseBottom, p2: mouthCenter, p3: mouthRight,
                          color: darkAmber))

    tris.append(Triangle(p1: muzzleSideLeft, p2: jawLeft, p3: mouthLeft,
                          color: darkOrangeBrown))
    tris.append(Triangle(p1: muzzleSideLeft, p2: mouthLeft, p3: noseLeft,
                          color: midAmber))
    tris.append(Triangle(p1: muzzleSideRight, p2: jawRight, p3: mouthRight,
                          color: darkOrangeBrown))
    tris.append(Triangle(p1: muzzleSideRight, p2: mouthRight, p3: noseRight,
                          color: midAmber))

    // Chin
    tris.append(Triangle(p1: mouthLeft, p2: mouthCenter, p3: chinLeft,
                          color: darkAmber))
    tris.append(Triangle(p1: mouthCenter, p2: mouthRight, p3: chinRight,
                          color: shadowBrown))
    tris.append(Triangle(p1: mouthCenter, p2: chinLeft, p3: chinCenter,
                          color: darkOrangeBrown))
    tris.append(Triangle(p1: mouthCenter, p2: chinCenter, p3: chinRight,
                          color: darkOrangeBrown))
    tris.append(Triangle(p1: jawLeft, p2: chinLeft, p3: mouthLeft,
                          color: shadowBrown))
    tris.append(Triangle(p1: jawRight, p2: chinRight, p3: mouthRight,
                          color: shadowBrown))
    tris.append(Triangle(p1: jawLeft, p2: chinCenter, p3: chinLeft,
                          color: darkShadow))
    tris.append(Triangle(p1: jawRight, p2: chinCenter, p3: chinRight,
                          color: darkShadow))

    return tris
}

// MARK: - Eyes

func drawEyes(ctx: CGContext, size s: CGFloat, scale: CGFloat) {
    let leftEyeCenter = CGPoint(x: s * 0.39, y: s * 0.635)
    let rightEyeCenter = CGPoint(x: s * 0.61, y: s * 0.635)
    let eyeWidth = s * 0.055
    let eyeHeight = s * 0.035

    for eyeCenter in [leftEyeCenter, rightEyeCenter] {
        // Eye glow
        ctx.saveGState()
        let glowColors = [
            makeColor(1.0, 0.85, 0.2, 0.4),
            makeColor(1.0, 0.65, 0.0, 0.1),
            makeColor(1.0, 0.65, 0.0, 0.0),
        ]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors as CFArray,
                                      locations: [0.0, 0.5, 1.0]) {
            ctx.drawRadialGradient(glowGrad,
                                   startCenter: eyeCenter, startRadius: 0,
                                   endCenter: eyeCenter, endRadius: eyeWidth * 1.5,
                                   options: [])
        }
        ctx.restoreGState()

        // Eye diamond shape (dark)
        ctx.saveGState()
        ctx.setFillColor(makeColor(0.08, 0.05, 0.02))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: eyeCenter.x - eyeWidth, y: eyeCenter.y))
        ctx.addLine(to: CGPoint(x: eyeCenter.x, y: eyeCenter.y + eyeHeight))
        ctx.addLine(to: CGPoint(x: eyeCenter.x + eyeWidth, y: eyeCenter.y))
        ctx.addLine(to: CGPoint(x: eyeCenter.x, y: eyeCenter.y - eyeHeight))
        ctx.closePath()
        ctx.fillPath()
        ctx.restoreGState()

        // Bright pupil / iris
        ctx.saveGState()
        let pupilRadius = eyeWidth * 0.4
        ctx.setFillColor(makeColor(1.0, 0.75, 0.1, 0.9))
        ctx.fillEllipse(in: CGRect(x: eyeCenter.x - pupilRadius,
                                    y: eyeCenter.y - pupilRadius,
                                    width: pupilRadius * 2,
                                    height: pupilRadius * 2))
        // Inner pupil (dark)
        let innerRadius = pupilRadius * 0.45
        ctx.setFillColor(makeColor(0.05, 0.03, 0.01))
        ctx.fillEllipse(in: CGRect(x: eyeCenter.x - innerRadius,
                                    y: eyeCenter.y - innerRadius,
                                    width: innerRadius * 2,
                                    height: innerRadius * 2))
        // Eye highlight
        let hlRadius = pupilRadius * 0.2
        let hlOffset = pupilRadius * 0.25
        ctx.setFillColor(makeColor(1.0, 1.0, 1.0, 0.7))
        ctx.fillEllipse(in: CGRect(x: eyeCenter.x - hlOffset - hlRadius,
                                    y: eyeCenter.y + hlOffset - hlRadius,
                                    width: hlRadius * 2,
                                    height: hlRadius * 2))
        ctx.restoreGState()
    }
}

// MARK: - Nose

func drawNose(ctx: CGContext, size s: CGFloat, scale: CGFloat) {
    let noseCenter = CGPoint(x: s * 0.50, y: s * 0.45)
    let shineRadius = s * 0.015

    ctx.saveGState()
    let shineColors = [
        makeColor(1.0, 1.0, 1.0, 0.15),
        makeColor(1.0, 1.0, 1.0, 0.0),
    ]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    if let shineGrad = CGGradient(colorsSpace: colorSpace, colors: shineColors as CFArray,
                                   locations: [0.0, 1.0]) {
        let shineCenter = CGPoint(x: noseCenter.x - s * 0.008, y: noseCenter.y + s * 0.008)
        ctx.drawRadialGradient(shineGrad,
                               startCenter: shineCenter, startRadius: 0,
                               endCenter: shineCenter, endRadius: shineRadius,
                               options: [])
    }
    ctx.restoreGState()
}

// MARK: - PNG / ICNS Generation

func savePNG(image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to create PNG data")
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("  Saved: \(path)")
    } catch {
        fatalError("Failed to write PNG: \(error)")
    }
}

func main() {
    let outputDir = "/Users/andysmith/projects/Grainulator/Resources/Assets"
    let iconsetDir = "\(outputDir)/AppIcon-option1.iconset"
    let icnsPath = "\(outputDir)/AppIcon-option1.icns"

    // Create iconset directory
    let fm = FileManager.default
    try? fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

    // Required icon sizes for .icns
    let sizes: [(name: String, size: Int)] = [
        ("icon_16x16",        16),
        ("icon_16x16@2x",     32),
        ("icon_32x32",        32),
        ("icon_32x32@2x",     64),
        ("icon_128x128",     128),
        ("icon_128x128@2x",  256),
        ("icon_256x256",     256),
        ("icon_256x256@2x",  512),
        ("icon_512x512",     512),
        ("icon_512x512@2x", 1024),
    ]

    print("Generating Synth Dog icon (geometric low-poly style)...")
    print()

    // Generate master 1024x1024 first
    print("Rendering master 1024x1024...")
    let master = generateIcon(size: 1024)
    let masterPath = "\(outputDir)/AppIcon-option1-1024.png"
    savePNG(image: master, to: masterPath)
    print()

    // Generate all iconset sizes
    print("Generating iconset sizes...")
    for entry in sizes {
        let img = generateIcon(size: entry.size)
        let path = "\(iconsetDir)/\(entry.name).png"
        savePNG(image: img, to: path)
    }
    print()

    // Convert to .icns using iconutil
    print("Converting to .icns...")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconsetDir, "-o", icnsPath]

    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            print("Successfully created: \(icnsPath)")
        } else {
            print("iconutil failed with exit code \(process.terminationStatus)")
        }
    } catch {
        print("Failed to run iconutil: \(error)")
    }

    // Clean up iconset directory
    try? fm.removeItem(atPath: iconsetDir)
    print()
    print("Done! Files created:")
    print("  Master PNG: \(masterPath)")
    print("  ICNS:       \(icnsPath)")
}

main()
