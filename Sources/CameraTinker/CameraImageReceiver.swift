// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import SceneKit
import AVFoundation

public protocol CameraImageReceiver : Sendable {
  associatedtype Recognizer : RecognizerProtocol
  associatedtype CameraData : Actor

  var textureUpdater : TextureUpdater { get }

  func start( /* _ perform: @escaping (CameraData) -> () */ )
  @MainActor func updateTexture(_ d : CameraData) async
  func isSceneStable(_ d : CameraData) async -> Bool

  func processFrame(_ d : CameraData) async

  func scene() -> SCNScene
  func resume()
  func pause()

  var recognizer : Recognizer { get }
  var aspect : CGSize { get }
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
