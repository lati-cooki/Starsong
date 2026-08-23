#!/usr/bin/env swift
// Renders Starsong's app icon: a night sky with a rising melody drawn across it.
// Usage: swift Tools/make-icon.swift [output.png]

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024.0
let output = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "Sources/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")

let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(data: nil, width: Int(side), height: Int(side),
                          bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("could not create a bitmap context")
}

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}
func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * side, y: (1 - y) * side) }

// Night gradient (top is dark, bottom warmer indigo).
let night = CGGradient(colorsSpace: space,
                       colors: [rgb(0.11, 0.08, 0.25), rgb(0.03, 0.03, 0.10)] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(night, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: side), options: [])

// Nebula bloom.
let bloom = CGGradient(colorsSpace: space,
                       colors: [rgb(1.0, 0.60, 0.76, 0.22), rgb(1.0, 0.60, 0.76, 0)] as CFArray,
                       locations: [0, 1])!
ctx.drawRadialGradient(bloom, startCenter: p(0.70, 0.72), startRadius: 0,
                       endCenter: p(0.70, 0.72), endRadius: side * 0.55, options: [])

// Field stars — deterministic so the icon never changes between builds.
var seed: UInt64 = 0x5741_5254_534F_4E47
func rnd() -> Double {
    seed &+= 0x9E37_79B9_7F4A_7C15
    var z = seed
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    z = z ^ (z >> 31)
    return Double(z >> 11) / Double(1 << 53)
}
for _ in 0..<150 {
    let c = p(rnd(), rnd())
    let r = 1.5 + rnd() * 5
    ctx.setFillColor(rgb(0.86, 0.88, 1.0, 0.25 + rnd() * 0.6))
    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
}

// The melody: a line rising across the sky.
let notes = [p(0.22, 0.34), p(0.36, 0.58), p(0.51, 0.46), p(0.66, 0.71), p(0.79, 0.55)]
let gold = rgb(0.96, 0.86, 0.54)

ctx.setShadow(offset: .zero, blur: 34, color: rgb(0.96, 0.86, 0.54, 0.75))
ctx.setStrokeColor(rgb(0.96, 0.86, 0.54, 0.85))
ctx.setLineWidth(9)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.addLines(between: notes)
ctx.strokePath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

for (i, note) in notes.enumerated() {
    let r = i == 3 ? 30.0 : 22.0
    let halo = CGGradient(colorsSpace: space,
                          colors: [rgb(0.96, 0.86, 0.54, 0.55), rgb(0.96, 0.86, 0.54, 0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(halo, startCenter: note, startRadius: r * 0.6,
                           endCenter: note, endRadius: r * 4.2, options: [])
    ctx.setFillColor(gold)
    ctx.fillEllipse(in: CGRect(x: note.x - r, y: note.y - r, width: r * 2, height: r * 2))
    ctx.setFillColor(rgb(1, 1, 1, 0.9))
    ctx.fillEllipse(in: CGRect(x: note.x - r * 0.35, y: note.y - r * 0.35,
                               width: r * 0.7, height: r * 0.7))
}

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("could not encode the icon") }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(output.path)") }
print("wrote \(output.path)")
