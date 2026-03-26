"""测试EasyOCR识别效果"""
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
        # 导入EasyOCR
        print("正在初始化EasyOCR...")
        import easyocr
        
        # 初始化OCR（使用繁体中文和英文）
        reader = easyocr.Reader(['ch_tra', 'en'], gpu=False)
        print("EasyOCR初始化完成！")
        
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
            
            # 使用EasyOCR进行识别
            result = reader.readtext(temp_image_path)
            
            # 提取文本
            page_text = ""
            for detection in result:
                text = detection[1]  # 提取文本内容
                page_text += text + "\n"
            
            all_text += page_text + "\n"
            
            # 清理临时文件
            os.unlink(temp_image_path)
            
            print(f"第{i+1}页识别完成，提取到 {len(page_text)} 个字符")
        
        print(f"\n" + "="*60)
        print(f"OCR完成，总文本长度: {len(all_text)}")
        print(f"\n识别结果前1000字符:")
        print(all_text[:1000])
        
        # 尝试解析题目
        print("\n" + "="*60)
        print("尝试解析题目...")
        
        import re
        questions = []
        lines = all_text.split('\n')
        current_question = None
        current_question_text = ""
        current_options = {}
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # 检测题目编号（如 1. 或 1﹒）
            match = re.match(r'^(\d+)\s*[\.﹒]', line)
            if match:
                # 保存上一题
                if current_question and len(current_options) >= 2:
                    questions.append({
                        'id': current_question,
                        'question': current_question_text,
                        'options': current_options
                    })
                
                # 开始新题目
                current_question = match.group(1)
                current_question_text = ""
                current_options = {}
                continue
            
            # 检测选项（多种格式：a), b), c), d) 或 A., B., C., D.）
            match = re.match(r'^([a-dA-D])\s*[\.\)﹚]\s*', line)
            if match:
                option_letter = match.group(1).upper()
                option_text = re.sub(r'^([a-dA-D])\s*[\.\)﹚]\s*', '', line).strip()
                current_options[option_letter] = option_text
                continue
            
            # 其他行作为题目内容（只有在还没有选项时）
            if current_question and len(current_options) == 0:
                if current_question_text:
                    current_question_text += " "
                current_question_text += line
        
        # 保存最后一题
        if current_question and len(current_options) >= 2:
            questions.append({
                'id': current_question,
                'question': current_question_text,
                'options': current_options
            })
        
        print(f"\n提取到 {len(questions)} 道题目")
        
        if questions:
            print("\n前3道题目示例:")
            for q in questions[:3]:
                print(f"\n题目 {q['id']}: {q['question']}")
                for opt in ['A', 'B', 'C', 'D']:
                    if opt in q['options']:
                        print(f"  {opt}: {q['options'][opt]}")
        
        print("\n" + "="*60)
        print("测试完成！")
        
    except Exception as e:
        print(f"测试失败: {str(e)}")
        import traceback
        traceback.print_exc()
else:
    print(f"PDF文件不存在: {pdf_path}")
