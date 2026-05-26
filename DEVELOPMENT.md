# 开发者说明

本文档用于维护、调试、测试和打包 Flutter 版考试练习系统。

## 环境要求

- Flutter 3.44.0 或更新的 stable 版本。
- Android Studio 或 Android SDK，并安装 Android command-line tools。
- JDK 17 或更新版本。
- Windows 打包需要 Visual Studio 2022 Build Tools，包含 C++、CMake、Windows SDK。
- Windows 安装包需要 Inno Setup 6。
- Windows 使用插件打包时需要开启 Developer Mode，否则 Flutter 会因为无法创建符号链接而失败。

本机 Flutter 路径示例：

```powershell
C:\Users\pc\flutter\bin\flutter.bat --version
```

## 调试与测试

获取依赖：

```powershell
C:\Users\pc\flutter\bin\flutter.bat pub get
```

Windows 调试：

```powershell
C:\Users\pc\flutter\bin\flutter.bat run -d windows
```

Android 调试：

```powershell
C:\Users\pc\flutter\bin\flutter.bat devices
C:\Users\pc\flutter\bin\flutter.bat run -d <device-id>
```

提交前至少运行：

```powershell
C:\Users\pc\flutter\bin\flutter.bat analyze
C:\Users\pc\flutter\bin\flutter.bat test
```

VS Code 快速入口：

- `Ctrl+Shift+D` 打开运行和调试。
- `Flutter Windows 调试` 启动桌面端。
- `运行 Flutter 测试` 执行测试。
- `打包 Windows 到 out 后启动` 或 `打包全部到 out 后启动 Windows` 会先执行打包任务。
- `Terminal > Run Task...` 可运行 `flutter: analyze`、`flutter: test`、`package: windows out`、`package: android out`、`package: all out`。

## 题库生成

题库生成入口在应用底部导航的「生成」页。

处理流程：

1. 用户选择 PDF。
2. 应用使用 `syncfusion_flutter_pdf` 抽取可选中文本。
3. 文本密度过低的页面会使用 `pdfrx` 渲染为 JPEG 图片。
4. 应用把文本和必要的页面图片按 chunk 发送给用户配置的 AI 模型。
5. AI 返回题库 JSON 后，应用校验单选 A-D 题并保存。

生成数据位置：

```text
%APPDATA%\ComprehensiveExamSystem\generated_banks\
%APPDATA%\ComprehensiveExamSystem\generation_jobs\
```

注意：

- API Key 只保存到本机应用数据目录，不写入源码。
- 生成题库默认自动加入题库列表，也可以导出 JSON。
- 扫描件需要用户配置的模型支持图片输入；如果模型不支持视觉输入，请换用视觉模型或先用外部 OCR 转成可选中文字 PDF。
- `syncfusion_flutter_pdf` 受 Syncfusion license 约束，发布前请确认项目符合其授权要求。

## 打包

所有最终分发文件都输出到项目内 `out/`。

一键打包：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\package_out.ps1 -Target all
```

只打 Windows：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\package_out.ps1 -Target windows
```

只打 Android：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\package_out.ps1 -Target android
```

输出文件：

```text
out/comprehensive-exam-system-windows-setup-v1.3.0.exe
out/comprehensive-exam-system-windows-portable-v1.3.0.zip
out/comprehensive-exam-system-android-v1.3.0.apk
```

Android App Bundle：

```powershell
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
C:\Users\pc\flutter\bin\flutter.bat build appbundle --release
```

## Git 提交规范

提交前检查：

```powershell
git status --short
git diff --cached --stat
```

不要提交以下内容：

- `build/`
- `.dart_tool/`
- `out/`
- `release_artifacts/`
- APK、AAB、ZIP、EXE 等打包产物
- `venv/`、`.venv/`
- `.env`、`config.py`
- `*.jks`、`*.keystore`、`key.properties` 等签名或密钥文件
- 用户 PDF、OCR 临时图片、生成任务缓存

## 发布到 GitHub Releases

```powershell
git push origin main
git tag -a v1.3.0 -m "v1.3.0"
git push origin v1.3.0

gh release create v1.3.0 `
  out\comprehensive-exam-system-windows-setup-v1.3.0.exe `
  out\comprehensive-exam-system-windows-portable-v1.3.0.zip `
  out\comprehensive-exam-system-android-v1.3.0.apk `
  --repo BitaMatt/comprehensive-exam-system `
  --title "v1.3.0 题库生成" `
  --notes-file CHANGELOG.md
```

如果 Release 已存在：

```powershell
gh release upload v1.3.0 out\<file-name> --repo BitaMatt/comprehensive-exam-system --clobber
```
