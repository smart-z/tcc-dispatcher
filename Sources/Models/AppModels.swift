import Foundation
import AppKit

struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleId: String
    let icon: NSImage?
    let path: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleId)
    }
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.bundleId == rhs.bundleId
    }
}

enum PermissionType: String, CaseIterable, Identifiable {
    case camera = "kTCCServiceCamera"
    case microphone = "kTCCServiceMicrophone"
    case contacts = "kTCCServiceContacts"
    case calendars = "kTCCServiceCalendars"
    case photos = "kTCCServicePhotos"
    case desktopFolder = "kTCCServiceSystemPolicyDesktopFolder"
    case documentsFolder = "kTCCServiceSystemPolicyDocumentsFolder"
    case downloadsFolder = "kTCCServiceSystemPolicyDownloadsFolder"
    case fullDiskAccess = "kTCCServiceSystemPolicyAllFiles"
    case accessibility = "kTCCServiceAccessibility"
    case inputMonitoring = "kTCCServiceInputMonitoring"
    case screenRecording = "kTCCServiceScreenCapture"
    case location = "kTCCServiceLocation"
    case bluetooth = "kTCCServiceBluetooth"
    case mediaLibrary = "kTCCServiceMediaLibrary"
    case speechRecognition = "kTCCServiceSpeechRecognition"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .camera: return "摄像头"
        case .microphone: return "麦克风"
        case .contacts: return "通讯录"
        case .calendars: return "日历"
        case .photos: return "照片"
        case .desktopFolder: return "桌面"
        case .documentsFolder: return "文档"
        case .downloadsFolder: return "下载"
        case .fullDiskAccess: return "全盘访问"
        case .accessibility: return "辅助功能"
        case .inputMonitoring: return "输入监控"
        case .screenRecording: return "屏幕录制"
        case .location: return "定位服务"
        case .bluetooth: return "蓝牙"
        case .mediaLibrary: return "媒体库"
        case .speechRecognition: return "语音识别"
        }
    }
}

enum PermissionStatus: Int {
    case notSet = -1
    case denied = 0
    case allowed = 2
    
    var displayText: String {
        switch self {
        case .notSet: return "—"
        case .denied: return "✗"
        case .allowed: return "✓"
        }
    }
}

struct PermissionRecord: Identifiable {
    let id = UUID()
    let appBundleId: String
    let service: String
    let status: PermissionStatus
}