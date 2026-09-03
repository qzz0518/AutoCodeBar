import SwiftUI

import AutoCodeBarCore

struct RulesPane: View {
  let state: AppState

  @State private var keywordText = ""
  @State private var patternText = ""
  @State private var sampleText = ""
  @State private var patternError: String?
  @State private var testResult: Extraction?
  @State private var didLoad = false
  @State private var commitTask: Task<Void, Never>?
  @State private var testTask: Task<Void, Never>?

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      SettingsSection(title: L10n.text("触发关键词"), systemImage: "text.quote", spacing: 10) {
        Text(L10n.text("只有包含任一关键词的消息才会被识别，匹配不区分大小写，每行一个。"))
          .font(Theme.caption)
          .foregroundStyle(Theme.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)

        FieldBox {
          TextEditor(text: $keywordText)
            .font(Theme.mono)
            .frame(height: 120)
            .scrollContentBackground(.hidden)
        }
      }

      SettingsSection(title: L10n.text("验证码格式"), systemImage: "number", spacing: 10) {
        FieldBox {
          TextField(L10n.text("正则"), text: $patternText)
            .font(Theme.mono)
        }

        HStack(spacing: 8) {
          if let patternError {
            StatusPill(text: L10n.text("无法编译"), tone: .bad)
            Text(patternError)
              .font(Theme.caption)
              .foregroundStyle(Theme.inkSecondary)
              .fixedSize(horizontal: false, vertical: true)
          } else {
            StatusPill(text: L10n.text("正则有效"), tone: .live)
          }
        }

        Text(L10n.text("匹配到的片段还需满足：4–8 个字母或数字，且至少包含 1 个数字。"))
          .font(Theme.caption)
          .foregroundStyle(Theme.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      SettingsSection(title: L10n.text("测试"), systemImage: "flask", spacing: 10) {
        FieldBox {
          ZStack(alignment: .topLeading) {
            TextEditor(text: $sampleText)
              .font(Theme.body)
              .frame(height: 80)
              .scrollContentBackground(.hidden)
            if sampleText.isEmpty {
              Text(L10n.text("粘贴一条短信或邮件内容…"))
                .font(Theme.body)
                .foregroundStyle(Theme.inkTertiary)
                .padding(.top, 1)
                .padding(.leading, 5)
                .allowsHitTesting(false)
            }
          }
        }

        if let testResult {
          Notice(
            text: L10n.format("提取到 %@（关键词「%@」）", testResult.code, testResult.keyword),
            tone: .good
          )
        } else {
          Notice(text: L10n.text("未识别到验证码"), tone: .info)
        }
      }

      Button(L10n.text("恢复默认规则")) {
        state.restoreDefaultRules()
        load()
        validate()
        runTest()
      }
      .buttonStyle(SoftButtonStyle())
    }
    .onAppear {
      guard !didLoad else {
        return
      }
      didLoad = true
      load()
      validate()
    }
    .onChange(of: keywordText) { _, _ in
      scheduleCommit()
    }
    .onChange(of: patternText) { _, _ in
      validate()
      scheduleCommit()
    }
    .onChange(of: sampleText) { _, _ in
      scheduleTest()
    }
  }

  private func load() {
    keywordText = state.settings.keywords.joined(separator: "\n")
    patternText = state.settings.codePattern
    testResult = nil
  }

  private func validate() {
    patternError = ExtractionRules.validationError(for: patternText)
  }

  private func scheduleCommit() {
    commitTask?.cancel()
    commitTask = Task {
      try? await Task.sleep(nanoseconds: 300_000_000)
      guard !Task.isCancelled else {
        return
      }
      commit()
      runTest()
    }
  }

  private func commit() {
    let keywords = keywordText
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    if !keywords.isEmpty, keywords != state.settings.keywords {
      state.settings.keywords = keywords
    }
    if patternError == nil, !patternText.isEmpty, patternText != state.settings.codePattern {
      state.settings.codePattern = patternText
    }
  }

  private func scheduleTest() {
    testTask?.cancel()
    testTask = Task {
      try? await Task.sleep(nanoseconds: 150_000_000)
      guard !Task.isCancelled else {
        return
      }
      runTest()
    }
  }

  private func runTest() {
    let trimmed = sampleText.trimmingCharacters(in: .whitespacesAndNewlines)
    testResult = trimmed.isEmpty ? nil : state.testExtraction(trimmed)
  }
}
