import MapKit
import SwiftUI

extension MapSpoofView {
    private var baseContent: some View {
        ZStack(alignment: .top) {
            map
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 9) {
                if let event = displayedEvent {
                    eventBanner(event)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let active = model.simulatedCoordinate {
                    activeBanner(active)
                        .transition(.opacity)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            controls
        }
        .navigationTitle("定点")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    UsageGuideView()
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("使用帮助")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.isSetupPresented = true
                } label: {
                    Image(systemName: model.isReady ? "checkmark.shield.fill" : "gearshape.fill")
                        .foregroundStyle(model.isReady ? .green : .primary)
                }
                .accessibilityLabel("设置")
            }
        }
        .sheet(isPresented: $model.isCellularStartPresented) {
            CellularStartView()
                .environmentObject(model)
        }
    }

    var searchAwareContent: some View {
        baseContent
        .searchable(
            text: $searchText,
            isPresented: $isSearchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "搜索地点或地址"
        )
        .searchSuggestions {
            searchSuggestions
        }
        .onSubmit(of: .search) {
            searchSubmittedText()
        }
        .onChange(of: searchText) { _, query in
            guard isSearchPresented else { return }

            if isSearching {
                searchTask?.cancel()
                placeSearch.cancelAll()
                searchOperationID = nil
                isSearching = false
            }
            placeSearch.update(query: query, region: visibleRegion)
        }
        .onChange(of: isSearchPresented) { _, presented in
            if presented {
                placeSearch.update(query: searchText, region: visibleRegion)
            } else {
                placeSearch.clearSuggestions()
            }
        }
        .confirmationDialog(
            "切换到移动数据？",
            isPresented: $isCellularHandoffConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("准备切换") {
                model.armCellularHandoff()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("保持 LocalDevVPN 已连接，开启飞行模式并关闭 Wi-Fi。点“准备切换”，等待提示关闭飞行模式后，再到控制中心关闭飞行模式，保持 Wi-Fi 关闭。")
        }
        .confirmationDialog(
            "恢复位置更新？",
            isPresented: $isKeepaliveResumeConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("恢复连接") {
                model.resumeSimulationAfterHandoffFailure()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("恢复前，请重新开启飞行模式并关闭 Wi-Fi，或连接 Wi-Fi 网络。只有移动数据时直接恢复可能导致连接断开。")
        }
    }

    private var searchSuggestions: some View {
        Group {
            if placeSearch.isCompleting && placeSearch.suggestions.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("正在查找地点…")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(placeSearch.suggestions) { suggestion in
                Button {
                    selectSuggestion(suggestion)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.blue)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .foregroundStyle(.primary)

                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(model.isCellularHandoffInProgress)
            }

            if placeSearch.completionFailed,
               !searchText.isEmpty,
               placeSearch.suggestions.isEmpty {
                Label("暂时无法获取搜索建议", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: .all) {
                if let active = model.simulatedCoordinate,
                   active != selection {
                    Marker("正在模拟的位置", coordinate: active.coreLocationCoordinate)
                        .tint(.blue)
                }

                Annotation("已选位置", coordinate: selection.coreLocationCoordinate, anchor: .bottom) {
                    draggablePin(proxy: proxy)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
                MapPitchToggle()
            }
            .coordinateSpace(name: "WaypointMap")
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                select(coordinate)
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                placeSearch.update(region: context.region)
            }
        }
    }

    private func draggablePin(proxy: MapProxy) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 46, height: 46)
                .shadow(color: .black.opacity(0.22), radius: 7, y: 3)

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 36))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.blue, .white)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("WaypointMap"))
                .onChanged { value in
                    guard let coordinate = proxy.convert(value.location, from: .named("WaypointMap")) else { return }
                    select(coordinate)
                }
        )
        .accessibilityLabel("已选位置标记")
        .accessibilityHint("拖动标记选择位置")
    }
}
