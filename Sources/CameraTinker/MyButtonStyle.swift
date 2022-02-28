// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import SwiftUI

/// A button style for the buttons I use throughout the app
public struct MyButtonStyle: ButtonStyle {
  var bgColor: Color

  public init(bgColor bg: Color) {
    bgColor = bg
  }

  public func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .padding(20)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .shadow(color: .white, radius: configuration.isPressed ? 7: 10, x: configuration.isPressed ? -5: -15, y: configuration.isPressed ? -5: -15)
            .shadow(color: .black, radius: configuration.isPressed ? 7: 10, x: configuration.isPressed ? 5: 15, y: configuration.isPressed ? 5: 15)
            .blendMode(.overlay)
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(bgColor)
        }
      )
      .font(.system(size: 7))
      .scaleEffect(configuration.isPressed ? 0.95: 1)
      .foregroundColor(.primary)
      .animation(.spring(), value: configuration.isPressed)
  }
}

public struct FlatButton : ButtonStyle {
  public init(enabledState: Bool) {
    self.enabledState = enabledState
  }

  var enabledState : Bool

  public func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .padding()
      .foregroundColor(Color.white)
      .background(self.enabledState ? Color.blue : Color.disabledColor)
  }
}

