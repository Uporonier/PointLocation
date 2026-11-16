import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SetupView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var isChoosingPairingFile = false
    @State private var isSideStoreConfirmationPresented = false
    @AppStorage(MapCoordinateCorrection.preferenceKey) private var coordinateCorrection = false

    private let localDevVPNAppStoreURL = URL(string: "https://apps.apple.com/app/id6755608044")!

    private let pairingTypes: [UTType] = [
        UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!,
        UTType(filenameExtension: "mobiledevicepair", conformingTo: .data)!,
        .propertyList,
        .json,
        .data
    ]

    var body: some View {
        List {
            Section {
                setupRow(
                    title: "设备配对文件",
                    detail: pairingDetail,
                    state: model.pairingState
                )
                setupRow(
                    title: "LocalDevVPN",
                    detail: tunnelDetail,
                    state: localDevVPNState
                )
                setupRow(
                    title: "开发者支持文件",
                    detail: developerImageDetail,
                    state: model.developerImageState
                )
            } header: {
                Text("连接状态")
            }

            Section {
                Group {
                    if model.isSideStoreAvailable {
                        Menu {
                            Button {
                                isChoosingPairingFile = true
                            } label: {
                                Label("选择配对文件", systemImage: "folder")
                            }

                            Button {
                                isSideStoreConfirmationPresented = true
                            } label: {
                                Label("从 SideStore 导入", systemImage: "arrow.up.forward.app")
                            }
                        } label: {
                            pairingImportLabel
                        }
                    } else {
                        Button {
                            isChoosingPairingFile = true
                        } label: {
                            pairingImportLabel
                        }
                    }
                }
                .disabled(model.isPreparing || model.isChangingSimulation || model.simulatedCoordinate != nil)

                if !model.isLocalDevVPNInstalled {
                    Link(destination: localDevVPNAppStoreURL) {
                        Label("安装 LocalDevVPN", systemImage: "arrow.down.app.fill")
                    }
                }
            } header: {
                Text("设备配置")
            } footer: {
                Text(model.isSideStoreAvailable ? "建议从“文件”导入，也可选择 SideStore。" : "导入专属于这台 iPhone 的配对文件。")
            }

            Section {
                Toggle(
                    "连接中断时通知",
                    isOn: Binding(
                        get: { model.disconnectAlertsEnabled },
                        set: { model.setDisconnectAlertsEnabled($0) }
                    )
                )
                .disabled(model.isUpdatingDisconnectAlerts)

                if model.disconnectAlertsDenied {
                    Link(destination: URL(string: UIApplication.openNotificationSettingsURLString)!) {
                        Label("打开通知设置", systemImage: "bell.badge")
                    }
                }
            } header: {
                Text("通知")
            } footer: {
                Text("无法确认模拟连接时提醒你。")
            }

            Section {
                Toggle("大陆地图偏移修正", isOn: $coordinateCorrection)
                    .disabled(model.simulatedCoordinate != nil || model.isPreparing ||
                              model.isChangingSimulation || model.isCellularLaunchRunning)
            } header: {
                Text("位置校准")
            } footer: {
                Text("仅当大陆地图选点与系统地图位置出现固定偏移时尝试开启。先停止模拟，再更改。海外地点或开启后偏差变大时请关闭；此选项不是自动识别坐标系，不能保证米级精度。")
            }

            Section {
                Toggle("保持后台连接", isOn: $model.backgroundKeepAliveEnabled)
            } header: {
                Text("后台运行")
            } footer: {
                Text("切换到微信等 App 时尝试保持连接，会增加耗电，不能保证始终运行。")
            }

            Section {
                Button("重置支持文件", role: .destructive) {
                    model.resetDeveloperImage()
                }
                .disabled(model.isPreparing || model.isChangingSimulation || model.simulatedCoordinate != nil)
            } header: {
                Text("故障排查")
            } footer: {
                Text("仅在设备准备持续失败时使用。")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
        .fileImporter(
            isPresented: $isChoosingPairingFile,
            allowedContentTypes: pairingTypes,
            allowsMultipleSelection: false,
            onCompletion: model.importPairingFile
        )
        .confirmationDialog(
            "从 SideStore 导入？",
            isPresented: $isSideStoreConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("打开 SideStore") {
                model.requestPairingFromSideStore()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("SideStore 使用回调链接传递配对文件，链接可能出现在日志中。建议选择“选择配对文件”。")
        }
    }

    private var pairingImportLabel: some View {
        Label(
            model.pairingState.isReady ? "更换配对文件" : "导入配对文件",
            systemImage: "doc.badge.plus"
        )
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(.interaction, Rectangle())
    }

    private var pairingDetail: String {
        detail(for: model.pairingState, ready: "已导入", required: "未导入")
    }

    private var tunnelDetail: String {
        detail(for: localDevVPNState, ready: "已连接", required: "等待连接")
    }

    private var localDevVPNState: SetupCheckState {
        model.isLocalDevVPNInstalled ? model.tunnelState : .failed("未安装")
    }

    private var developerImageDetail: String {
        detail(for: model.developerImageState, ready: "已就绪", required: "尚未检查")
    }

    private func detail(for state: SetupCheckState, ready: String, required: String) -> String {
        switch state {
        case .required: return required
        case .checking: return "正在检查…"
        case .ready: return ready
        case .failed(let message): return message
        }
    }

    private func setupRow(title: String, detail: String, state: SetupCheckState) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol(for: state))
                .foregroundStyle(color(for: state))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .padding(.vertical, 2)
    }

    private func symbol(for state: SetupCheckState) -> String {
        switch state {
        case .required: return "circle"
        case .checking: return "arrow.triangle.2.circlepath"
        case .ready: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private func color(for state: SetupCheckState) -> Color {
        switch state {
        case .required: return .secondary
        case .checking: return .blue
        case .ready: return .green
        case .failed: return .orange
        }
    }
}
