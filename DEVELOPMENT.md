# 开发者说明

本文档用于维护、调试、测试和打包 Flutter 版本的考试练习系统。

## 环境要求

- Flutter 3.44.0 或更新的 stable 版本。
- Android Studio 或 Android SDK，并安装 Android command-line tools。
- JDK 17 或更新版本。
- Windows 打包需要 Visual Studio 2022 Build Tools，包含 C++、CMake、Windows SDK。
- Windows 安装包需要 Inno Setup 6。

本机 Flutter 路径示例：

```powershell
C:\Users\pc\flutter\bin\flutter.bat --version
```

## 获取依赖

```powershell
C:\Users\pc\flutter\bin\flutter.bat pub get
```

国内网络如果下载 Flutter Android engine 依赖较慢，可临时使用镜像：

```powershell
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
```

## 调试运行

Windows 桌面端：

```powershell
C:\Users\pc\flutter\bin\flutter.bat run -d windows
```

Android 设备或模拟器：

```powershell
C:\Users\pc\flutter\bin\flutter.bat devices
C:\Users\pc\flutter\bin\flutter.bat run -d <device-id>
```

VS Code 快速入口：

- 按 `Ctrl+Shift+D` 打开“运行和调试”。
- 选择 `Flutter Windows 调试` 可直接启动桌面端。
- 选择 `运行 Flutter 测试` 可运行测试。
- 选择 `打包 Windows 到 out 后启动` 或 `打包全部到 out 后启动 Windows` 会先执行打包任务，再启动桌面端。
- `Terminal > Run Task...` 中可直接运行 `flutter: analyze`、`flutter: test`、`package: windows out`、`package: android out`、`package: all out`。

## 检查与测试

提交前至少运行：

```powershell
C:\Users\pc\flutter\bin\flutter.bat analyze
C:\Users\pc\flutter\bin\flutter.bat test
```

## 打包

所有最终分发文件都应放在项目内的 `out/`。不要把安装包、SDK 压缩包或缓存文件生成到项目目录外；如果临时下载了工具安装包，安装完成后应删除。

一键打包到 `out/`：

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
out/comprehensive-exam-system-windows-setup-v1.2.1.exe
out/comprehensive-exam-system-windows-portable-v1.2.1.zip
out/comprehensive-exam-system-android-v1.2.1.apk
```

Flutter 编译后的 Windows 程序目录如下，这是中间产物目录，不是最终发布目录：

```text
build/windows/x64/runner/Release/
```

Android App Bundle：

```powershell
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
C:\Users\pc\flutter\bin\flutter.bat build appbundle --release
```

## 清理项目外临时安装包

工具安装包不应长期保留在项目外。例如安装 Flutter SDK 和 Android command-line tools 后，可删除下载时留下的压缩包：

```powershell
Remove-Item C:\Users\pc\flutter_windows_*.zip -Force -ErrorAction SilentlyContinue
Remove-Item C:\Users\pc\commandlinetools-win*.zip -Force -ErrorAction SilentlyContinue
```

不要删除 `C:\Users\pc\flutter\` 或 Android SDK 目录，它们是已安装的开发工具。

## AI 设置

软件首次打开会弹出 AI 设置窗口，用户需要自行填写 API Key、Base URL 和模型名。后续可点击右上角 `AI 设置` 按钮修改。

默认 Base URL：

```text
https://api.chatanywhere.tech
```

AI 设置窗口支持：

- 保存 API Key、Base URL、模型名。
- 通过 `/v1/models` 获取模型列表。
- 通过 `/v1/chat/completions` 测试连接。

API Key 只保存到本机应用数据目录，不写入源码，也不要提交到 Git。

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

题库 JSON 已复制到 `assets/question_banks/` 并被 Git 跟踪。新增题库时如果确实需要提交，请确认不包含个人信息或密钥。

## 发布到 GitHub Releases

先推送代码和标签：

```powershell
git push origin main
git tag -a v1.2.1 -m "v1.2.1"
git push origin v1.2.1
```

再上传安装包：

```powershell
gh release create v1.2.1 `
  out\comprehensive-exam-system-windows-setup-v1.2.1.exe `
  out\comprehensive-exam-system-windows-portable-v1.2.1.zip `
  out\comprehensive-exam-system-android-v1.2.1.apk `
  --repo BitaMatt/comprehensive-exam-system `
  --title "v1.2.1 AI 设置与 out 打包优化" `
  --notes-file CHANGELOG.md
```

如果 Release 已存在，可追加或替换文件：

```powershell
gh release upload v1.2.1 out\<file-name> --repo BitaMatt/comprehensive-exam-system --clobber
```
