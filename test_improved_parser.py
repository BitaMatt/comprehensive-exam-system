"""测试改进后的PDF解析功能"""
import sys
import os
import re

# 添加当前目录到路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# 测试PDF文件
pdf_path = 'PDFs/卷2模擬題_(2).pdf'

if os.path.exists(pdf_path):
    print(f"测试PDF文件: {pdf_path}")
    print("="*60)
    
    try:
        # 首先使用EasyOCR提取文本
        print("正在提取PDF文本...")
        
        import tempfile
        import os
        
        # 临时添加poppler路径
        poppler_path = r'C:\poppler\Library\bin'
        if poppler_path not in os.environ['PATH']:
            os.environ['PATH'] = poppler_path + ';' + os.environ['PATH']
        
        from pdf2image import convert_from_path
        
        # 将PDF转换为图像
        images = convert_from_path(pdf_path, dpi=300, poppler_path=poppler_path, first_page=1, last_page=3)
        
        # 使用EasyOCR
        import easyocr
        reader = easyocr.Reader(['ch_tra', 'en'], gpu=False)
        
        text = ''
        # 对每页进行OCR
        for image in images:
            with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as temp_file:
                temp_image_path = temp_file.name
            image.save(temp_image_path)
            
            # 使用EasyOCR进行识别
            result = reader.readtext(temp_image_path)
            
            # 提取文本，每行一个文本块
            page_text = ""
            for detection in result:
                page_text += detection[1] + "\n"
            
            text += page_text
            
            # 清理临时文件
            os.unlink(temp_image_path)
        
        print(f"\n提取到的文本长度: {len(text)}")
        
        # 解析题目（改进的逻辑）
        print("\n" + "="*60)
        print("正在解析题目...")
        
        questions = []
        lines = text.split('\n')
        current_question = None
        current_question_text = ""
        current_options = {}
        current_roman_numerals = []
        pending_option_letter = None  # 等待内容的选项字母
        
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
                # 提取题目内容（去除编号后的剩余部分）
                q_text = re.sub(r'^(\d+)\s*[﹒\.]?', '', line).strip()
                current_question_text = q_text
                current_options = {}
                current_roman_numerals = []
                pending_option_letter = None
                continue
            
            # 检测选项（多种格式：a), a﹚, a, a.等）
            # 支持a), a﹚, a., a﹒, 或只有a后面没有内容
            option_match = re.match(r'^([a-d])\s*[)﹚\.﹒]?\s*$', line)
            if option_match:
                # 这行只有选项标记，没有内容，等待下一行
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
                current_roman_numerals.append(f"{roman_num} {roman_text}")
                # 罗马数字可能属于题目内容
                if current_question and len(current_options) == 0:
                    if current_question_text:
                        current_question_text += " "
                    current_question_text += f"{roman_num} {roman_text}"
                continue
            
            # 其他行作为题目内容或选项内容
            if current_question:
                if len(current_options) == 0 and pending_option_letter is None:
                    # 还没有选项，继续累积题目内容
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
        
        print(f"\n解析完成，找到 {len(questions)} 道题目")
        
        if questions:
            print("\n题目列表:")
            for i, q in enumerate(questions):
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
