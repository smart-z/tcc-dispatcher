import SwiftUI

// MARK: - 工业级常量配置
enum AppConfig {
    static let appNameKey: LocalizedStringKey = "AppTitle"
    static let scanPaths = [
        "/Applications",
        "/System/Applications",
        NSHomeDirectory() + "/Applications"
    ]
}

// MARK: - 统一跳转引擎
struct PrivacyLinker {
    static func open(for type: PermissionType, appName: String) {
        let anchor: String
        switch type {
        case .fullDiskAccess: anchor = "Privacy_AllFiles"
        case .microphone: anchor = "Privacy_Microphone"
        case .camera: anchor = "Privacy_Camera"
        case .accessibility: anchor = "Privacy_Accessibility"
        case .screenRecording: anchor = "Privacy_ScreenCapture"
        case .inputMonitoring: anchor = "Privacy_ListenEvent"
        case .desktopFolder, .documentsFolder, .downloadsFolder: anchor = "Privacy_FilesAndFolders"
        case .contacts: anchor = "Privacy_Contacts"
        case .calendars: anchor = "Privacy_Calendars"
        case .photos: anchor = "Privacy_Photos"
        case .location: anchor = "Privacy_LocationServices"
        case .bluetooth: anchor = "Privacy_Bluetooth"
        case .mediaLibrary: anchor = "Privacy_MediaLibrary"
        case .speechRecognition: anchor = "Privacy_SpeechRecognition"
        }
        
        let urlStrings = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)",
            "x-apple.systempreferences:com.apple.Settings.Privacy-Settings.extension?\(anchor)",
            "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ]
        
        for urlString in urlStrings {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let scriptSource = """
            tell application "System Events"
                tell process "System Settings"
                    set frontmost to true
                    try
                        keystroke "f" using {command down}
                        delay 0.3
                        keystroke "\(appName)"
                        delay 0.3
                        keystroke return
                    end try
                end tell
            end tell
            """
            if let script = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }
        }
    }
}

@main
struct TCCDispatcherApp: App {
    @State private var deepLinkQuery: String?

    var body: some Scene {
        Window(AppConfig.appNameKey, id: "main") {
            MainView(deepLinkQuery: $deepLinkQuery)
                .onOpenURL { url in
                    deepLinkQuery = url.query()
                }
        }
        .windowResizability(.contentSize)
    }
}

struct StatusText: View {
    let status: PermissionStatus
    let service: PermissionType
    let appName: String
    let appPath: String
    let bundleId: String
    
    var body: some View {
        Button(action: {
            PrivacyLinker.open(for: service, appName: appName)
        }) {
            ZStack {
                if status == .allowed {
                    Color.green.opacity(0.15)
                        .cornerRadius(4)
                } else if status == .denied {
                    Color.red.opacity(0.15)
                        .cornerRadius(4)
                } else {
                    Color.clear
                }
                
                if status != .notSet {
                    Image(systemName: status == .allowed ? "checkmark" : "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(status == .allowed ? .green : .red)
                }
            }
            .padding(2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 28)
    }
}

struct MainView: View {
    @Binding var deepLinkQuery: String?
    @State private var apps: [AppInfo] = []
    @State private var search = ""
    @State private var loading = false
    @StateObject private var tccReader = TCCReader()

    var filteredApps: [AppInfo] {
        let query = deepLinkQuery ?? search
        if query.isEmpty { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Table(filteredApps) {
                nameColumn
                
                Group {
                    permissionColumn("FullDiskAccess", width: 75, service: .fullDiskAccess)
                    permissionColumn("Microphone", width: 65, service: .microphone)
                    permissionColumn("Camera", width: 65, service: .camera)
                    permissionColumn("Accessibility", width: 75, service: .accessibility)
                }
                
                Group {
                    permissionColumn("ScreenRecording", width: 75, service: .screenRecording)
                    permissionColumn("InputMonitoring", width: 75, service: .inputMonitoring)
                    permissionColumn("Desktop", width: 65, service: .desktopFolder)
                    permissionColumn("Documents", width: 65, service: .documentsFolder)
                    permissionColumn("Downloads", width: 65, service: .downloadsFolder)
                }
            }
            .tableStyle(.inset)
            .searchable(text: $search, placement: .toolbar, prompt: LocalizedStringKey("SearchPrompt"))
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if loading { ProgressView().controlSize(.small) }
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: refresh) { Image(systemName: "arrow.clockwise") }.help(LocalizedStringKey("Refresh"))
                }
            }
            
            Divider()
            
            bottomBar
        }
        .frame(minWidth: 800, minHeight: 400)
        .onAppear { loadAll() }
        .onChange(of: deepLinkQuery) { newValue in
            if let query = newValue {
                search = query
            }
        }
    }
    
    // MARK: - 列工厂（官方 label: 构造器，控制表头对齐）
    private func permissionColumn(_ title: String, width: CGFloat, service: PermissionType) -> some TableColumnContent<AppInfo, Never> {
        TableColumn(LocalizedStringKey(title)) { (app: AppInfo) in
            StatusText(status: tccReader.getStatus(for: app.bundleId, service: service), service: service, appName: app.name, appPath: app.path, bundleId: app.bundleId)
        }
        .width(width)
        .alignment(.center)
    }
    
    private var nameColumn: some TableColumnContent<AppInfo, Never> {
        TableColumn(String(localized: "AppName")) { (app: AppInfo) in
            HStack(spacing: 8) {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                } else {
                    Image(systemName: "app.fill").foregroundColor(.secondary.opacity(0.3)).frame(width: 16, height: 16)
                }
                Text(app.name).font(.system(size: 11)).lineLimit(1)
            }
            .help(LocalizedStringKey("DragToAuth"))
            .onDrag { NSItemProvider(object: URL(fileURLWithPath: app.path) as NSURL) }
        }
        .width(min: 180, ideal: 220)
    }
}

// MARK: - UI 子模块
extension MainView {
    private var bottomBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Circle().fill(tccReader.hasFullDiskAccess ? Color.green : Color.red).frame(width: 8, height: 8)
                Text(tccReader.hasFullDiskAccess ? LocalizedStringKey("Ready") : LocalizedStringKey("NeedFDA")).font(.system(size: 10)).foregroundColor(.secondary)
                if !tccReader.hasFullDiskAccess {
                    Button(action: { PrivacyLinker.open(for: .fullDiskAccess, appName: "TCC Dispatcher") }) {
                        Text(LocalizedStringKey("Repair")).font(.system(size: 10)).foregroundColor(.blue)
                    }.buttonStyle(.plain)
                }
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "cursorarrow.click.2")
                Text(LocalizedStringKey("ClickToJump"))
                Text("|").opacity(0.3)
                Image(systemName: "hand.draw")
                Text(LocalizedStringKey("DragToAuth"))
            }.font(.system(size: 10, weight: .medium)).foregroundColor(.secondary.opacity(0.8))
            Spacer()
            Text("AppCount \(filteredApps.count) \(tccReader.permissionCount)").font(.system(size: 10)).foregroundColor(.secondary)
        }.padding(.horizontal, 12).padding(.vertical, 4).background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - 业务逻辑
extension MainView {
    func loadAll() { loadApps(); refresh() }
    func refresh() {
        loading = true
        tccReader.loadPermissions()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { loading = false }
    }
    func loadApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var list: [AppInfo] = []
            for base in AppConfig.scanPaths {
                if let contents = try? fm.contentsOfDirectory(atPath: base) {
                    for item in contents where item.hasSuffix(".app") {
                        let path = (base as NSString).appendingPathComponent(item)
                        let infoPath = (path as NSString).appendingPathComponent("Contents/Info.plist")
                        if let data = fm.contents(atPath: infoPath),
                           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                            let name = plist["CFBundleName"] as? String ?? (item as NSString).replacingOccurrences(of: ".app", with: "")
                            let bundleId = plist["CFBundleIdentifier"] as? String ?? "unknown"
                            let icon = NSWorkspace.shared.icon(forFile: path)
                            icon.size = NSSize(width: 32, height: 32)
                            list.append(AppInfo(name: name, bundleId: bundleId, icon: icon, path: path))
                        }
                    }
                }
            }
            DispatchQueue.main.async { self.apps = list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } }
        }
    }
}