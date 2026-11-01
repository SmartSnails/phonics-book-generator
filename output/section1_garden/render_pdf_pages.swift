#!/usr/bin/env swift
import Foundation
import AppKit
import PDFKit

guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: render_pdf_pages.swift <input.pdf> <output_dir>\n", stderr)
    exit(1)
}

let pdfURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outDir = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

guard let doc = PDFDocument(url: pdfURL) else {
    fputs("ERROR: Cannot open PDF at \(pdfURL.path)\n", stderr)
    exit(2)
}

for i in 0..<doc.pageCount {
    guard let page = doc.page(at: i) else { continue }
    let bounds = page.bounds(for: .mediaBox)
    let scale: CGFloat = 2.0
    let w = Int(bounds.width * scale)
    let h = Int(bounds.height * scale)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: ctx)
    if let cgImg = ctx.makeImage() {
        let rep = NSBitmapImageRep(cgImage: cgImg)
        if let png = rep.representation(using: .png, properties: [:]) {
            let outFile = outDir.appendingPathComponent(String(format: "page_%02d.png", i + 1))
            try png.write(to: outFile)
        }
    }
}
print("Rendered \(doc.pageCount) PDF pages to \(outDir.path)")
