import Foundation
import AppKit

let application = NSApplication.shared
let delegate = LegacyAppDelegate()

application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
