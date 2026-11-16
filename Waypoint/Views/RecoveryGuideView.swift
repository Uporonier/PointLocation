import SwiftUI

struct RecoveryGuideView: View {
    var body: some View {
        List {
            Section("先在定点中恢复") {
                Text("点首页“恢复真实定位”。App 会停止位置重发、清除模拟并释放连接，再用最多 15 秒检查系统返回的位置。检查期间请保持定点在前台。")
                Text("“已收到新的系统定位”仅表示收到了未标记为软件模拟的新位置，不代表已经验证微信或地图的显示。")
                    .foregroundStyle(.secondary)
            }
            Section("地图、微信仍停在旧位置") {
                Label("从后台划掉微信、地图和定点。", systemImage: "1.circle")
                Label("打开设置 → 隐私与安全性 → 定位服务。", systemImage: "2.circle")
                Label("关闭顶部“定位服务”总开关，确认后重新开启。", systemImage: "3.circle")
                Label("先打开地图，点击当前位置按钮，等待重新定位。", systemImage: "4.circle")
                Label("确认真实位置后，再打开微信的“发送位置”。", systemImage: "5.circle")
                Text("英文路径：Settings → Privacy & Security → Location Services。关闭期间所有 App 会暂时无法使用定位，完成后记得重新开启。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("重新检查") {
                Text("返回定点后点“重新检查系统位置”。此操作只读取系统位置，不会重新连接模拟服务，也不会重新应用选点。")
                Text("若仍无法恢复，可重启 iPhone 后再到地图确认。不要以定点首页保留的选点标记判断真实位置。")
            }
            Section("需要手动操作") {
                Text("定点无法替你关闭其他 App 或切换系统的定位服务总开关。恢复检查超时或权限不足时，会保留“尚未确认恢复”，不会把指令发送成功当成位置恢复成功。")
            }
        }
        .navigationTitle("恢复帮助")
        .navigationBarTitleDisplayMode(.inline)
    }
}
