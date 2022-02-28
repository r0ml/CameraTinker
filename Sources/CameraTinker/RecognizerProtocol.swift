// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import CoreGraphics
import CoreImage
import Vision

public protocol RecognizerProtocol {
  //  associatedtype Recognized

  /** This will perform whatever image processing is desired for this recognizer */
  func scanImage(_ ciImage: ImageWithDepth) async

  //  func pickBetterImage(_ current : ImageMeta, _ candidate : CIImage, _ b : BookRecord) -> ImageMeta

  /** Each recognizer has the opportunity to modify camera settings in case it wants specific settings to improve the recognition workflow.
   For example, one could use a fixed focus for barcode recognition since they are of standard size and one would be holding the phone at roughly the same distance for all of them.  This way, one doesn't have the autofocus delay */
  //  func cameraSettings(_ cameraManager : CameraManager<Self>)

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

  /*
  func pickBetterImage(_ current : CIImage?, _ candidates : [CIImage], _ b : BookText) -> CIImage? {
    var cc : ImageMeta = ImageMeta(current, b)
    log.debug("current: \(cc.description)")
    for c in candidates {
      cc = self.pickBetterImage(cc, c, b)
    }
    return cc.image
  }
*/

  /// This looks for rectangles in the camera view.  It can either be called where `im` is the depth map (and `orig` is the actual image)
  /// or `im` is the actual image, and so is `orig`.   This is done so that I can find rectangles either in the depth map -- or the image, and wind up with
  /// the rectangle from the image.
/*  public func rectangleHunt(_ im : CIImage, _ orig : CIImage, sweetSpot: CGRect, parms: [Float]) async -> [CIImage] {
    let x = im.extent.width * sweetSpot.minX
    let y = im.extent.height * sweetSpot.minY
    let width = im.extent.width * sweetSpot.width
    let height = im.extent.height * sweetSpot.height
    let rect = CGRect(x: x, y: y, width: width, height: height)

    /// This is the image cropped to the "sweet spot" -- which is the spot highlighted in the preview
    let cxiImage = im.cropped(to: rect)

    let x2 = orig.extent
    let rect2 = CGRect(x: x2.width * sweetSpot.minX,
                       y: x2.height * sweetSpot.minY,
                       width: x2.width * sweetSpot.width,
                       height: x2.height * sweetSpot.height)
    let original = orig.cropped(to: rect2)
    var si : [CIImage] = []
    let rrsem = DispatchSemaphore(value: 0)

    let rectangleRequest = VNDetectRectanglesRequest { request, error in
      if let res = request.results as? [ VNRectangleObservation ] {
        res.forEach { r in
          // perhaps this is specific to spine vs. cover?
          if r.boundingBox.width >= 0.7 || r.boundingBox.height >= 0.7 {
            let newImage = deskewRectangle(original, r)
            //     let pp =  newImage.oriented(.downMirrored)
            si.append(newImage)
          }
        }


        /*
         let x = si.filter { im in
         if im.extent.width > im.extent.height { return false }
         if im.extent.width < 10 { return false }
         if im.extent.height < height / 2 { return false }
         return true
         }
         if x.count == 0 {
         return }

         if let j = self.pickBetterSpine(self.spine, x, self.book) {
         self.spine = j
         }
         */
      }
      rrsem.signal()
    }

    rectangleRequest.maximumObservations = 3
    rectangleRequest.minimumAspectRatio = parms[0]
    rectangleRequest.maximumAspectRatio = parms[1]
    rectangleRequest.minimumSize = parms[2]
    rectangleRequest.quadratureTolerance = 10
    rectangleRequest.minimumConfidence = 0.5

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
 */
}

/*
extension RecognizerProtocol {
  // the default always uses the new proposed method
  func pickBetterImage(_ current : ImageMeta, _ candidate : CIImage, _ b : BookText) -> ImageMeta {
    return current
  }
}
*/
