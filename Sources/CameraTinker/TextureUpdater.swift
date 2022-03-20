// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Metal
import CoreVideo
import SceneKit
import CoreMedia

public class TextureUpdater : @unchecked Sendable {
  public let scenex = SCNScene()
  static let cic = CIContext(mtlDevice: device)
  static let device = MTLCreateSystemDefaultDevice()!

  static var frameTexture : MTLTexture?

  var thePixelFormat = MTLPixelFormat.bgra8Unorm   // could be bgra8Unorm_srgb
  var region : MTLRegion?

  public init() {
    scenex.background.contents = Self.frameTexture
  }

  private func setupTexture(_ s : CGSize) -> MTLTexture {
    log.debug("\(#function)")
    let w = Int(s.width)
    let h = Int(s.height)

    let ft = Self.frameTexture

    if ft == nil || ft?.height != h || ft?.width != w {
      log.debug("allocating texture \(w)x\(h)")

      let mtd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: thePixelFormat, width: w, height: h, mipmapped: false)

      // Need this for AR.  Not needed for Camera
      mtd.usage = [.shaderRead, .shaderWrite] // .pixelFormatView

      let tx = Self.device.makeTexture(descriptor: mtd)
      tx?.label = "texture for scene"
      tx?.setPurgeableState(.keepCurrent) // .nonVolatile

      scenex.background.contents = nil

      region = MTLRegionMake2D(0, 0, mtd.width, mtd.height)
      Self.frameTexture = tx

      scenex.background.contents = tx

#if os(macOS) || targetEnvironment(macCatalyst)
      // since the built in video mirroring seems to only work on the preview layer, and the preview layer doesn't work on ios,
      // I wind up manually doing the mirroring on macOS
      scenex.background.contentsTransform = SCNMatrix4MakeScale(-1, 1, 1)
#endif

    }
    return Self.frameTexture!
  }

  // I don't use the front camera -- it can't focus
  public func updateTextureBuffer(_ pixelBuffer : CVPixelBuffer) {
    let bpr = CVPixelBufferGetBytesPerRow(pixelBuffer)

    var ft = Self.frameTexture
    if ft == nil || ft!.width != CVPixelBufferGetWidth(pixelBuffer) || ft!.height != CVPixelBufferGetHeight(pixelBuffer) {
      ft = setupTexture( CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)) )
    }
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    if let dd = CVPixelBufferGetBaseAddress(pixelBuffer),
       let reg = region,
       let ft = ft {
      ft.replace(region: reg, mipmapLevel: 0, withBytes: dd, bytesPerRow: bpr)
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
  }

  public func updateTextureImage(_ d : CIImage) {
    let p = d
    let siz = p.extent.size
    var ft = Self.frameTexture
    if ft == nil || CGFloat(ft!.width) != siz.width || CGFloat(ft!.height) != siz.height {
      log.debug("setup texture \(siz.width)x\(siz.height)")
      ft = setupTexture(siz)
    }
    Self.cic.render(p, to: ft!, commandBuffer: nil, bounds: p.extent, colorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)! )
  }

}

