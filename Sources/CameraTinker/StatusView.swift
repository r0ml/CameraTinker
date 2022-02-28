// Copyright (c) 1868 Charles Babbage
// Found amongst his effects by r0ml

import Foundation
import CloudKit
import SwiftUI
import os

fileprivate let localLog = Logger()

extension Notification.Name {
  public static let reportMessage = Notification.Name(rawValue: "reportMessage" )
}

extension Notification {
  public static func reportStatus(_ m : String) {
    localLog.info("\(m)")
    Task {
      await MainActor.run {
        let noti = Notification( name: .reportMessage, object: nil, userInfo: ["msg":m, "status" : true])
        NotificationCenter.default.post(noti)
      }
    }
  }

  public static func reportError(_ m : String, _ err : Error?) {
    if let e = err {
      localLog.error("\(m) \(e.localizedDescription)")
      var mmm = e.localizedDescription
      if let ee = e as? CKError {
        if let mm = ee.userInfo["NSUnderlyingError"] as? NSError {
          mmm = mm.localizedDescription
        }
      }
      let pp = mmm
      Task {
        await MainActor.run {
          let noti = Notification( name: .reportMessage, object: nil, userInfo: ["msg":m, "err": pp])
          NotificationCenter.default.post(noti)
        }
      }
    }
  }
  public static func reportError(_ m : String, _ e : String) {
    Task {
      await MainActor.run {
        let noti = Notification( name: .reportMessage, object: nil, userInfo: ["msg":m, "err": e])
        NotificationCenter.default.post(noti)
      }
    }
  }
}

@MainActor public struct StatusView : View {
  private var labelColor : Color {
    get {
      #if os(iOS)
      return Color(.label)
      #elseif os(macOS)
      return Color(.labelColor)
      #endif
    }
  }
  @State private var errorMsg : String = " "
  @State private var color : Color = Color.clear

  public init() {
  }

  public var body : some View {
    Text(errorMsg).foregroundColor(self.color)
      .task {
        for await note in NotificationCenter.default.notifications(named: .reportMessage) {
          self.handle(note)
          }
       }
    }

  func handle(_ note : Notification) {
    self.errorMsg = note.userInfo?["msg"] as? String ?? ""
    if let _ = note.userInfo?["err"]  {
      self.color = Color.red
    } else {
      self.color = labelColor
    }
  }
}
