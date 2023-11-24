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

  func callAsFunction() {
    action()
  }
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

struct AppMenuBookmarkedFocusedValueKey: FocusedValueKey {
  typealias Value = Binding<Bool>
}

struct AppMenuJumpToCurrentImageFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuAction
}

extension FocusedValues {
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

  var sidebarBookmarked: AppMenuBookmarkedFocusedValueKey.Value? {
    get { self[AppMenuBookmarkedFocusedValueKey.self] }
    set { self[AppMenuBookmarkedFocusedValueKey.self] = newValue }
  }

  var jumpToCurrentImage: AppMenuJumpToCurrentImageFocusedValueKey.Value? {
    get { self[AppMenuJumpToCurrentImageFocusedValueKey.self] }
    set { self[AppMenuJumpToCurrentImageFocusedValueKey.self] = newValue }
  }
}

struct ImageCollectionCommands: Commands {
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject private var delegate: AppDelegate
  @AppStorage(Keys.appearance.key) private var appearance: SettingsGeneralView.Scheme
  @AppStorage(Keys.importHidden.key) private var importHidden = Keys.importHidden.value
  @AppStorage(Keys.importSubdirectories.key) private var importSubdirectories = Keys.importSubdirectories.value
  @FocusedBinding(\.sidebarBookmarked) private var bookmarked
  @FocusedValue(\.window) private var win
  @FocusedValue(\.fullScreen) private var fullScreen
  @FocusedValue(\.sidebarFinder) private var finder
  @FocusedValue(\.sidebarQuicklook) private var quicklook
  @FocusedValue(\.jumpToCurrentImage) private var jumpToCurrentImage
  private var window: NSWindow? { win?.window }

  var body: some Commands {
    // TODO: Figure out how to remove the "Show/Hide Toolbar" item.
    ToolbarCommands()

    SidebarCommands()

    CommandGroup(after: .newItem) {
      Button("Open...") {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]

        // We don't want panel.begin() since it creating a modeless window causes SwiftUI to not treat it like a window.
        // This is most obvious when there are no windows but the open dialog and the app is activated, creating a new
        // window for the scene.
        guard panel.runModal() == .OK else {
          return
        }

        Task {
          do {
            let bookmarks = try await ImageCollection.resolve(
              urls: panel.urls.enumerated(),
              hidden: importHidden,
              subdirectories: importSubdirectories
            ).ordered()

            openWindow(value: ImageCollection(bookmarks: bookmarks))
          } catch {
            Logger.model.error("\(error)")
          }
        }
      }.keyboardShortcut(.open)

      Divider()

      Button("Show in Finder") {
        finder?()
      }
      .keyboardShortcut(.finder)
      .disabled(finder?.enabled != true)

      Button("Quick Look", systemImage: "eye") {
        quicklook?()
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
      .keyboardShortcut(.fullScreen)
      .disabled(fullScreen == nil || window == nil)
    }

    CommandMenu("Image") {
      Toggle("Bookmark", isOn: .init($bookmarked, defaultValue: false))
        .keyboardShortcut(.bookmark)
        .disabled(bookmarked == nil)

      Divider()

      Button("Show in Sidebar") {
        jumpToCurrentImage?()
      }
      .keyboardShortcut(.jumpToCurrentImage)
      .disabled(jumpToCurrentImage?.enabled != true)
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
          Task {
            do {
              let bookmarks = try await ImageCollection.resolve(
                urls: urls.enumerated(),
                hidden: importHidden,
                subdirectories: importSubdirectories
              ).ordered()

              openWindow(value: ImageCollection(bookmarks: bookmarks))
            } catch {
              Logger.ui.error("\(error)")
            }
          }
        }
      }
    }
  }
}
