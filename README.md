# 考试练习系统

考试练习系统是一款面向 Windows 和 Android 的跨端刷题应用，使用 Flutter 构建。软件内置保险考试题库，也支持通过 PDF 和 AI 自动生成新的练习题库。

## 功能特色

- 跨端使用：同一套 Flutter 应用支持 Windows 桌面端和 Android 手机端。
- 单卷/分组练习：可按题库或考试分组随机抽题。
- 即时反馈：提交答案后显示正确答案和解析。
- 练习记录：保存练习时间、目标、题量、正确数和正确率。
- AI 设置：用户自行配置 Base URL、API Key 和模型，支持获取模型与测试连接。
- PDF 生成题库：选择 PDF 后自动抽取文本；扫描页会渲染成图片并交给视觉模型识别，生成可直接练习的题库。
- 本地 OCR 降级：当 API Key 不支持图片分析时，Windows 端可使用本机 RapidOCR/Tesseract 先识别文字，再交给普通文本模型整理题目。
- 可续跑生成：大 PDF 分片处理，支持暂停、失败后继续和生成进度显示。
- 本地保存：生成题库存放在本机应用数据目录，不写入源码仓库，可导出 JSON 备份。

## 当前版本

当前版本：`v1.3.0`

安装包输出目录：

- Windows 安装包：`out/comprehensive-exam-system-windows-setup-v1.3.0.exe`
- Windows 便携包：`out/comprehensive-exam-system-windows-portable-v1.3.0.zip`
- Android 安装包：`out/comprehensive-exam-system-android-v1.3.0.apk`

## AI 与 OCR

默认 Base URL 为：

```text
https://api.chatanywhere.tech
```

应用按 OpenAI-compatible `/v1/models` 和 `/v1/chat/completions` 接口调用。可选中文字 PDF 会优先走文本抽取；扫描页会作为图片发送给支持视觉输入的模型。如果接口不支持图片分析，Windows 端会尝试调用本机 RapidOCR/Tesseract 做 OCR 后再使用文本模型整理。

## 开发与构建

开发、测试、打包和发布说明见 [DEVELOPMENT.md](DEVELOPMENT.md)。
