import SwiftUI

struct ContentView: View {
    @StateObject private var store = TicketStore()

    var body: some View {
        TabView {
            LotteryTabView(type: .dlt)
                .tabItem { Label("大乐透", systemImage: "chart.bar.fill") }
            LotteryTabView(type: .ssq)
                .tabItem { Label("双色球", systemImage: "die.face.5.fill") }
        }
        .environmentObject(store)
    }
}
