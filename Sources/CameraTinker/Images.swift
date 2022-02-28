// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import CoreImage.CIFilterBuiltins
import SwiftUI

fileprivate let ctx : CIContext = CIContext.init(options: nil)

#if os(iOS)
import UIKit
public typealias XImage = UIImage

extension UIImage {
  /// Create a UIImage from fthe contents of a file
  public convenience init?(contentsOf u: URL) {
    self.init(contentsOfFile: u.path)
  }

  /// Create a UIImage from a CIImage
  public convenience init(ciImage ci: CIImage) {
    if let cg = ctx.createCGImage(ci, from: ci.extent) {
      self.init(cgImage: cg)
      return
    }
    fatalError("creating UIImage from CIImage")
  }
}

extension CIImage {
  /// Create a ciImage from a UIImage
  public convenience init?(xImage x : XImage) {
    self.init(image: x)
  }
}
#endif

#if os(macOS)

import AppKit
public typealias XImage = NSImage

extension NSImage {
  /// Create an NSImage from a CIImage
  public convenience init(ciImage ci: CIImage ) {
    if let cg = ctx.createCGImage(ci, from: ci.extent) {
      self.init(cgImage: cg, size: CGSize(width: cg.width, height: cg.height))
      return
    }
    fatalError("creating NSImage from CIImage")
  }
}

extension CIImage {
  /// Create a CIImage from an NSImage
  public convenience init?(xImage x : XImage ) {
    if let tiffData = x.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data:tiffData) {
      self.init(bitmapImageRep: bitmap)
    } else {
      return nil
    }
  }
}
#endif

extension Image {
  /// Create a SwiftUI Image View from a CIImage
  public static func with(ciImage i : CIImage) -> some View {
    let b = XImage(ciImage: i)
    return Image(image: b)
      .resizable().scaledToFit()
  }
}

extension CGImage {
  /// I need a blank image to initialize the spine preview to.  It should immediately be replaced by a real image
  public static var blankCG : CGImage = {
    var d = Data([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
    let ctx = d.withUnsafeMutableBytes { (n) -> CGContext in
      CGContext.init(data: n.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4 , space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: 1)!
    }
    ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 0)
    let j = ctx.makeImage()!
    return j
  }()
}

