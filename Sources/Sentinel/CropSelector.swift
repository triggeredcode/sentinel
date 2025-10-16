import Cocoa

/// Overlay window for selecting a crop region
final class CropSelector {
    private var window: NSWindow?
    private var completion: ((CGRect?) -> Void)?
    
    func selectRegion(completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        
        guard let screen = NSScreen.main else {
            completion(nil)
            return
        }
        
        // Create transparent overlay
        window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window?.level = .screenSaver
        window?.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        window?.isOpaque = false
        
        let view = SelectionView(frame: screen.frame)
        view.onComplete = { [weak self] rect in
            self?.finish(rect)
        }
        window?.contentView = view
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(view)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func finish(_ rect: CGRect?) {
        window?.orderOut(nil)
        window = nil
        completion?(rect)
    }
}

private class SelectionView: NSView {
    var onComplete: ((CGRect?) -> Void)?
    private var startPoint: NSPoint?
    private var currentRect: NSRect = .zero
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onComplete?(nil) }  // ESC
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        currentRect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        if currentRect.width > 20 && currentRect.height > 20 {
            onComplete?(currentRect)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.4).setFill()
        bounds.fill()
        
        if currentRect.width > 0 {
            NSColor.clear.setFill()
            currentRect.fill(using: .copy)
            
            NSColor.white.setStroke()
            NSBezierPath(rect: currentRect).stroke()
        }
    }
}
