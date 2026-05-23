# 更新日志

## v1.2.1 - 2026-05-23

- 统一将 Windows 安装包、Windows 便携包和 Android APK 输出到项目内的 `out/` 目录。
- 新增应用内 AI 设置窗口：首次启动强制配置，之后可从顶部 AI 设置入口随时修改。
- AI 设置支持 Base URL、API Key、模型名配置，默认兼容 ChatAnywhere 的 OpenAI 风格 `/v1` 接口。
- 新增测试连接和获取模型列表功能，便于验证 API Key、Base URL 和模型配置是否可用。
- 新增 VS Code 调试与打包配置，可通过运行面板快速启动 Windows、测试或打包。
- 新增 `scripts/package_out.ps1`，用于一键生成 `out/` 内的 Windows/Android 发布包。
- 更新 README 和开发者文档，补充 AI 设置、打包目录、调试测试与发布说明。

## v1.2.0 - 2026-05-22

- 使用 Flutter 重构应用，支持 Windows 和 Android 双端运行。
- 新增跨端练习界面，支持单卷练习和按考试分组练习。
- 内置原项目 7 套题库，并作为 Flutter assets 随安装包分发。
- 新增答题即时反馈、正确答案展示和题目解析展示。
- 新增练习记录列表，保存练习时间、目标、题量、正确数和正确率。
- 新增题库浏览页面，可查看每套题库的分组、题量和题目预览。
- 新增 Windows Inno Setup 安装脚本，并产出 Windows 安装包、Windows 便携包和 Android APK。
- README 改为中文文档，补充软件功能、特色和构建方式。
