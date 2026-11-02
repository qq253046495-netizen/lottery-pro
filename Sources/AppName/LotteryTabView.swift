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

struct LotteryTabView: View {
    let type: LotteryType
    @State private var draws: [Draw] = []
    @State private var strategy: Strategy = .balanced
    @State private var rec: (front: [Int], back: [Int])? = nil
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
                    recommendSection
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
                ForEach(Array(top10), id: \.0) { n, cnt in
                    BarMark(x: .value("号", "\(n)"), y: .value("次数", cnt))
                        .foregroundStyle(Color.red)
                }
            }
            .frame(height: 160)
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
                rec = analyzer.recommend(strategy: strategy, rng: &rng)
            } label: {
                Text("生成推荐号码").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            if let r = rec {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(type.frontLabel + "：").foregroundColor(.secondary)
                        HStack(spacing: 6) { ForEach(r.front, id: \.self) { n in Ball(number: n, color: .red) } }
                    }
                    HStack {
                        Text(type.backLabel + "：").foregroundColor(.secondary)
                        HStack(spacing: 6) { ForEach(r.back, id: \.self) { n in Ball(number: n, color: .blue) } }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
