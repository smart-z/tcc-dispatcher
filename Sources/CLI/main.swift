import Foundation
import AppKit
import SQLite3

// MARK: - CLI 数据模型（复用逻辑，不依赖 SwiftUI）

enum PermissionType: String, CaseIterable {
    case fullDiskAccess = "kTCCServiceSystemPolicyAllFiles"
    case microphone = "kTCCServiceMicrophone"
    case camera = "kTCCServiceCamera"
    case accessibility = "kTCCServiceAccessibility"
    case screenRecording = "kTCCServiceScreenCapture"
    case inputMonitoring = "kTCCServiceInputMonitoring"
    case desktopFolder = "kTCCServiceSystemPolicyDesktopFolder"
    case documentsFolder = "kTCCServiceSystemPolicyDocumentsFolder"
    case downloadsFolder = "kTCCServiceSystemPolicyDownloadsFolder"
    case contacts = "kTCCServiceContacts"
    case calendars = "kTCCServiceCalendars"
    case photos = "kTCCServicePhotos"
    case location = "kTCCServiceLocation"
    case bluetooth = "kTCCServiceBluetooth"
    case mediaLibrary = "kTCCServiceMediaLibrary"
    case speechRecognition = "kTCCServiceSpeechRecognition"

    var displayName: String {
        switch self {
        case .fullDiskAccess: return "全盘访问"
        case .microphone: return "麦克风"
        case .camera: return "摄像头"
        case .accessibility: return "辅助功能"
        case .screenRecording: return "屏幕录制"
        case .inputMonitoring: return "输入监控"
        case .desktopFolder: return "桌面"
        case .documentsFolder: return "文档"
        case .downloadsFolder: return "下载"
        case .contacts: return "通讯录"
        case .calendars: return "日历"
        case .photos: return "照片"
        case .location: return "定位"
        case .bluetooth: return "蓝牙"
        case .mediaLibrary: return "媒体库"
        case .speechRecognition: return "语音识别"
        }
    }

    var anchor: String {
        switch self {
        case .fullDiskAccess: return "Privacy_AllFiles"
        case .microphone: return "Privacy_Microphone"
        case .camera: return "Privacy_Camera"
        case .accessibility: return "Privacy_Accessibility"
        case .screenRecording: return "Privacy_ScreenCapture"
        case .inputMonitoring: return "Privacy_ListenEvent"
        case .desktopFolder, .documentsFolder, .downloadsFolder: return "Privacy_FilesAndFolders"
        case .contacts: return "Privacy_Contacts"
        case .calendars: return "Privacy_Calendars"
        case .photos: return "Privacy_Photos"
        case .location: return "Privacy_LocationServices"
        case .bluetooth: return "Privacy_Bluetooth"
        case .mediaLibrary: return "Privacy_MediaLibrary"
        case .speechRecognition: return "Privacy_SpeechRecognition"
        }
    }

    var sfSymbol: String {
        switch self {
        case .fullDiskAccess: return "internaldrive"
        case .microphone: return "mic"
        case .camera: return "camera"
        case .accessibility: return "accessibility"
        case .screenRecording: return "video"
        case .inputMonitoring: return "keyboard"
        case .desktopFolder: return "desktopcomputer"
        case .documentsFolder: return "doc"
        case .downloadsFolder: return "arrow.down.circle"
        case .contacts: return "person.2"
        case .calendars: return "calendar"
        case .photos: return "photo"
        case .location: return "location"
        case .bluetooth: return "bluetooth"
        case .mediaLibrary: return "music.note.list"
        case .speechRecognition: return "waveform"
        }
    }
}

enum PermissionStatus: Int {
    case notSet = -1
    case denied = 0
    case allowed = 2

    var displayText: String {
        switch self {
        case .notSet: return "未设置"
        case .denied: return "已拒绝"
        case .allowed: return "已允许"
        }
    }

    var sfSymbol: String {
        switch self {
        case .notSet: return "questionmark.circle"
        case .denied: return "xmark.circle.fill"
        case .allowed: return "checkmark.circle.fill"
        }
    }
}

// MARK: - CLI 数据模型

struct CLIAppInfo: Codable {
    let name: String
    let bundleId: String
    let path: String
    let permissions: [String: Int] // service -> status

    var allowedCount: Int { permissions.values.filter { $0 == 2 }.count }
    var deniedCount: Int { permissions.values.filter { $0 == 0 }.count }
    var totalCount: Int { permissions.count }
}

// MARK: - TCC 数据库读取

struct TCCDatabase {
    static let dbPaths = [
        NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db",
        "/Library/Application Support/com.apple.TCC/TCC.db",
    ]

    static func readAll() -> [String: [String: Int]] {
        var result: [String: [String: Int]] = [:]

        for path in dbPaths {
            var db: OpaquePointer?
            guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { continue }
            defer { sqlite3_close(db) }

            let query = "SELECT client, service, auth_value FROM access;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { continue }

            while sqlite3_step(stmt) == SQLITE_ROW {
                if let clientC = sqlite3_column_text(stmt, 0),
                   let serviceC = sqlite3_column_text(stmt, 1) {
                    let client = String(cString: clientC)
                    let service = String(cString: serviceC)
                    let authValue = Int(sqlite3_column_int(stmt, 2))

                    if result[client] == nil { result[client] = [:] }
                    result[client]?[service] = authValue
                }
            }
            sqlite3_finalize(stmt)
        }

        return result
    }
}

// MARK: - 应用扫描

struct AppScanner {
    static let scanPaths = [
        "/Applications",
        "/System/Applications",
        NSHomeDirectory() + "/Applications",
    ]

    static func scan(query: String = "") -> [CLIAppInfo] {
        let tccData = TCCDatabase.readAll()
        var apps: [CLIAppInfo] = []

        for basePath in scanPaths {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: basePath) else { continue }

            for item in contents where item.hasSuffix(".app") {
                let appPath = (basePath as NSString).appendingPathComponent(item)
                let infoPlistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")

                guard let data = FileManager.default.contents(atPath: infoPlistPath),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { continue }

                let name = plist["CFBundleName"] as? String ?? item.replacingOccurrences(of: ".app", with: "")
                let bundleId = plist["CFBundleIdentifier"] as? String ?? "unknown"

                if !query.isEmpty && !name.localizedCaseInsensitiveContains(query) && !bundleId.localizedCaseInsensitiveContains(query) {
                    continue
                }

                let permissions = tccData[bundleId] ?? [:]
                apps.append(CLIAppInfo(name: name, bundleId: bundleId, path: appPath, permissions: permissions))
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Alfred JSON 输出

struct AlfredItem: Codable {
    let uid: String
    let title: String
    let subtitle: String
    let arg: String
    let autocomplete: String?
    let valid: Bool?
    let icon: AlfredIcon
    let text: AlfredText?
    let mods: [String: AlfredMod]?

    struct AlfredIcon: Codable {
        let type: String?
        let name: String?
        let path: String?

        init(path: String) {
            self.type = "fileicon"
            self.name = nil
            self.path = path
        }

        init(sfSymbol: String) {
            self.type = "sf-symbol"
            self.name = sfSymbol
            self.path = nil
        }
    }

    struct AlfredText: Codable {
        let copy: String
        let largetype: String
    }

    struct AlfredMod: Codable {
        let valid: Bool
        let arg: String
        let subtitle: String
    }
}

struct AlfredOutput: Codable {
    let items: [AlfredItem]
}

func outputAlfredApps(_ apps: [CLIAppInfo]) {
    var items: [AlfredItem] = []

    if apps.isEmpty {
        items.append(AlfredItem(
            uid: "no-result",
            title: "未找到匹配的应用",
            subtitle: "请尝试其他关键词",
            arg: "",
            autocomplete: nil,
            valid: false,
            icon: .init(path: "/Applications"),
            text: nil,
            mods: nil
        ))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(AlfredOutput(items: items)) {
            print(String(data: data, encoding: .utf8) ?? "")
        }
        return
    }

    for app in apps {
        var subtitleParts = ["\(app.totalCount) 项权限"]
        if app.allowedCount > 0 { subtitleParts.append("\(app.allowedCount) 已允许") }
        if app.deniedCount > 0 { subtitleParts.append("\(app.deniedCount) 已拒绝") }

        items.append(AlfredItem(
            uid: "app-\(app.bundleId)",
            title: app.name,
            subtitle: subtitleParts.joined(separator: " | ") + " — \(app.bundleId)",
            arg: app.bundleId,
            autocomplete: app.bundleId,
            valid: false,
            icon: .init(path: app.path),
            text: nil,
            mods: [
                "cmd": AlfredItem.AlfredMod(
                    valid: true,
                    arg: String(data: try! JSONSerialization.data(withJSONObject: [
                        "action": "open_app",
                        "path": app.path,
                    ]), encoding: .utf8) ?? "",
                    subtitle: "打开此应用"
                ),
            ]
        ))
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(AlfredOutput(items: items)) {
        print(String(data: data, encoding: .utf8) ?? "")
    }
}

func outputAlfredPerms(_ app: CLIAppInfo) {
    var items: [AlfredItem] = []

    for permType in PermissionType.allCases {
        let service = permType.rawValue
        let status = app.permissions[service]
        let permStatus = status != nil ? (PermissionStatus(rawValue: status!) ?? .notSet) : .notSet

        let jumpArg = try! JSONSerialization.data(withJSONObject: [
            "action": "jump",
            "bundle_id": app.bundleId,
            "app_name": app.name,
            "app_path": app.path,
            "service": service,
            "anchor": permType.anchor,
        ])

        items.append(AlfredItem(
            uid: "perm-\(app.bundleId)-\(service)",
            title: "\(permType.displayName)",
            subtitle: "\(permStatus.displayText)  —  \(app.name)",
            arg: String(data: jumpArg, encoding: .utf8) ?? "",
            autocomplete: nil,
            valid: true,
            icon: .init(sfSymbol: permStatus.sfSymbol),
            text: AlfredItem.AlfredText(
                copy: "\(app.name) (\(app.bundleId)) — \(permType.displayName): \(permStatus.displayText)",
                largetype: "\(app.name)\n权限: \(permType.displayName)\n状态: \(permStatus.displayText)"
            ),
            mods: [
                "cmd": AlfredItem.AlfredMod(
                    valid: true,
                    arg: String(data: jumpArg, encoding: .utf8) ?? "",
                    subtitle: "跳转到系统设置"
                ),
            ]
        ))
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(AlfredOutput(items: items)) {
        print(String(data: data, encoding: .utf8) ?? "")
    }
}

// MARK: - 跳转逻辑

func jumpToSettings(service: String, appName: String) {
    guard let permType = PermissionType(rawValue: service) else {
        fputs("Unknown service: \(service)\n", stderr)
        exit(1)
    }

    let urls = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(permType.anchor)",
        "x-apple.systempreferences:com.apple.Settings.Privacy-Settings.extension?\(permType.anchor)",
        "x-apple.systempreferences:com.apple.preference.security?\(permType.anchor)",
    ]

    for urlString in urls {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - 入口

func printUsage() {
    print("""
    Usage: tcc-dispatcher <command> [args]

    Commands:
      search [query]       Search apps (Alfred format, apps only)
      perms <bundle_id>    Show permissions for specific app (Alfred format)
      link <service> [app_name]  Open system settings for a permission

    Services:
      \(PermissionType.allCases.map { "\($0.rawValue)" }.joined(separator: "\n      "))
    """)
}

let args = CommandLine.arguments
guard args.count > 1 else {
    printUsage()
    exit(1)
}

let command = args[1]

switch command {
case "search":
    let query = args.dropFirst(2).joined(separator: " ")
    let apps = AppScanner.scan(query: query)
    outputAlfredApps(apps)

case "perms":
    guard args.count > 2 else {
        print("Usage: tcc-dispatcher perms <bundle_id>")
        exit(1)
    }
    let bundleId = args[2]
    let allApps = AppScanner.scan(query: "")
    if let app = allApps.first(where: { $0.bundleId == bundleId }) {
        outputAlfredPerms(app)
    } else {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let emptyOutput = AlfredOutput(items: [AlfredItem(
            uid: "not-found",
            title: "未找到该应用",
            subtitle: bundleId,
            arg: "",
            autocomplete: nil,
            valid: false,
            icon: .init(path: "/Applications"),
            text: nil,
            mods: nil
        )])
        if let data = try? encoder.encode(emptyOutput) {
            print(String(data: data, encoding: .utf8) ?? "")
        }
    }

case "link":
    guard args.count > 2 else {
        print("Usage: tcc-dispatcher link <service> [app_name]")
        exit(1)
    }
    let service = args[2]
    let appName = args.dropFirst(3).joined(separator: " ")
    jumpToSettings(service: service, appName: appName)

default:
    print("Unknown command: \(command)")
    printUsage()
    exit(1)
}
