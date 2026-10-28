# Feihete

一款隐私优先的 macOS 菜单栏键盘统计应用。只统计次数,不记录内容;数据只存本机。

**当前版本** 0.1.1 · **要求** macOS 13+ · Intel / Apple Silicon · **零第三方依赖**

> 项目曾用名 TapTally,现已更名为 Feihete。

## 功能

- **今日击键** — 当天所有真实按键计数,附当前速度(键/分钟)
- **今日打字** — 中文按输入法上屏字数,英文按按键统计,分项 + 总计
- **统计区间** — 仪表盘与导出支持 今天 / 过去 7 天 / 过去 30 天
- **应用排名** — 击键最多的应用 Top 8,图标 + 计数 + 占比条
- **常用组合键** — ⌘C、⌘⇧4 等组合键计数排行 Top 8
- **时段分布** — 0–23 点击键柱状图
- **最快一分钟** — 任意连续 60 秒窗口的当日峰值及达成时间
- **数据导出** — Excel xlsx(4 个 sheet,无第三方依赖自研写入器)
- **菜单栏速览** — 点菜单栏图标即看今日核心数据
- **开机启动** — 系统登录项一键开关
- **跨天归档** — 过 0 点自动开新档
- **多语言** — 简体中文 / English / 繁體中文(香港) / 繁體中文(台灣)
- **外观** — 跟随系统 / 浅色 / 深色

## 安装

从 [Releases](https://github.com/GYY-y/Feihete/releases) 下载 `Feihete.dmg`,双击打开后:

1. 把窗口里的 **Feihete.app 拖到旁边的 Applications 文件夹**(即拖进「应用程序」)
2. 打开「应用程序」里的 Feihete —— 它是一个**菜单栏应用**,启动后不会出现在程序坞(Dock),
   图标在屏幕右上角菜单栏里;点它即可展开今日数据
3. 系统设置 → 隐私与安全性 → 辅助功能 中勾选 Feihete(首次启动会自动弹出引导)

> 因为应用未使用 Apple 开发者证书公证,首次打开若提示「无法验证开发者」,
> 请右键点图标选「打开」,或到 系统设置 → 隐私与安全性 点「仍要打开」。
> 也可以用命令行清除隔离属性:`xattr -cr /Applications/Feihete.app`

自行构建:

```bash
./build.sh          # 产物 build/Feihete.app 与 build/Feihete.dmg
open build/Feihete.app
```

## 隐私

- **不记录任何击键内容与顺序** — 数据文件中没有文本字段,无法还原输入
- **不联网** — 无遥测、无分析、无云同步(自动检查更新默认关闭)
- **中文统计**只读取焦点输入框的字符数差值(如 12 → 15 即上屏 3 字),不保存文本
- **密码框**等安全输入场景,系统自动暂停事件送达,应用收不到也存不了

## 统计口径

| 指标 | 定义 |
|---|---|
| 击键 | 所有真实按键,不含单独修饰键、不含长按自动重复 |
| 英文字符 | 无中文输入法时可打印字符键,不含空格、回车、方向键 |
| 中文字符 | 中文输入法激活期间,焦点输入框字符数增量(上屏字数,含中文标点) |
| 组合键 | ⌘/⌃/⌥ 与其他键的组合;⇧ 仅在与上述三者组合时计入 |
| 最快一分钟 | 连续 60 秒窗口内击键数的当日最大值 |
| 应用归属 | 击键瞬间的前台应用 |

## 数据存储

- 位置:`~/Library/Application Support/Feihete/days/`,每天一个 `day-YYYY-MM-DD.json`
- 每 10 秒自动落盘 + 退出时落盘;清理历史数据直接删除该目录即可
- 旧版本(TapTally)的数据目录会在首次启动时自动迁移,历史数据保留

## 构建

- Swift + SwiftUI(Charts),菜单栏 MenuBarExtra,仅依赖系统框架
- `./build.sh` 一键编译并打包 `build/Feihete.app`(ad-hoc 签名)+ DMG;最后一步会自动校验安装包内是否包含 app、Applications 快捷方式和图标
- `Package.swift` 保留供完整 Xcode 环境使用 `swift build`
- 应用图标由 `Feihete.svg` 生成,修改 logo 后执行 `bash tools/make-icon.sh` 重新生成 `AppIcon.icns`
- 注意:ad-hoc 签名应用每次重编译后,「辅助功能」授权可能需重新勾选

## 项目结构

```
Sources/
├── FeiheteCore/        # 纯 Foundation 统计内核,可独立编译测试
│   ├── Models.swift    # DayStats 数据模型与多日聚合
│   ├── StatsStore.swift    # 按天 JSON 存取
│   ├── RollingMinute.swift # 60 秒滚动窗口
│   ├── IME.swift       # 中文输入法检测(TIS)
│   ├── Keys.swift      # 键名映射与组合键规范化
│   └── XLSX.swift / ZipWriter.swift / Exporter.swift  # 无依赖 xlsx 导出
├── Feihete/            # GUI 应用
│   ├── FeiheteApp.swift    # 入口、菜单栏、登录项
│   ├── StatsEngine.swift   # CGEventTap 引擎、应用归属、跨天归档
│   ├── AXCharCounter.swift # 焦点元素字符数差值(中文字数)
│   └── …(仪表盘/设置/关于/菜单栏弹窗/偏好/更新检查)
└── taptool/            # xlsx 导出自测 CLI

tools/
├── make-icon.swift     # 从 SVG 渲染 macOS 应用图标
└── make-icon.sh        # 生成 AppIcon.icns
```

详细文档见 [说明文档.md](说明文档.md) 与 [需求文档.md](需求文档.md)。

## 许可证

见 [LICENSE](LICENSE)。
