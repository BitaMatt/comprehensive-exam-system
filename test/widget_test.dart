import 'package:comprehensive_exam_system/main.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters invalid questions from bank json', () {
    final bank = QuestionBank.fromJson({
      'name': '测试题库',
      'exam_group': '测试分组',
      'questions': [
        {
          'id': 'Q-001',
          'question': '有效题目？',
          'options': {'A': '一', 'B': '二', 'C': '三', 'D': '四'},
          'answer': 'A',
        },
        {
          'id': 'Q-002',
          'question': '',
          'options': {'A': '一', 'B': '二', 'C': '三', 'D': '四'},
          'answer': 'B',
        },
        {
          'id': 'Q-003',
          'question': '答案非法？',
          'options': {'A': '一', 'B': '二', 'C': '三', 'D': '四'},
          'answer': 'E',
        },
      ],
    });

    expect(bank.questions, hasLength(1));
    expect(bank.questions.single.id, 'Q-001');
  });

  test('generation job keeps resume cursor and completed questions', () {
    final job = GenerationJob.fromJson({
      'id': 'job-1',
      'pdf_path': 'sample.pdf',
      'pdf_name': 'sample.pdf',
      'bank_name': '生成题库',
      'exam_group': '分组',
      'question_prefix': 'G',
      'start_page': 1,
      'end_page': 5,
      'total_pages': 5,
      'next_chunk_index': 2,
      'completed_questions': [
        {
          'id': 'G-001',
          'question': '有效题目？',
          'options': {'A': '一', 'B': '二', 'C': '三', 'D': '四'},
          'answer': 'D',
        },
      ],
      'errors': ['第 1 页：无题目'],
      'completed': false,
      'created_at': '2026-05-26T00:00:00',
      'updated_at': '2026-05-26T00:01:00',
    });

    expect(job.nextChunkIndex, 2);
    expect(job.completedQuestions, hasLength(1));
    expect(job.errors.single, contains('无题目'));
    expect(job.completed, isFalse);
  });

  test('pdf file names with Chinese characters do not need URI decoding', () {
    expect(
      pdfFileNameFromPath(r'C:\Users\pc\Documents\保險考證\卷2模擬題.pdf'),
      '卷2模擬題.pdf',
    );
  });

  test('sample scanned PDF can be rendered for OCR when available', () async {
    const path = r'C:\Users\pc\Documents\保險考證\卷2模擬題.pdf';
    if (!File(path).existsSync()) return;

    TestWidgetsFlutterBinding.ensureInitialized();
    final service = PdfExtractionService();
    final info = await service.inspect(path);
    final pages = await service.extractPages(
      path: info.path,
      startPage: 1,
      endPage: 1,
      onPage: (_, _) {},
      shouldCancel: () => false,
    );

    expect(info.name, '卷2模擬題.pdf');
    expect(pages.single.needsOcr, isTrue);
    expect(pages.single.imageBytes, isNotNull);
    expect(pages.single.imageBytes!.length, greaterThan(10000));
  });

  testWidgets('loads the exam home page', (tester) async {
    await tester.pumpWidget(const ExamApp());
    await tester.pump();

    expect(find.text('考试练习系统'), findsWidgets);
    expect(find.text('练习'), findsWidgets);
    expect(find.text('生成'), findsOneWidget);
  });
}
