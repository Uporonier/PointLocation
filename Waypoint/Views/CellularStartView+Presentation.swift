import SwiftUI

extension CellularStartView {
    @ViewBuilder
    var toolbarAction: some View {
        if model.canCancelCellularLaunch {
            Button("取消") {
                model.cancelCellularLaunch()
            }
        } else {
            switch model.cellularLaunchState {
            case .failed:
                Button("关闭") {
                    model.closeCellularLaunch()
                }
            case .succeeded:
                Button("关闭") {
                    model.finishCellularLaunch()
                }
            default:
                EmptyView()
            }
        }
    }

    var presentation: StepPresentation {
        switch model.cellularLaunchState {
        case .idle:
            return StepPresentation(
                symbol: "antenna.radiowaves.left.and.right",
                color: .blue,
                title: "正在准备",
                message: "正在准备启动向导。",
                showsActivity: true
            )

        case .needsLocalDevVPN:
            return StepPresentation(
                symbol: "network.badge.shield.half.filled",
                color: .blue,
                title: "安装 LocalDevVPN",
                message: "需要 LocalDevVPN 连接此 iPhone。安装后返回，配置将自动继续。",
                showsActivity: false
            )

        case .needsPairing:
            return StepPresentation(
                symbol: "doc.badge.plus",
                color: .blue,
                title: "首次配置",
                message: "导入此 iPhone 的配对文件，并在系统设置中开启开发者模式。",
                showsActivity: false
            )

        case .cachingSupportFiles(let message):
            return StepPresentation(
                symbol: "arrow.down.circle.fill",
                color: .blue,
                title: "正在下载支持文件",
                message: model.isLaunchingOnWiFi
                    ? "\(message) 请保持 Wi-Fi 连接。首次下载约 17 MB。"
                    : "\(message) 请保持移动数据开启。首次下载约 17 MB。",
                showsActivity: true
            )

        case .openingLocalDevVPN:
            return StepPresentation(
                symbol: "network.badge.shield.half.filled",
                color: .blue,
                title: "正在连接 LocalDevVPN",
                message: "连接启动后将自动返回。",
                showsActivity: true
            )

        case .settlingLocalDevVPN:
            return StepPresentation(
                symbol: "network.badge.shield.half.filled",
                color: .blue,
                title: "等待 LocalDevVPN",
                message: model.isLaunchingOnWiFi
                    ? "请保持 Wi-Fi 连接。"
                    : "请保持移动数据开启。",
                showsActivity: true
            )

        case .waitingForAirplaneMode:
            return StepPresentation(
                symbol: "airplane",
                color: .blue,
                title: "开启飞行模式",
                message: "保持 Wi-Fi 关闭，手机断网后将自动继续。",
                showsActivity: true,
                activityLabel: "等待开启飞行模式"
            )

        case .preparingDevice:
            return StepPresentation(
                symbol: "iphone",
                color: .blue,
                title: "正在准备 iPhone",
                message: model.isLaunchingOnWiFi
                    ? "请保持定点在前台打开。"
                    : "保持飞行模式开启、Wi-Fi 关闭。",
                showsActivity: true
            )

        case .startingSpoof:
            return StepPresentation(
                symbol: "location.fill",
                color: .blue,
                title: "正在启动位置模拟",
                message: model.isLaunchingOnWiFi
                    ? "正在使用当前 Wi-Fi 连接。"
                    : "请暂时保持飞行模式开启。",
                showsActivity: true
            )

        case .handoff:
            return handoffPresentation

        case .succeeded:
            return StepPresentation(
                symbol: "checkmark.circle.fill",
                color: .green,
                title: model.isLaunchingOnWiFi ? "模拟连接已启动" : "移动数据模拟已启动",
                message: model.notificationWarningsEnabled
                    ? (model.isLaunchingOnWiFi ? "现在可以切换到微信检查“发送位置”。" : "现在可以通过移动数据切换到微信检查位置。")
                    : "模拟连接已启动，中断通知未开启。",
                showsActivity: false
            )

        case .failed(let message):
            return StepPresentation(
                symbol: "exclamationmark.triangle.fill",
                color: .orange,
                title: "未能完成配置",
                message: message,
                showsActivity: false
            )
        }
    }

    private var handoffPresentation: StepPresentation {
        switch model.cellularHandoffState {
        case .idle, .arming:
            return StepPresentation(
                symbol: "antenna.radiowaves.left.and.right",
                color: .blue,
                title: "正在准备移动数据",
                message: "暂时保持飞行模式开启、Wi-Fi 关闭。",
                showsActivity: true
            )

        case .waiting(let secondsRemaining):
            return StepPresentation(
                symbol: "antenna.radiowaves.left.and.right",
                color: .blue,
                title: "关闭飞行模式",
                message: "保持 Wi-Fi 关闭，正在等待 4G/5G，最多 \(secondsRemaining) 秒。",
                showsActivity: true,
                activityLabel: "等待移动数据"
            )

        case .verifying:
            return StepPresentation(
                symbol: "antenna.radiowaves.left.and.right",
                color: .blue,
                title: "正在检查移动数据",
                message: "保持 Wi-Fi 关闭，并让定点在前台检查连接。",
                showsActivity: true
            )

        case .succeeded:
            return StepPresentation(
                symbol: "checkmark.circle.fill",
                color: .green,
                title: "移动数据模拟已启动",
                message: "现在可以通过移动数据切换到微信检查位置。",
                showsActivity: false
            )

        case .failed(let message):
            return StepPresentation(
                symbol: "exclamationmark.triangle.fill",
                color: .orange,
                title: "无法切换到移动数据",
                message: message,
                showsActivity: false
            )
        }
    }

    var progressIndex: Int {
        switch model.cellularLaunchState {
        case .idle, .needsLocalDevVPN, .needsPairing, .cachingSupportFiles, .openingLocalDevVPN,
             .settlingLocalDevVPN:
            return 0
        case .waitingForAirplaneMode, .preparingDevice, .startingSpoof:
            return 1
        case .handoff, .succeeded:
            return 2
        case .failed:
            return model.simulatedCoordinate == nil ? 0 : 2
        }
    }
}

struct StepPresentation {
    let symbol: String
    let color: Color
    let title: String
    let message: String
    let showsActivity: Bool
    var activityLabel: String = "正在处理"
}
