//
//  PrivacyAuthService.swift
//  FocusLive
//
//  Created by 赵豪伟 on 2026/1/14.
//

import Foundation
import LocalAuthentication

/// 隐私验证服务
final class PrivacyAuthService {
    static let shared = PrivacyAuthService()
    
    private init() {}
    
    /// 请求解锁隐私内容
    /// - Parameter reason: 系统弹窗显示的验证原因
    /// - Returns: 是否验证通过
    func requestPrivacyUnlock(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            do {
                return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            } catch {
                return false
            }
        }
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            do {
                return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            } catch {
                return false
            }
        }
        
        return false
    }
}
