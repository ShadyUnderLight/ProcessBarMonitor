# ProcessBarMonitor

[English README](README.md)

一个原生 macOS 菜单栏监控应用，用来快速查看 CPU、内存、热状态和高占用进程。

## 它能做什么
- 在 macOS 菜单栏里显示简洁的实时摘要
- 展示整体 CPU 使用率、内存使用情况和热状态
- 列出 CPU 占用最高的应用
- 列出内存占用最高的应用
- 支持手动刷新、搜索和行数调节
- 支持开机启动

## 当前状态
这是一个还在打磨中的 MVP，但已经可以正常使用。

## 功能
- 菜单栏常驻工具，标题里显示实时摘要
- 整体 CPU 使用率
- 已用内存 / 总内存
- 热状态（Nominal / Fair / Serious / Critical）
- CPU 占用最高应用列表
- 内存占用最高应用列表
- 手动刷新 + 自动刷新
- 尽力而为的 CPU 温度支持
- 可按应用名 / 路径 / PID / bundle id 搜索
- 可调节进程列表显示行数
- 面板内置 Quit 按钮

## 安装
### 下载打包好的应用
从 GitHub Releases 下载最新版本，然后解压 `ProcessBarMonitor.app`。

### 从当前仓库本地安装
```bash
./install_app.sh
```

## 开发
可以直接用 Xcode 打开并运行，也可以使用仓库自带脚本。

本地构建 app bundle：

```bash
./build_app.sh
```

## CI
GitHub Actions 已经配置好，会在 push、pull request 和版本 tag 时自动构建 Swift package 和 app bundle。

## 关于 CPU 温度
macOS 没有为普通应用提供稳定的公开 CPU 温度 API，所以这个项目会：
- 尝试读取已安装的辅助工具，例如 `osx-cpu-temp` 或 `istats`
- 如果没有可用辅助工具，就回退显示为 `--` 和热状态
- **不需要** sudo，也不依赖私有 entitlement

## 已知限制
- CPU 温度是“尽力而为”，并不保证一定能拿到
- 在部分机器上，进程采样仍然可能比较耗资源
- 这个应用还在继续打磨，离更成熟的公开版本还有一些工作

## Roadmap 想法
- 趋势图 / 历史曲线
- 针对进程的操作按钮
- 更好的传感器集成
- 进一步的性能优化

## 维护者说明
发布流程文档见 `RELEASING.md`。

## 同步说明
`README.md` 是主版本，`README.zh-CN.md` 是中文翻译版。
以后更新 README 时，应同步更新这份中文版本，避免内容漂移。
