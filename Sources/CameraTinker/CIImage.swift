// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import CoreImage
import SwiftUI
import Vision

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

fileprivate let ctx : CIContext = CIContext.init(options: nil)

extension CIImage {

  public var pngData : Data? {
    get {
      return ctx.pngRepresentation(of: self, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB)!, options: [:])
    }
  }

  public var tiffData : Data? {
    get {
      return ctx.tiffRepresentation(of: self, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB)!, options: [:])
    }
  }

  /*
  public var imageBuffer : CVImageBuffer {
    get {
      var pb : CVPixelBuffer?
      CVPixelBufferCreate(kCFAllocatorDefault,
                                   Int(extent.width),
                                   Int(extent.height),
                                   kCVPixelFormatType_32BGRA,
                                   nil,
                                   &pb)
      ctx.render(self, to: pb!)
      return pb!
    }
  }
*/

  public var floats : [[SIMD4<Float>]]? {
    get {
      let wh = self.extent
      var pb : CVPixelBuffer? = nil
      CVPixelBufferCreate(kCFAllocatorDefault, Int(wh.width), Int(wh.height), kCVPixelFormatType_32ARGB, nil, &pb)
      if let pb = pb {
        let flags = CVPixelBufferLockFlags(rawValue: 0)
        CVPixelBufferLockBaseAddress(pb, flags)
        ctx.render(self, to: pb)

        var byteBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(pb), to: UnsafeMutablePointer<SIMD4<Float32>>.self)
        var out : [[SIMD4<Float>]] = []
        let bpr = CVPixelBufferGetBytesPerRow(pb)

        for _ in 0..<Int(wh.height) {
          var rr = [SIMD4<Float>]()
          for col in 0..<Int(wh.width) {
            rr.append(byteBuffer[col])
          }
          byteBuffer = byteBuffer.advanced(by: bpr)
          out.append(rr)
        }
        CVPixelBufferUnlockBaseAddress(pb, flags)
        return out
      } else {
        return nil
      }

    }
  }


  public static func named(_ name: String) -> CIImage? {
    #if os(macOS)
    if let im = NSImage(named: name),
       let cg = im.cgImage(forProposedRect: nil, context: nil, hints: nil) {
      return CIImage.init(cgImage: cg)
    }
    return nil

    #else
    if let z = UIImage(named: name) { return CIImage(image: z) }
    else { return nil }
    #endif
  }

  public func imageBuffer(_ ft : OSType) -> CVImageBuffer {
    var pb : CVPixelBuffer?
      CVPixelBufferCreate(kCFAllocatorDefault,
                                   Int(extent.width),
                                   Int(extent.height),
                                   ft,
                                   nil,
                                   &pb)
      ctx.render(self, to: pb!)
      return pb!
    }


  public func unitCropped(to: CGRect) -> CIImage {
    let a = self.extent
    let b = to.minX * a.width
    let c = to.minY * a.height
    let d = to.width * a.width
    let e = to.height * a.height
    let f = CGRect(x: a.minX + b, y: a.minY + c, width: d, height: e)
    return self.cropped(to: f)
  }
}

/*
extension CGImage {
  public static func named(_ s: String) -> CGImage? {
    #if os(macOS)
    if let image = NSImage(named: s){
      return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    #else
    if let image = UIImage(named: s){
      return image.cgImage
    }
    #endif
    return nil
  }

  //1x1 pixel PNG
  // 137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,1,0,0,0,1,8,6,0,0,0,31,21,196,137,0,0,0,1,115,82,71,66,0,174,206,28,233,0,0,0,68,101,88,73,102,77,77,0,42,0,0,0,8,0,1,135,105,0,4,0,0,0,1,0,0,0,26,0,0,0,0,0,3,160,1,0,3,0,0,0,1,0,1,0,0,160,2,0,4,0,0,0,1,0,0,0,1,160,3,0,4,0,0,0,1,0,0,0,1,0,0,0,0,249,34,157,254,0,0,0,13,73,68,65,84,8,29,99,48,232,211,250,15,0,3,194,1,232,36,246,48,1,0,0,0,0,73,69,78,68,174,66,96,130

}
*/


extension Image {
#if os(iOS)
  public init(image: UIImage) {
    self.init(uiImage: image)
  }
#elseif os(macOS)
  public init(image: NSImage) {
    self.init(nsImage: image)
  }
#endif
}



extension SIMD4 {
  var debugDescription : String {
    return "SIMD4(\(self.x),\(self.y),\(self.z),\(self.w))"
  }

  var description : String {
    return "SIMD4(\(self.x),\(self.y),\(self.z),\(self.w))"
  }

}
