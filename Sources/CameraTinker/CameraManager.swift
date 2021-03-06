// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import AVFoundation
import CoreImage
import os
import SwiftUI
import SceneKit
import Metal
import CoreImage.CIFilterBuiltins
import Vision

fileprivate let localLog = Logger()

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/*
#if os(macOS)
public typealias DeviceOrientation = FakeOrientation
#elseif os(iOS)
public typealias DeviceOrientation = UIDeviceOrientation
#endif
*/

public let tinkerUbiquityStash = "iCloud.software.tinker.stash"
public let ubiquityStash = "iCloud.net.r0ml.Librorum"

/*
public enum FakeOrientation {
  case portrait
  case landscape
  case landscapeLeft
  case landscapeRight
  case portraitUpsideDown

  var isPortrait : Bool { get {
    return false
  }}
  var isLandscape : Bool { get {
    return true
  }}
}
*/

#if os(macOS)
protocol AVCaptureDataOutputSynchronizerDelegate {
}
#endif

final public class CameraManager<T : RecognizerProtocol> : NSObject, CameraImageReceiver,
AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDataOutputSynchronizerDelegate,
// FIXME: I need to check this
@unchecked Sendable {

  public typealias CameraData = ImageWithDepth

  public let textureUpdater = TextureUpdater()
  let stabilizer = SceneStabilizer()

  public var aspect : CGSize
  public var camera : AVCaptureDevice?

  public var captureDevice : AVCaptureDevice? { return camera  }

  public var recognizer : T

  public func start() {
    startMonitoring()
  }

  public func updateTexture(_ d: CameraData) {
    if let p = d.image.pixelBuffer {
      textureUpdater.updateTextureBuffer(p)
    }
  }

  public var isAR : Bool = false
  
  public func resume() {
    startMonitoring()
  }
  
  public func pause() {
    stopMonitoring()
  }
  
  private func setAspect() {
    if let camera = camera {
    aspect = CMVideoFormatDescriptionGetPresentationDimensions(camera.activeFormat.formatDescription, usePixelAspectRatio: true, useCleanAperture: true)
//    print("camera size: \(aspect)")
    }
  }

  #if os(iOS)

  var myScene : UIWindowScene
  var orientation : UIInterfaceOrientation
  #endif

  public init(_ c : String, recognizer r : T) {
    recognizer = r
    aspect = CGSize.zero
    camera = Self.getDevice(c)

    #if os(iOS)
    myScene = UIApplication.shared.connectedScenes
//            .filter({$0.activationState == .foregroundActive})
            .compactMap({$0 as? UIWindowScene})
            .first!
    orientation = myScene.interfaceOrientation
    #endif

    super.init()
    changeCamera(c)
    setAspect()

    #if os(iOS)
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: nil, using:
    { notification in

    // when it is upside down, the scene orientation shows as whatever the last scene was, but the UIDevice orientation ((notification.object as! UIDevice).orientation)  shows as portraitUpsideDown


      self.orientation = self.myScene.interfaceOrientation
    })
    #endif

  }


  public func updateCameraSettings() {
    
  }

  /*
#if os(iOS)
  static public var currentOrientation : DeviceOrientation {
    get {
      let z = UIDevice.current.orientation; return z.isValidInterfaceOrientation ? z : .portrait
    }
  }
#elseif os(macOS)
  static public var currentOrientation : FakeOrientation {
    get {
      return .landscape
    }
  }
#endif
*/


  let captureSession = AVCaptureSession()
  let videoQueue = DispatchQueue(label: "metadata object q")
  let myVideoDataOutput = AVCaptureVideoDataOutput()

  let log = Logger()
  
//  let scenex = SCNScene()
  public var useDepth = false

  public func setUseDepth(_ x : Bool) { useDepth = x }
  
#if os(iOS)
  // iOS can use depth data for getting spines
  let myDepthDataOutput = AVCaptureDepthDataOutput()
  var outputSynchronizer : AVCaptureDataOutputSynchronizer!
#endif
  

  /// This is the delegate used when I'm not capturing depth data.  The image data is sent to the recognizer
  public func captureOutput(_ output: AVCaptureOutput, didOutput: CMSampleBuffer, from: AVCaptureConnection) {
    guard let sb = CMSampleBufferGetImageBuffer(didOutput) else { return }

    let cxImage = CIImage(cvImageBuffer: sb )
    var ciImage = cxImage

#if os(iOS)

    // .oriented(.rightMirrored)
//    print(output.connections[0].videoOrientation.rawValue)
    let a = from.videoOrientation
 //   let c = UIDevice.current.orientation
    let b = orientation

    switch b {
    case .landscapeRight:
      ciImage = cxImage.oriented(.downMirrored)
    case .portrait:
      ciImage = cxImage.oriented(.rightMirrored) // a == .landscapeRight
    case .landscapeLeft:
      ciImage = cxImage.oriented(.upMirrored)
    case .portraitUpsideDown:
      ciImage = cxImage.oriented(.leftMirrored) // This is clearly a bug -- should be .right
    case .unknown:
      ciImage = cxImage.oriented(.left) // What to do here?
//    case .faceUp:
//      ciImage = cxImage.oriented(.up)
    default:
      ciImage = cxImage
      break
    }


  #endif

    #if os(macOS) || targetEnvironment(macCatalyst)
//      .oriented(.down)
    #endif

//    textureUpdater.updateTextureBuffer(sb) // updating the texture is done to display the camera preview
    textureUpdater.updateTextureImage(ciImage)


    #if os(iOS)
    let iid = ImageWithDepth(ciImage.oriented(.downMirrored) )  // because of the aforementionned bug -- I need to adjust for upsideDown
    #else
    let iid = ImageWithDepth(ciImage)
    #endif

    Task {
      if await self.recognizer.isBusy() {
        return
      }

      if isSceneStable(iid) {
        self.recognizer.scanImage( iid )
      }
    }
  }
  
  public func isSceneStable( _ d : CameraData) -> Bool {
    return stabilizer.isSceneStable(ciImage: d.image)
  }
  
#if os(iOS)
  
  var bufferCopy : CVPixelBuffer? = nil
  
  /// This is the delegate function called when capturing both image and depth data
  public func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
    let syncedVideoDat: AVCaptureSynchronizedSampleBufferData? = synchronizedDataCollection.synchronizedData(for: myVideoDataOutput) as? AVCaptureSynchronizedSampleBufferData
    var theImage : CIImage! = nil
    
    if let syncedDepthData: AVCaptureSynchronizedDepthData = synchronizedDataCollection.synchronizedData(for: myDepthDataOutput) as? AVCaptureSynchronizedDepthData,
       let syncedVideoData = syncedVideoDat,
       !( syncedDepthData.depthDataWasDropped || syncedVideoData.sampleBufferWasDropped),       // only work on synced pairs
       let videoPixelBuffer = CMSampleBufferGetImageBuffer(syncedVideoData.sampleBuffer) {
      
      // here I have both image and depth data
      theImage = CIImage(cvImageBuffer: videoPixelBuffer)
      
      // One can get a CIImage from the depthData, but there is no way to create the AVDepthData from a CIImage !!
      // So, store the AVDepthData, and create the CIImage as needed when accessed.
      let iwd = ImageWithDepth(theImage, depth: syncedDepthData.depthData)
      textureUpdater.updateTextureBuffer(videoPixelBuffer)

        if self.stabilizer.isSceneStable(pixelBuffer: videoPixelBuffer) {
          self.recognizer.scanImage( iwd )
      }
      
    } else if let syncedVideoData = syncedVideoDat,
              let videoPixelBuffer = CMSampleBufferGetImageBuffer(syncedVideoData.sampleBuffer) {
      // here I have image data but not depth data
      // lots of frames where depth data is not available.
      textureUpdater.updateTextureBuffer(videoPixelBuffer)

      let cii = CIImage(cvImageBuffer: videoPixelBuffer)
      let iwd = ImageWithDepth( cii)

        if self.stabilizer.isSceneStable(pixelBuffer: videoPixelBuffer) {
          self.recognizer.scanImage( iwd )
        }
    } else {
      // here I would have depth data but not image data
      // I guess I ignore this condition -- I wouldn't be able to get an image
      // log.debug("I had depth data but no image data")
    }
  }
#endif
  
}

extension CameraManager {
  func stopMonitoring() {
    // log.debug("\(#function)")
    if captureSession.isRunning {
      captureSession.stopRunning()
    }
  }
  
  func startMonitoring() {
    captureSession.startRunning()
  }
  
  public func scene() -> SCNScene {
    return textureUpdater.getScene()
  }

  // ==============================================================================
  
  func selectDepthFormat(_ lookupView : AVCaptureDevice) {
    log.debug("\(#function)")
#if os(iOS)
    
    // I'm looking for some maximum size -- but there are two aspect ratios -- I need to figure that out
    // Also, I can't figure out how to tell if the depth is going to work (because
    
    // FIXME: ??
    if let selectedFormat = /* lookupView.activeFormat */  formatWithHighestResolution(lookupView) { // this is a depth format
//      print("selected format \(selectedFormat)")
      let depthFormats = selectedFormat.supportedDepthDataFormats
      let depth32formats = depthFormats.filter {
        CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat32 // or Disparity?
      }
      guard !depth32formats.isEmpty else { fatalError() }
      let selectedDepthFormat = depth32formats.max(by: {
        CMVideoFormatDescriptionGetDimensions($0.formatDescription).width
        < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
      })!
      
      localLog.debug("selected format: \(selectedFormat.description), depth format: \(selectedDepthFormat.description)")
      
      try! lookupView.lockForConfiguration()
      lookupView.activeFormat = selectedFormat
      lookupView.activeDepthDataFormat = selectedDepthFormat
      lookupView.unlockForConfiguration()
    }
#endif
  }
  
  
#if os(iOS)
  private func formatWithHighestResolution(_ v : AVCaptureDevice) -> AVCaptureDevice.Format? {
    log.debug("\(#function)")
    let availableFormats = v.formats.filter { format -> Bool in
      if (0 < (format.unsupportedCaptureOutputClasses.filter { $0 == AVCaptureDepthDataOutput.self }).count) {
        return false
      }
      
      if  ![kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange].contains(CMFormatDescriptionGetMediaSubType(format.formatDescription)) {
        return false
      }
      let validDepthFormats = format.supportedDepthDataFormats.filter{ depthFormat in
        return CMFormatDescriptionGetMediaSubType(depthFormat.formatDescription) == kCVPixelFormatType_DepthFloat32
      }
      return validDepthFormats.count > 0
    }
    
    var maxWidth: Int32 = 0
    var selectedFormat: AVCaptureDevice.Format?
    for format in availableFormats {
      let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
      let width = dimensions.width
      if width >= maxWidth {
        maxWidth = width
        selectedFormat = format
      }
    }
    return selectedFormat
  }
#endif
}

extension CameraManager {
  
  public func processFrame(_ d : CameraData) {
      recognizer.scanImage( d )
  }

  public func changeCamera(_ cn : String) {

    guard let cam = Self.getDevice(cn) else { return }
//    guard camera != cam || captureSession.connections.count == 0 else { return }

    log.debug("\(#function)")
    camera = cam

    // if the camera changed, the inputs are different -- but presumably the outputs are still OK
    captureSession.inputs.forEach { captureSession.removeInput($0) }
    captureSession.outputs.forEach { captureSession.removeOutput($0) }
    
    captureSession.beginConfiguration()
    captureSession.sessionPreset = AVCaptureSession.Preset.photo
    
    // make sure I commit the captureSession configuration
    defer {
      captureSession.commitConfiguration()
    }
    
    var videoInputx : AVCaptureDeviceInput?
    do {
      videoInputx = try AVCaptureDeviceInput(device: cam)
    } catch(let e) {
      Notification.reportError("Unable to obtain video input", e)
    }
    
    guard let videoInput = videoInputx else { return }
    
    guard self.captureSession.canAddInput(videoInput) else {
      Notification.reportError("recorder unable to add input \(videoInput.debugDescription)", "")
      return
    }
    
    self.captureSession.addInput(videoInput)
    
    if useDepth {
      self.selectDepthFormat(cam)
    }
    
    let videoDataOutput = myVideoDataOutput
    
#if targetEnvironment(simulator)
    
    // let vt = [UIPasteboard.Type.url]
    // previewView.registerForDraggedTypes(vt)
    // previewView.initAVLayer(with: captureSession)
    
    let availablePixelFormats = [kCVPixelFormatType_32BGRA]
#else
    let availablePixelFormats = videoDataOutput.availableVideoPixelFormatTypes
#endif

    if availablePixelFormats.contains(kCVPixelFormatType_32BGRA) {
      let newSettings: [String: Any]! = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA ]
      videoDataOutput.videoSettings = newSettings

      #if os(macOS) || targetEnvironment(macCatalyst)
      TextureUpdater.thePixelFormat = MTLPixelFormat.bgra8Unorm                          // bgra8Unorm_srgb
      #else
      TextureUpdater.thePixelFormat = MTLPixelFormat.bgra8Unorm_srgb                          // bgra8Unorm_srgb
      #endif

    } else {
      log.error("I didn't find a pixel format I know what to do with")
    }
    
    videoDataOutput.alwaysDiscardsLateVideoFrames = true
    
    if captureSession.canAddOutput(videoDataOutput) {
      captureSession.addOutput(videoDataOutput) }
    
#if os(macOS)
    videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
#endif
    
#if os(iOS)
    if useDepth {
      // this is for using the syncronized delegate to include depth data
      let depthDataOutput = myDepthDataOutput
      // if false I get NaN's in the depth data -- and the current code can't handle that
      depthDataOutput.isFilteringEnabled = true
      
      if captureSession.canAddOutput(depthDataOutput) {
        captureSession.addOutput(depthDataOutput)
      }
      
      if let k = depthDataOutput.connection(with: .depthData), k.isEnabled {
        // k.videoOrientation = videoOrientation
        
        // synchronized (with depth)
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [myVideoDataOutput, myDepthDataOutput]) // captureSession.outputs)
        outputSynchronizer.setDelegate(self, queue: videoQueue)
      } else {
        // just video, no depth
        videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
      }
    } else {
      videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
    }
#endif




    /*
    var vdo : AVCaptureVideoOrientation = .portrait
    switch Self.currentOrientation {
    case .landscapeLeft: vdo = .landscapeRight
    case .landscapeRight: vdo = .landscapeLeft
    default: vdo = .portrait
    }

    captureSession.outputs.forEach { n in
      if let nn = n as? AVCaptureVideoDataOutput {
        
        if let conn = nn.connection(with: .video) {
          conn.videoOrientation = vdo

          // These seem to do nothing
          // conn.automaticallyAdjustsVideoMirroring = false
          //  conn.isVideoMirrored = true
          //  print("video mirroring supported: \(conn.isVideoMirroringSupported)")
          
        }
      }
    }
     */

    setAspect()
  }


  /*
  private var videoOrientation : AVCaptureVideoOrientation {
    get {
      switch Self.currentOrientation {
      case .landscapeLeft:
        return .landscapeLeft
      case .landscapeRight:
        return .landscapeRight
      default:
        return .portrait
      }
    }
  }
*/

  private static func getDevice(_ s : String) -> AVCaptureDevice? {
    let list = CameraPicker._cameraList
    if let videoCaptureDevice = list.first(where : { $0.localizedName == s })  {
      return videoCaptureDevice
    } else {
      if let a = list.first {
        return a
      }
    }
    return nil
  }

}
