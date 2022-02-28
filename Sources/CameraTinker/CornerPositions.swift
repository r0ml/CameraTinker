//
//  CornerPositions.swift
//  Librorum Framework
//
//  Created by Robert Lefkowitz on 2/23/22.
//  Copyright © 2022 Sharper than Knot. All rights reserved.
//

import Foundation
import CoreGraphics

/// A quadrilateral has four corners, and this Enum enumerates them
public enum CornerPosition : CaseIterable, Identifiable {
  case topLeft
  case topRight
  case bottomRight
  case bottomLeft
  
  public var id : CornerPosition { get { return self } }

  public init(_ x : Int) {
    let y = ((x % 4)+4) % 4
    self = Self.allCases[y]
  }

  public var direction : CGPoint { get {
    switch self {
    case .topLeft: return CGPoint(x: 1, y: 1)
    case .topRight: return CGPoint(x: -1, y: 1)
    case .bottomLeft: return CGPoint(x: 1, y: -1)
    case .bottomRight: return CGPoint(x: -1, y: -1)
    }
  }}

  /// clockwise next point
  /// counter-clockwise if negative
  public func clockwise(_ x : Int = 1) -> CornerPosition {
    let z = Self.allCases.firstIndex(of: self)!
    return Self(z+x)
  }
}
