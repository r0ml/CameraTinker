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
let cic = CIContext(mtlDevice: device)

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif


#if os(macOS)
public typealias DeviceOrientation = FakeOrientation
#elseif os(iOS)
public typealias DeviceOrientation = UIDeviceOrientation
#endif


public let ubiquityStash = "iCloud.software.tinker.stash"
public let device = MTLCreateSystemDefaultDevice()!

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

#if os(macOS)
protocol AVCaptureDataOutputSynchronizerDelegate {
  
}
#endif

final public class CameraManager<T : RecognizerProtocol> : NSObject, CameraImageReceiver,
                                                     AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDataOutputSynchronizerDelegate,
// FIXME: I need to check this
@unchecked Sendable {
/*  public var view : PreviewView<CameraManager>?

  // for SceneKit (making a MTLTexture to use as a MaterialProperty)
  var region : MTLRegion?
  var thePixelFormat = MTLPixelFormat.bgra8Unorm_srgb // could be bgra8Unorm_srgb
  var frameTexture : MTLTexture?
 */
  public var textureUpdater = TextureUpdater()
  
  var stabilizer = SceneStabilizer()
  public var aspect : CGSize

  public typealias CameraData = ImageWithDepth
  
  public func start( /*_ perform: @escaping (CameraData) -> () */ ) {
    startMonitoring()
  }

  @MainActor public func updateTexture(_ d: CameraData) async {
    if let p = d.image.pixelBuffer {
      textureUpdater.globalUpdateTexture(p)
    }
  }
  
  public func resume() {
    startMonitoring()
  }
  
  public func pause() {
    stopMonitoring()
  }
  
  func setAspect() {
    if let c = _camera {
      aspect = CMVideoFormatDescriptionGetPresentationDimensions(c.activeFormat.formatDescription, usePixelAspectRatio: true, useCleanAperture: true)
    }
    print("camera size: \(aspect)")
  }

  public var _camera : AVCaptureDevice? {
    get {
      CameraPicker(cameraName: $cameraName).device // cameraNamed(cameraName)
    }
  }
  
  @AppStorage("camera name") var cameraName : String = "no camera"
  
  public var recognizer : T
  
  @MainActor public init( _ r : T) {
    recognizer = r
    aspect = CGSize.zero
    super.init()
    
    guard let _ = _camera else { return }
    //    recognizer.cameraSettings(self)
    // FIXME: this probably shouldn't be here, because it gets invoked when the ManualEntry is repainted.
    // cameraDidChange()
    setAspect()
  }
  
#if os(iOS)
  @MainActor static public var currentOrientation : DeviceOrientation {
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
  
  let captureSession = AVCaptureSession()
  let videoQueue = DispatchQueue(label: "metadata object q")
  
  let myVideoDataOutput = AVCaptureVideoDataOutput()
  //  var myPhotoDataOutput = AVCapturePhotoOutput()
  
  let log = Logger()
  
  let scenex = SCNScene()
  public var useDepth = false
  
#if os(iOS)
  // iOS can use depth data for getting spines
  let myDepthDataOutput = AVCaptureDepthDataOutput()
  var outputSynchronizer : AVCaptureDataOutputSynchronizer!
#endif
  

  /// This is the delegate used when I'm not capturing depth data.  The image data is sent to the recognizer
  public func captureOutput(_ output: AVCaptureOutput, didOutput: CMSampleBuffer, from: AVCaptureConnection) {
    guard let sb = CMSampleBufferGetImageBuffer(didOutput) else { return }
    let ciImage = CIImage(cvImageBuffer: sb )
    textureUpdater.globalUpdateTexture(sb) // updating the texture is done to display the camera preview

    Task {
      if await self.recognizer.isBusy() {
        return
      }
      
      let iid = ImageWithDepth(ciImage)
      
      if await isSceneStable(iid) {
        await self.recognizer.scanImage( iid )
      }
    }
  }
  
  public func isSceneStable( _ d : CameraData) async -> Bool {
    if let dd = d.image.pixelBuffer {
      return await stabilizer.isSceneStable(pixelBuffer: dd)
    } else {
      return false
    }
  }
  
#if os(iOS)
  
  var bufferCopy : CVPixelBuffer? = nil
  
  // extension CameraManager : AVCaptureDataOutputSynchronizerDelegate {
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
      
      /*
       // I stuck this in to save the camera image offline for fiddling with the algorithm
       if grabNextFrame {
       grabNextFrame = false
       savePicture(syncedDepthData.depthData, theImage)
       }
       */
      
      //   let depthPixelBuffer : CVPixelBuffer = syncedDepthData.depthData.depthDataMap
      //   let dImage = CIImage(cvPixelBuffer: depthPixelBuffer)
      
      // One can get a CIImage from the depthData, but there is no way to create the AVDepthData from a CIImage !!
      // So, store the AVDepthData, and create the CIImage as needed when accessed.
      let iwd = ImageWithDepth(theImage, depth: syncedDepthData.depthData)
      // let iwd = ImageWithDepth(theImage, depth: dImage)

      /*
#if DEBUG
      if bufferCopy == nil {
        let _ = CVPixelBufferCreate(kCFAllocatorDefault, CVPixelBufferGetWidth(videoPixelBuffer), CVPixelBufferGetHeight(videoPixelBuffer), CVPixelBufferGetPixelFormatType(videoPixelBuffer), nil, &bufferCopy)
      }
      
      Task {
        let gg = await iwd.prepImage()!
        cic.render(gg, to: bufferCopy!)
        updateTexture(bufferCopy!)
      }
      
#else
       */
      textureUpdater.globalUpdateTexture(videoPixelBuffer)

      

        Task.detached {
          if await self.stabilizer.isSceneStable(pixelBuffer: videoPixelBuffer) {
            await self.recognizer.scanImage( iwd )
        }
      }
      
    } else if let syncedVideoData = syncedVideoDat,
              let videoPixelBuffer = CMSampleBufferGetImageBuffer(syncedVideoData.sampleBuffer) {
      // here I have image data but not depth data
      // lots of frames where depth data is not available.
      textureUpdater.globalUpdateTexture(videoPixelBuffer)

      let cii = CIImage(cvImageBuffer: videoPixelBuffer)
      let iwd = ImageWithDepth( cii)

        Task.detached {
          if await self.stabilizer.isSceneStable(pixelBuffer: videoPixelBuffer) {
          await self.recognizer.scanImage( iwd )
        }
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
    do {
//      defer { _camera?.unlockForConfiguration() }
//      try _camera?.lockForConfiguration()
      captureSession.startRunning()
    } catch(let e) {
      log.error("startMonitoring \(e.localizedDescription)" )
      return
    }
  }
  
  public func scene() -> SCNScene {
    return textureUpdater.scenex
  }
  
  
  // ==============================================================================
  
  func selectDepthFormat(_ lookupView : AVCaptureDevice) {
    log.debug("\(#function)")
#if os(iOS)
    
    // I'm looking for some maximum size -- but there are two aspect ratios -- I need to figure that out
    // Also, I can't figure out how to tell if the depth is going to work (because
    
    // FIXME: ??
    if let selectedFormat = /* lookupView.activeFormat */  formatWithHighestResolution(lookupView) { // this is a depth format
      print("selected format \(selectedFormat)")
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
  public func zoom(_ factor : CGFloat) {
    log.debug("\(#function)")
#if os(iOS)
    if let d = _camera { // captureSession.inputs.first as? AVCaptureDeviceInput {
      do {
        try d.lockForConfiguration()
        d.videoZoomFactor = factor

        while(d.isRampingVideoZoom) {
          print("ramping")
        }

        d.unlockForConfiguration()
        localLog.debug("zooming at \(d.videoZoomFactor)")
      } catch(let e) {
        localLog.error("locking video for configuration \(e.localizedDescription)")
      }
    }
#endif
  }
  
  /* I don't use the front camera -- it can't focus */
/*  func updateTexture(_ pixelBuffer : CVPixelBuffer) {
    textureUpdater.globalUpdateTexture(pixelBuffer)
  }
  */

  public func processFrame(_ d : CameraData) async {
    await recognizer.scanImage( d )
  }
}

extension CameraManager {
  @MainActor func cameraDidChange() {
    log.debug("\(#function)")
    guard let camera = _camera else { return }


    


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
      videoInputx = try AVCaptureDeviceInput(device: camera)
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
      self.selectDepthFormat(camera)
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
      textureUpdater.thePixelFormat = MTLPixelFormat.bgra8Unorm_srgb
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
      
      /*      if let frameDuration = _camera!.activeDepthDataFormat?.videoSupportedFrameRateRanges.first?.minFrameDuration {
       do {
       try _camera!.lockForConfiguration()
       _camera!.activeVideoMinFrameDuration = frameDuration
       _camera!.unlockForConfiguration()
       } catch {
       print("could not lock device for configuration: \(error)")
       }
       }
       */
      
      if let k = depthDataOutput.connection(with: .depthData), k.isEnabled {
        k.videoOrientation = videoOrientation
        
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
    
    //    setVideoOrientation(Self.currentOrientation)
    //  }
    
    //  private func setVideoOrientation( _ o : DeviceOrientation) {
    
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

    setAspect()
  }
  
  @MainActor private var videoOrientation : AVCaptureVideoOrientation {
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
}
