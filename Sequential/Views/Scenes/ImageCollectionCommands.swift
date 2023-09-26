//
//  ImageCollectionCommands.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/18/23.
//

import OSLog
import SwiftUI

struct WindowFocusedValueKey: FocusedValueKey {
  typealias Value = Window
}

struct FullScreenFocusedValueKey: FocusedValueKey {
  typealias Value = Bool
}

struct AppMenuAction {
  let enabled: Bool
  let action: () -> Void
}

extension AppMenuAction: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.enabled == rhs.enabled
  }
}

struct AppMenuFinderFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuAction
}

struct AppMenuQuickLookFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuAction
}

extension FocusedValues {
  // FIXME: Add Equatable conformance to window to stop lagging.
  var window: WindowFocusedValueKey.Value? {
    get { self[WindowFocusedValueKey.self] }
    set { self[WindowFocusedValueKey.self] = newValue }
  }

  var fullScreen: FullScreenFocusedValueKey.Value? {
    get { self[FullScreenFocusedValueKey.self] }
    set { self[FullScreenFocusedValueKey.self] = newValue }
  }

  var sidebarFinder: AppMenuFinderFocusedValueKey.Value? {
    get { self[AppMenuFinderFocusedValueKey.self] }
    set { self[AppMenuFinderFocusedValueKey.self] = newValue }
  }

  var sidebarQuicklook: AppMenuQuickLookFocusedValueKey.Value? {
    get { self[AppMenuQuickLookFocusedValueKey.self] }
    set { self[AppMenuQuickLookFocusedValueKey.self] = newValue }
  }
}

struct ImageCollectionCommands: Commands {
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject private var delegate: AppDelegate
  @AppStorage(Keys.appearance.key) private var appearance: SettingsView.Scheme
  @FocusedValue(\.window) private var win
  @FocusedValue(\.fullScreen) private var fullScreen
  @FocusedValue(\.sidebarFinder) private var finder
  @FocusedValue(\.sidebarQuicklook) private var quicklook
  private var window: NSWindow? { win?.window }

  var body: some Commands {
    SidebarCommands()

    CommandGroup(after: .newItem) {
      Button("Open...") {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]

        Task {
          guard await panel.begin() == .OK else {
            return
          }

          do {
            openWindow(value: try ImageCollection(urls: panel.urls))
          } catch {
            Logger.ui.error("\(error)")
          }
        }
      }.keyboardShortcut(.open)

      Divider()

      Button("Show in Finder") {
        finder?.action()
      }
      .keyboardShortcut(.finder)
      .disabled(finder?.enabled != true)

      Button("Quick Look", systemImage: "eye") {
        quicklook?.action()
      }
      .keyboardShortcut(.quicklook)
      .disabled(quicklook?.enabled != true)
    }

    CommandGroup(after: .sidebar) {
      // The "Enter Full Screen" item is usually in its own space.
      Divider()

      // FIXME: The "Enter/Exit Full Screen" option sometimes disappears.
      //
      // This is a workaround that still has issues, such as it appearing in the menu bar (which looks like a duplicate
      // to the user), but at least it works.
      Button("\(fullScreen == true ? "Exit" : "Enter") Full Screen") {
        window?.toggleFullScreen(nil)
      }
      .keyboardShortcut("f", modifiers: [.command, .control])
      .disabled(fullScreen == nil || window == nil)
    }

    CommandGroup(after: .windowArrangement) {
      // This little hack allows us to do stuff with the UI on startup (since it's always called).
      Color.clear.onAppear {
        // We need to set NSApp's appearance explicitly so windows we don't directly control (such as the about) will
        // still sync with the user's preference.
        //
        // Note that we can't use .onChange(of:initial:_) since this scene will have to be focused to receive the
        // change (when the settings view would have focus).
        NSApp.appearance = appearance?.app()

        delegate.onOpen = { urls in
          do {
            openWindow(value: try ImageCollection(urls: urls))
          } catch {
            Logger.ui.error("\(error)")
          }
        }
      }
    }
  }
}
