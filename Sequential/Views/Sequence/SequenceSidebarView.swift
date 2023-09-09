//
//  SequenceSidebarView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/11/23.
//

import OSLog
import SwiftUI

struct SequenceSidebarView: View {
  @Environment(\.prerendering) private var prerendering
  @Environment(\.seqSelection) private var selection

  let sequence: Seq
  let scrollDetail: () -> Void

  var body: some View {
    // We don't want the "Drop Images Here" button to appear while the view is pre-rendering since it may change to
    // have data immediately after.
    let empty = !prerendering && sequence.bookmarks.isEmpty

    VStack {
      if empty {
        SequenceSidebarEmptyView(sequence: sequence)
      } else {
        SequenceSidebarContentView(sequence: sequence, scrollDetail: scrollDetail)
      }
    }
    .animation(.default, value: empty)
    .onDeleteCommand { // onDelete(perform:) doesn't seem to work.
      sequence.delete(selection.wrappedValue)
    }
  }
}

#Preview {
  SequenceSidebarView(
    sequence: try! .init(urls: []),
    scrollDetail: {}
  ).padding()
}
