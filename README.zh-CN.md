# ProcessBarMonitor

[English README](README.md)

一个原生 macOS 菜单栏监控应用，用来快速查看 CPU、内存、热状态和高占用应用。

## 下载
- [最新版本 / Latest release](https://github.com/ShadyUnderLight/ProcessBarMonitor/releases/latest)

## 这个应用适合什么
ProcessBarMonitor 想解决的是：你只想快速看一眼系统负载和当前最吃资源的应用，但又不想一直开着 Activity Monitor。它常驻在 macOS 菜单栏里，把最常看的几个信号压缩到一个轻量入口里：CPU、内存、热状态，以及当前最占资源的应用。

## 亮点
- 菜单栏实时摘要：CPU、内存、热状态
- 一键查看 CPU / 内存占用最高的应用
- 支持搜索和可调节显示行数
- 支持登录启动
- 在可用时支持“尽力而为”的 CPU 温度读取
- 原生 Swift / SwiftUI macOS 应用

## 适合这些场景
- 工作时顺手盯一下系统负载
- 快速定位刚刚把 CPU 或内存拉高的应用
- 在不打开 Activity Monitor 的情况下查看笔记本热状态
- 在 Apple silicon Mac 上做轻量菜单栏监控

## 功能
- 菜单栏常驻工具，标题里显示实时摘要
- 整体 CPU 使用率
- 系统内存压力（active + inactive + wired + compressor）
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
