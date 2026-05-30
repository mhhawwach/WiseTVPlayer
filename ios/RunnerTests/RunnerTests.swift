import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testCanLaunchApp() {
    // Minimal smoke test — just verifies the app delegate can be instantiated.
    let appDelegate = AppDelegate()
    XCTAssertNotNil(appDelegate)
  }
}
