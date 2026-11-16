import Foundation

enum SimulationEventKind: Equatable {
    case started
    case moved
    case cellularReady
    case stopped
    case connectionLost
}

struct SimulationEvent: Identifiable, Equatable {
    let id = UUID()
    let kind: SimulationEventKind
    let coordinate: SelectedCoordinate?

    var title: String {
        switch kind {
        case .started: return "模拟已启动"
        case .moved: return "模拟位置已更新"
        case .cellularReady: return "已切换到移动数据"
        case .stopped: return "恢复指令已发送"
        case .connectionLost: return "模拟连接已中断"
        }
    }

    var detail: String {
        if let coordinate {
            return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
        }

        switch kind {
        case .stopped: return "已发送恢复真实定位指令，请在地图中确认"
        case .cellularReady: return "移动数据连接检查已通过"
        case .connectionLost: return "模拟位置可能保留，请恢复真实定位或重新连接"
        case .started, .moved: return "位置已更新"
        }
    }

    var accessibilityAnnouncement: String {
        "\(title). \(detail)."
    }
}
