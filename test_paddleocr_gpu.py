"""测试PaddleOCR GPU版本识别效果"""
import sys
import os

# 添加当前目录到路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# 测试PDF文件
pdf_path = 'PDFs/卷2模擬題_(2).pdf'

if os.path.exists(pdf_path):
    print(f"测试PDF文件: {pdf_path}")
    print("="*60)
    
    try:
        # 检查CUDA是否可用
        print("检查CUDA环境...")
        try:
            import paddle
            print(f"Paddle版本: {paddle.__version__}")
            print(f"CUDA可用: {paddle.is_compiled_with_cuda()}")
            if paddle.is_compiled_with_cuda():
                print(f"GPU数量: {paddle.device.cuda.device_count()}")
                print(f"当前GPU: {paddle.device.cuda.get_device_name(0)}")
        except Exception as e:
            print(f"检查CUDA时出错: {str(e)}")
        
        # 导入PaddleOCR
        print("\n正在初始化PaddleOCR...")
        from paddleocr import PaddleOCR
        
        # 初始化OCR（使用繁体中文，启用GPU）
        # 新版本PaddleOCR使用 device='gpu' 来启用GPU
        # lang='ch' 支持中文（包括繁体）
        ocr = PaddleOCR(
            device='gpu',  # 启用GPU (新版本的参数格式)
            lang='ch',     # 中文模型
            use_textline_orientation=True  # 使用方向分类器
        )
        print("PaddleOCR初始化完成！")
        
        # 将PDF转换为图像
        print("\n正在将PDF转换为图像...")
        import tempfile
        from pdf2image import convert_from_path
        
        # 临时添加poppler路径
        poppler_path = r'C:\poppler\Library\bin'
        if poppler_path not in os.environ['PATH']:
            os.environ['PATH'] = poppler_path + ';' + os.environ['PATH']
        
        # 只转换前3页用于测试
        images = convert_from_path(pdf_path, dpi=300, poppler_path=poppler_path, first_page=1, last_page=3)
        print(f"转换成功，共 {len(images)} 页")
        
        # 对每页进行OCR
        all_text = ""
        for i, image in enumerate(images):
            print(f"\n正在识别第{i+1}页...")
            
            # 保存临时图像
            with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as temp_file:
                temp_image_path = temp_file.name
            image.save(temp_image_path)
            
            # 使用PaddleOCR进行识别
            result = ocr.ocr(temp_image_path)
            
            # 提取文本
            page_text = ""
            if result and result[0]:
                for line in result[0]:
                    if line:
                        text = line[1][0]  # 提取文本内容
                        page_text += text + "\n"
            
            all_text += page_text + "\n"
            
            # 清理临时文件
            os.unlink(temp_image_path)
            
            print(f"第{i+1}页识别完成，提取到 {len(page_text)} 个字符")
        
        print(f"\n" + "="*60)
        print(f"OCR完成，总文本长度: {len(all_text)}")
        print(f"\n识别结果:")
        print(all_text)
        
        # 尝试解析题目
        print("\n" + "="*60)
        print("尝试解析题目...")
        
        import re
        questions = []
        lines = all_text.split('\n')
        current_question = None
        current_question_text = ""
        current_options = {}
        pending_option_letter = None
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # 过滤掉页眉页脚等无关内容
            if any(keyword in line for keyword in ['GI', 'GII', 'GI/', 'GII/', '般保險', '第一章']):
                continue
            
            # 如果有pending选项，这行就是选项内容
            if pending_option_letter:
                current_options[pending_option_letter] = line
                pending_option_letter = None
                continue
            
            # 检测题目编号（如 1. 或 1﹒ 或 13. 或只有数字1）
            match = re.match(r'^(\d+)\s*[﹒\.]?', line)
            if match:
                # 保存上一题
                if current_question and current_question_text.strip():
                    questions.append({
                        "id": current_question,
                        "question": current_question_text.strip(),
                        "options": {
                            "A": current_options.get('A', ''),
                            "B": current_options.get('B', ''),
                            "C": current_options.get('C', ''),
                            "D": current_options.get('D', '')
                        },
                        "answer": "",
                        "analysis": ""
                    })
                
                # 开始新题目
                current_question = match.group(1)
                q_text = re.sub(r'^(\d+)\s*[﹒\.]?', '', line).strip()
                current_question_text = q_text
                current_options = {}
                pending_option_letter = None
                continue
            
            # 检测选项（多种格式：a), a﹚, a, a.等）
            option_match = re.match(r'^([a-d])\s*[)﹚\.﹒]?\s*$', line)
            if option_match:
                pending_option_letter = option_match.group(1).upper()
                continue
            
            # 检测选项（a)后面直接跟内容在同一行）
            option_match_with_content = re.match(r'^([a-d])\s*[)﹚\.﹒]?\s*(.+)$', line)
            if option_match_with_content:
                option_letter = option_match_with_content.group(1).upper()
                option_text = option_match_with_content.group(2).strip()
                current_options[option_letter] = option_text
                continue
            
            # 检测罗马数字（i, ii, iii, iv, v, vi）
            roman_match = re.match(r'^([iIvVxX]+)\s*[)﹚\.﹒]?\s*', line)
            if roman_match:
                roman_num = roman_match.group(1)
                roman_text = re.sub(r'^([iIvVxX]+)\s*[)﹚\.﹒]?\s*', '', line).strip()
                if current_question and len(current_options) == 0 and pending_option_letter is None:
                    if current_question_text:
                        current_question_text += " "
                    current_question_text += f"{roman_num} {roman_text}"
                continue
            
            # 其他行作为题目内容
            if current_question:
                if len(current_options) == 0 and pending_option_letter is None:
                    if current_question_text:
                        current_question_text += " "
                    current_question_text += line
        
        # 保存最后一题
        if current_question and current_question_text.strip():
            questions.append({
                "id": current_question,
                "question": current_question_text.strip(),
                "options": {
                    "A": current_options.get('A', ''),
                    "B": current_options.get('B', ''),
                    "C": current_options.get('C', ''),
                    "D": current_options.get('D', '')
                },
                "answer": "",
                "analysis": ""
            })
        
        print(f"\n提取到 {len(questions)} 道题目")
        
        if questions:
            print("\n题目列表:")
            for q in questions[:5]:  # 只显示前5题
                print(f"\n题目 {q['id']}: {q['question']}")
                for opt in ['A', 'B', 'C', 'D']:
                    if q['options'][opt]:
                        print(f"  {opt}: {q['options'][opt]}")
                    else:
                        print(f"  {opt}: (空)")
        
        print("\n" + "="*60)
        print("测试完成！")
        
    except Exception as e:
        print(f"测试失败: {str(e)}")
        import traceback
        traceback.print_exc()
else:
    print(f"PDF文件不存在: {pdf_path}")
