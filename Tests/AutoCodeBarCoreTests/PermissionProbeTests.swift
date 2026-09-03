import Foundation
import Testing

@testable import AutoCodeBarCore

@Suite("PermissionProbe")
struct PermissionProbeTests {
  @Test("可读文件返回 readable")
  func readableFile() throws {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("acb-probe-\(UUID().uuidString).txt")
    try Data("x".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(PermissionProbe.probeFile(url.path) == .readable)
  }

  @Test("父目录可读但文件不存在返回 missing")
  func missingFile() {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("acb-absent-\(UUID().uuidString).txt")
    #expect(PermissionProbe.probeFile(url.path) == .missing)
  }

  @Test("可读目录返回 readable，不存在的目录返回 missing")
  func directories() {
    #expect(PermissionProbe.probeDirectory(NSTemporaryDirectory()) == .readable)
    let absent = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("acb-absent-dir-\(UUID().uuidString)")
    #expect(PermissionProbe.probeDirectory(absent.path) == .missing)
  }

  @Test("探测不抛不崩，返回三态之一")
  func liveProbe() {
    let state = PermissionProbe.fullDiskAccess()
    #expect([.granted, .denied, .noData].contains(state))
  }
}
