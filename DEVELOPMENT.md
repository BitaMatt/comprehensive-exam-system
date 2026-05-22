# 开发者说明

本文档用于维护、调试、测试和打包 Flutter 版本的考试练习系统。

## 环境要求

- Flutter 3.44.0 或更新的 stable 版本
- Android Studio 或 Android SDK，已安装 Android command-line tools
- JDK 17 或更新版本
- Windows 打包需要 Visual Studio 2022 Build Tools，包含 C++、CMake、Windows SDK
- Windows 安装包需要 Inno Setup 6

本机当前 Flutter 路径示例：

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

## 检查与测试

提交前至少运行：

```powershell
C:\Users\pc\flutter\bin\flutter.bat analyze
C:\Users\pc\flutter\bin\flutter.bat test
```

`analyze` 用于静态检查，`test` 用于运行 widget/unit 测试。

## 打包

Windows release：

```powershell
C:\Users\pc\flutter\bin\flutter.bat build windows --release
```

产物目录：

```text
build/windows/x64/runner/Release/
```

Windows 便携包：

```powershell
New-Item -ItemType Directory -Force -Path release_artifacts | Out-Null
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath release_artifacts\comprehensive-exam-system-windows-portable-v1.2.0.zip -Force
```

Windows 安装包：

```powershell
& 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' setup_flutter.iss
```

Android APK：

```powershell
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
C:\Users\pc\flutter\bin\flutter.bat build apk --release
Copy-Item build\app\outputs\flutter-apk\app-release.apk release_artifacts\comprehensive-exam-system-android-v1.2.0.apk -Force
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
git tag -a v1.2.0 -m "v1.2.0"
git push origin v1.2.0
```

再上传安装包：

```powershell
gh release create v1.2.0 `
  release_artifacts\comprehensive-exam-system-windows-setup-v1.2.0.exe `
  release_artifacts\comprehensive-exam-system-windows-portable-v1.2.0.zip `
  release_artifacts\comprehensive-exam-system-android-v1.2.0.apk `
  --repo BitaMatt/comprehensive-exam-system `
  --title "v1.2.0 Flutter 跨端版本" `
  --notes-file CHANGELOG.md
```

如果 Release 已存在，可追加或替换文件：

```powershell
gh release upload v1.2.0 release_artifacts\<file-name> --repo BitaMatt/comprehensive-exam-system --clobber
```
