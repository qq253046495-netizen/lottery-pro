import Foundation
import Combine

struct SavedTicket: Identifiable, Codable {
    let id: UUID
    let typeRaw: String
    let front: [Int]
    let back: [Int]
    let strategy: String
    let createdAt: Date
}

final class TicketStore: ObservableObject {
    @Published private(set) var tickets: [SavedTicket] = []
    private let key = "saved_tickets_v1"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([SavedTicket].self, from: data) else { return }
        tickets = arr
    }

    func save() {
        if let data = try? JSONEncoder().encode(tickets) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(type: LotteryType, front: [Int], back: [Int], strategy: String) {
        let t = SavedTicket(id: UUID(), typeRaw: type.rawValue, front: front,
                            back: back, strategy: strategy, createdAt: Date())
        tickets.insert(t, at: 0)
        save()
    }

    func remove(_ t: SavedTicket) {
        tickets.removeAll { $0.id == t.id }
        save()
    }

    func forType(_ type: LotteryType) -> [SavedTicket] {
        tickets.filter { $0.typeRaw == type.rawValue }
    }

    func contains(type: LotteryType, front: [Int], back: [Int]) -> Bool {
        forType(type).contains { $0.front == front && $0.back == back }
    }
}
