import SwiftUI

// The system creates this controller when you pick Potter's Stages in a share sheet.
// It only hosts the SwiftUI ShareView; all the logic lives in ShareModel.

#if os(iOS)
import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareView(model: ShareModel(context: extensionContext)))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

#else
import AppKit

final class ShareViewController: NSViewController {
    override func loadView() {
        let host = NSHostingView(rootView: ShareView(model: ShareModel(context: extensionContext)))
        host.frame = NSRect(x: 0, y: 0, width: 420, height: 460)
        view = host
        preferredContentSize = host.frame.size
    }
}
#endif
