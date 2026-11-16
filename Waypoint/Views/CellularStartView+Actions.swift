import SwiftUI
import UIKit

extension CellularStartView {
    var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index <= progressIndex ? presentation.color : Color.secondary.opacity(0.18))
                    .frame(width: index == progressIndex ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: progressIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("启动进度")
        .accessibilityValue("第 \(progressIndex + 1) 步，共 3 步")
    }

    @ViewBuilder
    var actions: some View {
        switch model.cellularLaunchState {
        case .needsLocalDevVPN:
            VStack(spacing: 11) {
                Link(destination: localDevVPNAppStoreURL) {
                    Label("安装 LocalDevVPN", systemImage: "arrow.down.app.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    model.checkLocalDevVPNInstallation()
                } label: {
                    Label("重新检查", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

        case .needsPairing:
            VStack(spacing: 11) {
                Button {
                    isChoosingPairingFile = true
                } label: {
                    Label("选择配对文件", systemImage: "folder.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isPreparing)

                if model.isSideStoreAvailable {
                    Button {
                        isSideStoreConfirmationPresented = true
                    } label: {
                        Label("从 SideStore 导入", systemImage: "arrow.up.forward.app.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(model.isPreparing)
                }

                if model.isPreparing {
                    ProgressView("正在导入配对文件…")
                        .font(.footnote)
                }

                Text(model.isSideStoreAvailable
                    ? "使用此 iPhone 的配对文件，也可选择 SideStore 导入。"
                    : "使用专属于此 iPhone 的配对文件。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

        case .failed:
            VStack(spacing: 11) {
                Button {
                    model.retryCellularLaunch()
                } label: {
                    Label("重试", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if model.canReplacePairingForCellularLaunch {
                    Button {
                        model.replacePairingForCellularLaunch()
                    } label: {
                        Label("更换配对文件", systemImage: "doc.badge.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Link(destination: localDevVPNAppStoreURL) {
                    Label("在 App Store 查看 LocalDevVPN", systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

        case .succeeded:
            if !model.notificationWarningsEnabled {
                if model.disconnectAlertsDenied {
                    Link(destination: URL(string: UIApplication.openNotificationSettingsURLString)!) {
                        Label("打开通知设置", systemImage: "bell.badge")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button {
                        model.setDisconnectAlertsEnabled(true)
                    } label: {
                        Label("开启中断通知", systemImage: "bell.badge")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.isUpdatingDisconnectAlerts)
                }
            }

        default:
            EmptyView()
        }
    }
}
