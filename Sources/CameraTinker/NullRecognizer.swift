// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import CoreGraphics

/** A `Recognizer` which does nothing */
public class NullRecognizer : RecognizerProtocol {
  public func scanImage(_ ciImage: ImageWithDepth) {
  }

  public init() {
  }

  public let sweetSpotSize = CGSize(width: 1, height: 1)

  public func isBusy() async -> Bool {
    return false
  }

  public typealias Recognized = ()

}
