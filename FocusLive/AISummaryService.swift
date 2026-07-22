//
//  AISummaryService.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/22.
//

import Foundation
import Combine
import SwiftData
import os

let aiSummaryTextKey = "aiSummaryText"
let aiSummaryLastUpdatedKey = "aiSummaryLastUpdated"
let aiSummaryEnabledKey = "aiSummaryEnabled"
let aiSummaryTrialUsedKey = "aiSummaryTrialUsed"
let aiSummaryTaskFingerprintKey = "aiSummaryTaskFingerprint"

@MainActor
final class AISummaryService: ObservableObject {
    static let shared = AISummaryService()

    @Published private(set) var latestSummary: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String? = nil
    @Published private(set) var lastUpdatedDate: Date? = nil
    @Published private(set) var isTrialUsed: Bool = false
    @Published var shouldShowPaywall: Bool = false

    private var updateDebounceTask: Task<Void, Never>? = nil

    private init() {
        loadCachedSummary()
    }

    /// 从 App Group 读取缓存的总结
    func loadCachedSummary() {
        let defaults = UserDefaults(suiteName: appGroupID)
        self.latestSummary = defaults?.string(forKey: aiSummaryTextKey) ?? ""
        self.isTrialUsed = defaults?.bool(forKey: aiSummaryTrialUsedKey) ?? false
        if let timestamp = defaults?.object(forKey: aiSummaryLastUpdatedKey) as? Date {
            self.lastUpdatedDate = timestamp
        }
    }

    /// 检查当前是否具备生成权限（Pro 会员无限使用，非 Pro 用户拥有 1 次设备免费试用）
    func canGenerateSummary() -> Bool {
        let defaults = UserDefaults(suiteName: appGroupID)
        let isPro = defaults?.bool(forKey: "isProUser") ?? false
        let trialUsed = defaults?.bool(forKey: aiSummaryTrialUsedKey) ?? false
        return isPro || !trialUsed
    }

    /// 计算任务指纹哈希，确保只有任务创建/修改/删除/完成状态变化时才触发
    func computeTaskFingerprint(groups: [TaskGroup]) -> String {
        let publicTasks = groups.flatMap { group -> [String] in
            guard !(group.isPrivate ?? false) else { return [] }
            return group.sortedTasks
                .filter { !($0.isPrivate ?? false) && !$0.isCompleted }
                .map { "\($0.id.uuidString):\($0.title)" }
        }
        return publicTasks.sorted().joined(separator: "|")
    }

    /// 当任务发生变更时触发自动生成 AI 总结（带防抖与重复比对）
    func requestSummaryUpdate(groups: [TaskGroup]) {
        updateDebounceTask?.cancel()
        updateDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s 防抖
            guard !Task.isCancelled else { return }
            await generateSummary(groups: groups)
        }
    }

    /// 核心方法：调用 OpenRouter API 生成一句话总结
    func generateSummary(groups: [TaskGroup], force: Bool = false) async {
        guard !isLoading else { return }

        // 1. 重复调用拦截：比对任务 Fingerprint
        let currentFingerprint = computeTaskFingerprint(groups: groups)
        let defaults = UserDefaults(suiteName: appGroupID)
        let savedFingerprint = defaults?.string(forKey: aiSummaryTaskFingerprintKey) ?? ""

        if !force && currentFingerprint == savedFingerprint && !latestSummary.isEmpty {
            debugLog("ℹ️ AISummaryService: 任务未变动，保持现有 AI 总结，跳过重复 API 调用")
            return
        }

        // 2. 会员与试用权限拦截
        if !canGenerateSummary() {
            let err = isEnglishLanguage 
                ? "AI Summary is a Pro feature. Your 1-time free trial has been used." 
                : "AI 总结为 Pro 会员专属功能。您的 1 次设备免费试用已结束，升级会员即可解锁无限使用。"
            self.lastError = err
            self.shouldShowPaywall = true
            debugLog("⚠️ AISummaryService: 试用已结束且非 Pro 用户，拦截 API 调用")
            return
        }
        
        let publicIncompleteTasks = groups.flatMap { group -> [String] in
            guard !(group.isPrivate ?? false) else { return [] }
            return group.sortedTasks
                .filter { !($0.isPrivate ?? false) && !$0.isCompleted }
                .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        guard !publicIncompleteTasks.isEmpty else {
            let emptyMsg = isEnglishLanguage ? "All tasks are completed! Enjoy your day." : "当前无待办任务，享受高效轻松的一天！"
            updateLocalSummary(emptyMsg, fingerprint: currentFingerprint)
            return
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let apiKey = fetchOpenRouterAPIKey()
        guard !apiKey.isEmpty else {
            let err = isEnglishLanguage ? "API Key not found in .env" : "未在 .env 中找到 API Key"
            self.lastError = err
            debugLog("⚠️ AISummaryService: \(err)")
            return
        }

        // 构造纯任务清单上下文（不传分组名，避免 AI 产生固定机械套句）
        let taskLines = publicIncompleteTasks.map { "- \($0)" }
        let taskContext = taskLines.joined(separator: "\n")

        // 双语提示词准备（Humanizer-zh 拟人化自然人话，摒弃抽象假大空套话）
        let isEN = isEnglishLanguage
        let systemPrompt = isEN
            ? """
            You are a helpful, warm personal assistant. Summarize all active tasks (todos, habits, reminders) into ONE natural, friendly, and cohesive human sentence (30-50 words). 
            Rules:
            1. Mention concrete core tasks naturally (e.g. graduation photo, daily study habits, groceries).
            2. NEVER use rigid corporate buzzwords (like 'spearhead', 'holistic', 'synergize', 'optimize status').
            3. Sound like a caring real friend or personal manager giving a clear, warm preview.
            4. MUST output strict JSON format: {"summary": "your summary sentence"}
            """
            : """
            你是一位细心贴心的私人助手。请阅读用户未完成的所有事项（包含待办、提醒与打卡），用一段自然口语化、接地气且通顺连贯的人话（40-80字）总结出用户最近的具体安排与行动。
            核心规则：
            1. 具体自然：真实保留并巧妙串联用户的核心具体任务（例如：毕业照/毕业典礼/形象整理、单词听力阅读打卡、买西红柿等），像真实朋友说话一样连贯表达。
            2. 严禁假大空：坚决禁止使用任何 AI 官僚/营销假大空词汇（如“以...为基调”、“同步推进”、“焕新”、“精进”、“赋能”、“积蓄...状态”等）。
            3. 语气亲切得体：像熟人或贴心管家温馨提示：“最近需要...；同时坚持...打卡，另外记得...”。
            4. 格式要求：必须输出严格 JSON 格式：{"summary": "你的总结内容"}
            """

        let userPrompt = isEN
            ? "Current active tasks:\n\(taskContext)"
            : "当前待办事项清单：\n\(taskContext)"

        // 构造 OpenRouter 请求 Payload
        let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("FocusLive-iOS", forHTTPHeaderField: "X-Title")

        let requestBody: [String: Any] = [
            "model": "inclusionai/ling-2.6-flash",
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.6,
            "max_tokens": 250
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw NSError(domain: "AISummaryService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenRouter HTTP Error \(statusCode)"])
            }

            if let summaryResult = parseSummaryFromJSONResponse(data: data) {
                updateLocalSummary(summaryResult, fingerprint: currentFingerprint)
                debugLog("✨ AI 总结生成成功: \(summaryResult)")
                
                // 触发 Live Activity 同步
                ActivityManager.shared.syncActivities(groups: groups)
            } else {
                throw NSError(domain: "AISummaryService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON summary"])
            }
        } catch {
            self.lastError = error.localizedDescription
            debugLog("⚠️ AI 总结生成失败: \(error.localizedDescription)")
        }
    }

    /// 更新本地缓存与发布属性
    private func updateLocalSummary(_ summary: String, fingerprint: String? = nil) {
        let cleanText = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        self.latestSummary = cleanText
        self.lastUpdatedDate = Date()
        
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(cleanText, forKey: aiSummaryTextKey)
        defaults?.set(self.lastUpdatedDate, forKey: aiSummaryLastUpdatedKey)
        if let fingerprint = fingerprint {
            defaults?.set(fingerprint, forKey: aiSummaryTaskFingerprintKey)
        }

        // 若非 Pro 会员，完成生成后消费 1 次试用
        let isPro = defaults?.bool(forKey: "isProUser") ?? false
        if !isPro {
            defaults?.set(true, forKey: aiSummaryTrialUsedKey)
            self.isTrialUsed = true
        }
    }

    /// 读取与解析 OpenRouter 返回的 JSON
    private func parseSummaryFromJSONResponse(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let contentString = message["content"] as? String else {
            return nil
        }

        // 解析包含 {"summary": "..."} 的内嵌 JSON 字符串
        if let innerData = contentString.data(using: .utf8),
           let innerJSON = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any],
           let summaryText = innerJSON["summary"] as? String {
            return summaryText
        }

        // 兜底返回清理后的文本
        return contentString.replacingOccurrences(of: "{\"summary\":", with: "")
            .replacingOccurrences(of: "}", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \"\n"))
    }

    /// 读取 `.env` 或 Bundle 中的 OPENROUTER_API_KEY
    private func fetchOpenRouterAPIKey() -> String {
        // 尝试从项目 Bundle 或开发环境路径读取
        let possiblePaths = [
            Bundle.main.path(forResource: ".env", ofType: nil) ?? "",
            "/Users/qingteng/Downloads/项目代码_Projects/我的制作/FocusLive/FocusLive/FocusLive/.env"
        ]

        for path in possiblePaths where !path.isEmpty {
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    if trimmedLine.hasPrefix("OPENROUTER_API_KEY=") {
                        let key = trimmedLine.replacingOccurrences(of: "OPENROUTER_API_KEY=", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !key.isEmpty { return key }
                    }
                }
            }
        }
        
        return ""
    }

    /// 是否处于英文系统语言
    private var isEnglishLanguage: Bool {
        if let lang = Locale.current.language.languageCode?.identifier {
            return lang.lowercased().hasPrefix("en")
        }
        return Bundle.main.preferredLocalizations.first?.lowercased().hasPrefix("en") ?? false
    }
}
