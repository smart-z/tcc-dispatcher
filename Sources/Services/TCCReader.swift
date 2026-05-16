import Foundation
import AppKit
import SQLite3

class TCCReader: ObservableObject {
    @Published var permissionCount: Int = 0
    @Published var hasFullDiskAccess: Bool = false
    
    private var pollingTimer: Timer?
    private var permissions: [String: [String: PermissionStatus]] = [:]
    
    init() {
        startPolling()
    }
    
    func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.loadPermissions()
        }
    }
    
    func loadPermissions() {
        let systemPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        let userPath = NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db"
        
        DispatchQueue.global(qos: .userInitiated).async {
            var combinedPermissions: [String: [String: PermissionStatus]] = [:]
            
            // 使用原生 C API 读取数据库
            self.readDbNative(path: userPath, into: &combinedPermissions)
            self.readDbNative(path: systemPath, into: &combinedPermissions)
            
            let count = combinedPermissions.values.reduce(0) { $0 + $1.count }
            
            // 只要能从系统库读到数据，或者系统库文件存在且尝试打开没报错，就判定为 FDA 成功
            let fdaGranted = self.testFda(path: systemPath)
            
            DispatchQueue.main.async {
                self.permissions = combinedPermissions
                self.permissionCount = count
                self.hasFullDiskAccess = fdaGranted
            }
        }
    }
    
    private func testFda(path: String) -> Bool {
        var db: OpaquePointer?
        if sqlite3_open(path, &db) == SQLITE_OK {
            sqlite3_close(db)
            return true
        }
        return false
    }
    
    private func readDbNative(path: String, into dict: inout [String: [String: PermissionStatus]]) {
        var db: OpaquePointer?
        
        // SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            return
        }
        
        defer { sqlite3_close(db) }
        
        let query = "SELECT client, service, auth_value FROM access;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let clientCStr = sqlite3_column_text(statement, 0),
                   let serviceCStr = sqlite3_column_text(statement, 1) {
                    
                    let client = String(cString: clientCStr)
                    let service = String(cString: serviceCStr)
                    let authValue = sqlite3_column_int(statement, 2)
                    
                    let status: PermissionStatus
                    switch authValue {
                    case 2: status = .allowed
                    case 0: status = .denied
                    default: continue }
                    
                    if dict[client] == nil {
                        dict[client] = [:]
                    }
                    dict[client]?[service] = status
                }
            }
            sqlite3_finalize(statement)
        }
    }
    
    func getStatus(for bundleId: String, service: PermissionType) -> PermissionStatus {
        return permissions[bundleId]?[service.rawValue] ?? .notSet
    }
}