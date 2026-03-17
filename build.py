import os
import shutil
import subprocess
import glob

def main():
    print("清理之前的打包文件...")
    # 清理之前的打包文件
    for dir_name in ['build', 'dist', 'installer_dist', 'portable_dist']:
        if os.path.exists(dir_name):
            try:
                shutil.rmtree(dir_name)
            except Exception as e:
                print(f"清理{dir_name}时出错: {e}")
    
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
    # 获取当前目录的绝对路径
    current_dir = os.getcwd()
    print(f"当前目录: {current_dir}")
    
    # 查看当前目录的实际内容
    print("当前目录内容:")
    for entry in os.scandir(current_dir):
        print(f"  {entry.name} (类型: {entry.stat().st_mode})")
    
    # 复制到移动版目录
    main_exe_path = os.path.join(current_dir, 'dist', 'main.exe')
    if os.path.exists(main_exe_path):
        portable_dist_path = os.path.join(current_dir, 'portable_dist')
        shutil.copy(main_exe_path, portable_dist_path)
        print("已复制main.exe到移动版目录")
        
        # 尝试直接遍历当前目录，寻找类似题库的目录
        question_bank_dir = None
        for entry in os.scandir(current_dir):
            if entry.is_dir() and '题库' in entry.name:
                question_bank_dir = entry.name
                break
        
        if question_bank_dir:
            print(f"找到题库目录: {question_bank_dir}")
            question_bank_path = os.path.join(current_dir, question_bank_dir)
            print(f"题库目录路径: {question_bank_path}")
            print(f"题库目录是否存在: {os.path.exists(question_bank_path)}")
            
            if os.path.exists(question_bank_path):
                print(f"题库目录内容: {os.listdir(question_bank_path)}")
                # 确保portable_dist/题库目录存在
                portable_question_bank_path = os.path.join(portable_dist_path, '题库')
                os.makedirs(portable_question_bank_path, exist_ok=True)
                print(f"已创建portable_dist/题库目录: {portable_question_bank_path}")
                # 逐个复制文件
                for file in os.listdir(question_bank_path):
                    src = os.path.join(question_bank_path, file)
                    dst = os.path.join(portable_question_bank_path, file)
                    print(f"尝试复制: {src} -> {dst}")
                    if os.path.isfile(src):
                        shutil.copy2(src, dst)
                        print(f"已复制：{file}")
                    else:
                        print(f"跳过非文件: {file}")
            else:
                print("题库目录不存在，跳过复制")
        else:
            print("未找到题库目录，跳过复制")
    else:
        print(f"dist/main.exe不存在: {main_exe_path}")
        print("跳过复制")
    
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
        
        # 生成更新包
        
        # 查找生成的安装包
        installer_files = glob.glob('installer_dist/*.exe')
        if installer_files:
            installer_path = installer_files[0]
            # 创建更新包副本，使用英文名称以避免GitHub Release问题
            update_path = 'installer_dist/update-package.exe'
            shutil.copy2(installer_path, update_path)
            print(f"更新包已生成：{update_path}")
    else:
        print("Inno Setup 未找到，请安装 Inno Setup 6")
        return
    
    print("打包完成！")
    print("移动版位于：portable_dist")
    print("安装包位于：installer_dist")
    print("更新包位于：installer_dist（文件名为update-package.exe）")
    
    # 自动git commit功能
    print("\n正在自动提交更改到git...")
    try:
        # 检查是否有未提交的更改
        status_result = subprocess.run(['git', 'status', '--porcelain'], capture_output=True, text=True, check=True)
        if status_result.stdout:
            # 添加所有更改
            subprocess.run(['git', 'add', '.'], check=True)
            # 提交更改，使用中文描述
            commit_message = "自动提交：更新打包版本"
            subprocess.run(['git', 'commit', '-m', commit_message], check=True)
            print("已成功提交更改到git")
        else:
            print("没有检测到需要提交的更改")
    except Exception as e:
        print(f"自动提交失败：{e}")
        print("请手动提交更改")

if __name__ == "__main__":
    main()