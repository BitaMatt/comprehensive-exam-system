# 考试练习系统

考试练习系统是一款面向 Windows 和 Android 的跨端刷题应用，用 Flutter 重构自原 Python/PyQt 桌面版本。软件内置多套保险考试题库，适合日常练习、考前冲刺和错题复盘。

## 功能特色

- 跨端使用：同一套 Flutter 代码同时支持 Windows 桌面端和 Android 手机端。
- 单卷练习：可按 A/B/C 卷或卷四题库随机抽题。
- 分组练习：可按考试分组汇总题库后随机练习。
- 即时反馈：提交答案后立即显示正确/错误、正确答案和题目解析。
- 练习记录：自动保存练习时间、目标、答题数量、正确数和正确率。
- 题库浏览：可查看内置题库、题目数量和题目预览。
- AI 设置：首次启动要求用户自行配置 API Key、Base URL 和模型，支持获取模型与测试连接。
- 离线练习：题库随安装包内置，无需联网即可刷题；AI 相关功能需要用户自行配置接口。

## 当前版本

当前版本：`v1.2.1`

本版本安装包输出目录：

- Windows 安装包：`out/comprehensive-exam-system-windows-setup-v1.2.1.exe`
- Windows 便携包：`out/comprehensive-exam-system-windows-portable-v1.2.1.zip`
- Android 安装包：`out/comprehensive-exam-system-android-v1.2.1.apk`

## 开发与构建

开发、测试和打包说明见 [DEVELOPMENT.md](DEVELOPMENT.md)。
