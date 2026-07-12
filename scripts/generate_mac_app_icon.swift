import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: swift scripts/generate_mac_app_icon.swift /path/source.png /path/AppIcon.appiconset")
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let side = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))

guard
    let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
    let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    fatalError("Unable to read source image at \(sourceURL.path)")
}

func makeCanvas(size: Int) -> [UInt8] {
    var pixels = [UInt8](repeating: 0, count: size * size * 4)
    pixels.withUnsafeMutableBytes { rawBuffer in
        guard let context = CGContext(
            data: rawBuffer.baseAddress,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            fatalError("Unable to create bitmap context")
        }
        context.clear(CGRect(x: 0, y: 0, width: size, height: size))
        context.interpolationQuality = .high
        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: size, height: size))
    }
    return pixels
}

func isWhiteEdgeCandidate(_ pixels: [UInt8], offset: Int) -> Bool {
    let red = Int(pixels[offset])
    let green = Int(pixels[offset + 1])
    let blue = Int(pixels[offset + 2])
    let alpha = Int(pixels[offset + 3])
    let high = max(red, green, blue)
    let low = min(red, green, blue)
    return alpha > 0 && red > 232 && green > 232 && blue > 232 && high - low < 18
}

func removeConnectedWhiteEdge(from pixels: inout [UInt8], size: Int) {
    var visited = [Bool](repeating: false, count: size * size)
    var queue: [Int] = []
    queue.reserveCapacity(size * 4)

    func enqueue(_ index: Int) {
        guard !visited[index] else { return }
        let offset = index * 4
        guard isWhiteEdgeCandidate(pixels, offset: offset) else { return }
        visited[index] = true
        queue.append(index)
    }

    for x in 0..<size {
        enqueue(x)
        enqueue((size - 1) * size + x)
    }
    for y in 0..<size {
        enqueue(y * size)
        enqueue(y * size + size - 1)
    }

    var cursor = 0
    while cursor < queue.count {
        let index = queue[cursor]
        cursor += 1
        let x = index % size
        let y = index / size
        if x > 0 { enqueue(index - 1) }
        if x + 1 < size { enqueue(index + 1) }
        if y > 0 { enqueue(index - size) }
        if y + 1 < size { enqueue(index + size) }
    }

    for index in queue {
        let offset = index * 4
        pixels[offset + 3] = 0
    }
}

func image(from pixels: [UInt8], size: Int) -> CGImage {
    let data = Data(pixels) as CFData
    guard
        let provider = CGDataProvider(data: data),
        let image = CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    else {
        fatalError("Unable to create CGImage")
    }
    return image
}

func resized(_ sourceImage: CGImage, to size: Int) -> CGImage {
    var pixels = [UInt8](repeating: 0, count: size * size * 4)
    pixels.withUnsafeMutableBytes { rawBuffer in
        guard let context = CGContext(
            data: rawBuffer.baseAddress,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            fatalError("Unable to create resize context")
        }
        context.clear(CGRect(x: 0, y: 0, width: size, height: size))
        context.interpolationQuality = .high
        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: size, height: size))
    }
    return image(from: pixels, size: size)
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Unable to create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Unable to write \(url.path)")
    }
}

let fileManager = FileManager.default
try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

var basePixels = makeCanvas(size: side)
removeConnectedWhiteEdge(from: &basePixels, size: side)
let baseImage = image(from: basePixels, size: side)

let entries: [(logicalSize: String, scale: String, pixels: Int, fileName: String)] = [
    ("16x16", "1x", 16, "icon_16x16.png"),
    ("16x16", "2x", 32, "icon_16x16@2x.png"),
    ("32x32", "1x", 32, "icon_32x32.png"),
    ("32x32", "2x", 64, "icon_32x32@2x.png"),
    ("128x128", "1x", 128, "icon_128x128.png"),
    ("128x128", "2x", 256, "icon_128x128@2x.png"),
    ("256x256", "1x", 256, "icon_256x256.png"),
    ("256x256", "2x", 512, "icon_256x256@2x.png"),
    ("512x512", "1x", 512, "icon_512x512.png"),
    ("512x512", "2x", 1024, "icon_512x512@2x.png")
]

for entry in entries {
    try writePNG(resized(baseImage, to: entry.pixels), to: outputURL.appendingPathComponent(entry.fileName))
}

let imageJSON = entries
    .map { entry in
        """
            {
              "filename" : "\(entry.fileName)",
              "idiom" : "mac",
              "scale" : "\(entry.scale)",
              "size" : "\(entry.logicalSize)"
            }
        """
    }
    .joined(separator: ",\n")

let contents = """
{
  "images" : [
\(imageJSON)
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

try contents.write(to: outputURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
