import Foundation
import AppKit

class AppScanner: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var isLoading = false
    
    func scanApps() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let appPaths = [
                "/Applications",
                "/System/Applications",
                NSHomeDirectory() + "/Applications"
            ]
            
            var foundApps: [AppInfo] = []
            
            for basePath in appPaths {
                let fileManager = FileManager.default
                guard fileManager.fileExists(atPath: basePath) else { continue }
                
                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: basePath)
                    for item in contents where item.hasSuffix(".app") {
                        let appPath = (basePath as NSString).appendingPathComponent(item)
                        if let appInfo = self?.extractAppInfo(from: appPath) {
                            foundApps.append(appInfo)
                        }
                    }
                } catch {
                    continue
                }
            }
            
            foundApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            DispatchQueue.main.async {
                self?.apps = foundApps
                self?.isLoading = false
            }
        }
    }
    
    private func extractAppInfo(from path: String) -> AppInfo? {
        let infoPlistPath = (path as NSString).appendingPathComponent("Contents/Info.plist")
        guard let plistData = FileManager.default.contents(atPath: infoPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }
        
        let name = plist["CFBundleName"] as? String ?? (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let bundleId = plist["CFBundleIdentifier"] as? String ?? "unknown"
        
        let iconPath = (path as NSString).appendingPathComponent("Contents/Resources/AppIcon.icns")
        let icon = NSImage(contentsOfFile: iconPath)
        
        return AppInfo(name: name, bundleId: bundleId, icon: icon, path: path)
    }
}