import Foundation

enum Strategy: String, CaseIterable, Identifiable {
    case hot = "热号优先"
    case cold = "冷号回补"
    case balanced = "均衡随机"
    var id: String { rawValue }
}

struct Analyzer {
    let type: LotteryType
    let draws: [Draw]

    func frontCounts() -> [Int: Int] {
        var c: [Int: Int] = [:]
        for d in draws { for n in d.front { c[n, default: 0] += 1 } }
        return c
    }

    func backCounts() -> [Int: Int] {
        var c: [Int: Int] = [:]
        for d in draws { for n in d.back { c[n, default: 0] += 1 } }
        return c
    }

    // 当前遗漏：某号码距最新一期的未出现期数（从未出现 = 总期数）
    func omission(pick: (Draw) -> [Int], range: ClosedRange<Int>) -> [Int: Int] {
        var last: [Int: Int] = [:]
        for (idx, d) in draws.enumerated() {
            for n in pick(d) { last[n] = idx }
        }
        var res: [Int: Int] = [:]
        for n in range {
            res[n] = last[n].map { draws.count - 1 - $0 } ?? draws.count
        }
        return res
    }

    func frontOmission() -> [Int: Int] { omission(pick: { $0.front }, range: type.frontRange) }
    func backOmission() -> [Int: Int] { omission(pick: { $0.back }, range: type.backRange) }

    func topFront(by counts: [Int: Int], n: Int, hottest: Bool) -> [(Int, Int)] {
        let arr = type.frontRange.map { ($0, counts[$0, default: 0]) }
        let sorted = arr.sorted { hottest ? $0.1 > $1.1 : $0.1 < $1.1 }
        return Array(sorted.prefix(n))
    }

    // 多策略推荐：基于历史频率 / 遗漏 / 加权组合
    func recommend(strategy: Strategy, rng: inout RNG) -> (front: [Int], back: [Int]) {
        let fc = frontCounts()
        let bc = backCounts()
        let fo = frontOmission()
        let bo = backOmission()

        func weight(n: Int, counts: [Int: Int], om: [Int: Int]) -> Double {
            switch strategy {
            case .hot:      return Double(counts[n, default: 0] + 1)
            case .cold:     return Double(om[n, default: 0] + 1)
            case .balanced: return Double(counts[n, default: 0] + 1) / (Double(om[n, default: 0]) + 1)
            }
        }

        func pick(count: Int, range: ClosedRange<Int>, counts: [Int: Int], om: [Int: Int]) -> [Int] {
            var pool = Array(range)
            var out: [Int] = []
            for _ in 0..<count {
                let weights = pool.map { max(weight(n: $0, counts: counts, om: om), 0.0001) }
                let total = weights.reduce(0, +)
                var r = (Double(rng.int(in: 0...1_000_000)) / 1_000_000.0) * total
                var chosen = pool.last!
                for i in pool.indices {
                    r -= weights[i]
                    if r <= 0 { chosen = pool[i]; break }
                }
                if let idx = pool.firstIndex(of: chosen) { pool.remove(at: idx) }
                out.append(chosen)
            }
            return out.sorted()
        }

        let front = pick(count: type.frontCount, range: type.frontRange, counts: fc, om: fo)
        let back = pick(count: type.backCount, range: type.backRange, counts: bc, om: bo)
        return (front, back)
    }
}
