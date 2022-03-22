// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import SwiftUI
import CoreGraphics

public struct CornerHandle : View {
  public var length : CGFloat
  var corner : CornerPosition
  public var wedgeRadius : CGFloat
  public var angles : (Angle, Angle)

  init( length l : CGFloat, corner c : CornerPosition, radius r : CGFloat,
        angles a : (Angle, Angle) ) {
    length = l
    corner = c
    wedgeRadius = r
    angles = a
  }

  let radius : CGFloat = 10
  let lineWidth : CGFloat = 4

  public var body: some View {

    ZStack {
      Path { path in
        path.addRelativeArc(center: CGPoint(x: wedgeRadius, y: wedgeRadius), radius: wedgeRadius, startAngle: angles.0, delta: angles.1)
        path.addLine(to: CGPoint(x: wedgeRadius, y: wedgeRadius) )
        path.closeSubpath()
      }.fill(Color.green)
        .frame(width: wedgeRadius * 2, height: wedgeRadius * 2)
        .position(x: 0, y: 0)
      ZStack {
        Path { path in
          path.move(to: CGPoint(x: 0, y: 0 )) // radius+lineWidth))
          path.addLine(to: CGPoint(x: length, y: 0 )) // radius+lineWidth))
        }
        .stroke(Color.orange, lineWidth: lineWidth)

        Circle().path(in: CGRect(x: length, y: -radius /* ineWidth */ , width: 2*radius, height: 2*radius ))
          .fill(Color.orange)
      }.transformEffect(
        CGAffineTransform(scaleX: (corner == .topLeft || corner == .bottomLeft ? -1 : 1),
                          y: (corner == .bottomLeft || corner == .bottomRight ? -1 : 1))
      )

    }
    .frame(width: length + 2 * radius + lineWidth, height: 2*radius + 2*lineWidth )
  }
}

/// A Quadrilateral defines four points which are used to define a shape which I will assume to be a perspective view of a rectangle.
/// In actual usage, it is created for a unit image (all values are fractional) and then gets scaled to the actual view size.
/// Ths scaling might be requested more than once, so I keep track if I have already been scaled.
public class Quadrilateral : ObservableObject {
  @Published private var topLeft : CGPoint
  @Published private var topRight : CGPoint
  @Published private var bottomLeft : CGPoint
  @Published private var bottomRight : CGPoint
  private var extent : CGSize = .zero

  public func copy() -> Quadrilateral {
    return Quadrilateral.init(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight, extent: extent)
  }

  public init(topLeft ul : CGPoint, topRight ur : CGPoint, bottomLeft bl : CGPoint, bottomRight br : CGPoint, extent: CGSize) {
    self.topLeft = ul
    self.topRight = ur
    self.bottomLeft = bl
    self.bottomRight = br
    self.extent = extent
  }
  
  /// The Path which draws the quadrilateral
  public var path : CGMutablePath {
    let path = CGMutablePath()
    path.move(to: topLeft * extent)
    path.addLine(to: topRight * extent)
    path.addLine(to: bottomRight * extent )
    path.addLine(to: bottomLeft * extent)
    path.closeSubpath()
    return path
  }
  
  /// Given a size assumed to be the size of a centered rectangle in the unit view
  /// create the four points of the rectangle.
  public init(size s: CGSize) {
    let minx = (1.0-s.width) / 2.0
    let miny = (1.0-s.height) / 2.0
    let maxx = minx + s.width
    let maxy = miny + s.height
    topLeft = CGPoint(x: minx, y: miny)
    topRight = CGPoint(x: maxx, y: miny)
    bottomRight = CGPoint(x: maxx, y: maxy)
    bottomLeft = CGPoint(x: minx, y: maxy)
  }

  public func resetTo(_ o : Quadrilateral) {
    extent = o.extent
    topLeft = o.topLeft
    topRight = o.topRight
    bottomRight = o.bottomRight
    bottomLeft = o.bottomLeft
  }
  
  /// The Quadrilateral can be thought of as an array of four points, which can be referenced or set by indexing them (using the CornerPosition enum as the index
  subscript( _ index: CornerPosition) -> CGPoint {
    get {
      switch(index) {
      case .topLeft: return topLeft * extent
      case .topRight: return topRight * extent
      case .bottomLeft: return bottomLeft * extent
      case .bottomRight: return bottomRight * extent
      }
    }
    set(nv) {
      switch(index) {
      case .topLeft: topLeft = nv / extent
      case .topRight: topRight = nv / extent
      case .bottomLeft: bottomLeft = nv / extent
      case .bottomRight: bottomRight = nv / extent
      }
    }
  }
  
  /// Scale the quadrilateral to fit the current view size.  This gets called when the view size changes
  public func setExtent(_ s : CGSize) {
    extent = s
  }

  /// Assuming the given image is being displayed in the given frame, crop the perspective rectangle defined by this quadrilateral.
  public func crop(_ im : CIImage /* , frame: CGRect */) -> CIImage {
    let k = CGSize(width: im.extent.size.width - 50, height: im.extent.size.height - 50)
    let j = im.oriented(.downMirrored).applyingFilter(
      "CIPerspectiveCorrection",
      parameters: [
        "inputTopLeft": CIVector(cgPoint: (CGPoint(x: topLeft.x * k.width + 25, y: topLeft.y * k.height + 25) )),
        "inputTopRight": CIVector(cgPoint: (CGPoint(x: topRight.x * k.width + 25, y: topRight.y * k.height + 25) ) ),
        "inputBottomLeft": CIVector(cgPoint: (CGPoint(x: bottomLeft.x * k.width + 25, y: bottomLeft.y * k.height + 25) ) ),
        "inputBottomRight": CIVector(cgPoint: (CGPoint(x: bottomRight.x * k.width + 25, y: bottomRight.y * k.height + 25) ) )
      ])
    return j
  }
}

/// Draw quadrilateral to outline the perspective rectangle for clipping a spine / cover
/// An alternative is to draw it as a mask to dim everyting outside the area
struct QuadrilateralView : View {
  @ObservedObject var corners : Quadrilateral
  var offset : CGRect
  @State var dragOffset : CGPoint?
  @GestureState private var isPressingDown: Bool = false
  @GestureState private var isPressing2Down : Bool = false
  @Binding var isZooming : CornerPosition?


  init(corners: Quadrilateral, offset: CGRect, isZooming: Binding<CornerPosition?>) {
    self.corners = corners
    self.offset = offset
    self._isZooming = isZooming
    self.corners.setExtent(offset.size)
  }

  func mask(_ g : CGSize) -> some View {
    var shape = Rectangle().path(in: CGRect(origin: .zero, size: g))
    shape.addPath( Path(corners.path) )
    return shape.fill(style: FillStyle(eoFill: true)).colorInvert().opacity(0.5)
  }

  func dragEnded(_ n : CornerPosition, _ value : DragGesture.Value) {
    if let dd = dragOffset {
      self.corners[n] = CGPoint(x: value.location.x + dd.x, y: value.location.y + dd.y)
    } else {
      let c = self.corners[n]
      self.dragOffset = CGPoint(x: c.x-value.startLocation.x, y: c.y - value.startLocation.y)
    }
  }

  func dragZoomed(_ n : CornerPosition) -> some Gesture {
    let d2 = DragGesture(minimumDistance: 1)
      .updating($isPressing2Down) { currentstate, gestureState, transaction in
      }
      .onChanged { value in
        if nil == dragOffset {
          let zp = zoomedPosition(n, n)
          self.dragOffset = CGPoint(x: zp.x - value.startLocation.x, y: zp.y - value.startLocation.y)
        }
        self.corners[n] = unzoomedPosition(CGPoint(x: value.location.x + self.dragOffset!.x,
                                                   y: value.location.y + self.dragOffset!.y),
                                           n)
      }
      .onEnded { value in
        self.dragOffset = nil
      }

    let d1 = TapGesture(count: 2).onEnded {
      self.isZooming = nil
    }
    return d1.exclusively(before: d2)
  }

  func drag(_ n : CornerPosition) -> some Gesture {
    let d1 = DragGesture(minimumDistance: 1)
      .updating($isPressingDown) { currentstate, gestureState, transaction in
      }
      .onChanged { value in
        if nil == dragOffset {
          let c = self.corners[n]
          self.dragOffset = CGPoint(x: c.x - value.startLocation.x, y: c.y - value.startLocation.y)
        }
        self.corners[n] = CGPoint(x: value.location.x + self.dragOffset!.x, y: value.location.y + self.dragOffset!.y)
      }

      .onEnded { value in
        self.isZooming = nil
        self.dragOffset = nil
      }

    let d2 = TapGesture(count: 2).onEnded {
      self.isZooming = n
    }
    return d2.exclusively(before: d1)
  }

  func angleAdjust(_ a : CGPoint, _ b : CGPoint, _ c : CGPoint) -> (Angle, Angle) {
    let k1 = atan( (b.y - a.y) / (b.x - a.x) )
    let res1 = Angle(radians: Double(k1) )

    let k2 = atan( (c.x - a.x) / (c.y - a.y) )
    let res2 = Angle(radians: Double(k2) )
    let res = (res1, res2)
    return res
  }

  func wedgeAngles(_ i : Int) -> (Angle, Angle) {
    let z = (i % 2) == 0
    let r = Angle(degrees: Double((i+1)*90))
    let q = Angle(degrees:270)
    let (a,b,c) = (corners[CornerPosition(i)], corners[ CornerPosition(i+1)],corners[CornerPosition(i-1)])
    if z {
      let (s,d) = angleAdjust(a, b, c)
      return ( r - d, q+d+s)
    } else {
      let (s, d) = angleAdjust(a.flipped, b.flipped, c.flipped)
      return ( r + d, q-(d+s))
    }
  }

  let zoomFactor = CGPoint(x: 2, y: 2)

  /// produces the zoomed position of corner iz with respect to riz
  /// i.e. you are zoomed in to riz -- but are calculating the relative position of iz
  func zoomedPosition(_ iz : CornerPosition, _ riz : CornerPosition) -> CGPoint {
    var j = self.corners[iz]
    let k = self.offset.origin
    j = CGPoint(x: (j.x - k.x) * zoomFactor.x, y: (j.y - k.y ) * zoomFactor.y)
    let off = zoomOffset(riz)
    j = CGPoint(x: j.x - off.x, y: j.y - off.y)
    let res = CGPoint(x: j.x + k.x, y: j.y + k.y)
    return res
  }

  func unzoomedPosition(_ j : CGPoint, _ iz : CornerPosition) -> CGPoint {
    let k = self.offset.origin
    let off = zoomOffset(iz)
    return CGPoint(x: (j.x-k.x+off.x)/zoomFactor.x+k.x, y: (j.y - k.y + off.y)/zoomFactor.y + k.y)
  }

  func zoomOffset(_ iz : CornerPosition) -> CGPoint {
    let k = self.offset
    switch iz {
    case .topLeft: return .zero
    case .topRight: return CGPoint(x: k.width, y: 0)
    case .bottomLeft: return CGPoint(x: 0, y: k.height)
    case .bottomRight: return CGPoint(x: k.width, y: k.height)
    }
  }

  func zoomDragAdjust(_ loc : CGPoint, _ iz : CornerPosition ) -> CGPoint {
    let k = zoomOffset(iz)
    return CGPoint(x: self.dragOffset!.x + (loc.x + k.x) / zoomFactor.x - k.x,
                   y: self.dragOffset!.y + (loc.y + k.y) / zoomFactor.y - k.y)
  }

  func handleOffset(_ corner : CornerPosition) -> CGSize {
    return CGSize(width: 42, height: 14)
  }

  var body: some View {
    GeometryReader { g in
      ZStack {
        if let iz = isZooming {
          CornerHandle(length: 60, corner: iz,
                       radius: 25,
                       angles: wedgeAngles( CornerPosition.allCases.firstIndex(of: iz)! ))
            .position(zoomedPosition(iz, iz))
            .offset(handleOffset(iz))
            .gesture(dragZoomed(iz) )
          /// This is the rectangular outline
          Path { path in
            path.move(to: zoomedPosition(iz, iz) )
            path.addLine(to: zoomedPosition(iz.clockwise(1), iz))
            path.move(to: zoomedPosition(iz, iz) )
            path.addLine(to: zoomedPosition(iz.clockwise(-1), iz))
          }.stroke(style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .round))
            .foregroundColor(.green)
        } else  {
          Path(self.corners.path)
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .round))
            .foregroundColor(Color.green)
          ForEach(0..<CornerPosition.allCases.count, id: \.self) { i in
            ZStack {
              CornerHandle(length: 60, corner: CornerPosition.allCases[i],
                           radius: 25, angles: wedgeAngles(i) )
                .position(corners[CornerPosition.allCases[i]])
                .offset(handleOffset(CornerPosition.allCases[i]))
                .gesture( drag(CornerPosition.allCases[i]))
                .onChange(of: isPressingDown) {
                  z in
                  log.debug("pressing down: \(z) \(isPressingDown)")
                  if z {
                    self.isZooming = CornerPosition.allCases[i]
                  } else {
                    self.isZooming = nil
                  }
                }
            }
          }
          mask(g.size)
        }
      }
    }.frame(width: offset.width, height: offset.height)
  }
}

struct QuadrilateralView_Preview : PreviewProvider {
  @State static var zoomedCorner : CornerPosition?
  static var zz = CGRect(x: 0, y: 0, width: 400, height: 600)
  static var cc = Quadrilateral.init(size: CGSize(width: 0.4, height: 0.8))

  static var previews : some View {
    QuadrilateralView(corners: cc, offset: zz, isZooming: $zoomedCorner)
      .previewInterfaceOrientation(.portraitUpsideDown)
  }
}
