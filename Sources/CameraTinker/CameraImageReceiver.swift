// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import SceneKit
import AVFoundation

public protocol CameraImageReceiver : Sendable {
  associatedtype Recognizer : RecognizerProtocol
  associatedtype CameraData : AnyObject

  var textureUpdater : TextureUpdater { get }

  func start()
  func changeCamera(_ x : String)

  func updateTexture(_ d : CameraData)
  func isSceneStable(_ d : CameraData) -> Bool

  func processFrame(_ d : CameraData)
  var captureDevice : AVCaptureDevice? { get }

  func scene() -> SCNScene
  func resume()
  func pause()

  func setUseDepth(_ : Bool)
  
  var recognizer : Recognizer { get }
  var aspect : CGSize { get }
  var isAR : Bool { get }
}

extension AVCaptureDevice {
  static func haveAccess() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      return true
    case .denied:
      return false
    case .restricted:
      return false
    case .notDetermined:
      return await AVCaptureDevice.requestAccess(for: AVMediaType.video)
    default:
      // this should never happen
      return false
    }
  }
}
