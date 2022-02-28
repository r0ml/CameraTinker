// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

#if os(iOS)
import UIKit
typealias XColor = UIColor
#endif

#if os(macOS)
import AppKit
typealias XColor = NSColor
#endif

import SwiftUI

/// Named colors for use throughout the app (for iOS/macOS compatibility)
extension Color {
  #if os(iOS)
  public static var labColor = Color(UIColor.label)
  public static var secColor = Color(UIColor.secondaryLabel)
  public static var sysColor = Color(UIColor.systemBackground)
  public static var secSysColor = Color(UIColor.secondarySystemBackground)

  public static var disabledColor = Color(UIColor.lightGray)

  #elseif os(macOS)
  public static var labColor = Color(NSColor.labelColor)
  public static var secColor = Color(NSColor.secondaryLabelColor)
  public static var sysColor = Color(NSColor.windowBackgroundColor)
  public static var secSysColor = Color(NSColor.selectedContentBackgroundColor)

  public static var disabledColor = Color(NSColor.lightGray)

  #endif

}

extension CIColor {
  #if os(iOS)
  public static var white = CIColor.init(color: XColor.white)
  #endif

  #if os(macOS)
  public static var white = CIColor.init(color: XColor.white)!
  #endif
}

extension CGColor {
  static var black = XColor.black.cgColor
}
