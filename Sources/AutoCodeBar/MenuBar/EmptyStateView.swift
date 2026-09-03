import SwiftUI

import AutoCodeBarCore

struct EmptyStateView: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "key.horizontal")
        .font(.system(size: 28))
        .foregroundStyle(.quaternary)
      Text(L10n.text("还没有验证码"))
        .font(.system(size: 13, weight: .medium))
      Text(L10n.text("收到短信或邮件里的验证码后，会自动复制到剪贴板并显示在这里。"))
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
    .padding(.horizontal, 24)
  }
}
