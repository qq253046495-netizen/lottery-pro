import Foundation

enum LotteryType: String, CaseIterable, Identifiable {
    case dlt
    case ssq
    var id: String { rawValue }

    var title: String {
        switch self {
        case .dlt: return "体彩大乐透"
        case .ssq: return "福彩双色球"
        }
    }

    var frontRange: ClosedRange<Int> { self == .dlt ? 1...35 : 1...33 }
    var backRange: ClosedRange<Int> { self == .dlt ? 1...12 : 1...16 }
    var frontCount: Int { self == .dlt ? 5 : 6 }
    var backCount: Int { self == .dlt ? 2 : 1 }

    var frontLabel: String { self == .dlt ? "前区" : "红球" }
    var backLabel: String { self == .dlt ? "后区" : "蓝球" }
}

struct Draw: Identifiable, Hashable {
    let issue: Int
    let date: String
    let front: [Int]
    let back: [Int]
    var id: Int { issue }
}

// 可复现伪随机 (xorshift64)，保证每次生成同样的历史样本
struct RNG {
    var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed)) | 1
    }
    mutating func nextU64() -> UInt64 {
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        state = x
        return x
    }
    mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(nextU64() % span)
    }
}

func pickUnique(count: Int, range: ClosedRange<Int>, rng: inout RNG) -> [Int] {
    var set = Set<Int>()
    while set.count < count {
        set.insert(rng.int(in: range))
    }
    return Array(set)
}

// 确定性示例历史数据：用于跑通统计与推荐算法。
// 真实历史数据后续可替换（提供 CSV/JSON，或我写抓取脚本打入 Bundle）。
func generateSampleData(type: LotteryType, issues: Int, baseSeed: Int = 20260602) -> [Draw] {
    var rng = RNG(seed: baseSeed + (type == .dlt ? 1 : 1000))
    var result: [Draw] = []
    let cal = Calendar(identifier: .gregorian)
    var date = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    for i in 1...issues {
        let front = pickUnique(count: type.frontCount, range: type.frontRange, rng: &rng).sorted()
        let back = pickUnique(count: type.backCount, range: type.backRange, rng: &rng).sorted()
        result.append(Draw(issue: i, date: fmt.string(from: date), front: front, back: back))
        date = cal.date(byAdding: .day, value: type == .dlt ? 3 : 2, to: date)!
    }
    return result
}
