//
//  Standard.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import Foundation
import OSLog

extension Bundle {
  static let identifier = Bundle.main.bundleIdentifier!
}

extension Logger {
  static let ui = Self(subsystem: Bundle.identifier, category: "UI")
  static let model = Self(subsystem: Bundle.identifier, category: "Model")
  static let standard = Self(subsystem: Bundle.identifier, category: "Standard")
  static let sandbox = Self(subsystem: Bundle.identifier, category: "Sandbox")
}

func noop<each T>(_ args: repeat each T) {}

func constantly<T, each U>(_ value: T) -> ((repeat each U) -> T) {
  func result<each V>(_ args: repeat each V) -> T {
    return value
  }

  return result
}

extension Comparable {
  func clamp(to range: ClosedRange<Self>) -> Self {
    max(range.lowerBound, min(self, range.upperBound))
  }
}

// MARK: - Files

extension URL {
  static let file = Self(string: "file:")!
  static let rootDirectory = Self(string: "file:/")!

  var string: String {
    self.path(percentEncoded: false)
  }

  func isDirectory() -> Bool {
    (try? self.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
  }

  func contains(url: URL) -> Bool {
    let lhs = self.pathComponents
    let rhs = url.pathComponents

    return ArraySlice(lhs) == rhs.prefix(upTo: min(rhs.count, lhs.count))
  }

  // TODO: Change "components" to "paths"
  func appending(paths: some BidirectionalCollection<some StringProtocol>) -> URL {
    self.appending(path: paths.joined(separator: "/"))
  }
}

extension FileManager {
  func creatingDirectories<T>(at url: URL, code: CocoaError.Code, body: () throws -> T) rethrows -> T {
    do {
      return try body()
    } catch let err as CocoaError where err.code == code {
      try self.createDirectory(at: url, withIntermediateDirectories: true)

      return try body()
    }
  }
}

extension FileManager.DirectoryEnumerator {
  func contents() -> [URL] {
    self.compactMap { element -> URL? in
      guard let url = element as? URL else {
        return nil
      }

      if url.isDirectory() {
        return nil
      }

      return url
    }
  }
}

// MARK: - Collections

extension Sequence {
  func sum() -> Element where Element: AdditiveArithmetic {
    self.reduce(into: .zero, +=)
  }

  func filter<T>(in set: Set<T>, by value: (Element) -> T) -> [Element] {
    self.filter { set.contains(value($0)) }
  }
}

struct FinderSort {
  let url: URL
  let component: String
}

extension Sequence {
  func finderSort(_ predicate: (FinderSort, FinderSort) -> Bool) -> [Element] where Element == URL {
    self.sorted { a, b in
      // First, we need to find a and b's common directory, then compare which one is a file or directory (since Finder
      // sorts folders first). Finally, if they're the same type, we do a localized standard comparison (the same Finder
      // applies when sorting by name) to sort by ascending order.
      let ap = a.pathComponents
      let bp = b.pathComponents
      let (index, (ac, bc)) = zip(ap, bp).enumerated().first { _, pair in
        pair.0 != pair.1
      }!

      let count = index + 1

      if ap.count > count && bp.count == count {
        return true
      }

      if ap.count == count && bp.count > count {
        return false
      }

      return predicate(.init(url: a, component: ac), .init(url: b, component: bc))
    }
  }

  func finderSort() -> [Element] where Element == URL {
    finderSort { a, b in
      a.component.localizedStandardCompare(b.component) == .orderedAscending
    }
  }
}

extension Collection where Index: FixedWidthInteger {
  var middleIndex: Index {
    self.startIndex + ((self.endIndex - self.startIndex) / 2)
  }

  var middle: Element? {
    if self.isEmpty {
      return nil
    }

    return self[middleIndex]
  }
}

// I have no idea if Swift will specialize if we implement this on Collection.
extension RandomAccessCollection {
  var isMany: Bool {
    self.count > 1
  }
}

extension Array {
  init(minimumCapacity capacity: Int) {
    self.init()
    self.reserveCapacity(capacity)
  }
}

struct Pair<Left, Right> {
  let left: Left
  let right: Right
}

// MARK: - Others

struct Execution<T> {
  let duration: Duration
  let value: T
}

// This should be used sparingly, since Instruments provides more insight.
func time<T>(
  _ body: () async throws -> T
) async rethrows -> Execution<T> {
  var result: T?

  let duration = try await ContinuousClock.continuous.measure {
    result = try await body()
  }

  return .init(
    duration: duration,
    value: result!
  )
}

struct Matcher<Item, Path, Transform> where Item: Equatable, Path: Sequence<Item?> {
  typealias Items = Sequence<Item>

  let path: Path
  let transform: ([Item]) -> Transform

  func match(items: some Items) -> Transform? {
    guard let matches = Self.match(path: self.path, items: items) else {
      return nil
    }

    return transform(matches)
  }

  static func match(path: Path, items: some Items) -> [Item]? {
    let paths = zip(items, path)
    let satisfied = paths.allSatisfy { (component, path) in
      if let path {
        return component == path
      }

      return true
    }

    guard satisfied else {
      return nil
    }

    return paths.filter { (_, path) in path == nil }.map(\.0)
  }
}

extension Matcher where Item == String, Path == [String?], Transform == URL {
  typealias URLItems = BidirectionalCollection<Item>

  static let home = Matcher(path: ["/", "Users", nil], transform: constantly(.rootDirectory))
  // "/Users/<user>/.Trash" -> "/Users/<...>/Trash"
  static let trash = Matcher(path: ["/", "Users", nil, ".Trash"]) { matches in
    .rootDirectory.appending(components: "Users", matches.first!, "Trash")
  }

  static let volume = Matcher(path: ["/", "Volumes", nil], transform: constantly(.rootDirectory))
  // "/Volumes/<volume>/.Trashes/<uid>" -> "/Volumes/<...>/Trash"
  static let volumeTrash = Matcher(path: ["/", "Volumes", nil, ".Trashes", nil]) { matched in
    .rootDirectory.appending(components: "Volumes", matched.first!, "Trash")
  }

  func match(items: some URLItems) -> Transform? {
    if let matches = Self.match(path: path, items: items) {
      return self
        .transform(matches)
        .appending(paths: items.dropFirst(self.path.count))
    }

    return nil
  }
}

extension CGSize {
  var length: Double {
    max(self.width, self.height)
  }
}

// Borrowed (but inverted) from https://www.swiftbysundell.com/articles/the-power-of-key-paths-in-swift/
func setter<Object: AnyObject, Value>(
  keyPath: ReferenceWritableKeyPath<Object, Value>,
  value: Value
) -> (Object) -> Void {
  return { object in
    object[keyPath: keyPath] = value
  }
}
