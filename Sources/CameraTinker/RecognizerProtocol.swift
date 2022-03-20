// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import CoreGraphics
import CoreImage
import Vision

public protocol RecognizerProtocol {

  /** This will perform whatever image processing is desired for this recognizer */
  func scanImage(_ ciImage: ImageWithDepth)

  /** This rectangle identifies the "sweet spot" of the preview:  the image will be clipped to that rectangle before being processed */
  var sweetSpotSize : CGSize { get }

  func isBusy() async -> Bool
}

extension RecognizerProtocol {
  public var sweetSpot : CGRect { get {
    let a = 1 - sweetSpotSize.width
    let b = 1 - sweetSpotSize.height
    return CGRect(origin: CGPoint(x: a / 2.0, y: b / 2.0) , size : sweetSpotSize)
  } }
}
