// Renders a web page to PNG with WebKit (used for the README images).
// Usage: swift tools/snapshot.swift <url> <out.png> <width> <height> [light|dark] [delay-seconds]
import AppKit
import WebKit

let args = CommandLine.arguments
guard args.count >= 5, let url = URL(string: args[1]),
      let width = Double(args[3]), let height = Double(args[4]) else {
    FileHandle.standardError.write("usage: snapshot <url> <out.png> <width> <height> [light|dark] [delay]\n".data(using: .utf8)!)
    exit(2)
}
let out = URL(fileURLWithPath: args[2])
let dark = args.count > 5 && args[5] == "dark"
let delay = args.count > 6 ? Double(args[6]) ?? 1.0 : 1.0

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

final class Loader: NSObject, WKNavigationDelegate {
    let view: WKWebView
    let window: NSWindow

    init(size: NSSize, dark: Bool) {
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless],
                          backing: .buffered, defer: false)
        window.backingType = .buffered
        view = WKWebView(frame: NSRect(origin: .zero, size: size))
        super.init()
        view.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.appearance = view.appearance
        window.contentView = view
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.orderBack(nil)
        view.navigationDelegate = self
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let config = WKSnapshotConfiguration()
            config.rect = webView.bounds
            config.snapshotWidth = NSNumber(value: Double(webView.bounds.width) * 2) // retina
            webView.takeSnapshot(with: config) { image, error in
                guard let image = image, let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    FileHandle.standardError.write("snapshot failed: \(String(describing: error))\n".data(using: .utf8)!)
                    exit(1)
                }
                try? png.write(to: out)
                print(out.path)
                exit(0)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        FileHandle.standardError.write("load failed: \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}

let loader = Loader(size: NSSize(width: width, height: height), dark: dark)
if url.isFileURL {
    loader.view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent().deletingLastPathComponent())
} else {
    loader.view.load(URLRequest(url: url))
}
DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
    FileHandle.standardError.write("timeout\n".data(using: .utf8)!)
    exit(1)
}
app.run()
