import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("海鸥 IPA Demo")
                .font(.title.bold())
            Text("工程链路已打通，等老子把功能塞进来。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
