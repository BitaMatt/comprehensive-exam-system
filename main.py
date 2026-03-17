import os
import sys
import json
import random
from datetime import datetime
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.textinput import TextInput
from kivy.uix.tabbedpanel import TabbedPanel, TabbedPanelItem
from kivy.uix.radiobutton import RadioButton
from kivy.uix.gridlayout import GridLayout
from kivy.uix.scrollview import ScrollView
from kivy.uix.progressbar import ProgressBar
from kivy.uix.dropdown import DropDown
from kivy.uix.popup import Popup
from kivy.uix.filechooser import FileChooserListView
from kivy.core.window import Window
import requests
import PyPDF2

# 版本号
VERSION = "v1.1.0"

# 激励用语列表
MOTIVATIONAL_QUOTES = [
    "🌟 相信自己，你一定能行！",
    "💪 每一次练习都是进步的机会",
    "🎯 目标就在前方，加油！",
    "🔥 坚持就是胜利",
    "📚 知识就是力量",
    "🚀 努力的人运气不会差",
    "🌈 今天的努力，明天的收获",
    "🎓 学习是终身的事业",
    "💎 越努力，越幸运",
    "🌟 成功属于坚持到底的人"
]

class QuestionEditorPopup(Popup):
    """题目编辑弹窗"""
    def __init__(self, question_data=None, **kwargs):
        super().__init__(**kwargs)
        self.title = "编辑题目" if question_data else "新增题目"
        self.size_hint = (0.9, 0.8)
        self.question_data = question_data or {
            "id": "", "question": "", "options": {"A": "", "B": "", "C": "", "D": ""},
            "answer": "", "analysis": ""
        }
        
        layout = BoxLayout(orientation='vertical', padding=10, spacing=10)
        
        # 题目ID
        id_layout = BoxLayout(size_hint_y=None, height=50)
        id_layout.add_widget(Label(text="题目编号："))
        self.id_input = TextInput(text=self.question_data["id"])
        id_layout.add_widget(self.id_input)
        layout.add_widget(id_layout)
        
        # 题目内容
        question_layout = BoxLayout(orientation='vertical', size_hint_y=None, height=100)
        question_layout.add_widget(Label(text="题目内容："))
        self.question_input = TextInput(text=self.question_data["question"], multiline=True)
        question_layout.add_widget(self.question_input)
        layout.add_widget(question_layout)
        
        # 选项
        options_layout = BoxLayout(orientation='vertical', spacing=5)
        options_layout.add_widget(Label(text="选项："))
        
        a_layout = BoxLayout(size_hint_y=None, height=40)
        a_layout.add_widget(Label(text="A："))
        self.opt_a_input = TextInput(text=self.question_data["options"]["A"])
        a_layout.add_widget(self.opt_a_input)
        options_layout.add_widget(a_layout)
        
        b_layout = BoxLayout(size_hint_y=None, height=40)
        b_layout.add_widget(Label(text="B："))
        self.opt_b_input = TextInput(text=self.question_data["options"]["B"])
        b_layout.add_widget(self.opt_b_input)
        options_layout.add_widget(b_layout)
        
        c_layout = BoxLayout(size_hint_y=None, height=40)
        c_layout.add_widget(Label(text="C："))
        self.opt_c_input = TextInput(text=self.question_data["options"]["C"])
        c_layout.add_widget(self.opt_c_input)
        options_layout.add_widget(c_layout)
        
        d_layout = BoxLayout(size_hint_y=None, height=40)
        d_layout.add_widget(Label(text="D："))
        self.opt_d_input = TextInput(text=self.question_data["options"]["D"])
        d_layout.add_widget(self.opt_d_input)
        options_layout.add_widget(d_layout)
        
        layout.add_widget(options_layout)
        
        # 正确答案
        answer_layout = BoxLayout(size_hint_y=None, height=50)
        answer_layout.add_widget(Label(text="正确答案(A/B/C/D)："))
        self.answer_input = TextInput(text=self.question_data["answer"])
        answer_layout.add_widget(self.answer_input)
        layout.add_widget(answer_layout)
        
        # 解析
        analysis_layout = BoxLayout(orientation='vertical', size_hint_y=None, height=100)
        analysis_layout.add_widget(Label(text="题目解析："))
        self.analysis_input = TextInput(text=self.question_data["analysis"], multiline=True)
        analysis_layout.add_widget(self.analysis_input)
        layout.add_widget(analysis_layout)
        
        # 按钮
        button_layout = BoxLayout(size_hint_y=None, height=50, spacing=10)
        self.ok_button = Button(text="确定")
        self.cancel_button = Button(text="取消")
        button_layout.add_widget(self.ok_button)
        button_layout.add_widget(self.cancel_button)
        layout.add_widget(button_layout)
        
        self.add_widget(layout)
        
    def get_question_data(self):
        """获取编辑后的题目数据"""
        return {
            "id": self.id_input.text.strip(),
            "question": self.question_input.text.strip(),
            "options": {
                "A": self.opt_a_input.text.strip(),
                "B": self.opt_b_input.text.strip(),
                "C": self.opt_c_input.text.strip(),
                "D": self.opt_d_input.text.strip()
            },
            "answer": self.answer_input.text.strip().upper(),
            "analysis": self.analysis_input.text.strip()
        }

class ExamStatisticsPopup(Popup):
    """成绩统计弹窗"""
    def __init__(self, stats, **kwargs):
        super().__init__(**kwargs)
        self.title = "练习成绩统计"
        self.size_hint = (0.8, 0.6)
        
        layout = BoxLayout(orientation='vertical', padding=10, spacing=10)
        
        # 基本信息
        info_label = Label(
            text=f"练习类型：{stats['exam_type']}\n"+
                 f"练习时间：{stats['time']}\n"+
                 f"答题总数：{stats['total']}题\n"+
                 f"正确题数：{stats['correct']}题\n"+
                 f"错误题数：{stats['wrong']}题\n"+
                 f"正确率：{stats['rate']:.1f}%\n"+
                 f"成绩评价：{self.get_evaluation(stats['rate'])}  ",
            halign='left',
            valign='top'
        )
        info_label.bind(size=lambda s, w: s.setter('text_size')(s, w))
        layout.add_widget(info_label)
        
        # 按钮
        button = Button(text="确定", size_hint_y=None, height=50)
        button.bind(on_press=self.dismiss)
        layout.add_widget(button)
        
        self.add_widget(layout)
    
    def get_evaluation(self, rate):
        """获取成绩评价"""
        if rate >= 80:
            return "🌟 优秀！对知识点掌握扎实"
        elif rate >= 60:
            return "✅ 合格！基础知识点掌握良好"
        else:
            return "⚠️  不合格！需重点复习核心知识点"

class PracticeTab(BoxLayout):
    """练习标签页"""
    def __init__(self, main_app, **kwargs):
        super().__init__(**kwargs)
        self.orientation = 'vertical'
        self.main_app = main_app
        
        # 模式选择区域
        mode_layout = BoxLayout(size_hint_y=None, height=150, padding=10, spacing=10)
        
        # 模式类型选择
        type_layout = BoxLayout(orientation='vertical', spacing=5)
        type_layout.add_widget(Label(text="练习类型："))
        
        self.single_radio = RadioButton(text="单卷练习", group="mode")
        self.group_radio = RadioButton(text="分组练习", group="mode")
        self.single_radio.active = True
        
        self.single_radio.bind(active=self.on_mode_type_change)
        self.group_radio.bind(active=self.on_mode_type_change)
        
        type_layout.add_widget(self.single_radio)
        type_layout.add_widget(self.group_radio)
        mode_layout.add_widget(type_layout)
        
        # 练习目标
        target_layout = BoxLayout(orientation='vertical', spacing=5)
        target_layout.add_widget(Label(text="练习目标："))
        
        self.target_button = Button(text="请选择练习目标")
        self.target_dropdown = DropDown()
        self.target_button.bind(on_release=self.target_dropdown.open)
        self.target_dropdown.bind(on_select=lambda instance, x: setattr(self.target_button, 'text', x))
        
        target_layout.add_widget(self.target_button)
        mode_layout.add_widget(target_layout)
        
        # 抽题数量
        count_layout = BoxLayout(orientation='vertical', spacing=5)
        count_layout.add_widget(Label(text="抽题数量："))
        self.question_count_input = TextInput(text="50", size_hint_y=None, height=35)
        count_layout.add_widget(self.question_count_input)
        mode_layout.add_widget(count_layout)
        
        # 开始按钮
        self.start_button = Button(text="开始练习", disabled=True)
        self.start_button.bind(on_press=self.start_exam)
        mode_layout.add_widget(self.start_button)
        
        self.add_widget(mode_layout)
        
        # 答题进度条
        self.progress_bar = ProgressBar(max=100, value=0)
        self.add_widget(self.progress_bar)
        
        # 题目显示区域
        question_layout = BoxLayout(orientation='vertical', padding=10, spacing=10)
        
        self.question_label = Label(text="准备就绪", halign='left', valign='top')
        self.question_label.bind(size=lambda s, w: s.setter('text_size')(s, w))
        question_layout.add_widget(self.question_label)
        
        # 选项区域
        options_layout = BoxLayout(orientation='vertical', spacing=5)
        
        self.option_group = []
        self.opt_a = RadioButton(text="A. ", group="options")
        self.opt_b = RadioButton(text="B. ", group="options")
        self.opt_c = RadioButton(text="C. ", group="options")
        self.opt_d = RadioButton(text="D. ", group="options")
        
        self.option_group.extend([self.opt_a, self.opt_b, self.opt_c, self.opt_d])
        
        options_layout.add_widget(self.opt_a)
        options_layout.add_widget(self.opt_b)
        options_layout.add_widget(self.opt_c)
        options_layout.add_widget(self.opt_d)
        
        question_layout.add_widget(options_layout)
        
        # 手动输入答案
        input_layout = BoxLayout(size_hint_y=None, height=50, spacing=5)
        input_layout.add_widget(Label(text="手动输入答案："))
        self.answer_input = TextInput(hint_text="请输入A/B/C/D")
        input_layout.add_widget(self.answer_input)
        question_layout.add_widget(input_layout)
        
        # 按钮区域
        button_layout = BoxLayout(size_hint_y=None, height=50, spacing=10)
        
        self.submit_button = Button(text="提交答案", disabled=True)
        self.submit_button.bind(on_press=self.submit_answer)
        button_layout.add_widget(self.submit_button)
        
        self.next_button = Button(text="下一题", disabled=True)
        self.next_button.bind(on_press=self.show_next_question)
        button_layout.add_widget(self.next_button)
        
        self.finish_button = Button(text="结束练习", disabled=True)
        self.finish_button.bind(on_press=self.finish_exam)
        button_layout.add_widget(self.finish_button)
        
        question_layout.add_widget(button_layout)
        
        # 反馈信息
        self.feedback_label = Label(text="", halign='left', valign='top')
        self.feedback_label.bind(size=lambda s, w: s.setter('text_size')(s, w))
        question_layout.add_widget(self.feedback_label)
        
        self.add_widget(question_layout)
        
        # 初始化目标下拉框
        self.update_target_dropdown()
    
    def on_mode_type_change(self, instance, value):
        """切换练习模式类型"""
        if value:
            self.update_target_dropdown()
            self.start_button.disabled = self.target_button.text == "请选择练习目标"
    
    def update_target_dropdown(self):
        """更新练习目标下拉框"""
        # 清空下拉框
        self.target_dropdown.clear_widgets()
        
        if self.single_radio.active:
            # 单卷模式
            for bank_name in self.main_app.raw_question_banks.keys():
                question_count = len(self.main_app.raw_question_banks[bank_name]["questions"])
                btn = Button(text=f"{bank_name}（{question_count}题）", size_hint_y=None, height=44)
                btn.bind(on_release=lambda btn: self.target_dropdown.select(btn.text))
                self.target_dropdown.add_widget(btn)
        else:
            # 分组模式
            for exam_group in self.main_app.exam_groups.keys():
                question_count = len(self.main_app.exam_groups[exam_group])
                btn = Button(text=f"{exam_group}（{question_count}题）", size_hint_y=None, height=44)
                btn.bind(on_release=lambda btn: self.target_dropdown.select(btn.text))
                self.target_dropdown.add_widget(btn)
    
    def start_exam(self, instance):
        """开始练习"""
        target_text = self.target_button.text
        if target_text == "请选择练习目标":
            return
        
        # 解析选中的目标
        self.main_app.selected_target = target_text.split("（")[0]
        
        # 清空答题记录
        self.main_app.user_answers.clear()
        self.main_app.score = 0
        self.main_app.current_question_idx = 0
        
        # 获取抽题数量
        try:
            if self.question_count_input.text.strip():
                select_count = int(self.question_count_input.text.strip())
            else:
                select_count = 50
        except ValueError:
            select_count = 50
        
        # 根据模式类型处理
        if self.single_radio.active:
            # 单卷模式
            self.main_app.selected_mode_type = "single"
            self.main_app.exam_type = f"{self.main_app.selected_target}（单卷抽题）"
            
            # 验证单卷是否存在
            if self.main_app.selected_target not in self.main_app.raw_question_banks:
                return
            
            # 获取该卷的所有题目
            bank_questions = self.main_app.raw_question_banks[self.main_app.selected_target]["questions"].copy()
        else:
            # 分组模式
            self.main_app.selected_mode_type = "group"
            self.main_app.exam_type = f"{self.main_app.selected_target}（按考试分组抽题）"
            
            # 验证分组是否存在
            if self.main_app.selected_target not in self.main_app.exam_groups:
                return
            
            # 获取该分组的所有题目
            bank_questions = self.main_app.exam_groups[self.main_app.selected_target].copy()
        
        # 校验抽题数量
        total_questions = len(bank_questions)
        if select_count <= 0:
            select_count = 10
        elif select_count > total_questions:
            select_count = total_questions
        
        # 随机抽题
        random.shuffle(bank_questions)
        self.main_app.current_exam = bank_questions[:select_count]
        
        # 检查题库是否为空
        if not self.main_app.current_exam:
            return
        
        # 更新进度条
        self.progress_bar.max = len(self.main_app.current_exam)
        self.progress_bar.value = 1
        
        # 显示第一题
        self.show_question(0)
        
        # 按钮状态
        self.start_button.disabled = True
        self.submit_button.disabled = False
        self.finish_button.disabled = False
    
    def show_question(self, idx):
        """显示指定索引的题目"""
        if idx >= len(self.main_app.current_exam):
            self.finish_exam(None)
            return
        
        q = self.main_app.current_exam[idx]
        
        # 显示题目
        self.question_label.text = f"第{idx + 1}/{len(self.main_app.current_exam)}题：{q['question']}"
        
        # 显示选项
        self.opt_a.text = f"A. {q['options']['A']}"
        self.opt_b.text = f"B. {q['options']['B']}"
        self.opt_c.text = f"C. {q['options']['C']}"
        self.opt_d.text = f"D. {q['options']['D']}"
        
        # 取消选中
        for opt in self.option_group:
            opt.active = False
        
        # 清空输入框
        self.answer_input.text = ""
        self.feedback_label.text = ""
        
        # 更新进度
        self.progress_bar.value = idx + 1
        
        # 按钮状态
        self.submit_button.disabled = False
        self.next_button.disabled = True
    
    def show_next_question(self, instance):
        """显示下一题"""
        self.main_app.current_question_idx += 1
        self.show_question(self.main_app.current_question_idx)
    
    def submit_answer(self, instance):
        """提交答案"""
        # 获取用户答案
        user_ans = ""
        
        if self.opt_a.active:
            user_ans = "A"
        elif self.opt_b.active:
            user_ans = "B"
        elif self.opt_c.active:
            user_ans = "C"
        elif self.opt_d.active:
            user_ans = "D"
        elif self.answer_input.text.strip().upper() in ["A", "B", "C", "D"]:
            user_ans = self.answer_input.text.strip().upper()
        else:
            return
        
        # 验证答案
        q = self.main_app.current_exam[self.main_app.current_question_idx]
        correct_ans = q["answer"]
        is_correct = user_ans == correct_ans
        
        # 记录答案
        self.main_app.user_answers[self.main_app.current_question_idx] = {
            "question": q,
            "user_ans": user_ans,
            "correct_ans": correct_ans,
            "is_correct": is_correct
        }
        
        # 更新得分和反馈
        if is_correct:
            self.main_app.score += 1
            analysis = q.get("analysis", "无解析")
            self.feedback_label.text = f"✅ 回答正确！\n正确答案：{correct_ans}\n解析：{analysis}"
        else:
            analysis = q.get("analysis", "无解析")
            self.feedback_label.text = f"❌ 回答错误！\n你的答案：{user_ans} | 正确答案：{correct_ans}\n解析：{analysis}"
        
        # 按钮状态
        self.submit_button.disabled = True
        self.next_button.disabled = False
    
    def finish_exam(self, instance):
        """结束练习"""
        total = len(self.main_app.user_answers)
        if total == 0:
            return
        
        correct = self.main_app.score
        wrong = total - correct
        rate = (correct / total * 100) if total > 0 else 0
        
        # 保存记录
        self.main_app.save_exam_record(total, correct, rate)
        
        # 显示统计弹窗
        stats = {
            "exam_type": self.main_app.exam_type,
            "total": total,
            "correct": correct,
            "wrong": wrong,
            "rate": rate,
            "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        popup = ExamStatisticsPopup(stats)
        popup.open()
        
        # 重置状态
        self.reset_exam_state()
    
    def reset_exam_state(self):
        """重置考试状态"""
        self.start_button.disabled = False
        self.submit_button.disabled = True
        self.next_button.disabled = True
        self.finish_button.disabled = True
        self.question_label.text = "准备就绪"
        self.feedback_label.text = ""
        self.progress_bar.value = 0

class BankTab(BoxLayout):
    """题库管理标签页"""
    def __init__(self, main_app, **kwargs):
        super().__init__(**kwargs)
        self.orientation = 'vertical'
        self.main_app = main_app
        
        # 操作按钮
        button_layout = BoxLayout(size_hint_y=None, height=50, spacing=10)
        
        self.add_question_button = Button(text="新增题目")
        self.add_question_button.bind(on_press=self.add_question)
        button_layout.add_widget(self.add_question_button)
        
        self.edit_question_button = Button(text="编辑题目", disabled=True)
        self.edit_question_button.bind(on_press=self.edit_question)
        button_layout.add_widget(self.edit_question_button)
        
        self.delete_question_button = Button(text="删除题目", disabled=True)
        self.delete_question_button.bind(on_press=self.delete_question)
        button_layout.add_widget(self.delete_question_button)
        
        self.refresh_bank_button = Button(text="刷新题库")
        self.refresh_bank_button.bind(on_press=self.refresh_question_banks)
        button_layout.add_widget(self.refresh_bank_button)
        
        self.import_pdf_button = Button(text="导入PDF题目")
        self.import_pdf_button.bind(on_press=self.import_pdf_questions)
        button_layout.add_widget(self.import_pdf_button)
        
        self.add_widget(button_layout)
        
        # 题库列表
        self.bank_list = ScrollView()
        self.bank_content = BoxLayout(orientation='vertical', spacing=5)
        self.bank_list.add_widget(self.bank_content)
        self.add_widget(self.bank_list)
        
        # 加载题库
        self.load_bank_to_list()
    
    def load_bank_to_list(self):
        """加载题库到列表"""
        self.bank_content.clear_widgets()
        
        # 遍历所有题目
        for exam_group, questions in self.main_app.exam_groups.items():
            group_label = Label(text=f"{exam_group}", bold=True, size_hint_y=None, height=30)
            self.bank_content.add_widget(group_label)
            
            for q in questions:
                question_item = BoxLayout(size_hint_y=None, height=80, padding=5, spacing=5)
                question_item.bind(on_touch_down=self.on_question_select)
                
                question_info = BoxLayout(orientation='vertical')
                question_info.add_widget(Label(text=f"ID: {q['id']}", size_hint_y=None, height=20))
                question_info.add_widget(Label(
                    text=f"题目: {q['question'][:50]}..." if len(q['question']) > 50 else f"题目: {q['question']}",
                    size_hint_y=None, 
                    height=40,
                    halign='left',
                    valign='top'
                ))
                question_info.add_widget(Label(text=f"来源: {q['source_bank']}", size_hint_y=None, height=20))
                
                question_item.add_widget(question_info)
                self.bank_content.add_widget(question_item)
    
    def on_question_select(self, instance, touch):
        """题目选择事件"""
        if instance.collide_point(*touch.pos):
            # 启用编辑和删除按钮
            self.edit_question_button.disabled = False
            self.delete_question_button.disabled = False
            # 保存选中的题目
            self.selected_question = instance
    
    def add_question(self, instance):
        """新增题目"""
        # 检查是否有题库
        if not self.main_app.raw_question_banks:
            # 创建新题库
            # 这里简化处理，实际应用中可能需要更复杂的交互
            bank_name = "新题库"
            exam_group = "卷一"
            self.main_app.raw_question_banks[bank_name] = {
                "file_name": f"{bank_name}.json",
                "exam_group": exam_group,
                "questions": []
            }
            self.main_app.exam_groups = self.main_app.group_by_exam(self.main_app.raw_question_banks)
        
        # 打开编辑弹窗
        popup = QuestionEditorPopup()
        
        def on_ok(instance):
            q_data = popup.get_question_data()
            if not all([q_data["id"], q_data["question"], q_data["answer"]]):
                return
            
            # 选择添加到哪个题库（这里简化处理，实际应用中可能需要更复杂的交互）
            bank_name = list(self.main_app.raw_question_banks.keys())[0]
            
            # 添加题目
            self.main_app.raw_question_banks[bank_name]["questions"].append(q_data)
            # 重新分组
            self.main_app.exam_groups = self.main_app.group_by_exam(self.main_app.raw_question_banks)
            # 保存并刷新
            self.main_app.save_question_bank()
            self.load_bank_to_list()
            popup.dismiss()
        
        popup.ok_button.bind(on_press=on_ok)
        popup.cancel_button.bind(on_press=popup.dismiss)
        popup.open()
    
    def edit_question(self, instance):
        """编辑选中的题目"""
        # 这里简化处理，实际应用中可能需要更复杂的交互
        pass
    
    def delete_question(self, instance):
        """删除选中的题目"""
        # 这里简化处理，实际应用中可能需要更复杂的交互
        pass
    
    def refresh_question_banks(self, instance):
        """刷新题库"""
        self.main_app.load_and_group_question_banks()
        self.load_bank_to_list()
    
    def import_pdf_questions(self, instance):
        """从PDF文件导入题目"""
        # 打开文件选择器
        filechooser = FileChooserListView()
        popup = Popup(title="选择PDF文件", content=filechooser, size_hint=(0.9, 0.9))
        
        def on_select(instance, selection):
            if selection:
                file_path = selection[0]
                try:
                    # 打开PDF文件
                    with open(file_path, 'rb') as file:
                        reader = PyPDF2.PdfReader(file)
                        text = ''
                        for page_num in range(len(reader.pages)):
                            page = reader.pages[page_num]
                            text += page.extract_text()
                    
                    # 解析PDF文本
                    questions = self.main_app.parse_pdf_text(text)
                    
                    if questions:
                        # 创建新题库
                        bank_name = "PDF导入题库"
                        exam_group = "卷一"
                        self.main_app.raw_question_banks[bank_name] = {
                            "file_name": f"{bank_name}.json",
                            "exam_group": exam_group,
                            "questions": questions
                        }
                        
                        # 保存题库
                        self.main_app.save_question_bank()
                        
                        # 刷新题库
                        self.main_app.load_and_group_question_banks()
                        self.load_bank_to_list()
                    
                except Exception as e:
                    pass
                
            popup.dismiss()
        
        filechooser.bind(on_submit=on_select)
        popup.open()

class RecordTab(BoxLayout):
    """练习记录标签页"""
    def __init__(self, main_app, **kwargs):
        super().__init__(**kwargs)
        self.orientation = 'vertical'
        self.main_app = main_app
        
        # 刷新按钮
        refresh_button = Button(text="刷新记录", size_hint_y=None, height=50)
        refresh_button.bind(on_press=self.load_records_to_list)
        self.add_widget(refresh_button)
        
        # 记录列表
        self.record_list = ScrollView()
        self.record_content = BoxLayout(orientation='vertical', spacing=5)
        self.record_list.add_widget(self.record_content)
        self.add_widget(self.record_list)
        
        # 加载记录
        self.load_records_to_list(None)
    
    def load_records_to_list(self, instance):
        """加载练习记录到列表"""
        self.record_content.clear_widgets()
        
        # 确定记录文件路径
        if getattr(sys, 'frozen', False):
            # 打包后的环境
            base_dir = os.path.dirname(sys.executable)
        else:
            # 开发环境
            base_dir = os.path.dirname(os.path.abspath(__file__))
        
        record_file = os.path.join(base_dir, "comprehensive_exam_records.json")
        
        if not os.path.exists(record_file):
            return
        
        try:
            with open(record_file, "r", encoding="utf-8") as f:
                records = json.load(f)
            
            for record in records:
                record_item = BoxLayout(size_hint_y=None, height=80, padding=5, spacing=5)
                
                record_info = BoxLayout(orientation='vertical')
                record_info.add_widget(Label(text=f"时间: {record['time']}", size_hint_y=None, height=20))
                record_info.add_widget(Label(text=f"类型: {record['exam_type']}", size_hint_y=None, height=20))
                record_info.add_widget(Label(text=f"成绩: {record['correct_questions']}/{record['total_questions']} ({record['score_rate']})", size_hint_y=None, height=20))
                
                record_item.add_widget(record_info)
                self.record_content.add_widget(record_item)
        except Exception as e:
            pass

class ExamApp(App):
    """主应用"""
    def build(self):
        # 初始化数据
        self.raw_question_banks = {}  # 原始题库
        self.exam_groups = {}  # 按所属考试分组的题库
        self.load_and_group_question_banks()
        
        self.current_exam = []
        self.current_question_idx = 0
        self.user_answers = {}
        self.score = 0
        self.exam_type = ""
        self.selected_mode_type = ""
        self.selected_target = ""
        
        # 主布局
        main_layout = BoxLayout(orientation='vertical')
        
        # 顶部状态栏
        status_bar = BoxLayout(size_hint_y=None, height=40)
        self.status_label = Label(text="准备就绪")
        status_bar.add_widget(self.status_label)
        main_layout.add_widget(status_bar)
        
        # 激励用语栏
        motivation_bar = BoxLayout(size_hint_y=None, height=40)
        self.motivation_label = Label(text="", halign='center', valign='middle')
        self.update_motivation()
        motivation_bar.add_widget(self.motivation_label)
        main_layout.add_widget(motivation_bar)
        
        # 顶部按钮栏
        top_button_layout = BoxLayout(size_hint_y=None, height=40, spacing=10)
        check_update_button = Button(text="检查更新")
        check_update_button.bind(on_press=self.check_for_updates)
        top_button_layout.add_widget(check_update_button)
        main_layout.add_widget(top_button_layout)
        
        # 标签页
        self.tab_panel = TabbedPanel()
        
        # 练习标签页
        practice_tab = TabbedPanelItem(text="练习")
        self.practice_tab_content = PracticeTab(self)
        practice_tab.add_widget(self.practice_tab_content)
        self.tab_panel.add_widget(practice_tab)
        
        # 题库管理标签页
        bank_tab = TabbedPanelItem(text="题库管理")
        self.bank_tab_content = BankTab(self)
        bank_tab.add_widget(self.bank_tab_content)
        self.tab_panel.add_widget(bank_tab)
        
        # 练习记录标签页
        record_tab = TabbedPanelItem(text="练习记录")
        self.record_tab_content = RecordTab(self)
        record_tab.add_widget(self.record_tab_content)
        self.tab_panel.add_widget(record_tab)
        
        main_layout.add_widget(self.tab_panel)
        
        return main_layout
    
    def load_raw_question_banks(self):
        """加载原始题库文件"""
        raw_banks = {}
        
        # 确定题库文件夹路径
        if getattr(sys, 'frozen', False):
            # 打包后的环境
            exe_dir = os.path.dirname(sys.executable)
            # 优先使用可执行文件所在目录的题库
            bank_folder = os.path.join(exe_dir, "題庫")
            if not os.path.exists(bank_folder):
                # 如果可执行文件所在目录没有题库，使用当前目录
                bank_folder = os.path.join(os.getcwd(), "題庫")
        else:
            # 开发环境
            base_dir = os.path.dirname(os.path.abspath(__file__))
            bank_folder = os.path.join(base_dir, "題庫")
        
        # 创建題庫文件夹
        if not os.path.exists(bank_folder):
            os.makedirs(bank_folder)
            return raw_banks
        
        # 遍历JSON文件
        for filename in os.listdir(bank_folder):
            if filename.lower().endswith(".json"):
                file_path = os.path.join(bank_folder, filename)
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        file_content = json.load(f)
                    
                    # 标准格式：{"name": "A卷", "exam_group": "卷一", "count": 50, "questions": [...]}
                    if isinstance(file_content, dict):
                        # 必选字段
                        if "name" not in file_content or "questions" not in file_content:
                            continue
                        
                        # 补充所属考试（默认卷一）
                        exam_group = file_content.get("exam_group", "卷一")
                        bank_name = file_content["name"]
                        questions = file_content["questions"]
                    else:
                        continue
                    
                    # 验证题目有效性
                    valid_questions = []
                    for idx, q in enumerate(questions):
                        if self.is_valid_question(q):
                            valid_questions.append(q)
                    
                    if valid_questions:
                        raw_banks[bank_name] = {
                            "file_name": filename,
                            "exam_group": exam_group,
                            "questions": valid_questions
                        }
                except Exception as e:
                    pass
        
        return raw_banks
    
    def group_by_exam(self, raw_banks):
        """按所属考试分组题库"""
        exam_groups = {}
        
        for bank_name, bank_data in raw_banks.items():
            exam_group = bank_data["exam_group"]
            questions = bank_data["questions"]
            
            # 为每个题目添加来源信息
            for q in questions:
                q["source_bank"] = bank_name
                q["exam_group"] = exam_group
            
            # 添加到对应考试分组
            if exam_group not in exam_groups:
                exam_groups[exam_group] = []
            exam_groups[exam_group].extend(questions)
        
        return exam_groups
    
    def load_and_group_question_banks(self):
        """加载并分组题库"""
        self.raw_question_banks = self.load_raw_question_banks()
        self.exam_groups = self.group_by_exam(self.raw_question_banks)
    
    def is_valid_question(self, question):
        """验证题目格式是否有效"""
        required_fields = ["id", "question", "options", "answer"]
        for field in required_fields:
            if field not in question:
                return False
        
        if not isinstance(question["options"], dict) or not all(
                opt in question["options"] for opt in ["A", "B", "C", "D"]):
            return False
        
        if question["answer"] not in ["A", "B", "C", "D"]:
            return False
        
        if not question["question"].strip() or any(
                not question["options"][opt].strip() for opt in ["A", "B", "C", "D"]):
            return False
        
        return True
    
    def save_question_bank(self):
        """保存题库到文件"""
        # 确定题库文件夹路径
        if getattr(sys, 'frozen', False):
            # 打包后的环境 - 保存到可执行文件所在目录，以便用户更改持久化
            base_dir = os.path.dirname(sys.executable)
        else:
            # 开发环境
            base_dir = os.path.dirname(os.path.abspath(__file__))
        
        bank_folder = os.path.join(base_dir, "題庫")
        if not os.path.exists(bank_folder):
            os.makedirs(bank_folder)
        
        for bank_name, bank_data in self.raw_question_banks.items():
            filename = bank_data["file_name"]
            exam_group = bank_data["exam_group"]
            questions = bank_data["questions"]
            
            # 构造标准格式
            save_data = {
                "name": bank_name,
                "exam_group": exam_group,
                "count": len(questions),
                "questions": questions
            }
            
            file_path = os.path.join(bank_folder, filename)
            try:
                with open(file_path, "w", encoding="utf-8") as f:
                    json.dump(save_data, f, ensure_ascii=False, indent=4)
            except Exception as e:
                pass
    
    def save_exam_record(self, total, correct, rate):
        """保存练习记录"""
        try:
            # 确定记录文件路径
            if getattr(sys, 'frozen', False):
                # 打包后的环境
                base_dir = os.path.dirname(sys.executable)
            else:
                # 开发环境
                base_dir = os.path.dirname(os.path.abspath(__file__))
            
            record_file = os.path.join(base_dir, "comprehensive_exam_records.json")
            record = {
                "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "exam_type": self.exam_type,
                "total_questions": total,
                "correct_questions": correct,
                "score_rate": f"{rate:.1f}%"
            }
            
            if not os.path.exists(record_file):
                with open(record_file, "w", encoding="utf-8") as f:
                    json.dump([record], f, ensure_ascii=False, indent=4)
            else:
                with open(record_file, "r", encoding="utf-8") as f:
                    records = json.load(f)
                records.append(record)
                with open(record_file, "w", encoding="utf-8") as f:
                    json.dump(records, f, ensure_ascii=False, indent=4)
        except Exception as e:
            pass
    
    def parse_pdf_text(self, text):
        """解析PDF文本，提取题目"""
        # 这里实现简单的题目提取逻辑
        questions = []
        lines = text.split('\n')
        current_question = None
        question_id = 1
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # 检测题目开始
            if line.endswith('?') or line.endswith('？'):
                if current_question:
                    # 保存上一题
                    if self.is_valid_question(current_question):
                        questions.append(current_question)
                
                # 开始新题目
                current_question = {
                    "id": str(question_id),
                    "question": line,
                    "options": {"A": "", "B": "", "C": "", "D": ""},
                    "answer": "",
                    "analysis": ""
                }
                question_id += 1
            
            # 检测选项
            elif current_question:
                if line.startswith('A.') or line.startswith('A、'):
                    current_question["options"]["A"] = line[2:].strip()
                elif line.startswith('B.') or line.startswith('B、'):
                    current_question["options"]["B"] = line[2:].strip()
                elif line.startswith('C.') or line.startswith('C、'):
                    current_question["options"]["C"] = line[2:].strip()
                elif line.startswith('D.') or line.startswith('D、'):
                    current_question["options"]["D"] = line[2:].strip()
                elif line.startswith('答案：') or line.startswith('答案:'):
                    answer = line[3:].strip()
                    if answer in ["A", "B", "C", "D"]:
                        current_question["answer"] = answer
        
        # 保存最后一题
        if current_question and self.is_valid_question(current_question):
            questions.append(current_question)
        
        return questions
    
    def update_motivation(self):
        """更新激励用语"""
        try:
            # 尝试从网络获取心灵鸡汤
            response = requests.get("https://api.quotable.io/random", timeout=3)
            if response.status_code == 200:
                data = response.json()
                quote = data.get("content", "")
                author = data.get("author", "")
                if quote:
                    self.motivation_label.text = f"🌟 {quote} - {author}"
                    return
        except:
            # 网络不可用时使用本地激励用语
            pass
        
        # 使用本地激励用语
        self.motivation_label.text = random.choice(MOTIVATIONAL_QUOTES)
    
    def check_for_updates(self, instance):
        """检查更新"""
        # 这里简化处理，实际应用中可能需要更复杂的更新检查逻辑
        self.status_label.text = "检查更新中..."
        
        try:
            # 尝试从GitHub获取最新版本信息
            response = requests.get("https://api.github.com/repos/BitaMatt/comprehensive-exam-system/releases/latest", timeout=5)
            if response.status_code == 200:
                data = response.json()
                latest_version = data.get("tag_name", "")
                
                if latest_version > VERSION:
                    self.status_label.text = f"发现新版本：{latest_version}"
                else:
                    self.status_label.text = "当前已是最新版本"
            else:
                self.status_label.text = "检查更新失败"
        except Exception as e:
            self.status_label.text = "检查更新失败"

if __name__ == "__main__":
    ExamApp().run()
