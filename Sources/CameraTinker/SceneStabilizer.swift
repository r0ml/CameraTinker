// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import AVFoundation
import Vision

final class SceneStabilizer {
  private var transpositionHistoryPoints: [CGPoint] = [ ]
  private var previousSb: CVPixelBuffer?
  private let sequenceRequestHandler = VNSequenceRequestHandler()

  let maximumHistoryLength = 15

  fileprivate func resetTranspositionHistory() {
    transpositionHistoryPoints.removeAll()
  }

  fileprivate func recordTransposition(_ point: CGPoint) {
    transpositionHistoryPoints.append(point)

    if transpositionHistoryPoints.count > maximumHistoryLength {
      transpositionHistoryPoints.removeFirst()
    }
  }

  fileprivate func sceneStabilityAchieved() -> Bool {
    // Determine if we have enough evidence of stability.
    if transpositionHistoryPoints.count == maximumHistoryLength {
      // Calculate the moving average.
      var movingAverage: CGPoint = CGPoint.zero
      for currentPoint in transpositionHistoryPoints {
        movingAverage.x += currentPoint.x
        movingAverage.y += currentPoint.y
      }
      let distance = abs(movingAverage.x) + abs(movingAverage.y)
      if distance < 20 {
        return true
      }
    }
    return false
  }

  func isSceneStable(pixelBuffer sb : CVPixelBuffer) -> Bool {
    guard previousSb != nil else {
      previousSb = sb
      self.resetTranspositionHistory()
      return false
    }

    let registrationRequest = VNTranslationalImageRegistrationRequest(targetedCVPixelBuffer: sb)
    do {
      try sequenceRequestHandler.perform([ registrationRequest ], on: previousSb!)
    } catch let error as NSError {
      log.error("Failed to process image registration request for stabilizer: \(error.localizedDescription).")
      return false
    }

    previousSb = sb

    if let results = registrationRequest.results {
      if let alignmentObservation = results.first {
        let alignmentTransform = alignmentObservation.alignmentTransform
        self.recordTransposition(CGPoint(x: alignmentTransform.tx, y: alignmentTransform.ty))
      }
    }
    return self.sceneStabilityAchieved()
  }
}
