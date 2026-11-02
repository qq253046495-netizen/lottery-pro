import SwiftUI
import Charts

struct Ball: View {
    let number: Int
    let color: Color
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 34, height: 34)
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct Combo: Identifiable {
    let id = UUID()
    let front: [Int]
    let back: [Int]
}

struct LotteryTabView: View {
    let type: LotteryType
    @EnvironmentObject var store: TicketStore

    @State private var draws: [Draw] = []
    @State private var strategy: Strategy = .balanced
    @State private var batch: [Combo] = []
    @State private var rng = RNG(seed: 12345)
    @State private var dataURL: String = ""
    @State private var netStatus: String = ""
    @State private var isLoading = false

    private var analyzer: Analyzer { Analyzer(type: type, draws: draws) }
    private var urlKey: String { "lottery_data_url_\(type.rawValue)" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    disclaimer
                    networkSection
                    recentSection
                    statsSection
                    omissionSection
                    historyCompareSection
                    recommendSection
                    favoritesSection
                }
                .padding()
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if draws.isEmpty {
                draws = generateSampleData(type: type, issues: 200)
            }
            dataURL = UserDefaults.standard.string(forKey: urlKey) ?? ""
        }
    }

    private var disclaimer: some View {
        Text("号码由历史统计模型生成，仅供娱乐参考。彩票为独立随机事件，任何方法都无法预测中奖，请理性购彩。")
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
    }

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("联网数据（实时分析）").font(.headline)
            TextField("数据源 JSON URL（HTTPS）", text: $dataURL)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: dataURL) { _, newVal in
                    UserDefaults.standard.set(newVal, forKey: urlKey)
                }
            HStack {
                Button {
                    Task { await refresh() }
                } label: {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("联网更新并分析")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                Spacer()
                if !netStatus.isEmpty {
                    Text(netStatus).font(.caption2).foregroundColor(.secondary)
                }
            }
            Text("格式：{\"type\":\"dlt|ssq\",\"draws\":[{\"issue\":1,\"date\":\"2026-01-01\",\"front\":[...],\"back\":[...]}]}")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private func refresh() async {
        guard !dataURL.isEmpty else {
            netStatus = "请先填写数据源 URL"
            return
        }
        isLoading = true
        netStatus = "拉取中…"
        do {
            let remote = try await LotteryService.fetch(type: type, from: dataURL)
            draws = remote
            netStatus = "已更新 \(remote.count) 期"
        } catch {
            netStatus = "失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("近期开奖").font(.headline)
            if draws.isEmpty {
                ProgressView()
            } else {
                ForEach(Array(draws.suffix(8).reversed())) { d in
                    HStack(spacing: 6) {
                        Text("第\(d.issue)期").font(.caption).foregroundColor(.secondary).frame(width: 64, alignment: .leading)
                        Text(d.date).font(.caption2).foregroundColor(.secondary).frame(width: 84)
                        HStack(spacing: 3) {
                            ForEach(d.front, id: \.self) { n in Ball(number: n, color: .red) }
                        }
                        HStack(spacing: 3) {
                            ForEach(d.back, id: \.self) { n in Ball(number: n, color: .blue) }
                        }
                    }
                }
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("统计分析（近 \(draws.count) 期）").font(.headline)
            let fc = analyzer.frontCounts()
            let fo = analyzer.frontOmission()
            let hot = analyzer.topFront(by: fc, n: 5, hottest: true)
            let cold = fo.sorted { $0.value > $1.value }.prefix(5)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(type.frontLabel)热号").font(.subheadline).foregroundColor(.secondary)
                    Text(hot.map { "\($0.0)" }.joined(separator: " "))
                        .font(.headline).foregroundColor(.red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(type.frontLabel)冷号").font(.subheadline).foregroundColor(.secondary)
                    Text(cold.map { "\($0.key)" }.joined(separator: " "))
                        .font(.headline).foregroundColor(.blue)
                }
            }
            let top10 = type.frontRange
                .map { ($0, fc[$0, default: 0]) }
                .sorted { $0.1 > $1.1 }
                .prefix(10)
            Chart {
                ForEach(Array(top10), id: \.0) { item in
                    BarMark(x: .value("号", "\(item.0)"), y: .value("次数", item.1))
                        .foregroundStyle(Color.red)
                }
            }
            .frame(height: 160)
        }
    }

    private var omissionSection: some View {
        let fo = analyzer.frontOmission()
        let ranked = fo.sorted { $0.value > $1.value }.prefix(8)
        let maxMiss = ranked.first?.value ?? 1
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(type.frontLabel)遗漏排行").font(.headline)
            ForEach(Array(ranked), id: \.key) { item in
                HStack(spacing: 8) {
                    Ball(number: item.key, color: .blue)
                    Text("遗漏 \(item.value) 期")
                        .font(.caption).foregroundColor(.secondary)
                        .frame(width: 84, alignment: .leading)
                    ProgressView(value: Double(item.value), total: Double(max(maxMiss, 1)))
                }
            }
        }
    }

    private var historyCompareSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("历史同期对比").font(.headline)
            if let last = draws.last, let same = previousYearSameMonth(last: last) {
                Text("去年同月 第\(same.issue)期（\(same.date)）").font(.caption).foregroundColor(.secondary)
                HStack(spacing: 3) {
                    ForEach(same.front, id: \.self) { Ball(number: $0, color: .red) }
                }
                HStack(spacing: 3) {
                    ForEach(same.back, id: \.self) { Ball(number: $0, color: .blue) }
                }
                let overlap = Set(last.front).intersection(Set(same.front)).count
                Text("与最新一期 \(type.frontLabel)重合 \(overlap) 个").font(.caption).foregroundColor(.secondary)
            } else {
                Text("样本不足一年，暂无法做同期对比").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private var recommendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("号码推荐").font(.headline)
            Picker("策略", selection: $strategy) {
                ForEach(Strategy.allCases) { s in Text(s.rawValue).tag(s) }
            }
            .pickerStyle(.segmented)
            Button {
                batch = (0..<5).map { _ in
                    let r = analyzer.recommend(strategy: strategy, rng: &rng)
                    return Combo(front: r.front, back: r.back)
                }
            } label: {
                Text("生成 5 注推荐").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            ForEach(batch) { c in
                let saved = store.contains(type: type, front: c.front, back: c.back)
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        ForEach(c.front, id: \.self) { Ball(number: $0, color: .red) }
                    }
                    HStack(spacing: 3) {
                        ForEach(c.back, id: \.self) { Ball(number: $0, color: .blue) }
                    }
                    Spacer()
                    Button {
                        if !saved {
                            store.add(type: type, front: c.front, back: c.back, strategy: strategy.rawValue)
                        }
                    } label: {
                        Image(systemName: saved ? "star.fill" : "star")
                            .foregroundColor(saved ? .yellow : .gray)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private var favoritesSection: some View {
        let favs = store.forType(type)
        return VStack(alignment: .leading, spacing: 8) {
            Text("我的收藏（\(favs.count)）").font(.headline)
            if favs.isEmpty {
                Text("生成的号码点 ☆ 收藏，会出现在这里").font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(favs) { t in
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            ForEach(t.front, id: \.self) { Ball(number: $0, color: .red) }
                        }
                        HStack(spacing: 3) {
                            ForEach(t.back, id: \.self) { Ball(number: $0, color: .blue) }
                        }
                        Spacer()
                        Button {
                            store.remove(t)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private func previousYearSameMonth(last: Draw) -> Draw? {
        let c = last.date.split(separator: "-")
        guard c.count == 3, let y = Int(c[0]), let m = Int(c[1]) else { return nil }
        let target = y - 1
        return draws.first { d in
            let dc = d.date.split(separator: "-")
            guard dc.count == 3, let dy = Int(dc[0]), let dm = Int(dc[1]) else { return false }
            return dy == target && dm == m
        }
    }
}
