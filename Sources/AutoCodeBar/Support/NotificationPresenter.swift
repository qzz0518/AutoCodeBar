import AppKit
import Foundation
import UserNotifications

import AutoCodeBarCore

/// 复制成功后的系统通知。
@MainActor
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
  /// 用户点击通知时回调（把验证码再复制一次）。
  var onOpenCode: ((String) -> Void)?

  private var didRequestAuthorization = false

  func configure() {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.removeAllDeliveredNotifications()
  }

  /// 首次需要发通知时才申请权限。
  @discardableResult
  func requestAuthorization() async -> Bool {
    didRequestAuthorization = true
    do {
      return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
    } catch {
      return false
    }
  }

  func present(_ event: CodeEvent) {
    Task { [weak self] in
      guard let self else {
        return
      }
      let center = UNUserNotificationCenter.current()
      let status = await center.notificationSettings().authorizationStatus
      if status == .notDetermined, !self.didRequestAuthorization {
        guard await self.requestAuthorization() else {
          return
        }
      } else if status == .denied {
        return
      }

      let content = UNMutableNotificationContent()
      content.title = L10n.format("已复制验证码 %@", event.code)
      content.body = L10n.format("来自 %@ · %@", event.senderDisplay, event.kind.shortName)
      content.sound = nil
      content.threadIdentifier = "codes"
      content.userInfo = ["code": event.code]

      let request = UNNotificationRequest(
        identifier: event.id.uuidString,
        content: content,
        trigger: nil
      )
      try? await center.add(request)
    }
  }

  // MARK: - UNUserNotificationCenterDelegate

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner])
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let code = response.notification.request.content.userInfo["code"] as? String
    Task { @MainActor [weak self] in
      if let code {
        self?.onOpenCode?(code)
      }
      completionHandler()
    }
  }
}
