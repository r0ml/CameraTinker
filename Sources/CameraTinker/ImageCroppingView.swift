// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import SwiftUI
import AVFoundation
import Vision

extension Notification.Name {
  public static let rectanglePicked = Notification.Name("rectanglePicked")

  public func post(_ info : [String:Any]) {
    NotificationCenter.default.post(name: self, object: nil, userInfo: info)
  }

}

public struct ImageCroppingView : View {
  
  @Binding var original : CIImage
  @State var cropped : CIImage?

  @State var target : Bool = false
  @ObservedObject var corners : Quadrilateral
  @State var imageOffset : CGRect = .zero
  @State var zoomedCorner : CornerPosition? = nil
  let originalCorners : Quadrilateral

  @Binding var candidate : CIImage
  @Binding var isActive : Bool

  var type : String

  public init (original o: Binding<CIImage>, corners c : Quadrilateral, candidate: Binding<CIImage>, isActive: Binding<Bool>,
               type: String ) {
    self._original = o
    self.corners = c.copy()
    self.originalCorners = c
    self._candidate = candidate
    self._isActive = isActive
    self.type = type
  }

  func xImage(image: CIImage) -> some View {
    var zim : CIImage = image
    if let zc = zoomedCorner {
      let w = image.extent.width / 2
      let h = image.extent.height / 2
      let sz = CGSize(width: w, height: h)
      switch zc {
      case .bottomLeft:
        zim = image.cropped(to: CGRect(origin: CGPoint(x: 0, y: h),
                                       size: sz))
      case .bottomRight:
        zim = image.cropped(to: CGRect(origin: CGPoint(x: w, y: h),
                                       size: sz))
      case .topLeft:
        zim = image.cropped(to: CGRect(origin: CGPoint(x: 0, y: 0),
                                       size: sz))
      case .topRight:
        zim = image.cropped(to: CGRect(origin: CGPoint(x: w, y: 0),
                                       size: sz))
      }
    }
    return Image.init(image: XImage(ciImage: zim))
      .resizable().scaledToFit()
      .border(Color.green, width: 5)
  }

  public var body : some View {

    VStack {
      xImage(image: cropped ?? original )
        .overlay(
          GeometryReader { (gg : GeometryProxy) -> QuadrilateralView in
            let zz = gg.frame(in: .local)
            // self.imageOffset = zz

            return QuadrilateralView(corners: corners, offset:  zz, isZooming: $zoomedCorner)
          }
        )
        .padding(25)


      // This changes the picture I'm working with
      /*      .onDrop(of: [.fileURL], isTargeted: $target) {
       providers in
       let p = providers.first!
       p.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, err in
       // log.error("\(err.localizedDescription)")
       if let d = data,
       let f = String.init(data: d, encoding: .utf8),
       let u = URL(string: f) {
       #if canImport(AppKit)
       self.original = NSImage.init(contentsOf: u)!.ciImage!
       #elseif canImport(UIKit)
       self.original = UIImage.init(contentsOf: u)!.ciImage!
       #endif
       }
       }
       self.cropped = nil
       return true
       }
       */
      /*
       .modifier(if: isCropping, then: { c in
       ZStack {
       c
       }

       }
       /* , else: { c in
        ZStack {
        c
        Button.init("Cancel") {
        cropped = nil
        zoomedCorner = nil
        }
        }
        }*/
       )
       */

      HStack {
        Button(action: {

          Notification.Name.rectanglePicked.post([type : candidate])
        }) {
          Text("Use Image")
            .frame(maxWidth: .infinity)
        }.buttonStyle(MyButtonStyle(bgColor: .blue))
        
        Button(action: {
           // FIXME: do I have to add the imageOffset to the VNRectangle points?
          let yy = corners.crop( original )
          /*                                 frame: /* CGRect(x: self.imageOffset.minX + 25,
                                                     y: self.imageOffset.minY - 25,
                                                     width: self.imageOffset.width - 50,
                                                     height: self.imageOffset.height - 50) */
           */
          candidate = yy
        }) {
          Text("Crop")
            .frame(maxWidth: .infinity)
        }.buttonStyle(MyButtonStyle(bgColor: .blue))
        Button( action:  {
          cropped = nil
          corners.resetTo(originalCorners)
        }) {
          Text("Reset")
            .frame(maxWidth: .infinity)
        }.buttonStyle(MyButtonStyle(bgColor: .blue))

        Button( action:  {
          isActive = false
        }) {
          Text("Cancel")
            .frame(maxWidth: .infinity)
        }.buttonStyle(MyButtonStyle(bgColor: .blue))
      }
    }
  }
}
