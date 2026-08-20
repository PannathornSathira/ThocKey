import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var isSoundEnabled = true

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) in
            self.handleKeyPressEvent(event: event)
            return event
        }
    }

    @objc func handleKeyPressEvent(event: NSEvent) {
        if isSoundEnabled, let _ = event.characters {
            if let soundFileURL = Bundle.main.url(forResource: "keyPressSound", withExtension: "wav") {
                let keySound = NSSound(contentsOf: soundFileURL, byReference: false)
                keySound?.play()
            }
        }
    }
}
