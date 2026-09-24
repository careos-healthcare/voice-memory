import SwiftUI

/// Kept so existing watch previews open the same recorder as [WatchRecordingView].
struct QuickRecordView: View {
  var body: some View {
    WatchRecordingView()
  }
}

#Preview {
  QuickRecordView()
}
