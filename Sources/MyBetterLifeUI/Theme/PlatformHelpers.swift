import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Cross-platform utilities for images and clipboard across macOS and iOS.
public enum PlatformHelpers {
    public static func swiftUIImage(from data: Data) -> Image? {
        #if os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #elseif os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }

    /// Copies plain text to the system clipboard on macOS and iOS.
    public static func copyToClipboard(_ text: String) {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
    }

    /// Reads an image from the system clipboard as PNG data if present.
    public static func pngDataFromClipboard() -> Data? {
        #if os(macOS)
        let pb = NSPasteboard.general
        if let image = NSImage(pasteboard: pb),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return png
        }
        return nil
        #elseif os(iOS)
        if let image = UIPasteboard.general.image {
            return image.pngData()
        }
        return nil
        #else
        return nil
        #endif
    }

    /// Compresses/normalizes raw image data to JPEG/PNG for efficient CloudKit external storage.
    public static func normalizedImageData(from rawData: Data, maxDimension: CGFloat = 1800) -> (data: Data, mimeType: String)? {
        #if os(macOS)
        guard let image = NSImage(data: rawData) else { return nil }
        let targetSize = scaledSize(image.size, maxDimension: maxDimension)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()
        if let tiff = resized.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
            return (jpeg, "image/jpeg")
        }
        return (rawData, "image/png")
        #elseif os(iOS)
        guard let image = UIImage(data: rawData) else { return nil }
        let targetSize = scaledSize(image.size, maxDimension: maxDimension)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        if let jpeg = resized.jpegData(compressionQuality: 0.85) {
            return (jpeg, "image/jpeg")
        }
        return (rawData, "image/png")
        #else
        return (rawData, "image/png")
        #endif
    }

    private static func scaledSize(_ size: CGSize, maxDimension: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: 800, height: 600) }
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return size }
        let ratio = maxDimension / longest
        return CGSize(width: (size.width * ratio).rounded(), height: (size.height * ratio).rounded())
    }
}
