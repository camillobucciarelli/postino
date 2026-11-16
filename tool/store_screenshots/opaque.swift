// Riscrive i PNG passati senza canale alfa (App Store Connect rifiuta gli screenshot con alfa), in sRGB.
// Uso: swift tool/store_screenshots/opaque.swift file.png...
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

for path in CommandLine.arguments.dropFirst() {
  let url = URL(fileURLWithPath: path) as CFURL
  guard let source = CGImageSourceCreateWithURL(url, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
    let srgb = CGColorSpace(name: CGColorSpace.sRGB),
    let context = CGContext(
      data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
  else { fatalError("non leggo \(path)") }
  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
  guard let opaque = context.makeImage(),
    let out = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)
  else { fatalError("non scrivo \(path)") }
  CGImageDestinationAddImage(out, opaque, nil)
  guard CGImageDestinationFinalize(out) else { fatalError("non scrivo \(path)") }
}
