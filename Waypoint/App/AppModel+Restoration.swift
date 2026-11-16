import Foundation
import UIKit

extension AppModel {
    func markLocationRecoveryRequired() {
        recoveryStore.markRequired()
        needsLocationRecovery = true
        recoveryResult = nil
    }

    /// Available even after force-quit, with no in-memory simulation session.
    func restoreRealLocation() async {
        guard !isChangingSimulation, !isPreparing,
              cellularLaunchOperationID == nil else { return }

        isChangingSimulation = true
        isStoppingSimulation = true
        bridge.suspendLocationWrites()
        markLocationRecoveryRequired()
        defer {
            needsLocationRecovery = recoveryStore.isRequired
            isStoppingSimulation = false
            isChangingSimulation = false
        }

        let sessionID = simulationSessionID
        simulationSessionID = nil
        resendTask?.cancel()
        resendTask = nil
        cancelCellularHandoffWork(resetState: true)
        simulatedCoordinate = nil
        if let sessionID {
            SimulationNotificationMonitor.shared.endSession(sessionID)
        }
        BackgroundKeepAlive.shared.stop()
        UIApplication.shared.isIdleTimerDisabled = false

        // Drain a write already in flight before clearing. All producers also
        // check the invalidated session before enqueuing any further writes.
        await bridge.waitUntilIdle()
        do {
            try await LocationRestoration.clear(
                hasConnection: isReady,
                store: recoveryStore,
                reconnect: {
                    self.invalidateConnectionReadiness()
                    try await self.prepareDeviceCore()
                },
                sendClear: { try await self.bridge.clearLocation() },
                disconnect: {
                    await self.bridge.disconnect()
                    self.invalidateConnectionReadiness()
                }
            )
            await verifyLocationAfterDisconnect()
        } catch {
            presentError(
                title: "恢复未完成",
                message: "连接已释放，但未确认清除。请连接 Wi-Fi、开启 LocalDevVPN 后重试；缺少配对文件时请先导入。\n\n仍停在旧位置时，请按首页“恢复帮助”关闭相关 App，再关闭并重新开启系统定位服务。\n\n\(error.localizedDescription)"
            )
        }
    }

    /// Read-only follow-up after the user manually toggles Location Services.
    /// It must never reconnect the developer tunnel or send a simulated point.
    func checkLocationRecovery() async {
        guard simulatedCoordinate == nil, !isChangingSimulation, !isPreparing,
              cellularLaunchOperationID == nil else { return }
        isChangingSimulation = true
        bridge.suspendLocationWrites()
        BackgroundKeepAlive.shared.stop()
        await bridge.disconnect()
        invalidateConnectionReadiness()
        await verifyLocationAfterDisconnect()
        isChangingSimulation = false
    }

    private func verifyLocationAfterDisconnect() async {
        isVerifyingLocation = true
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            isVerifyingLocation = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
        let result = await realLocationVerifier.check()
        recoveryResult = result
        recoveryStore.recordVerification(result)
        needsLocationRecovery = recoveryStore.isRequired
        if result == .systemLocationObserved {
            publishSimulationEvent(.stopped)
            alert = AppAlert(
                title: "已收到新的系统定位",
                message: "\(result.detail)\n\n若微信或地图仍停在旧位置，先从后台关闭它们，再重新打开。仍不变时请查看首页“恢复帮助”。定点首页选点标记不是当前位置。"
            )
        } else {
            alert = AppAlert(
                title: "尚未确认恢复",
                message: "\(result.detail)\n\n本 App 的模拟连接已释放。若地图仍在旧位置：\n1. 从后台关闭微信、地图和定点。\n2. 设置 → 隐私与安全性 → 定位服务，关闭后重新开启。\n3. 先在地图确认当前位置，再打开微信。\n\n也可回到定点，点击“重新检查系统位置”。"
            )
        }
    }
}
