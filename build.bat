@echo off

REM 清理之前的打包文件
echo 清理之前的打包文件...
if exist build rd /s /q build
if exist dist rd /s /q dist
if exist installer_dist rd /s /q installer_dist
if exist portable_dist rd /s /q portable_dist

REM 创建必要的目录
mkdir installer_dist
mkdir portable_dist
mkdir "portable_dist\題庫"

REM 生成移动版
echo 生成移动版...
pyinstaller --onefile --noconsole main.py

REM 复制到移动版目录
echo 复制到移动版目录...
if exist "dist\main.exe" (
    copy "dist\main.exe" "portable_dist\" /y
    if exist "題庫" (
        xcopy "題庫\*" "portable_dist\題庫\" /E /I /Y
    )
)

REM 生成安装包
echo 生成安装包...
if exist "C:\Program Files (x86)\Inno Setup 6\iscc.exe" (
    "C:\Program Files (x86)\Inno Setup 6\iscc.exe" setup.iss
) else if exist "C:\Program Files\Inno Setup 6\iscc.exe" (
    "C:\Program Files\Inno Setup 6\iscc.exe" setup.iss
) else (
    echo Inno Setup 未找到，请安装 Inno Setup 6
    pause
    exit /b 1
)

echo 打包完成！
echo 移动版位于：portable_dist
echo 安装包位于：installer_dist
pause