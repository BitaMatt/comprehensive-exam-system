import sys
import json
import os
import random
from datetime import datetime
from typing import List, Dict, Any

# 导入多语言支持
from translations import _

# 导入PDF处理库
import PyPDF2

# 导入网络请求库
import requests

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QRadioButton, QButtonGroup, QLineEdit,
    QTextEdit, QMessageBox, QTabWidget, QTableWidget, QTableWidgetItem,
    QHeaderView, QProgressBar, QComboBox, QInputDialog, QDialog,
    QDialogButtonBox, QFormLayout, QGroupBox, QCheckBox, QFileDialog
)
from PyQt6.QtCore import Qt, QTimer, pyqtSignal
from PyQt6.QtGui import QFont, QPalette, QColor, QIcon


class QuestionEditorDialog(QDialog):
    """题目编辑弹窗"""

    def __init__(self, question_data: Dict = None, parent=None):
        super().__init__(parent)
        self.setWindowTitle("编辑题目" if question_data else "新增题目")
        self.setFixedSize(500, 400)
        self.question_data = question_data or {
            "id": "", "question": "", "options": {"A": "", "B": "", "C": "", "D": ""},
            "answer": "", "analysis": ""
        }

        # 布局
        layout = QVBoxLayout()

        # 表单布局
        form_layout = QFormLayout()

        # 题目ID
        self.id_edit = QLineEdit(self.question_data["id"])
        form_layout.addRow("题目编号：", self.id_edit)

        # 题目内容
        self.question_edit = QTextEdit(self.question_data["question"])
        self.question_edit.setFixedHeight(60)
        form_layout.addRow("题目内容：", self.question_edit)

        # 选项
        self.opt_a_edit = QLineEdit(self.question_data["options"]["A"])
        self.opt_b_edit = QLineEdit(self.question_data["options"]["B"])
        self.opt_c_edit = QLineEdit(self.question_data["options"]["C"])
        self.opt_d_edit = QLineEdit(self.question_data["options"]["D"])
        form_layout.addRow("选项A：", self.opt_a_edit)
        form_layout.addRow("选项B：", self.opt_b_edit)
        form_layout.addRow("选项C：", self.opt_c_edit)
        form_layout.addRow("选项D：", self.opt_d_edit)

        # 正确答案
        self.answer_edit = QLineEdit(self.question_data["answer"])
        form_layout.addRow("正确答案(A/B/C/D)：", self.answer_edit)

        # 解析
        self.analysis_edit = QTextEdit(self.question_data["analysis"])
        self.analysis_edit.setFixedHeight(60)
        form_layout.addRow("题目解析：", self.analysis_edit)

        layout.addLayout(form_layout)

        # 按钮
        button_box = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        button_box.accepted.connect(self.accept)
        button_box.rejected.connect(self.reject)
        layout.addWidget(button_box)

        self.setLayout(layout)

    def get_question_data(self) -> Dict:
        """获取编辑后的题目数据"""
        return {
            "id": self.id_edit.text().strip(),
            "question": self.question_edit.toPlainText().strip(),
            "options": {
                "A": self.opt_a_edit.text().strip(),
                "B": self.opt_b_edit.text().strip(),
                "C": self.opt_c_edit.text().strip(),
                "D": self.opt_d_edit.text().strip()
            },
            "answer": self.answer_edit.text().strip().upper(),
            "analysis": self.analysis_edit.toPlainText().strip()
        }


class ExamStatisticsDialog(QDialog):
    """成绩统计弹窗（纯文本版）"""

    def __init__(self, stats: Dict, parent=None):
        super().__init__(parent)
        self.setWindowTitle("练习成绩统计")
        self.setFixedSize(500, 300)
        self.stats = stats

        layout = QVBoxLayout()

        # 基本信息（纯文本）
        info_label = QLabel(f"""
        <h2 style='text-align: center;'>练习成绩统计</h2>
        <hr>
        <p><strong>练习类型：</strong>{stats['exam_type']}</p>
        <p><strong>练习时间：</strong>{stats['time']}</p>
        <p><strong>答题总数：</strong>{stats['total']}题</p>
        <p><strong>正确题数：</strong>{stats['correct']}题</p>
        <p><strong>错误题数：</strong>{stats['wrong']}题</p>
        <p><strong>正确率：</strong>{stats['rate']:.1f}%</p>
        <p><strong>成绩评价：</strong>{self.get_evaluation(stats['rate'])}</p>
        <hr>
        <p style='color: #666;'>提示：可在「练习记录」标签页查看历史成绩</p>
        """)
        info_label.setWordWrap(True)
        layout.addWidget(info_label)

        self.setLayout(layout)

    def get_evaluation(self, rate: float) -> str:
        """获取成绩评价"""
        if rate >= 80:
            return "<span style='color: #28a745; font-weight: bold;'>🌟 优秀！对知识点掌握扎实</span>"
        elif rate >= 60:
            return "<span style='color: #007bff; font-weight: bold;'>✅ 合格！基础知识点掌握良好</span>"
        else:
            return "<span style='color: #dc3545; font-weight: bold;'>⚠️  不合格！需重点复习核心知识点</span>"


class ExamMainWindow(QMainWindow):
    """主窗口"""

    def __init__(self):
        super().__init__()
        self.setWindowTitle(_('app_title'))
        self.setMinimumSize(800, 600)
        self.resize(1000, 700)

        # 初始化数据
        self.raw_question_banks = {}  # 原始题库（按文件名称：A卷/B卷/C卷）
        self.exam_groups = {}  # 按所属考试分组的题库（卷一/卷二/卷三）
        self.load_and_group_question_banks()

        self.current_exam: List[Dict] = []
        self.current_question_idx = 0
        self.user_answers: Dict[int, Dict] = {}
        self.score = 0
        self.exam_type = ""
        self.selected_mode_type = ""  # 记录选中的模式类型：single(单卷)/group(分组)
        self.selected_target = ""  # 记录选中的目标：A卷/卷一

        # 设置样式
        self.set_style()

        # 中心窗口
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)

        # 顶部状态栏
        self.status_bar = QLabel(_('status_ready'))
        self.status_bar.setStyleSheet("background-color: #f0f0f0; padding: 8px; border-radius: 4px;")
        main_layout.addWidget(self.status_bar)

        # 顶部按钮栏
        top_btn_layout = QHBoxLayout()
        # 检查更新按钮
        self.check_update_btn = QPushButton(_('update_feature'))
        self.check_update_btn.clicked.connect(self.check_for_updates)
        top_btn_layout.addWidget(self.check_update_btn)
        main_layout.addLayout(top_btn_layout)

        # 标签页
        self.tab_widget = QTabWidget()
        main_layout.addWidget(self.tab_widget)

        # 1. 练习标签页
        self.practice_tab = QWidget()
        self.setup_practice_tab()
        self.tab_widget.addTab(self.practice_tab, _('practice_tab'))

        # 2. 题库管理标签页
        self.bank_tab = QWidget()
        self.setup_bank_tab()
        self.tab_widget.addTab(self.bank_tab, _('bank_tab'))

        # 3. 练习记录标签页
        self.record_tab = QWidget()
        self.setup_record_tab()
        self.tab_widget.addTab(self.record_tab, _('record_tab'))

        # 初始化记录表格
        self.load_records_to_table()

    def set_style(self):
        """设置界面样式"""
        self.setStyleSheet("""
            QMainWindow {
                background-color: #f8f9fa;
            }
            QPushButton {
                background-color: #007bff;
                color: white;
                border: none;
                padding: 8px 16px;
                border-radius: 4px;
                font-size: 14px;
            }
            QPushButton:hover {
                background-color: #0056b3;
            }
            QPushButton:disabled {
                background-color: #6c757d;
            }
            QRadioButton {
                margin: 8px;
                font-size: 14px;
            }
            QLabel {
                font-size: 14px;
            }
            QTextEdit, QLineEdit {
                border: 1px solid #ced4da;
                border-radius: 4px;
                padding: 8px;
                font-size: 14px;
            }
            QTableWidget {
                border: 1px solid #ced4da;
                border-radius: 4px;
                gridline-color: #e9ecef;
            }
            QHeaderView::section {
                background-color: #e9ecef;
                padding: 8px;
                border: none;
            }
            QTabWidget::pane {
                border: 1px solid #ced4da;
                border-radius: 4px;
            }
            QTabBar::tab {
                padding: 8px 16px;
                margin-right: 4px;
            }
            QTabBar::tab:selected {
                background-color: #007bff;
                color: white;
            }
            QGroupBox {
                font-weight: bold;
                margin: 8px;
            }
        """)

    def setup_practice_tab(self):
        """设置练习标签页"""
        layout = QVBoxLayout(self.practice_tab)

        # 模式选择区域
        mode_group = QGroupBox(_('mode_selection'))
        mode_layout = QVBoxLayout(mode_group)

        # 子布局：模式类型选择 + 具体选项
        top_layout = QHBoxLayout()

        # 模式类型选择（单卷/分组）
        type_layout = QVBoxLayout()
        type_label = QLabel(_('practice_type'))
        self.single_radio = QRadioButton(_('single_practice'))
        self.group_radio = QRadioButton(_('group_practice'))
        self.single_radio.setChecked(True)  # 默认选中单卷练习

        # 绑定单选按钮事件
        self.single_radio.toggled.connect(self.on_mode_type_change)
        self.group_radio.toggled.connect(self.on_mode_type_change)

        type_layout.addWidget(type_label)
        type_layout.addWidget(self.single_radio)
        type_layout.addWidget(self.group_radio)
        top_layout.addLayout(type_layout)

        # 具体选项下拉框
        target_layout = QVBoxLayout()
        target_label = QLabel(_('practice_target'))
        self.target_combo = QComboBox()
        self.update_target_combobox()  # 初始化下拉框

        target_layout.addWidget(target_label)
        target_layout.addWidget(self.target_combo)
        top_layout.addLayout(target_layout)

        # 抽题数量输入框
        count_layout = QVBoxLayout()
        count_label = QLabel(_('question_count'))
        self.question_count_edit = QLineEdit()
        self.question_count_edit.setPlaceholderText("50")
        self.question_count_edit.setFixedWidth(100)

        count_layout.addWidget(count_label)
        count_layout.addWidget(self.question_count_edit)
        top_layout.addLayout(count_layout)

        # 开始按钮
        self.start_btn = QPushButton(_('start_practice'))
        self.start_btn.clicked.connect(self.start_exam)
        self.start_btn.setDisabled(True)
        self.target_combo.currentIndexChanged.connect(lambda idx: self.start_btn.setDisabled(idx == 0))
        top_layout.addWidget(self.start_btn)

        mode_layout.addLayout(top_layout)
        layout.addWidget(mode_group)

        # 答题进度条
        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        layout.addWidget(self.progress_bar)

        # 题目显示区域
        question_group = QGroupBox(_('question_content'))
        question_layout = QVBoxLayout(question_group)

        self.question_label = QLabel(_('status_ready'))
        self.question_label.setWordWrap(True)
        self.question_label.setStyleSheet("font-size: 16px; margin: 8px;")
        question_layout.addWidget(self.question_label)

        # 选项区域
        self.option_group = QButtonGroup(self)
        self.opt_a = QRadioButton()
        self.opt_b = QRadioButton()
        self.opt_c = QRadioButton()
        self.opt_d = QRadioButton()

        self.option_group.addButton(self.opt_a, 0)
        self.option_group.addButton(self.opt_b, 1)
        self.option_group.addButton(self.opt_c, 2)
        self.option_group.addButton(self.opt_d, 3)

        for opt in [self.opt_a, self.opt_b, self.opt_c, self.opt_d]:
            question_layout.addWidget(opt)

        layout.addWidget(question_group)

        # 手动输入答案区域
        input_group = QHBoxLayout()
        self.answer_input = QLineEdit()
        self.answer_input.setPlaceholderText(_('answer_hint'))
        self.answer_input.returnPressed.connect(self.submit_answer)
        input_group.addWidget(QLabel(_('manual_answer')))
        input_group.addWidget(self.answer_input)
        layout.addLayout(input_group)

        # 按钮区域
        btn_layout = QHBoxLayout()

        self.submit_btn = QPushButton(_('submit_answer'))
        self.submit_btn.clicked.connect(self.submit_answer)
        self.submit_btn.setDisabled(True)
        btn_layout.addWidget(self.submit_btn)

        self.next_btn = QPushButton(_('next_question'))
        self.next_btn.clicked.connect(self.show_next_question)
        self.next_btn.setDisabled(True)
        btn_layout.addWidget(self.next_btn)

        self.finish_btn = QPushButton(_('finish_practice'))
        self.finish_btn.clicked.connect(self.finish_exam)
        self.finish_btn.setDisabled(True)
        btn_layout.addWidget(self.finish_btn)

        layout.addLayout(btn_layout)

        # 反馈信息
        self.feedback_label = QLabel("")
        self.feedback_label.setStyleSheet("padding: 8px;")
        self.feedback_label.setWordWrap(True)
        layout.addWidget(self.feedback_label)

    def on_mode_type_change(self):
        """切换练习模式类型（单卷/分组）"""
        self.update_target_combobox()
        self.start_btn.setDisabled(self.target_combo.currentIndex() == 0)

    def update_target_combobox(self):
        """更新练习目标下拉框"""
        self.target_combo.clear()
        self.target_combo.addItem("请选择练习目标")

        if self.single_radio.isChecked():
            # 单卷模式：显示A/B/C卷等
            for bank_name in self.raw_question_banks.keys():
                question_count = len(self.raw_question_banks[bank_name]["questions"])
                self.target_combo.addItem(f"{bank_name}（{question_count}题）")
        else:
            # 分组模式：显示卷一/卷二等
            for exam_group in self.exam_groups.keys():
                question_count = len(self.exam_groups[exam_group])
                self.target_combo.addItem(f"{exam_group}（{question_count}题）")

    def setup_bank_tab(self):
        """设置题库管理标签页"""
        layout = QVBoxLayout(self.bank_tab)

        # 操作按钮
        btn_layout = QHBoxLayout()

        self.add_question_btn = QPushButton(_('add_question'))
        self.add_question_btn.clicked.connect(self.add_question)
        btn_layout.addWidget(self.add_question_btn)

        self.edit_question_btn = QPushButton(_('edit_question'))
        self.edit_question_btn.clicked.connect(self.edit_question)
        self.edit_question_btn.setDisabled(True)
        btn_layout.addWidget(self.edit_question_btn)

        self.delete_question_btn = QPushButton(_('delete_question'))
        self.delete_question_btn.clicked.connect(self.delete_question)
        self.delete_question_btn.setDisabled(True)
        btn_layout.addWidget(self.delete_question_btn)

        # 刷新题库按钮
        self.refresh_bank_btn = QPushButton(_('refresh_bank'))
        self.refresh_bank_btn.clicked.connect(self.refresh_question_banks)
        btn_layout.addWidget(self.refresh_bank_btn)

        # PDF导入按钮
        self.import_pdf_btn = QPushButton(_('pdf_feature'))
        self.import_pdf_btn.clicked.connect(self.import_pdf_questions)
        btn_layout.addWidget(self.import_pdf_btn)

        layout.addLayout(btn_layout)

        # 题库表格（增加所属考试列）
        self.bank_table = QTableWidget()
        self.bank_table.setColumnCount(8)
        self.bank_table.setHorizontalHeaderLabels([_('exam_group'), _('bank_name'), _('question_id'), _('question_text'), _('option_a'), _('option_b'), _('option_c'), _('option_d')])
        self.bank_table.horizontalHeader().setStretchLastSection(True)
        self.bank_table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.bank_table.itemSelectionChanged.connect(self.on_bank_table_select)
        layout.addWidget(self.bank_table)

        # 加载题库到表格
        self.load_bank_to_table()

    def setup_record_tab(self):
        """设置练习记录标签页"""
        layout = QVBoxLayout(self.record_tab)

        # 刷新按钮
        refresh_btn = QPushButton(_('refresh_records'))
        refresh_btn.clicked.connect(self.load_records_to_table)
        layout.addWidget(refresh_btn)

        # 记录表格
        self.record_table = QTableWidget()
        self.record_table.setColumnCount(5)
        self.record_table.setHorizontalHeaderLabels([_('practice_time'), _('practice_type_col'), _('total_questions'), _('correct_questions'), _('score_rate')])
        self.record_table.horizontalHeader().setStretchLastSection(True)
        self.record_table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        layout.addWidget(self.record_table)

    def load_raw_question_banks(self) -> Dict[str, Dict]:
        """加载原始题库文件（包含所属考试属性）"""
        raw_banks = {}
        
        # 确定题库文件夹路径
        if getattr(sys, 'frozen', False):
            # 打包后的环境
            exe_dir = os.path.dirname(sys.executable)
            # 优先使用可执行文件所在目录的题库
            bank_folder = os.path.join(exe_dir, "題庫")
            if not os.path.exists(bank_folder) and hasattr(sys, '_MEIPASS'):
                # 如果可执行文件所在目录没有题库，使用临时目录中的题库
                base_dir = sys._MEIPASS
                bank_folder = os.path.join(base_dir, "題庫")
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
                            QMessageBox.warning(self, _('warning'), _('missing_fields', filename=filename))
                            continue

                        # 补充所属考试（默认卷一）
                        exam_group = file_content.get("exam_group", "卷一")
                        bank_name = file_content["name"]
                        questions = file_content["questions"]

                        # 验证题目数量
                        if "count" in file_content and len(questions) != file_content["count"]:
                            QMessageBox.warning(self, _('warning'),
                                                _('question_count_mismatch', filename=filename, actual=len(questions), declared=file_content['count']))
                    else:
                        QMessageBox.warning(self, _('warning'), _('invalid_format', filename=filename))
                        continue

                    # 验证题目有效性
                    valid_questions = []
                    for idx, q in enumerate(questions):
                        if self.is_valid_question(q):
                            valid_questions.append(q)
                        else:
                            QMessageBox.warning(self, _('warning'), _('invalid_question', filename=filename, index=idx + 1))

                    if valid_questions:
                        raw_banks[bank_name] = {
                            "file_name": filename,
                            "exam_group": exam_group,
                            "questions": valid_questions
                        }
                    else:
                        pass

                except json.JSONDecodeError:
                    QMessageBox.warning(self, _('warning'), _('invalid_json', filename=filename))
                except Exception as e:
                    QMessageBox.warning(self, _('warning'), _('bank_load_failed', filename=filename, error=str(e)))

        if not raw_banks:
            pass

        return raw_banks

    def group_by_exam(self, raw_banks: Dict) -> Dict[str, List[Dict]]:
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

    def refresh_question_banks(self):
        """刷新题库"""
        self.load_and_group_question_banks()
        self.load_bank_to_table()
        self.update_target_combobox()
        QMessageBox.information(self, _('success'), _('banks_refreshed'))

    def is_valid_question(self, question: Dict) -> bool:
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
                QMessageBox.warning(self, "警告", f"保存「{bank_name}」题库失败：{str(e)}")

    def load_bank_to_table(self):
        """加载题库到表格"""
        self.bank_table.setRowCount(0)

        # 遍历所有题目
        row = 0
        for exam_group, questions in self.exam_groups.items():
            for q in questions:
                self.bank_table.insertRow(row)
                self.bank_table.setItem(row, 0, QTableWidgetItem(q["exam_group"]))  # 所属考试
                self.bank_table.setItem(row, 1, QTableWidgetItem(q["source_bank"]))  # 题库名称
                self.bank_table.setItem(row, 2, QTableWidgetItem(q["id"]))
                self.bank_table.setItem(row, 3, QTableWidgetItem(
                    q["question"][:50] + "..." if len(q["question"]) > 50 else q["question"]))
                self.bank_table.setItem(row, 4, QTableWidgetItem(q["options"]["A"]))
                self.bank_table.setItem(row, 5, QTableWidgetItem(q["options"]["B"]))
                self.bank_table.setItem(row, 6, QTableWidgetItem(q["options"]["C"]))
                self.bank_table.setItem(row, 7, QTableWidgetItem(q["options"]["D"]))
                row += 1

    def load_records_to_table(self):
        """加载练习记录到表格"""
        # 确定记录文件路径
        if getattr(sys, 'frozen', False):
            # 打包后的环境
            base_dir = os.path.dirname(sys.executable)
        else:
            # 开发环境
            base_dir = os.path.dirname(os.path.abspath(__file__))
        
        record_file = os.path.join(base_dir, "comprehensive_exam_records.json")
        self.record_table.setRowCount(0)

        if not os.path.exists(record_file):
            return

        try:
            with open(record_file, "r", encoding="utf-8") as f:
                records = json.load(f)

            for row, record in enumerate(records):
                self.record_table.insertRow(row)
                self.record_table.setItem(row, 0, QTableWidgetItem(record["time"]))
                self.record_table.setItem(row, 1, QTableWidgetItem(record["exam_type"]))
                self.record_table.setItem(row, 2, QTableWidgetItem(str(record["total_questions"])))
                self.record_table.setItem(row, 3, QTableWidgetItem(str(record["correct_questions"])))
                self.record_table.setItem(row, 4, QTableWidgetItem(record["score_rate"]))
        except Exception as e:
            QMessageBox.warning(self, "警告", f"练习记录加载失败：{str(e)}")

    def start_exam(self):
        """开始练习（支持单卷/分组两种模式）"""
        try:
            target_text = self.target_combo.currentText()
            if target_text == _('please_select'):
                return

            # 解析选中的目标
            self.selected_target = target_text.split("（")[0]
            self.status_bar.setText(_('status_practicing', target=target_text))

            # 清空答题记录
            self.user_answers.clear()
            self.score = 0
            self.current_question_idx = 0

            # 获取抽题数量
            try:
                if self.question_count_edit.text().strip():
                    select_count = int(self.question_count_edit.text().strip())
                else:
                    select_count = 50
            except ValueError:
                QMessageBox.warning(self, _('warning'), "抽题数量必须是数字，已使用默认值50")
                select_count = 50

            # 根据模式类型处理
            if self.single_radio.isChecked():
                # 单卷模式
                self.selected_mode_type = "single"
                self.exam_type = f"{self.selected_target}（单卷抽题）"

                # 验证单卷是否存在
                if self.selected_target not in self.raw_question_banks:
                    QMessageBox.warning(self, _('warning'), f"题库「{self.selected_target}」不存在")
                    return

                # 获取该卷的所有题目
                bank_questions = self.raw_question_banks[self.selected_target]["questions"].copy()
                total_questions = len(bank_questions)

            else:
                # 分组模式
                self.selected_mode_type = "group"
                self.exam_type = f"{self.selected_target}（按考试分组抽题）"

                # 验证分组是否存在
                if self.selected_target not in self.exam_groups:
                    QMessageBox.warning(self, _('warning'), f"考试分组「{self.selected_target}」不存在")
                    return

                # 获取该分组的所有题目
                bank_questions = self.exam_groups[self.selected_target].copy()
                total_questions = len(bank_questions)

            # 校验抽题数量
            if select_count <= 0:
                select_count = 10
            elif select_count > total_questions:
                select_count = total_questions
                QMessageBox.information(self, _('information'), f"抽题数量超过题库总数，已自动调整为{total_questions}题")

            # 随机抽题
            random.shuffle(bank_questions)
            self.current_exam = bank_questions[:select_count]

            # 检查题库是否为空
            if not self.current_exam:
                QMessageBox.warning(self, _('warning'), _('no_questions'))
                self.start_btn.setDisabled(False)
                self.target_combo.setDisabled(False)
                return

            # 更新进度条
            self.progress_bar.setRange(0, len(self.current_exam))
            self.progress_bar.setValue(1)

            # 显示第一题
            self.show_question(0)

            # 按钮状态
            self.start_btn.setDisabled(True)
            self.submit_btn.setDisabled(False)
            self.finish_btn.setDisabled(False)
            self.target_combo.setDisabled(True)
            self.single_radio.setDisabled(True)
            self.group_radio.setDisabled(True)
        except Exception as e:
            QMessageBox.critical(self, _('error'), _('start_failed', error=str(e)))
            # 恢复状态
            self.start_btn.setDisabled(False)
            self.target_combo.setDisabled(False)
            self.single_radio.setDisabled(False)
            self.group_radio.setDisabled(False)

    def show_question(self, idx: int):
        """显示指定索引的题目"""
        try:
            if idx >= len(self.current_exam):
                self.finish_exam()
                return

            q = self.current_exam[idx]

            # 显示题目
            self.question_label.setText(f"<h4>第{idx + 1}/{len(self.current_exam)}题：{q['question']}</h4>")

            # 显示选项
            self.opt_a.setText(f"A. {q['options']['A']}")
            self.opt_b.setText(f"B. {q['options']['B']}")
            self.opt_c.setText(f"C. {q['options']['C']}")
            self.opt_d.setText(f"D. {q['options']['D']}")

            # 取消选中
            self.opt_a.setChecked(False)
            self.opt_b.setChecked(False)
            self.opt_c.setChecked(False)
            self.opt_d.setChecked(False)

            # 清空输入框
            self.answer_input.clear()
            self.feedback_label.setText("")

            # 更新进度
            self.progress_bar.setValue(idx + 1)

            # 按钮状态
            self.submit_btn.setDisabled(False)
            self.next_btn.setDisabled(True)
        except Exception as e:
            QMessageBox.critical(self, _('error'), _('load_question_failed', error=str(e)))

    def show_next_question(self):
        """显示下一题"""
        try:
            self.current_question_idx += 1
            self.show_question(self.current_question_idx)
        except Exception as e:
            QMessageBox.critical(self, _('error'), _('load_next_failed', error=str(e)))

    def submit_answer(self):
        """提交答案"""
        try:
            # 获取用户答案
            user_ans = ""

            if self.opt_a.isChecked():
                user_ans = "A"
            elif self.opt_b.isChecked():
                user_ans = "B"
            elif self.opt_c.isChecked():
                user_ans = "C"
            elif self.opt_d.isChecked():
                user_ans = "D"
            elif self.answer_input.text().strip().upper() in ["A", "B", "C", "D"]:
                user_ans = self.answer_input.text().strip().upper()
            else:
                QMessageBox.warning(self, _('warning'), _('enter_valid_answer'))
                return

            # 验证答案
            q = self.current_exam[self.current_question_idx]
            correct_ans = q["answer"]
            is_correct = user_ans == correct_ans

            # 记录答案
            self.user_answers[self.current_question_idx] = {
                "question": q,
                "user_ans": user_ans,
                "correct_ans": correct_ans,
                "is_correct": is_correct
            }

            # 更新得分和反馈
            if is_correct:
                self.score += 1
                analysis = q.get("analysis", "无解析")
                self.feedback_label.setText(f"""
                <span style='color: #28a745; font-weight: bold;'>✅ 回答正确！</span>
                <p>正确答案：{correct_ans}</p>
                <p>解析：{analysis}</p>
                """)
            else:
                analysis = q.get("analysis", "无解析")
                self.feedback_label.setText(f"""
                <span style='color: #dc3545; font-weight: bold;'>❌ 回答错误！</span>
                <p>你的答案：{user_ans} | 正确答案：{correct_ans}</p>
                <p>解析：{analysis}</p>
                """)

            # 按钮状态
            self.submit_btn.setDisabled(True)
            self.next_btn.setDisabled(False)
        except Exception as e:
            QMessageBox.critical(self, _('error'), _('submit_failed', error=str(e)))

    def finish_exam(self):
        """结束练习"""
        try:
            total = len(self.user_answers)
            if total == 0:
                QMessageBox.information(self, _('information'), _('no_answers'))
                self.reset_exam_state()
                return

            correct = self.score
            wrong = total - correct
            rate = (correct / total * 100) if total > 0 else 0

            # 保存记录
            self.save_exam_record(total, correct, rate)

            # 显示统计弹窗
            stats = {
                "exam_type": self.exam_type,
                "total": total,
                "correct": correct,
                "wrong": wrong,
                "rate": rate,
                "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
            dialog = ExamStatisticsDialog(stats, self)
            dialog.exec()

            # 重置状态
            self.reset_exam_state()
        except Exception as e:
            QMessageBox.critical(self, _('error'), _('finish_failed', error=str(e)))

    def reset_exam_state(self):
        """重置考试状态"""
        self.start_btn.setDisabled(False)
        self.submit_btn.setDisabled(True)
        self.next_btn.setDisabled(True)
        self.finish_btn.setDisabled(True)
        self.target_combo.setDisabled(False)
        self.single_radio.setDisabled(False)
        self.group_radio.setDisabled(False)
        self.status_bar.setText(_('status_finished'))
        self.question_label.setText(_('status_ready'))
        self.feedback_label.setText("")
        self.progress_bar.setValue(0)

    def save_exam_record(self, total: int, correct: int, rate: float):
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
            QMessageBox.warning(self, _('warning'), _('record_load_failed', error=str(e)))

    def add_question(self):
        """新增题目"""
        try:
            # 检查是否有题库
            if not self.raw_question_banks:
                QMessageBox.warning(self, _('warning'), _('no_banks'))
                # 创建新题库
                bank_name, ok1 = QInputDialog.getText(self, _('create_bank'), _('bank_name_input'))
                if ok1 and bank_name.strip():
                    exam_group, ok2 = QInputDialog.getText(self, _('create_bank'), _('exam_group_input'), text="卷一")
                    if ok2 and exam_group.strip():
                        self.raw_question_banks[bank_name.strip()] = {
                            "file_name": f"{bank_name.strip()}.json",
                            "exam_group": exam_group.strip(),
                            "questions": []
                        }
                        self.exam_groups = self.group_by_exam(self.raw_question_banks)
                        self.update_target_combobox()
                else:
                    return

            # 打开编辑弹窗
            dialog = QuestionEditorDialog(parent=self)
            if dialog.exec():
                q_data = dialog.get_question_data()
                if not all([q_data["id"], q_data["question"], q_data["answer"]]):
                    QMessageBox.warning(self, _('warning'), _('question_not_empty'))
                    return

                # 选择添加到哪个题库
                bank_names = list(self.raw_question_banks.keys())
                bank_name, ok = QInputDialog.getItem(
                    self, _('select_bank'), _('add_to'), bank_names, 0, False
                )
                if ok:
                    # 添加题目
                    self.raw_question_banks[bank_name]["questions"].append(q_data)
                    # 重新分组
                    self.exam_groups = self.group_by_exam(self.raw_question_banks)
                    # 保存并刷新
                    self.save_question_bank()
                    self.load_bank_to_table()
                    self.update_target_combobox()
                    QMessageBox.information(self, _('success'), _('question_added'))
        except Exception as e:
            QMessageBox.critical(self, _('error'), _('add_failed', error=str(e)))

    def edit_question(self):
        """编辑选中的题目"""
        try:
            selected_rows = self.bank_table.selectionModel().selectedRows()
            if not selected_rows:
                QMessageBox.warning(self, _('warning'), _('please_select_question'))
                return

            row = selected_rows[0].row()

            # 找到对应题目
            all_questions = []
            for exam_group, questions in self.exam_groups.items():
                all_questions.extend(questions)
            q_data = all_questions[row]
            source_bank = q_data["source_bank"]

            # 打开编辑弹窗
            dialog = QuestionEditorDialog(q_data, self)
            if dialog.exec():
                new_data = dialog.get_question_data()
                if not all([new_data["id"], new_data["question"], new_data["answer"]]):
                    QMessageBox.warning(self, _('warning'), _('question_not_empty'))
                    return

                # 更新原始题库
                for idx, q in enumerate(self.raw_question_banks[source_bank]["questions"]):
                    if q["id"] == q_data["id"] and q["question"] == q_data["question"]:
                        self.raw_question_banks[source_bank]["questions"][idx] = new_data
                        break

                # 重新分组、保存、刷新
                self.exam_groups = self.group_by_exam(self.raw_question_banks)
                self.save_question_bank()
                self.load_bank_to_table()
                QMessageBox.information(self, _('success'), _('question_edited'))
        except Exception as e:
            QMessageBox.critical(self, _('error'), _('edit_failed', error=str(e)))

    def delete_question(self):
        """删除选中的题目"""
        try:
            selected_rows = self.bank_table.selectionModel().selectedRows()
            if not selected_rows:
                QMessageBox.warning(self, _('warning'), _('please_select_question_delete'))
                return

            if QMessageBox.question(self, _('confirm'), _('confirm_delete'),
                                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No) != QMessageBox.StandardButton.Yes:
                return

            row = selected_rows[0].row()

            # 找到对应题目
            all_questions = []
            for exam_group, questions in self.exam_groups.items():
                all_questions.extend(questions)
            q_data = all_questions[row]
            source_bank = q_data["source_bank"]

            # 从原始题库删除
            self.raw_question_banks[source_bank]["questions"] = [
                q for q in self.raw_question_banks[source_bank]["questions"]
                if not (q["id"] == q_data["id"] and q["question"] == q_data["question"])
            ]

            # 重新分组、保存、刷新
            self.exam_groups = self.group_by_exam(self.raw_question_banks)
            self.save_question_bank()
            self.load_bank_to_table()
            self.update_target_combobox()
            QMessageBox.information(self, _('success'), _('question_deleted'))
        except Exception as e:
            QMessageBox.critical(self, _('error'), _('delete_failed', error=str(e)))

    def on_bank_table_select(self):
        """题库表格选中事件"""
        try:
            has_selection = len(self.bank_table.selectionModel().selectedRows()) > 0
            self.edit_question_btn.setDisabled(not has_selection)
            self.delete_question_btn.setDisabled(not has_selection)
        except Exception as e:
            QMessageBox.warning(self, _('warning'), _('select_failed', error=str(e)))

    def import_pdf_questions(self):
        """从PDF文件导入题目"""
        try:
            # 打开文件选择对话框
            file_name, _ = QFileDialog.getOpenFileName(
                self, _('select_pdf'), '', 'PDF Files (*.pdf)'
            )
            if not file_name:
                return

            # 打开PDF文件
            with open(file_name, 'rb') as file:
                reader = PyPDF2.PdfReader(file)
                text = ''
                for page_num in range(len(reader.pages)):
                    page = reader.pages[page_num]
                    text += page.extract_text()

            # 简单的题目提取逻辑（实际应用中可能需要更复杂的解析）
            questions = self.parse_pdf_text(text)

            if not questions:
                QMessageBox.warning(self, _('warning'), "未从PDF中提取到题目")
                return

            # 选择或创建题库
            bank_name, ok = QInputDialog.getText(
                self, _('create_bank'), _('bank_name_input')
            )
            if not ok or not bank_name.strip():
                return

            exam_group, ok = QInputDialog.getText(
                self, _('create_bank'), _('exam_group_input'), text="卷一"
            )
            if not ok or not exam_group.strip():
                return

            # 创建新题库
            bank_name = bank_name.strip()
            exam_group = exam_group.strip()
            self.raw_question_banks[bank_name] = {
                "file_name": f"{bank_name}.json",
                "exam_group": exam_group,
                "questions": questions
            }

            # 保存题库
            self.save_question_bank()

            # 刷新题库
            self.load_and_group_question_banks()
            self.load_bank_to_table()
            self.update_target_combobox()

            QMessageBox.information(self, _('success'), _('pdf_import_success'))

        except Exception as e:
            QMessageBox.critical(self, _('error'), _('pdf_import_failed', error=str(e)))

    def parse_pdf_text(self, text):
        """解析PDF文本，提取题目"""
        # 这里实现简单的题目提取逻辑
        # 实际应用中可能需要根据PDF的具体格式进行调整
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

    def check_for_updates(self):
        """检查软件更新"""
        try:
            self.status_bar.setText(_('checking_update'))
            
            # 当前版本
            current_version = "1.0.0"
            
            # GitHub 仓库信息
            repo_owner = "yourusername"  # 替换为你的 GitHub 用户名
            repo_name = "comprehensive-exam-system"  # 项目名称
            
            # 从 GitHub API 获取最新版本信息
            api_url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/releases/latest"
            response = requests.get(api_url, timeout=10)
            
            if response.status_code == 200:
                release_info = response.json()
                latest_version = release_info["tag_name"].lstrip("v")  # 移除 v 前缀
                download_url = None
                
                # 查找更新包下载链接
                for asset in release_info.get("assets", []):
                    if asset["name"].endswith(".exe") and "update" in asset["name"].lower():
                        download_url = asset["browser_download_url"]
                        break
                
                # 比较版本号
                if latest_version > current_version and download_url:
                    # 有更新
                    reply = QMessageBox.question(
                        self, _('update_feature'), 
                        f"发现新版本 v{latest_version}！是否下载更新？\n\n{release_info.get('body', '')}",
                        QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
                    )
                    if reply == QMessageBox.StandardButton.Yes:
                        self.status_bar.setText(_('downloading_update'))
                        
                        # 下载更新包
                        update_file = os.path.join(os.path.dirname(sys.executable), "update.exe")
                        response = requests.get(download_url, stream=True)
                        
                        # 显示下载进度
                        total_size = int(response.headers.get('content-length', 0))
                        downloaded_size = 0
                        
                        with open(update_file, 'wb') as f:
                            for chunk in response.iter_content(chunk_size=8192):
                                if chunk:
                                    f.write(chunk)
                                    downloaded_size += len(chunk)
                                    progress = int((downloaded_size / total_size) * 100)
                                    self.status_bar.setText(f"下载更新中... {progress}%")
                        
                        # 提示安装
                        reply_install = QMessageBox.question(
                            self, _('update_feature'), _('update_downloaded') + '\n' + '是否立即安装更新包？',
                            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
                        )
                        if reply_install == QMessageBox.StandardButton.Yes:
                            # 运行更新包
                            os.startfile(update_file)
                            # 退出当前程序
                            QApplication.quit()
                else:
                    QMessageBox.information(self, _('information'), _('no_update'))
            else:
                QMessageBox.information(self, _('information'), _('no_update'))
                
            self.status_bar.setText(_('status_ready'))
            
        except Exception as e:
            QMessageBox.critical(self, _('error'), _('update_failed', error=str(e)))
            self.status_bar.setText(_('status_ready'))


def main():
    """主函数"""
    if os.name == "nt":
        os.environ["QT_QPA_PLATFORM"] = "windows:darkmode=0"
        os.environ["QT_AUTO_SCREEN_SCALE_FACTOR"] = "0"

    app = QApplication(sys.argv)
    app.setApplicationName(_('app_title'))

    # 中文显示
    font = QFont()
    font.setFamily("Microsoft YaHei")
    app.setFont(font)

    window = ExamMainWindow()
    window.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()