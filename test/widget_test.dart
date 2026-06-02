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

  test('generated bank metadata marks bank editable', () {
    final bank = QuestionBank.fromJson({
      'name': '生成题库',
      'exam_group': '分组',
      'metadata': {'id': 'gen_1'},
      'questions': [
        {
          'id': 'G-001',
          'question': '有效题目？',
          'options': {'A': '一', 'B': '二', 'C': '三', 'D': '四'},
          'answer': 'A',
        },
      ],
    });

    expect(bank.isGenerated, isTrue);
    expect(bank.generatedId, 'gen_1');
  });

  test('pdf file names with Chinese characters do not need URI decoding', () {
    expect(
      pdfFileNameFromPath(r'C:\Users\pc\Documents\保險考證\卷2模擬題.pdf'),
      '卷2模擬題.pdf',
    );
  });

  test('translates common question and analysis text to traditional Chinese', () {
    const text =
        '考试练习系统：自然损耗、折旧等是属于以下哪项除外责任？因为这些损失是必然发生的、可预见的，不符合风险原则。选项D普通除外责任并非标准分类。';

    expect(
      translateChinese(text, ChineseLanguage.traditional),
      '考試練習系統：自然損耗、折舊等是屬於以下哪項除外責任？因為這些損失是必然發生的、可預見的，不符合風險原則。選項D普通除外責任並非標準分類。',
    );
  });

  test('uses broad simplified traditional conversion for bank content', () {
    const text = '火灾的损毁，可包括：由烟、水及热力引致的损毁。这些是火灾常见的伴随后果，不属于火灾的直接损毁范畴，也可能波及邻近财产。';

    expect(
      translateChinese(text, ChineseLanguage.traditional),
      '火災的損毀，可包括：由煙、水及熱力引致的損毀。這些是火災常見的伴隨後果，不屬於火災的直接損毀範疇，也可能波及鄰近財產。',
    );
    expect(
      translateChinese('火災的損毀，可包括水及熱力，並波及鄰近財產。', ChineseLanguage.simplified),
      '火灾的损毁，可包括水及热力，并波及邻近财产。',
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
    if (await _hasRapidOcr()) {
      expect(pages.single.ocrText, contains('保险'));
    }
  });

  testWidgets('loads the exam home page', (tester) async {
    await tester.pumpWidget(const ExamApp());
    await tester.pump();

    expect(find.text('考试练习系统'), findsWidgets);
    expect(find.text('练习'), findsWidgets);
    expect(find.text('生成'), findsOneWidget);
  });
}

Future<bool> _hasRapidOcr() async {
  try {
    final result = await Process.run('python', [
      '-c',
      'import rapidocr_onnxruntime',
    ]).timeout(const Duration(seconds: 8));
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
