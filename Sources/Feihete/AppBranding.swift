import AppKit

enum AppBranding {
    static func logo(size: NSSize = NSSize(width: 24, height: 24)) -> NSImage? {
        guard let url = Bundle.main.url(forResource: "Feihete", withExtension: "svg"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = size
        return image
    }

    /// 菜单栏专用：模板图（系统自动按单色渲染，浅色菜单栏为黑色、深色为白色）
    static func menuBarLogo(size: NSSize = NSSize(width: 18, height: 18)) -> NSImage? {
        guard let image = logo(size: size) else { return nil }
        image.isTemplate = true
        return image
    }
}

enum MainSection: Hashable {
    case dashboard
    case settings
    case about
}

final class WindowRouter: ObservableObject {
    static let shared = WindowRouter()
    @Published var requestedSection: MainSection?

    func show(_ section: MainSection) {
        requestedSection = section
    }
}
