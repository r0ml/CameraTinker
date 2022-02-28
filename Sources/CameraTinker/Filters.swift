// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import CoreImage

/** These are various ways of getting a monochramatic image from a CIImage.  I thought that that might help identify barcodes more easily, but it did not seem to help.
 This extension is probably unused and not necessary.
 */
extension CIImage {
  public var monochrome : CIImage? {
    /*let ff = CIFilter.init(name: "CIColorControls", parameters: [
     kCIInputBrightnessKey: NSNumber(value: 0.0),
     kCIInputContrastKey: NSNumber(value: 1.1),
     kCIInputSaturationKey: NSNumber(value: 0.0)]
     )*/
    let ff = CIFilter.colorControls()
    ff.inputImage = self
    ff.brightness = 0
    ff.contrast = 1.1
    ff.saturation = 0
    let gg = ff.outputImage

    let hh = CIFilter.exposureAdjust()
    hh.inputImage = gg
    hh.ev = 0.5
    return hh.outputImage

  }

  public var mono : CIImage? {
    let ff = CIFilter.photoEffectMono()
    ff.inputImage = self
    return ff.outputImage
  }

  public var noir : CIImage? {
    let ff = CIFilter.photoEffectNoir()
    ff.inputImage = self
    return ff.outputImage
  }

  public var monoch : CIImage? {
    let ff = CIFilter.colorMonochrome()
    ff.inputImage = self
    ff.intensity = 1

    ff.color = CIColor.white
    return ff.outputImage
  }

  /// Calculates a score for how bright the image is.
  public var brightness : Float {
    get {
      let ff = CIFilter.init(name: "CIAreaAverage", parameters: ["inputImage": self ])!
      let oo = ff.outputImage!
      var bitmap = [UInt8](repeating: 0, count: 4)
      CIContext().render(oo, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x:0, y:0, width:1, height: 1), format: .Lf, colorSpace: CGColorSpaceCreateDeviceGray())
      let aa = Data.init(bytes: bitmap, count: 4)
      return aa.withUnsafeBytes { p in
        p.load(as: Float.self)
      }
    }
  }
}
