import Foundation

/// 来自某个来源、尚未经过抽取的一条待检文本。
public struct Candidate: Sendable, Equatable {
  public let kind: SourceKind
  /// 源内唯一标识：messages `rowid:123`、mail 文件路径、notificationCenter `rec:456`。
  public let identity: String
  /// 短信 handle、邮件地址、通知 bundle id（小写）。
  public let senderIdentifier: String?
  public let senderDisplay: String?
  /// 仅邮件有值。
  public let subject: String?
  /// 正文（邮件不含 subject）。
  public let text: String
  public let receivedAt: Date

  public init(
    kind: SourceKind,
    identity: String,
    senderIdentifier: String? = nil,
    senderDisplay: String? = nil,
    subject: String? = nil,
    text: String,
    receivedAt: Date
  ) {
    self.kind = kind
    self.identity = identity
    self.senderIdentifier = senderIdentifier
    self.senderDisplay = senderDisplay
    self.subject = subject
    self.text = text
    self.receivedAt = receivedAt
  }
}
