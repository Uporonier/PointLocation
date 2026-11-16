import SwiftUI

struct UsageGuideView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(.blue)
                    Text("定点")
                        .font(.largeTitle.bold())
                    Text("选一个地方，开始位置模拟。")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 16)
            }
            Section("首次准备") {
                Label("开启 iPhone 开发者模式", systemImage: "1.circle")
                Label("安装 LocalDevVPN 并允许 VPN 配置", systemImage: "2.circle")
                Label("在设置中导入这台手机的配对文件", systemImage: "3.circle")
                Text("首次配对需要电脑。日常操作在手机上完成；签名失效或配对失效时仍需维护。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("选点与启动") {
                Text("搜索地点，或轻点地图放置标记。拖动标记可调整位置；选好后点“开始模拟”。")
                Text("首次建议连接 Wi-Fi。使用移动数据时，请按启动向导操作飞行模式。")
            }
            Section("微信 · 发送位置") {
                Text("等待模拟启动，切换到微信，进入聊天中的“＋ → 位置 → 发送位置”。检查地图中心和附近地点是否对应刚选的位置。")
                Text("本 App 的状态仅表示模拟服务连接状态，不代表已经验证微信读取结果。确认地点正确后，再由你决定是否发送。")
                    .foregroundStyle(.secondary)
                Text("验证时可使用“文件传输助手”。如位置不符，先返回本 App 检查连接；不要把 App 内的标记当成微信已生效的证明。")
            }
            Section("结束使用") {
                Text("返回定点，点“停止模拟”，再在系统地图中确认真实位置。若停止失败，断开 LocalDevVPN 或重启手机后再次检查。")
            }
            Section("关于此版本") {
                Text("0.1.2 · 选点版")
                Text("基于 Waypoint 开源项目修改，保留 AGPL-3.0 许可证。主要界面为中文，底层诊断信息可能为英文。")
                    .font(.footnote)
                Link("Waypoint 源项目与许可证", destination: URL(string: "https://github.com/raph559/WaypointApp")!)
            }
        }
        .navigationTitle("使用帮助")
        .navigationBarTitleDisplayMode(.inline)
    }
}
