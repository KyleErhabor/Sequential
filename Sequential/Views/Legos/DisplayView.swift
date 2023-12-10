//
//  DisplayView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 10/10/23.
//

import Combine
import OSLog
import SwiftUI

struct DisplayView<Content>: View where Content: View {
  typealias Action = (CGSize) -> Void

  @State private var size = CGSize.zero
  private let subject = PassthroughSubject<CGSize, Never>()
  private let publisher: AnyPublisher<CGSize, Never>

  let action: Action
  let content: Content

  var body: some View {
    content
      .background {
        GeometryReader { proxy in
          Color.clear
            .onChange(of: proxy.size) {
              subject.send(proxy.size)
            }.task(id: size) {
              let size = proxy.size

              guard size != .zero else {
                return
              }

              action(size)
            }
        }
      }.onReceive(publisher) { size in
        self.size = size
      }
  }

  init(action: @escaping Action, @ViewBuilder content: () -> Content) {
    self.action = action
    self.content = content()
    self.publisher = subject
      .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
}
