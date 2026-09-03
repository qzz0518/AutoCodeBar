import Foundation
import Testing

@testable import AutoCodeBarCore

private struct Sample {
  let id: String
  let text: String
  let subject: String?
  let context: ExtractionContext
  let expected: String?

  init(_ id: String, _ text: String, subject: String? = nil, context: ExtractionContext = .message, expected: String?) {
    self.id = id
    self.text = text
    self.subject = subject
    self.context = context
    self.expected = expected
  }
}

private let corpus: [Sample] = [
  Sample("1", "【AIdea】您的验证码为：282443，请勿泄露于他人！", expected: "282443"),
  Sample("2", "【APPLE】Apple ID代码为：724818。请勿与他人共享。", expected: "724818"),
  Sample("3", "If this was you, your verification code is: 047289", expected: "047289"),
  Sample("4", "Code is: RKJ-YP6 We'll NEVER call for this code.", expected: "RKJ-YP6"),
  Sample("5", "Get a 10% discount promo code on your first payment.", expected: nil),
  Sample("6", "account 12345678 login verification code: 731464", expected: "731464"),
  Sample("7", "【京东】验证码 183920，5 分钟内有效。如非本人操作请忽略。", expected: "183920"),
  Sample("8", "【汇丰银行】09月03日20:20:40您尾号为6493的借记卡通过财付通从微信支付消费人民币128.00元", expected: nil),
  Sample("9", "Your Uber code is 4821. Never share this code.", expected: "4821"),
  Sample("10", "G-482913 is your Google verification code.", expected: "482913"),
  Sample("11", "[TikTok] 482913 is your verification code, valid for 5 minutes", expected: "482913"),
  Sample("12", "Your WhatsApp code: 482-913  Don't share this code", expected: "482913"),
  Sample("13", "【Steam】您的 Steam Guard 验证码 J7K9P，用于登录账号 qiuze", expected: "J7K9P"),
  Sample("14", "订单号 2025090412345678 已发货，物流单号 SF1234567890123", expected: nil),
  Sample("15", "您的验证码是 123456，订单号 2025090412345678，请勿泄露。", expected: "123456"),
  Sample("16", "验证码：１２３４５６（全角）", expected: "123456"),
  Sample("17", "Your code is 2024. It expires in 10 minutes.", expected: "2024"),
  Sample("18", "2024年9月4日 验证码 3391 有效期10分钟", expected: "3391"),
  Sample("19", "Verification code: 5678. Reference ID: 88213", expected: "5678"),
  Sample("20", "Amazon: 你的验证码是 314159。请勿与他人分享。", expected: "314159"),
  Sample(
    "21",
    "Your verification code is 552901. Or click https://example.com/verify?token=8837162&u=44215",
    expected: "552901"
  ),
  Sample("22", "尊敬的用户，您的账户于 09月04日 登录验证成功。", expected: nil),
  Sample("23", "Slack confirmation code: ABC-DEF", expected: nil),
  Sample("24", "Microsoft account security code: 7734519", expected: "7734519"),
  Sample("25", "【中国移动】您本月流量已使用 80%，剩余 2048MB。", expected: nil),
  Sample("26", "[카카오] 인증번호 [482913] 를 입력해 주세요.", expected: "482913"),
  Sample("27", "【メルカリ】認証番号は 482913 です。", expected: "482913"),
  Sample(
    "28",
    "Login code: 48213. Do not give this code to anyone, even if they say they are from Telegram!",
    expected: "48213"
  ),
  Sample("29", "Your verification code is 9F3K2Q", expected: "9F3K2Q"),
  Sample("30", "Use 123456 as your login code. It will expire at 12:45.", expected: "123456"),
  Sample("31", "Tu clave de acceso es 402913", expected: nil),
  Sample("32", "您尾号6493的信用卡本次交易验证码为 908172，请勿告知他人。", expected: "908172"),
  Sample("33", "Your Apple Account code is: 483921. Don't share it with anyone.", expected: "483921"),
  Sample("34", "付款 ¥ 4821 已成功，验证成功", expected: nil),
  Sample("35", "Dein Bestätigungscode lautet 402913", expected: "402913"),
  Sample(
    "M1",
    """
    Here's your GitHub launch code!

    Continue signing up for GitHub by entering the code below:

    918273

    Open GitHub

    If you didn't sign up for a GitHub account, you can safely ignore this email.
    """,
    subject: "Your GitHub launch code",
    context: .mail,
    expected: "918273"
  ),
  Sample(
    "M2",
    """
    Hi Zezheng,

    Thanks for signing up. Before we can get started, we need to confirm this address belongs to you. \
    Enter the following number in the app to continue. It will expire in 10 minutes.

    664120

    Cheers,
    The Team
    """,
    subject: "Verify your email address",
    context: .mail,
    expected: "664120"
  ),
  Sample(
    "M3",
    "Thanks for your purchase. Your order will ship in 3 days.",
    subject: "Order #48213 confirmed",
    context: .mail,
    expected: nil
  ),
  Sample(
    "M4",
    """
    您正在登录知乎，验证码：

    557201

    15 分钟内有效。
    """,
    subject: "【知乎】登录验证码",
    context: .mail,
    expected: "557201"
  )
]

@Suite("CodeExtractor 语料")
struct CodeExtractorTests {
  private let extractor = CodeExtractor()

  @Test("语料逐条", arguments: corpus.indices)
  func corpusEntry(_ index: Int) {
    let sample = corpus[index]
    let result = extractor.extract(text: sample.text, subject: sample.subject, context: sample.context)
    #expect(result?.code == sample.expected, "语料 #\(sample.id) 期望 \(sample.expected ?? "nil")，实际 \(result?.code ?? "nil")（score \(result?.score ?? -1)）")
  }

  @Test("命中关键词随候选返回")
  func keywordReported() throws {
    let result = try #require(extractor.extract(text: corpus[6].text, context: .message))
    #expect(result.code == "183920")
    #expect(result.keyword == "验证码")
  }

  @Test("无效正则报错，规则保持不变")
  func invalidPatternKeepsPreviousRules() {
    let error = ExtractionRules.validationError(for: "[A-Z")
    #expect(error != nil)
    #expect(ExtractionRules.validationError(for: AppSettings.defaultCodePattern) == nil)

    var rules = ExtractionRules.defaults
    if let updated = try? ExtractionRules(keywords: ["验证码"], pattern: "[A-Z") {
      rules = updated
      Issue.record("无效正则不应编译成功")
    }
    #expect(rules.pattern == AppSettings.defaultCodePattern)
  }

  @Test("输出规范化")
  func outputNormalization() {
    #expect(CodeExtractor.normalizeCode("G-482913") == "482913")
    #expect(CodeExtractor.normalizeCode("482-913") == "482913")
    #expect(CodeExtractor.normalizeCode("RKJ-YP6") == "RKJ-YP6")
  }
}
