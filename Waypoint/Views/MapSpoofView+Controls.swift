import SwiftUI

extension MapSpoofView {
    var controls: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 48, height: 48)
                    .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 3) {
                    Text("已选位置")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.6f, %.6f", selection.latitude, selection.longitude))
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }

                Spacer()

                if isSearching {
                    ProgressView()
                }
            }

            if coordinateCorrection {
                Label("大陆地图偏移修正已开启", systemImage: "scope")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button {
                    if model.simulatedCoordinate != nil {
                        Task { await model.startSimulation(at: selection) }
                    } else {
                        model.beginAdaptiveLaunch(at: selection)
                    }
                } label: {
                    Label(primaryButtonTitle, systemImage: primaryButtonSymbol)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(
                    model.isChangingSimulation ||
                    model.isPreparing ||
                    (model.simulatedCoordinate == nil && !hasUsableConnection) ||
                    model.areLocationWritesPausedForCellularHandoff ||
                    model.isCellularLaunchRunning
                )

            }

            Button {
                Task { await model.restoreRealLocation() }
            } label: {
                HStack(spacing: 8) {
                    if model.isStoppingSimulation {
                        ProgressView()
                        Text("正在恢复真实定位…")
                    } else {
                        Label("恢复真实定位", systemImage: "location.circle.fill")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(model.isChangingSimulation || model.isPreparing || model.isCellularLaunchRunning)

            if model.needsLocationRecovery && model.simulatedCoordinate == nil {
                Label("模拟位置尚未确认清除，请恢复真实定位。", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if model.simulatedCoordinate == nil {
                Text("轻点地图或搜索地点，再开始模拟。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("结束使用前请点“恢复真实定位”。直接关闭 App 不会确保清除模拟位置。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if model.simulatedCoordinate != nil {
                cellularHandoffControl

                Text(model.backgroundKeepAliveEnabled ? "后台连接已开启。切换到微信后，请先检查发送位置页面。" : "后台连接未开启，切换 App 后模拟可能中断。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.primary.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var cellularHandoffControl: some View {
        switch model.cellularHandoffState {
        case .idle:
            Button {
                isCellularHandoffConfirmationPresented = true
            } label: {
                Label("切换到移动数据", systemImage: "antenna.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(model.isChangingSimulation)

        case .arming:
            HStack(spacing: 12) {
                ProgressView()

                VStack(alignment: .leading, spacing: 2) {
                    Text("正在准备连接…")
                        .font(.subheadline.weight(.semibold))
                    Text("保持飞行模式开启、Wi-Fi 关闭")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button("取消") {
                    model.cancelCellularHandoff()
                }
                .buttonStyle(.borderless)
            }

        case .waiting(let secondsRemaining):
            HStack(spacing: 12) {
                ProgressView()

                VStack(alignment: .leading, spacing: 2) {
                    Text("现在关闭飞行模式")
                        .font(.subheadline.weight(.semibold))
                    Text("保持 Wi-Fi 关闭 · 最多等待 \(secondsRemaining) 秒")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button("取消") {
                    model.cancelCellularHandoff()
                }
                .buttonStyle(.borderless)
            }

        case .verifying:
            HStack(spacing: 12) {
                ProgressView()
                Text("正在检查连接…")
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
            }

        case .succeeded:
            Label("已切换到移动数据", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "antenna.radiowaves.left.and.right.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)

                Button("重新尝试切换") {
                    isCellularHandoffConfirmationPresented = true
                }
                .buttonStyle(.bordered)

                Button("恢复常规连接") {
                    isKeepaliveResumeConfirmationPresented = true
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var primaryButtonTitle: String {
        if model.simulatedCoordinate != nil { return "应用新位置" }
        switch pathMonitor.activeConnection {
        case .wifi:
            return "开始模拟"
        case .cellular:
            return "使用移动数据启动"
        case .unknown:
            return "正在检查连接…"
        case .offline:
            return "等待网络连接"
        }
    }

    private var primaryButtonSymbol: String {
        if model.simulatedCoordinate != nil { return "mappin.and.ellipse" }
        switch pathMonitor.activeConnection {
        case .wifi:
            return "location.fill"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .unknown:
            return "network"
        case .offline:
            return "wifi.slash"
        }
    }

    private var hasUsableConnection: Bool {
        switch pathMonitor.activeConnection {
        case .wifi, .cellular:
            return true
        case .unknown, .offline:
            return false
        }
    }
}
