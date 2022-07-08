// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import CoreImage
import Accelerate
import AVFoundation

/// There is no way to store an image with data.  One can create a core graphics object -- but the creation and extraction of the depth data is AWFUL
/// So this is an object with stores an image and optionally associated depth data.  This makes it a good place to have the algorithm for modifying the image
/// with the depth data for a modified image.  I was doing this for capturing spines to improve recognition of the boundary -- but once I have done the clipping,
/// I want to use the original image.  The previous solution involved creating a modified image -- but then the clipping happened on that modified image and
/// the original image was lost.
public actor ImageWithDepth : Sendable {
  nonisolated public let image : CIImage
  public var depthData : AVDepthData? {
    if let dd = _depthData { return dd }
    if let di = _depth {
      return depthFromImage(di)
    }
    return nil
  }
  
  public var depth : CIImage? {
    if let di = _depth { return di }
    if let dd = _depthData {
      return CIImage(cvPixelBuffer: dd.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32).depthDataMap)
    }
    return nil
  }
  
  private let _depthData : AVDepthData?
  private let _depth : CIImage?
  
  public init(_ i : CIImage, depth: AVDepthData? = nil) {
    image = i
    self._depthData = depth
    self._depth = nil
  }
  
  public init(_ i : CIImage, depthImage: CIImage) {
    image = i
    self._depth = depthImage
    self._depthData = nil
  }
  
  func depthFromImage(_ ci : CIImage) -> AVDepthData? {
    var d = [ CFString : Any ]()
    
    // FIXME: if the pixelBuffer is nil, then render the image into a pixelBuffer to recover the pixels so I can create an AVDepthData
    let k = ci.pixelBuffer ?? ci.imageBuffer(kCVPixelFormatType_DepthFloat32)
    CVPixelBufferLockBaseAddress(k, .readOnly)
    let bb = CVPixelBufferGetBaseAddress(k)!
    let len = CVPixelBufferGetDataSize(k)
    let j = Data(bytes: bb, count: len)
    
    d[kCGImageAuxiliaryDataInfoData] = j as CFData
    var dd = [ CFString : Any ] ()
    dd[kCGImagePropertyPixelFormat] = NSNumber(value: CVPixelBufferGetPixelFormatType(k))
    dd[kCGImagePropertyWidth] = NSNumber(value: CVPixelBufferGetWidth(k))
    dd[kCGImagePropertyHeight] = NSNumber(value: CVPixelBufferGetHeight(k))
    dd[kCGImagePropertyBytesPerRow] = NSNumber(value: CVPixelBufferGetBytesPerRow(k))
    d[kCGImageAuxiliaryDataInfoDataDescription] = dd
    do {
      return try AVDepthData.init(fromDictionaryRepresentation: d)
    } catch(let e ) {
      fatalError("creating AVDepthData \(e.localizedDescription)")
    }
  }
  
  /** Given a CVPixelBuffer (assuming the values are all Floats), figure out the maximum and minumum values within a rectangle of CGSize centered in the image
   This is used on a depth buffer to find the minimum and maximum to provide a scaled fade.  When trying to locate the spine, the spine should be closer to the camera than anything else --
   and the non-spine part should fall away pretty rapidly.
   */
  func pixelRange(_ destSize : CGSize, _ depthPixelBuffer : CVPixelBuffer) -> (Float, Float) {
    // this crops the cvpixelbuffer directly
    var croppedBuffer : CVPixelBuffer?
    let bytesPerRow = CVPixelBufferGetBytesPerRow(depthPixelBuffer)
    let width = CVPixelBufferGetWidth(depthPixelBuffer)
    let height = CVPixelBufferGetHeight(depthPixelBuffer)
    let offset = ( CGFloat(height) - destSize.height) / 2 * CGFloat(bytesPerRow) + (CGFloat(width) - destSize.width) / 2 * 4
    let baseAddress = CVPixelBufferGetBaseAddress(depthPixelBuffer)!
    
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                 Int(destSize.width),
                                 Int(destSize.height),
                                 CVPixelBufferGetPixelFormatType(depthPixelBuffer),
                                 baseAddress.advanced(by: Int(offset)),
                                 CVPixelBufferGetBytesPerRow(depthPixelBuffer),
                                 nil, nil, nil,
                                 &croppedBuffer)
    
    CVPixelBufferLockBaseAddress(croppedBuffer!, .init(rawValue: 0))
    let count = Int(destSize.width) * Int(destSize.height)
    let pixelBufferBase = CVPixelBufferGetBaseAddress(croppedBuffer!)!.assumingMemoryBound(to: Float.self) // , to: UnsafeMutablePointer<Float>.self)
    let depthCopyBuffer = UnsafeMutableBufferPointer<Float>(start: pixelBufferBase, count: count)
    
    let maxValue = vDSP.maximum(depthCopyBuffer)
    let minValue = vDSP.minimum(depthCopyBuffer)
    CVPixelBufferUnlockBaseAddress(croppedBuffer!, .init(rawValue: 0))
    return (minValue, maxValue)
  }

  /*

  /// Modify the image by using the depth to make the high points pop

  public func prepImage() -> CIImage? {
    let theImage = image
    
    guard let depthPixelBuffer = depth?.pixelBuffer else { return nil}
    guard let _ /* videoPixelBuffer */ = theImage.pixelBuffer else { return nil }
    
    // Figure out the distance to the spine (the minimum depth value)
    CVPixelBufferLockBaseAddress(depthPixelBuffer, .init(rawValue: 0))
    
    let width = CVPixelBufferGetWidth(depthPixelBuffer)
    let height = CVPixelBufferGetHeight(depthPixelBuffer)
    
    let destSize = CGSize(width: CGFloat(width) /* * sweetSpot.width */ , height: CGFloat(height) /* * sweetSpot.height */ )
    
    var (minValue, maxValue) = pixelRange(destSize, depthPixelBuffer)
    let baseAddress = CVPixelBufferGetBaseAddress(depthPixelBuffer)!
    
    minValue = max(minValue, 0.175)
    minValue = min(minValue, 1.9)
    
    maxValue = min(maxValue, 2)
    
    let range = maxValue - minValue
    
    // Otherwise, I blow up
    guard minValue < maxValue else { return theImage }
    
    var depthBuffer = UnsafeMutableBufferPointer<Float>(start: baseAddress.assumingMemoryBound(to: Float.self), count: width * height)
    vDSP.clip(depthBuffer, to: minValue...maxValue, result: &depthBuffer)
    vDSP.add( -minValue, depthBuffer, result: &depthBuffer)
    vDSP.divide(depthBuffer, -range, result: &depthBuffer )
    vDSP.add(1, depthBuffer, result: &depthBuffer)
    // let croppedDepthImage = CIImage(cvPixelBuffer: croppedBuffer!)
    
    let normImage = CIImage(cvPixelBuffer: depthPixelBuffer)
    CVPixelBufferUnlockBaseAddress(depthPixelBuffer, .init(rawValue: 0))
    
    // Smooth edges to create an alpha matte, then upscale it to the RGB resolution.
    // let dd2 = dd0.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 3])
    // 1) clamp the depth image buffer to the range 0, 1?
    // 2) do a histogram equalisation
    
    /*      let am = CIFilter.areaMinimum()
     am.inputImage = alphaMatte
     am.extent = alphaMatte.extent
     let zz = am.outputImage!
     let ahi = cic.createCGImage(zz, from: zz.extent)!
     let d = ahi.dataProvider!.data! as Data
     //      (0..<16).forEach { print(d[$0]) }
     */
    
    let slope : CGFloat = 4.0
    //      let mpwidth : CGFloat = CGFloat(minValue) * 0.25 // was 0.1
    //      let focus : CGFloat = CGFloat(minValue) * 1.1
    
    let mpwidth : CGFloat = 0.2
    let focus : CGFloat = 1
    
    let s1 = slope
    //      let s2 = -slope
    let filterWidth =  2 / slope + mpwidth
    let b1 = -s1 * (focus - filterWidth / 2)
    //      let b2 = -s2 * (focus + filterWidth / 2)
    
    
    let blurRadius = 7
    
    let depthImage = normImage.clampedToExtent()
      .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": blurRadius])
    //       .applyingFilter("CIGammaAdjust", parameters: ["inputPower": gamma])
      .cropped(to: normImage.extent)
    
    
    // let depthImage = normImage
    
    let mask0 = depthImage
      .applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: s1, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0, y: s1, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: s1, w: 0),
        "inputBiasVector": CIVector(x: b1, y: b1, z: b1, w: 0)])
      .applyingFilter("CIColorClamp")
    
    /*      let mask1 = depthImage
     .applyingFilter("CIColorMatrix", parameters: [
     "inputRVector": CIVector(x: s2, y: 0, z: 0, w: 0),
     "inputGVector": CIVector(x: 0, y: s2, z: 0, w: 0),
     "inputBVector": CIVector(x: 0, y: 0, z: s2, w: 0),
     "inputBiasVector": CIVector(x: b2, y: b2, z: b2, w: 0)])
     .applyingFilter("CIColorClamp")
     
     let combinedMask = mask0.applyingFilter("CIDarkenBlendMode", parameters: [
     "inputBackgroundImage": mask1
     ])
     */
    let combinedMask = mask0
    
    
    // let gamma = 0.5
    let alphaUpscaleFactor = theImage.extent.width / combinedMask.extent.width
    
    let alphaMatte = combinedMask.applyingFilter("CIBicubicScaleTransform", parameters: ["inputScale": alphaUpscaleFactor])
    
    // Apply alpha matte to the video.
    var parameters = ["inputMaskImage": alphaMatte]
    parameters["inputImage"] = theImage
    parameters["inputBackgroundImage"] = CIImage.init(color: CIColor.white).cropped(to: theImage.extent)
    let output = theImage.applyingFilter("CIBlendWithMask", parameters: parameters) // .oriented(.right)
    
    /// The reason I did what follows is so that I would be able to update the texture for getting visual feedback the preview to show the modified image.
    /// For the release, I will be showing the actual image unmodified by depth.  But for debugging, it would be useful to see the modified image.
    /*
     //      if bufferCopy == nil || CVPixelBufferGetWidth(videoPixelBuffer) != CVPixelBufferGetWidth(bufferCopy!) {
     if bufferCopy == nil /* || cameraManager.frameTexture?.width != CVPixelBufferGetWidth(bufferCopy!) */ {
     print("data output synchronizer")
     let _ /* status */ = CVPixelBufferCreate(kCFAllocatorDefault, CVPixelBufferGetWidth(videoPixelBuffer), CVPixelBufferGetHeight(videoPixelBuffer), CVPixelBufferGetPixelFormatType(videoPixelBuffer), nil, &bufferCopy)
     }
     cic.render(output, to: bufferCopy!)
     return CIImage.init(cvPixelBuffer: bufferCopy!)
     */
    return output
  }
  */

  /// This can be used to save a picture at a known location, or also to append a timestamp to the name for storing multiple pictures disambiguated by time.
  public func savePicture(_ pfx : String, timeStamped: Bool) {
     let z3 = FileManager.default.url(forUbiquityContainerIdentifier: ubiquityStash)!.appendingPathComponent("Documents")
    if !FileManager.default.fileExists(atPath: z3.path) {
      try? FileManager.default.createDirectory(at: z3, withIntermediateDirectories: true, attributes: nil)
    }
    
    let dd = Date()
    let ddx = DateFormatter()
    ddx.dateFormat = "HH-mm-ss"
    let mmm = ddx.string(from: dd)
    
    let dd2 = DateFormatter()
    dd2.dateFormat = "yyyy-MM-dd"
    //    dd2.timeStyle = .none
    let mmx = dd2.string(from: dd)
    let fn = timeStamped ? "\(pfx)-\(mmx) \(mmm).heif" : "\(pfx).heif"
    let z4 = z3.appendingPathComponent(fn)
    
    let outputURL = z4 // URL.init(string: "test")
    guard let cgImageDestination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.heic.identifier as CFString, 1, nil) else {
      return
    }
    
    let context = CIContext(options: [:])
    //let dict: NSDictionary = [
    // kCGImageDestinationLossyCompressionQuality: 1.0,
    //   kCGImagePropertyIsFloat: true,
    // ]

    if let cgImage: CGImage = context.createCGImage(image, from: image.extent) {
      CGImageDestinationAddImage(cgImageDestination, cgImage, nil)
    }
    
    if let dd = depthData {
      var auxDataType: NSString?
      let auxData = dd.dictionaryRepresentation(forAuxiliaryDataType: &auxDataType)
      CGImageDestinationAddAuxiliaryDataInfo(cgImageDestination, auxDataType!, auxData! as CFDictionary)
    }
    CGImageDestinationFinalize(cgImageDestination)
  }

  convenience public init?(filename s : String) {
    var z3 = FileManager.default.url(forUbiquityContainerIdentifier: ubiquityStash)!.appendingPathComponent("Documents")
    z3.appendPathComponent(s)
    self.init(url: z3)
  }

  public init?(url: URL) {
    if
      let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
      if let auxiliaryInfoDict = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeDepth) as? [AnyHashable: Any],  // or Disparity
         let depthData = try? AVDepthData(fromDictionaryRepresentation: auxiliaryInfoDict)
      {
        self._depthData = depthData
        self._depth = nil
      } else {
        self._depthData = nil
        self._depth = nil
      }
      if let i = CGImageSourceCreateImageAtIndex(source, 0, nil) {
        self.image = CIImage(cgImage: i)
      } else {
        return nil
      }
    } else {
      return nil
    }
  }
}
