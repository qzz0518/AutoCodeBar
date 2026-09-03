import Foundation

/// 一条已识别并复制的验证码记录。
public struct CodeEvent: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let code: String
  public let kind: SourceKind
  public let senderDisplay: String
  /// 单行预览，≤ 80 字符。
  public let preview: String
  public let receivedAt: Date

  public init(
    id: UUID = UUID(),
    code: String,
    kind: SourceKind,
    senderDisplay: String,
    preview: String,
    receivedAt: Date
  ) {
    self.id = id
    self.code = code
    self.kind = kind
    self.senderDisplay = senderDisplay
    self.preview = preview
    self.receivedAt = receivedAt
  }
}
