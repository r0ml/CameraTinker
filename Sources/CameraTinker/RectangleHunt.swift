// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import Vision
import CoreImage

struct RectangleCandidate {
  var image : CIImage
  var rect : VNRectangleObservation
}

/// Given an image `cxiImage`,  find any rectangles which might be spines / covers
/// I return images, because I deskew the rectangles.
/// If a second image is provided, deskew the image from the second image, not the first, assuming the first image is a depth map used to locate rectangles
///
public func rectangleHunt(_ cxiImage : CIImage, _ original : CIImage?, parms: [Float]) async -> [CIImage] {

  /// This will be the resulting array
  /// For additional metadata, use a structure which contains the resulting image, as well as the rectangle, so I can evaluate the amount of skew
  var si : [CIImage] = []
  let rrsem = DispatchSemaphore(value: 0)

  let rectangleRequest = VNDetectRectanglesRequest { request, error in
    if let res = request.results as? [ VNRectangleObservation ] {
      res.forEach { r in
        // perhaps this is specific to spine vs. cover?
        if true || (r.boundingBox.width >= 0.7 || r.boundingBox.height >= 0.7) {
          let newImage = deskewRectangle(original ?? cxiImage, r)
          //     let pp =  newImage.oriented(.downMirrored)
          si.append(newImage)
        }
      }
    }
    rrsem.signal()
  }

  rectangleRequest.maximumObservations = 3
  rectangleRequest.minimumAspectRatio = parms[0]
  rectangleRequest.maximumAspectRatio = parms[1]
  rectangleRequest.minimumSize = parms[2]
  rectangleRequest.quadratureTolerance = 10
  rectangleRequest.minimumConfidence = 0.2

  let handler = VNImageRequestHandler(ciImage: cxiImage, options: [:])
  let reqlist = [ rectangleRequest]
  do {
    try handler.perform(reqlist)
  } catch {
    log.error("Could not perform rectangle-request for spine! \(error.localizedDescription)")
  }
  rrsem.wait()
  return si
}

// Given an image and a rectangle observation -- return an image which is the deskewed rectangle
public func deskewRectangle(_ ciImage : CIImage, _ r : VNRectangleObservation) -> CIImage {
  // perhaps this is specific to spine vs. cover?
  let width = ciImage.extent.width
  let height = ciImage.extent.height

  var tl, tr, bl, br : CIVector
  if r.topLeft.y < r.bottomLeft.y {
    tl = CIVector(cgPoint: CGPoint(x: r.topLeft.x * width, y: r.topLeft.y * height))
    tr = CIVector(cgPoint: CGPoint(x:r.topRight.x * width, y: r.topRight.y * height))
    bl = CIVector(cgPoint: CGPoint(x: r.bottomLeft.x * width, y: r.bottomLeft.y * height))
    br = CIVector(cgPoint: CGPoint(x:r.bottomRight.x * width, y: r.bottomRight.y * height))
  } else {
    bl = CIVector(cgPoint: CGPoint(x: r.topLeft.x * width, y: r.topLeft.y * height))
    br = CIVector(cgPoint: CGPoint(x:r.topRight.x * width, y: r.topRight.y * height))
    tl = CIVector(cgPoint: CGPoint(x: r.bottomLeft.x * width, y: r.bottomLeft.y * height))
    tr = CIVector(cgPoint: CGPoint(x:r.bottomRight.x * width, y: r.bottomRight.y * height))
  }

  let toTransform = CGAffineTransform(translationX: -ciImage.extent.origin.x, y: -ciImage.extent.origin.y)
  let ci2 = ciImage.transformed(by: toTransform)

  let newimage = ci2.applyingFilter("CIPerspectiveCorrection",
                                        parameters: [
                                          "inputTopLeft": bl, // tl,
                                          "inputTopRight": br, // tr,
                                          "inputBottomLeft": tl, // bl,
                                          "inputBottomRight": tr // br
                                        ])

  return newimage
}
