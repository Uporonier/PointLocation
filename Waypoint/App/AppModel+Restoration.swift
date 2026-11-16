import Foundation
import UIKit

extension AppModel {
    func markLocationRecoveryRequired() {
        recoveryStore.markRequired()
        needsLocationRecovery = true
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
                sendClear: { try await self.bridge.clearLocation() }
            )
            publishSimulationEvent(.stopped)
            alert = AppAlert(
                title: "已发送恢复真实定位指令",
                message: "模拟位置已请求清除。请打开地图，点击当前位置按钮等待重新定位；微信请退出“发送位置”页面后重新进入。\n\n本 App 尚未验证其他 App 的定位结果。首页地图上的选点标记仍会保留，它不是当前位置。"
            )
        } catch {
            await bridge.disconnect()
            invalidateConnectionReadiness()
            presentError(
                title: "恢复未完成",
                message: "模拟位置可能仍然保留。请连接 Wi-Fi、开启 LocalDevVPN，返回后再次点“恢复真实定位”；缺少配对文件时，请先在设置中导入本机文件。\n\n仍无法恢复时，可重启 iPhone 后在地图中重新定位。直接关闭定点或断开 VPN 不代表已清除模拟位置。\n\n\(error.localizedDescription)"
            )
        }
    }
}
