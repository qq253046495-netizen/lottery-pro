import Foundation

struct RemoteDraw: Codable {
    let issue: Int
    let date: String
    let front: [Int]
    let back: [Int]
}

struct RemotePayload: Codable {
    let type: String
    let draws: [RemoteDraw]
}

enum LotteryServiceError: LocalizedError {
    case empty
    case invalidURL
    var errorDescription: String? {
        switch self {
        case .empty: return "返回数据为空"
        case .invalidURL: return "数据源 URL 无效"
        }
    }
}

struct LotteryService {
    // 从可配置 HTTPS(JSON) 数据源拉取并解码为标准 Draw 数组
    static func fetch(type: LotteryType, from urlString: String) async throws -> [Draw] {
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            throw LotteryServiceError.invalidURL
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        let (data, _) = try await URLSession.shared.data(for: req)
        let payload = try JSONDecoder().decode(RemotePayload.self, from: data)
        guard !payload.draws.isEmpty else { throw LotteryServiceError.empty }
        return payload.draws
            .map { Draw(issue: $0.issue, date: $0.date, front: $0.front, back: $0.back) }
            .sorted { $0.issue < $1.issue }
    }
}
