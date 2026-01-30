import Cocoa

/// Transparent overlay window for selecting a capture region
@MainActor
final class CropSelector {
    
    private var overlayWindow: NSWindow?
    private var selectionView: CropSelectionView?
    private var completion: ((CGRect?) -> Void)?
    
    /// Shows the crop selector overlay
    /// - Parameter completion: Called with the selected region, or nil if cancelled
    func selectRegion(completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        showOverlay()
    }
    
    private func showOverlay() {
        guard let screen = NSScreen.main else {
            completion?(nil)
            return
        }
        
        // Create full-screen transparent window
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Create selection view
        let view = CropSelectionView(frame: screen.frame)
        view.onComplete = { [weak self] rect in
            self?.finishSelection(rect)
        }
        view.onCancel = { [weak self] in
            self?.finishSelection(nil)
        }
        
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        
        self.overlayWindow = window
        self.selectionView = view
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func finishSelection(_ rect: CGRect?) {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        selectionView = nil
        
        if let rect = rect, let screen = NSScreen.main {
            // Convert from view coordinates to screen coordinates
            let screenRect = CGRect(
                x: rect.origin.x,
                y: screen.frame.height - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            )
            completion?(screenRect)
        } else {
            completion?(nil)
        }
    }
}

/// View that handles mouse drag for region selection
private final class CropSelectionView: NSView {
    
    var onComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    
    private var startPoint: NSPoint?
    private var currentRect: NSRect = .zero
    private var isDragging = false
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Semi-transparent overlay
        NSColor.black.withAlphaComponent(0.5).setFill()
        bounds.fill()
        
        // Instructions if not dragging
        if !isDragging && currentRect == .zero {
            let text = "Drag to select region • Press ESC to cancel"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let size = text.size(withAttributes: attrs)
            let point = NSPoint(
                x: (bounds.width - size.width) / 2,
                y: (bounds.height - size.height) / 2
            )
            text.draw(at: point, withAttributes: attrs)
        }
        
        // Selection rectangle
        if currentRect.width > 0 && currentRect.height > 0 {
            // Clear the selection area
            NSColor.clear.setFill()
            currentRect.fill(using: .copy)
            
            // White border
            NSColor.white.setStroke()
            let borderPath = NSBezierPath(rect: currentRect)
            borderPath.lineWidth = 2
            borderPath.stroke()
            
            // Blue dashed inner border
            NSColor.systemBlue.setStroke()
            let innerRect = currentRect.insetBy(dx: 3, dy: 3)
            let innerPath = NSBezierPath(rect: innerRect)
            innerPath.lineWidth = 1
            innerPath.setLineDash([6, 4], count: 2, phase: 0)
            innerPath.stroke()
            
            // Corner handles
            let handleSize: CGFloat = 8
            NSColor.white.setFill()
            for corner in [
                CGPoint(x: currentRect.minX, y: currentRect.minY),
                CGPoint(x: currentRect.maxX, y: currentRect.minY),
                CGPoint(x: currentRect.minX, y: currentRect.maxY),
                CGPoint(x: currentRect.maxX, y: currentRect.maxY)
            ] {
                let handleRect = NSRect(
                    x: corner.x - handleSize/2,
                    y: corner.y - handleSize/2,
                    width: handleSize,
                    height: handleSize
                )
                NSBezierPath(ovalIn: handleRect).fill()
            }
            
            // Dimensions label
            let dims = String(format: "%.0f × %.0f", currentRect.width, currentRect.height)
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let labelSize = dims.size(withAttributes: labelAttrs)
            let labelPadding: CGFloat = 6
            let labelRect = NSRect(
                x: currentRect.midX - labelSize.width/2 - labelPadding,
                y: currentRect.maxY + 10,
                width: labelSize.width + labelPadding * 2,
                height: labelSize.height + labelPadding
            )
            
            NSColor.black.withAlphaComponent(0.8).setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4).fill()
            dims.draw(
                at: NSPoint(x: labelRect.minX + labelPadding, y: labelRect.minY + labelPadding/2),
                withAttributes: labelAttrs
            )
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // ESC
            onCancel?()
        } else if event.keyCode == 36 && currentRect.width > 10 {  // Enter
            onComplete?(currentRect)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        isDragging = true
        currentRect = .zero
        needsDisplay = true
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
        isDragging = false
        
        if currentRect.width > 20 && currentRect.height > 20 {
            onComplete?(currentRect)
        } else {
            currentRect = .zero
            needsDisplay = true
        }
    }
}
