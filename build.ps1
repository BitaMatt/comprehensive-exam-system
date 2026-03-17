# 清理之前的打包文件
Remove-Item -Recurse -Force build, dist, installer_dist, portable_dist -ErrorAction SilentlyContinue

# 创建必要的目录
New-Item -ItemType Directory -Path installer_dist, portable_dist -Force

# 生成移动版
pyinstaller --onefile --noconsole --hidden-import=PyPDF2 main.py

# 复制到移动版目录
if (Test-Path "dist\main.exe") {
    Copy-Item "dist\main.exe" "portable_dist\"
    if (Test-Path "題庫") {
        Copy-Item "題庫" "portable_dist\" -Recurse -Force
    }
}

# 生成安装包 - 直接使用完整路径
Write-Host "Generating installer..."
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" setup.iss

# 显示结果
Write-Host "Build completed!"
Write-Host "Portable version: portable_dist"
Write-Host "Installer: installer_dist"
Get-ChildItem -Path portable_dist -Recurse
Get-ChildItem -Path installer_dist -Recurse