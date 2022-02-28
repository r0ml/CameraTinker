// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import SwiftUI

struct CornersOverlay : ViewModifier {
  let size : CGSize
  init(_ s : CGSize) {
    self.size = s
  }
  
  func mask(_ g : CGSize, _ ss : CGRect) -> some View {
    var shape = Rectangle().path(in: CGRect(origin: .zero, size: g))
    shape.addPath(Rectangle().path(in: ss))
    return shape.fill(style: FillStyle(eoFill: true)).colorInvert().opacity(0.33)
  }
  
  func body(content: Content) -> some View {
    GeometryReader { (g : GeometryProxy)  in
      let sweetSpot = CGRect(
        x: g.size.width * ((1 - size.width) / 2),
        y: g.size.height * ((1-size.height) / 2),
        width: g.size.width * size.width,
        height: g.size.height * size.height)
      ZStack {
        content
        FourCorners(bounds: sweetSpot)
        mask(g.size, sweetSpot)
      }
    }
  }
}

extension View {
  func cornersOverlay(_ size : CGSize) -> some View {
    return self.modifier(CornersOverlay(size))
  }
}

struct Corner : View {
  var origin : CGPoint
  var dir : CornerPosition
  let size = CGPoint(x: 26, y: 20)
  
  var body: some View {
    Path { path in
      path.move(to: CGPoint(x: origin.x, y: origin.y+size.y * dir.direction.y))
      path.addLine(to: origin)
      path.addLine(to: CGPoint(x: origin.x + size.x * dir.direction.x, y: origin.y))
    }.stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round,  dash: [6, 12]))
      .foregroundColor(Color.green)
  }
}

/// Draw four corners to bracket the sweet spot for the recognizer.
/// An alternative is to just draw a rectangle which leaves everything within it bright -- and shades everything outside of it.
struct FourCorners : View {
  var bounds : CGRect
  
  var body: some View {
    Group {
      Corner(origin: CGPoint(x: bounds.minX, y: bounds.minY), dir: .topLeft)
      Corner(origin: CGPoint(x: bounds.minX, y: bounds.maxY), dir: .bottomLeft)
      Corner(origin: CGPoint(x: bounds.maxX, y: bounds.minY), dir: .topRight)
      Corner(origin: CGPoint(x: bounds.maxX, y: bounds.maxY), dir: .bottomRight)
    }
  }
}

struct FourCorners_Preview : PreviewProvider {
  static var recognizer = NullRecognizer()
  static var cm = CameraManager(recognizer)

  static var sweetSpotSize = CGSize(width: 0.8, height: 0.5)
  static var previews: some View {
    Group {
#if os(macOS)
      PreviewView(imageReceiver: &cm )
        .previewDevice("Mac")
#elseif os(iOS)
      Image("ClassicalRhetoric").resizable().scaledToFit().cornersOverlay(CGSize(width: 0.5, height: 0.3))

      // PreviewView(recognizer: recognizer )
      PreviewView(imageReceiver: cm)
        .previewDevice("iPhone X").background(Color.blue)
      //  PreviewView(recognizer: recognizder)
      //        .previewDevice("iPad Pro (12.9-inch) (4th generation)")
      //        .previewLayout(.fixed(width: 1366, height: 1024))
#endif
    }
  }
}
