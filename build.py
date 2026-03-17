import os
import shutil
import subprocess

def main():
    print("清理之前的打包文件...")
    # 清理之前的打包文件
    for dir_name in ['build', 'dist', 'installer_dist', 'portable_dist']:
        if os.path.exists(dir_name):
            shutil.rmtree(dir_name)
    
    print("创建必要的目录...")
    # 创建必要的目录
    os.makedirs('installer_dist', exist_ok=True)
    os.makedirs('portable_dist', exist_ok=True)
    
    print("生成移动版...")
    # 生成移动版
    subprocess.run([
        'python', '-m', 'PyInstaller',
        '--onefile', '--noconsole',
        '--hidden-import=PyPDF2', '--hidden-import=requests',
        'main.py'
    ], check=True)
    
    print("复制到移动版目录...")
    # 复制到移动版目录
    if os.path.exists('dist/main.exe'):
        shutil.copy('dist/main.exe', 'portable_dist/')
        if os.path.exists('题库'):
            shutil.copytree('题库', 'portable_dist/题库', dirs_exist_ok=True)
    
    print("生成安装包...")
    # 生成安装包
    inno_paths = [
        'C:\\Program Files (x86)\\Inno Setup 6\\iscc.exe',
        'C:\\Program Files\\Inno Setup 6\\iscc.exe'
    ]
    inno_exe = None
    for path in inno_paths:
        if os.path.exists(path):
            inno_exe = path
            break
    
    if inno_exe:
        subprocess.run([inno_exe, 'setup.iss'], check=True)
    else:
        print("Inno Setup 未找到，请安装 Inno Setup 6")
        input("按任意键退出...")
        return
    
    print("打包完成！")
    print("移动版位于：portable_dist")
    print("安装包位于：installer_dist")
    input("按任意键退出...")

if __name__ == "__main__":
    main()