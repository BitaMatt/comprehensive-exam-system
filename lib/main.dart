import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

const appVersion = 'v1.3.0';
const recordStorageKey = 'exam_records_v1';
const aiSettingsFileName = 'ai_settings.json';
const generatedBankDirectoryName = 'generated_banks';
const generationJobDirectoryName = 'generation_jobs';
const defaultAiBaseUrl = 'https://api.chatanywhere.tech';
const defaultAiModel = 'gpt-4o-mini';
const bankAssets = [
  'assets/question_banks/bank1.json',
  'assets/question_banks/bank2.json',
  'assets/question_banks/bank3.json',
  'assets/question_banks/bank4.json',
  'assets/question_banks/bank5.json',
  'assets/question_banks/bank6.json',
  'assets/question_banks/bank7.json',
];

void main() {
  runApp(const ExamApp());
}

class ExamApp extends StatelessWidget {
  const ExamApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff1b6f6a),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: '考试练习系统',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff6f7f4),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: scheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: const ExamHomePage(),
    );
  }
}

class QuestionBank {
  const QuestionBank({
    required this.name,
    required this.examGroup,
    required this.questions,
  });

  final String name;
  final String examGroup;
  final List<Question> questions;

  Map<String, dynamic> toJson() => {
    'name': name,
    'exam_group': examGroup,
    'count': questions.length,
    'questions': questions.map((question) => question.toJson()).toList(),
  };

  factory QuestionBank.fromJson(Map<String, dynamic> json) {
    final questions = (json['questions'] as List<dynamic>? ?? [])
        .map((item) => Question.fromJson(item as Map<String, dynamic>))
        .where((question) => question.isValid)
        .toList();

    return QuestionBank(
      name: (json['name'] ?? '未命名题库').toString(),
      examGroup: (json['exam_group'] ?? '未分组').toString(),
      questions: questions,
    );
  }
}

class Question {
  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.answer,
    required this.analysis,
    required this.sourceBank,
    required this.examGroup,
  });

  final String id;
  final String text;
  final Map<String, String> options;
  final String answer;
  final String analysis;
  final String sourceBank;
  final String examGroup;

  bool get isValid =>
      text.trim().isNotEmpty &&
      ['A', 'B', 'C', 'D'].contains(answer) &&
      options.keys.toSet().containsAll(['A', 'B', 'C', 'D']);

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': text,
    'options': options,
    'answer': answer,
    'analysis': analysis,
    'source_bank': sourceBank,
    'exam_group': examGroup,
  };

  factory Question.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as Map<String, dynamic>? ?? {};
    return Question(
      id: (json['id'] ?? '').toString(),
      text: (json['question'] ?? '').toString(),
      options: {
        for (final key in ['A', 'B', 'C', 'D'])
          key: (rawOptions[key] ?? '').toString(),
      },
      answer: (json['answer'] ?? '').toString().trim().toUpperCase(),
      analysis: (json['analysis'] ?? '').toString(),
      sourceBank: (json['source_bank'] ?? '').toString(),
      examGroup: (json['exam_group'] ?? '').toString(),
    );
  }
}

class ExamRecord {
  const ExamRecord({
    required this.time,
    required this.target,
    required this.total,
    required this.correct,
  });

  final String time;
  final String target;
  final int total;
  final int correct;

  double get rate => total == 0 ? 0 : correct * 100 / total;

  Map<String, dynamic> toJson() => {
    'time': time,
    'target': target,
    'total': total,
    'correct': correct,
  };

  factory ExamRecord.fromJson(Map<String, dynamic> json) {
    return ExamRecord(
      time: (json['time'] ?? '').toString(),
      target: (json['target'] ?? '').toString(),
      total: (json['total'] as num? ?? 0).toInt(),
      correct: (json['correct'] as num? ?? 0).toInt(),
    );
  }
}

class GeneratedBankMetadata {
  const GeneratedBankMetadata({
    required this.id,
    required this.name,
    required this.examGroup,
    required this.questionCount,
    required this.sourcePdfName,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String name;
  final String examGroup;
  final int questionCount;
  final String sourcePdfName;
  final String createdAt;
  final String status;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'exam_group': examGroup,
    'question_count': questionCount,
    'source_pdf_name': sourcePdfName,
    'created_at': createdAt,
    'status': status,
  };

  factory GeneratedBankMetadata.fromJson(Map<String, dynamic> json) {
    return GeneratedBankMetadata(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      examGroup: (json['exam_group'] ?? '').toString(),
      questionCount: (json['question_count'] as num? ?? 0).toInt(),
      sourcePdfName: (json['source_pdf_name'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}

class GenerationJob {
  const GenerationJob({
    required this.id,
    required this.pdfPath,
    required this.pdfName,
    required this.bankName,
    required this.examGroup,
    required this.questionPrefix,
    required this.startPage,
    required this.endPage,
    required this.totalPages,
    required this.nextChunkIndex,
    required this.completedQuestions,
    required this.errors,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String pdfPath;
  final String pdfName;
  final String bankName;
  final String examGroup;
  final String questionPrefix;
  final int startPage;
  final int endPage;
  final int totalPages;
  final int nextChunkIndex;
  final List<Question> completedQuestions;
  final List<String> errors;
  final bool completed;
  final String createdAt;
  final String updatedAt;

  GenerationJob copyWith({
    int? totalPages,
    int? nextChunkIndex,
    List<Question>? completedQuestions,
    List<String>? errors,
    bool? completed,
    String? updatedAt,
  }) {
    return GenerationJob(
      id: id,
      pdfPath: pdfPath,
      pdfName: pdfName,
      bankName: bankName,
      examGroup: examGroup,
      questionPrefix: questionPrefix,
      startPage: startPage,
      endPage: endPage,
      totalPages: totalPages ?? this.totalPages,
      nextChunkIndex: nextChunkIndex ?? this.nextChunkIndex,
      completedQuestions: completedQuestions ?? this.completedQuestions,
      errors: errors ?? this.errors,
      completed: completed ?? this.completed,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pdf_path': pdfPath,
    'pdf_name': pdfName,
    'bank_name': bankName,
    'exam_group': examGroup,
    'question_prefix': questionPrefix,
    'start_page': startPage,
    'end_page': endPage,
    'total_pages': totalPages,
    'next_chunk_index': nextChunkIndex,
    'completed_questions': completedQuestions
        .map((question) => question.toJson())
        .toList(),
    'errors': errors,
    'completed': completed,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory GenerationJob.fromJson(Map<String, dynamic> json) {
    final questions = (json['completed_questions'] as List<dynamic>? ?? [])
        .map((item) => Question.fromJson(item as Map<String, dynamic>))
        .where((question) => question.isValid)
        .toList();
    return GenerationJob(
      id: (json['id'] ?? '').toString(),
      pdfPath: (json['pdf_path'] ?? '').toString(),
      pdfName: (json['pdf_name'] ?? '').toString(),
      bankName: (json['bank_name'] ?? '').toString(),
      examGroup: (json['exam_group'] ?? '').toString(),
      questionPrefix: (json['question_prefix'] ?? 'Q').toString(),
      startPage: (json['start_page'] as num? ?? 1).toInt(),
      endPage: (json['end_page'] as num? ?? 1).toInt(),
      totalPages: (json['total_pages'] as num? ?? 0).toInt(),
      nextChunkIndex: (json['next_chunk_index'] as num? ?? 0).toInt(),
      completedQuestions: questions,
      errors: (json['errors'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      completed: json['completed'] == true,
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }
}

class GenerationProgress {
  const GenerationProgress({
    required this.stage,
    required this.currentPage,
    required this.totalPages,
    required this.currentChunk,
    required this.totalChunks,
    required this.successCount,
    this.message = '',
    this.warning = '',
  });

  final String stage;
  final int currentPage;
  final int totalPages;
  final int currentChunk;
  final int totalChunks;
  final int successCount;
  final String message;
  final String warning;

  double? get value {
    if (totalChunks <= 0) return null;
    return currentChunk.clamp(0, totalChunks) / totalChunks;
  }
}

class PdfPageContent {
  const PdfPageContent({
    required this.pageNumber,
    required this.text,
    required this.needsOcr,
    this.imageBytes,
  });

  final int pageNumber;
  final String text;
  final bool needsOcr;
  final Uint8List? imageBytes;
}

class PdfInspection {
  const PdfInspection({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.totalPages,
    required this.previewText,
    required this.languageHint,
    required this.scannedLike,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final int totalPages;
  final String previewText;
  final String languageHint;
  final bool scannedLike;
}

class AiSettings {
  const AiSettings({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  bool get isConfigured => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  AiSettings copyWith({String? baseUrl, String? apiKey, String? model}) {
    return AiSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    return AiSettings(
      baseUrl: (json['baseUrl'] ?? defaultAiBaseUrl).toString(),
      apiKey: (json['apiKey'] ?? '').toString(),
      model: (json['model'] ?? defaultAiModel).toString(),
    );
  }

  static const empty = AiSettings(
    baseUrl: defaultAiBaseUrl,
    apiKey: '',
    model: defaultAiModel,
  );
}

class AiService {
  const AiService();

  Future<List<String>> fetchModels(AiSettings settings) async {
    final response = await _request(
      settings: settings,
      method: 'GET',
      path: '/v1/models',
    );
    final body = jsonDecode(response) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! List) return [];
    final models =
        data
            .map((item) => item is Map<String, dynamic> ? item['id'] : null)
            .whereType<Object>()
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return models;
  }

  Future<void> testConnection(AiSettings settings) async {
    await _request(
      settings: settings,
      method: 'POST',
      path: '/v1/chat/completions',
      body: {
        'model': settings.model.trim(),
        'messages': [
          {'role': 'user', 'content': 'ping'},
        ],
        'temperature': 0,
        'max_tokens': 5,
      },
    );
  }

  Future<String> chatCompletion({
    required AiSettings settings,
    required List<Map<String, dynamic>> messages,
    int maxTokens = 4000,
  }) async {
    final response = await _request(
      settings: settings,
      method: 'POST',
      path: '/v1/chat/completions',
      body: {
        'model': settings.model.trim(),
        'messages': messages,
        'temperature': 0.1,
        'max_tokens': maxTokens,
      },
    );
    final body = jsonDecode(response) as Map<String, dynamic>;
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiRequestException('AI 未返回可用内容');
    }
    final message = choices.first is Map<String, dynamic>
        ? (choices.first as Map<String, dynamic>)['message']
        : null;
    if (message is! Map<String, dynamic>) {
      throw const AiRequestException('AI 返回格式不完整');
    }
    final content = message['content'];
    if (content is String) return content;
    if (content is List) {
      return content
          .map((item) {
            if (item is Map<String, dynamic>) return item['text']?.toString();
            return item?.toString();
          })
          .whereType<String>()
          .join('\n');
    }
    throw const AiRequestException('AI 返回内容为空');
  }

  Future<String> _request({
    required AiSettings settings,
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    if (settings.apiKey.trim().isEmpty) {
      throw const AiRequestException('请先填写 API Key');
    }

    final uri = Uri.parse('${_normalizeBaseUrl(settings.baseUrl)}$path');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.openUrl(method, uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${settings.apiKey.trim()}',
      );
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiRequestException('请求失败：HTTP ${response.statusCode}\n$text');
      }
      return text;
    } on AiRequestException {
      rethrow;
    } catch (error) {
      throw AiRequestException('连接失败：$error');
    } finally {
      client.close(force: true);
    }
  }

  String _normalizeBaseUrl(String value) {
    var base = value.trim();
    if (base.isEmpty) base = defaultAiBaseUrl;
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      base = 'https://$base';
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/v1')) {
      base = base.substring(0, base.length - 3);
    }
    return base;
  }
}

class AiRequestException implements Exception {
  const AiRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PdfExtractionService {
  const PdfExtractionService();

  Future<PdfInspection> inspect(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final document = sfpdf.PdfDocument(inputBytes: bytes);
    try {
      final extractor = sfpdf.PdfTextExtractor(document);
      final totalPages = document.pages.count;
      final previewPages = min(totalPages, 3);
      final preview = <String>[];
      for (var index = 0; index < previewPages; index += 1) {
        preview.add(
          extractor.extractText(startPageIndex: index, endPageIndex: index),
        );
      }
      final previewText = preview.join('\n').trim();
      return PdfInspection(
        path: path,
        name: file.uri.pathSegments.isEmpty
            ? 'document.pdf'
            : Uri.decodeComponent(file.uri.pathSegments.last),
        sizeBytes: await file.length(),
        totalPages: totalPages,
        previewText: previewText,
        languageHint: _detectLanguage(previewText),
        scannedLike: previewText.replaceAll(RegExp(r'\s+'), '').length < 120,
      );
    } finally {
      document.dispose();
    }
  }

  Future<List<PdfPageContent>> extractPages({
    required String path,
    required int startPage,
    required int endPage,
    required void Function(int page, int total) onPage,
    required bool Function() shouldCancel,
  }) async {
    final bytes = await File(path).readAsBytes();
    final document = sfpdf.PdfDocument(inputBytes: bytes);
    try {
      final extractor = sfpdf.PdfTextExtractor(document);
      final totalPages = document.pages.count;
      final normalizedStart = startPage.clamp(1, totalPages);
      final normalizedEnd = endPage.clamp(normalizedStart, totalPages);
      final pages = <PdfPageContent>[];
      for (var page = normalizedStart; page <= normalizedEnd; page += 1) {
        if (shouldCancel()) break;
        onPage(page, totalPages);
        final text = extractor
            .extractText(startPageIndex: page - 1, endPageIndex: page - 1)
            .trim();
        final needsOcr = text.replaceAll(RegExp(r'\s+'), '').length < 80;
        pages.add(
          PdfPageContent(pageNumber: page, text: text, needsOcr: needsOcr),
        );
      }
      return pages;
    } finally {
      document.dispose();
    }
  }

  String _detectLanguage(String text) {
    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final latin = RegExp(r'[A-Za-z]').allMatches(text).length;
    if (chinese > latin) return '中文';
    if (latin > 0) return '英文/拉丁文字';
    return '未知';
  }
}

class QuestionChunk {
  const QuestionChunk({required this.index, required this.pages});

  final int index;
  final List<PdfPageContent> pages;
}

class QuestionGenerationService {
  const QuestionGenerationService({
    required this.aiService,
    required this.pdfService,
    required this.store,
  });

  final AiService aiService;
  final PdfExtractionService pdfService;
  final GeneratedBankStore store;

  Future<QuestionBank> generate({
    required GenerationJob initialJob,
    required AiSettings settings,
    required void Function(GenerationProgress progress) onProgress,
    required bool Function() shouldCancel,
  }) async {
    var job = initialJob;
    onProgress(
      GenerationProgress(
        stage: '读取 PDF',
        currentPage: job.startPage,
        totalPages: job.totalPages,
        currentChunk: job.nextChunkIndex,
        totalChunks: 0,
        successCount: job.completedQuestions.length,
        message: '正在抽取 PDF 文本并识别扫描页',
      ),
    );

    final pages = await pdfService.extractPages(
      path: job.pdfPath,
      startPage: job.startPage,
      endPage: job.endPage,
      shouldCancel: shouldCancel,
      onPage: (page, total) {
        onProgress(
          GenerationProgress(
            stage: '抽取文本/OCR准备',
            currentPage: page,
            totalPages: total,
            currentChunk: job.nextChunkIndex,
            totalChunks: 0,
            successCount: job.completedQuestions.length,
          ),
        );
      },
    );
    if (shouldCancel()) {
      await store.saveJob(
        job.copyWith(updatedAt: DateTime.now().toIso8601String()),
      );
      throw const GenerationCancelledException();
    }

    final chunks = _buildChunks(pages);
    final questions = [...job.completedQuestions];
    final errors = [...job.errors];

    for (
      var chunkIndex = job.nextChunkIndex;
      chunkIndex < chunks.length;
      chunkIndex += 1
    ) {
      if (shouldCancel()) break;
      final chunk = chunks[chunkIndex];
      onProgress(
        GenerationProgress(
          stage: chunk.pages.any((page) => page.needsOcr)
              ? 'OCR/视觉识别'
              : 'AI 解析',
          currentPage: chunk.pages.last.pageNumber,
          totalPages: job.totalPages,
          currentChunk: chunkIndex,
          totalChunks: chunks.length,
          successCount: questions.length,
          message: '正在处理第 ${chunkIndex + 1} / ${chunks.length} 个片段',
        ),
      );

      try {
        final parsed = await _parseChunk(
          settings: settings,
          chunk: chunk,
          bankName: job.bankName,
          examGroup: job.examGroup,
          prefix: job.questionPrefix,
          existingCount: questions.length,
        );
        questions.addAll(_dedupe(questions, parsed));
      } catch (error) {
        errors.add(
          '第 ${chunk.pages.first.pageNumber}-${chunk.pages.last.pageNumber} 页：$error',
        );
      }

      job = job.copyWith(
        nextChunkIndex: chunkIndex + 1,
        completedQuestions: questions,
        errors: errors,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await store.saveJob(job);
    }

    if (shouldCancel()) {
      await store.saveJob(
        job.copyWith(updatedAt: DateTime.now().toIso8601String()),
      );
      throw const GenerationCancelledException();
    }

    final bank = QuestionBank(
      name: job.bankName,
      examGroup: job.examGroup,
      questions: questions,
    );
    await store.saveGeneratedBank(
      bank: bank,
      metadata: GeneratedBankMetadata(
        id: job.id,
        name: job.bankName,
        examGroup: job.examGroup,
        questionCount: questions.length,
        sourcePdfName: job.pdfName,
        createdAt: job.createdAt,
        status: errors.isEmpty ? 'completed' : 'completed_with_warnings',
      ),
    );
    await store.saveJob(
      job.copyWith(
        completed: true,
        completedQuestions: questions,
        errors: errors,
        updatedAt: DateTime.now().toIso8601String(),
      ),
    );
    onProgress(
      GenerationProgress(
        stage: '保存完成',
        currentPage: job.endPage,
        totalPages: job.totalPages,
        currentChunk: chunks.length,
        totalChunks: chunks.length,
        successCount: questions.length,
        warning: errors.join('\n'),
      ),
    );
    return bank;
  }

  List<QuestionChunk> _buildChunks(List<PdfPageContent> pages) {
    final chunks = <QuestionChunk>[];
    var current = <PdfPageContent>[];
    var currentChars = 0;
    for (final page in pages) {
      final pageChars = page.text.length;
      final forceSingle = page.needsOcr;
      if (current.isNotEmpty &&
          (forceSingle ||
              current.length >= 3 ||
              currentChars + pageChars > 7000)) {
        chunks.add(QuestionChunk(index: chunks.length, pages: current));
        current = [];
        currentChars = 0;
      }
      current.add(page);
      currentChars += pageChars;
      if (forceSingle) {
        chunks.add(QuestionChunk(index: chunks.length, pages: current));
        current = [];
        currentChars = 0;
      }
    }
    if (current.isNotEmpty) {
      chunks.add(QuestionChunk(index: chunks.length, pages: current));
    }
    return chunks;
  }

  Future<List<Question>> _parseChunk({
    required AiSettings settings,
    required QuestionChunk chunk,
    required String bankName,
    required String examGroup,
    required String prefix,
    required int existingCount,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        final content = await aiService.chatCompletion(
          settings: settings,
          messages: [
            {
              'role': 'system',
              'content':
                  '你是考试题库整理助手。只输出严格 JSON，不要解释。只提取单选 A/B/C/D 题。无法确定答案的题不要输出。',
            },
            {
              'role': 'user',
              'content': _buildChunkContent(
                chunk: chunk,
                bankName: bankName,
                examGroup: examGroup,
                prefix: prefix,
                existingCount: existingCount,
                previousError: attempt == 0 ? '' : '上次错误：$lastError',
              ),
            },
          ],
        );
        final json = _decodeJsonObject(content);
        final rawQuestions = json['questions'];
        if (rawQuestions is! List) {
          throw const FormatException('缺少 questions 数组');
        }
        final questions = rawQuestions
            .map(
              (item) =>
                  item is Map<String, dynamic> ? Question.fromJson(item) : null,
            )
            .whereType<Question>()
            .where((question) => question.isValid)
            .map(
              (question) => _normalizeQuestion(question, bankName, examGroup),
            )
            .toList();
        if (questions.isEmpty) {
          throw const FormatException('没有解析出有效单选题');
        }
        return questions;
      } catch (error) {
        lastError = error;
      }
    }
    throw AiRequestException('AI 解析失败：$lastError');
  }

  Object _buildChunkContent({
    required QuestionChunk chunk,
    required String bankName,
    required String examGroup,
    required String prefix,
    required int existingCount,
    required String previousError,
  }) {
    final prompt =
        '''
$previousError
请从以下 PDF 内容中提取单选题，输出 JSON：
{
  "name": "$bankName",
  "exam_group": "$examGroup",
  "questions": [
    {
      "id": "$prefix-001",
      "question": "题干",
      "options": {"A": "选项A", "B": "选项B", "C": "选项C", "D": "选项D"},
      "answer": "A",
      "analysis": "简短解析，没有则留空",
      "source_bank": "$bankName",
      "exam_group": "$examGroup"
    }
  ]
}
题号从 ${existingCount + 1} 继续。保留原文语言，不要编造题目或答案。

PDF 页文本：
${chunk.pages.map((page) => '--- 第 ${page.pageNumber} 页 ---\n${page.text}').join('\n\n')}
''';
    final imagePages = chunk.pages
        .where((page) => page.imageBytes != null)
        .toList();
    if (imagePages.isEmpty) return prompt;
    if (imagePages.any((page) => page.imageBytes == null)) {
      throw const AiRequestException(
        '检测到扫描页，但当前 Windows/Android 稳定版本未启用 PDF 页面渲染。请先使用外部 OCR 转成可选中文字 PDF 后再生成题库。',
      );
    }
    return [
      {'type': 'text', 'text': prompt},
      for (final page in imagePages)
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/jpeg;base64,${base64Encode(page.imageBytes!)}',
          },
        },
    ];
  }

  Map<String, dynamic> _decodeJsonObject(String content) {
    var text = content.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (fence != null) text = fence.group(1)!.trim();
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) text = text.substring(start, end + 1);
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI 返回不是 JSON 对象');
    }
    return decoded;
  }

  Question _normalizeQuestion(
    Question question,
    String bankName,
    String examGroup,
  ) {
    return Question(
      id: question.id,
      text: question.text,
      options: question.options,
      answer: question.answer,
      analysis: question.analysis,
      sourceBank: question.sourceBank.trim().isEmpty
          ? bankName
          : question.sourceBank,
      examGroup: question.examGroup.trim().isEmpty
          ? examGroup
          : question.examGroup,
    );
  }

  List<Question> _dedupe(List<Question> existing, List<Question> incoming) {
    final seen = existing.map((question) => question.text.trim()).toSet();
    final result = <Question>[];
    for (final question in incoming) {
      final key = question.text.trim();
      if (seen.add(key)) result.add(question);
    }
    return result;
  }
}

class GeneratedBankStore {
  const GeneratedBankStore();

  Future<List<QuestionBank>> loadGeneratedBanks() async {
    final dir = await _generatedBanksDirectory();
    if (!await dir.exists()) return [];
    final banks = <QuestionBank>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final content = await entity.readAsString();
        banks.add(
          QuestionBank.fromJson(jsonDecode(content) as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip broken user-generated banks so the app can still start.
      }
    }
    return banks;
  }

  Future<void> saveGeneratedBank({
    required QuestionBank bank,
    required GeneratedBankMetadata metadata,
  }) async {
    final dir = await _generatedBanksDirectory();
    await dir.create(recursive: true);
    final bankJson = bank.toJson();
    bankJson['metadata'] = metadata.toJson();
    await File(
      '${dir.path}/${metadata.id}.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(bankJson));
  }

  Future<void> saveJob(GenerationJob job) async {
    final dir = await _generationJobsDirectory();
    await dir.create(recursive: true);
    await File(
      '${dir.path}/${job.id}.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(job.toJson()));
  }

  Future<GenerationJob?> loadLatestIncompleteJob() async {
    final dir = await _generationJobsDirectory();
    if (!await dir.exists()) return null;
    final jobs = <GenerationJob>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final content = await entity.readAsString();
        final job = GenerationJob.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        );
        if (!job.completed && await File(job.pdfPath).exists()) jobs.add(job);
      } catch (_) {
        // Ignore invalid job state files.
      }
    }
    if (jobs.isEmpty) return null;
    jobs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return jobs.first;
  }
}

class GenerationCancelledException implements Exception {
  const GenerationCancelledException();

  @override
  String toString() => '已取消生成';
}

class ExamHomePage extends StatefulWidget {
  const ExamHomePage({super.key});

  @override
  State<ExamHomePage> createState() => _ExamHomePageState();
}

class _ExamHomePageState extends State<ExamHomePage> {
  final _random = Random();
  final _answerController = TextEditingController();
  final _aiService = const AiService();
  final _generatedBankStore = const GeneratedBankStore();

  var _loading = true;
  var _tabIndex = 0;
  var _mode = PracticeMode.bank;
  var _questionCount = 20;
  var _aiSettings = AiSettings.empty;
  String? _selectedTarget;
  String? _selectedAnswer;
  String? _feedback;
  List<QuestionBank> _banks = [];
  List<ExamRecord> _records = [];
  List<Question> _currentExam = [];
  final Map<int, String> _answers = {};
  var _currentIndex = 0;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    _loadAppData();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadAppData() async {
    final banks = <QuestionBank>[];
    for (final path in bankAssets) {
      final content = await rootBundle.loadString(path);
      banks.add(
        QuestionBank.fromJson(jsonDecode(content) as Map<String, dynamic>),
      );
    }

    final records = await _loadRecords();
    final aiSettings = await _loadAiSettings();
    final generatedBanks = await _generatedBankStore.loadGeneratedBanks();

    if (!mounted) return;
    setState(() {
      _banks = [...banks, ...generatedBanks];
      _records = records.reversed.toList();
      _aiSettings = aiSettings;
      _selectedTarget = _targets.firstOrNull;
      _loading = false;
    });

    if (!aiSettings.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAiSettings(required: true);
      });
    }
  }

  List<String> get _targets {
    if (_mode == PracticeMode.bank) {
      return _banks.map((bank) => bank.name).toList();
    }
    return _banks.map((bank) => bank.examGroup).toSet().toList()..sort();
  }

  List<Question> _questionsForSelection() {
    if (_selectedTarget == null) return [];
    if (_mode == PracticeMode.bank) {
      final bank = _banks.firstWhere((item) => item.name == _selectedTarget);
      return bank.questions;
    }
    return _banks
        .where((bank) => bank.examGroup == _selectedTarget)
        .expand((bank) => bank.questions)
        .toList();
  }

  void _changeMode(PracticeMode mode) {
    setState(() {
      _mode = mode;
      _selectedTarget = _targets.firstOrNull;
      _resetExam();
    });
  }

  void _startExam() {
    final questions = _questionsForSelection();
    if (questions.isEmpty) {
      _showMessage('当前目标没有可用题目');
      return;
    }

    final shuffled = [...questions]..shuffle(_random);
    setState(() {
      _currentExam = shuffled
          .take(min(_questionCount, shuffled.length))
          .toList();
      _answers.clear();
      _currentIndex = 0;
      _finished = false;
      _feedback = null;
      _selectedAnswer = null;
      _answerController.clear();
    });
  }

  void _submitAnswer() {
    if (_currentExam.isEmpty || _finished) return;
    final manual = _answerController.text.trim().toUpperCase();
    final answer = (_selectedAnswer ?? manual).trim().toUpperCase();
    if (!['A', 'B', 'C', 'D'].contains(answer)) {
      _showMessage('请选择或输入 A/B/C/D');
      return;
    }

    final question = _currentExam[_currentIndex];
    setState(() {
      _answers[_currentIndex] = answer;
      _feedback = answer == question.answer
          ? '回答正确'
          : '回答错误，正确答案是 ${question.answer}';
    });
  }

  void _nextQuestion() {
    if (_currentIndex >= _currentExam.length - 1) {
      _finishExam();
      return;
    }
    setState(() {
      _currentIndex += 1;
      _selectedAnswer = _answers[_currentIndex];
      _answerController.text = _selectedAnswer ?? '';
      _feedback = null;
    });
  }

  Future<void> _finishExam() async {
    if (_currentExam.isEmpty) return;
    final correct = _currentExam.asMap().entries.where((entry) {
      return _answers[entry.key] == entry.value.answer;
    }).length;
    final record = ExamRecord(
      time: _formatDateTime(DateTime.now()),
      target: _selectedTarget ?? '未命名练习',
      total: _currentExam.length,
      correct: correct,
    );

    final nextRecords = [record, ..._records];
    await _saveRecords(nextRecords.reversed.toList());

    if (!mounted) return;
    setState(() {
      _records = nextRecords;
      _finished = true;
      _feedback =
          '练习完成：$correct/${_currentExam.length}，正确率 ${record.rate.toStringAsFixed(1)}%';
    });
  }

  Future<AiSettings?> _openAiSettings({bool required = false}) async {
    final result = await showDialog<AiSettings>(
      context: context,
      barrierDismissible: !required,
      builder: (context) => AiSettingsDialog(
        initialSettings: _aiSettings,
        aiService: _aiService,
        forceSetup: required,
      ),
    );
    if (result == null) return null;
    await _saveAiSettings(result);
    if (!mounted) return result;
    setState(() => _aiSettings = result);
    _showMessage('AI 设置已保存');
    return result;
  }

  void _resetExam() {
    _currentExam = [];
    _answers.clear();
    _currentIndex = 0;
    _finished = false;
    _feedback = null;
    _selectedAnswer = null;
    _answerController.clear();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildPracticePage(),
      _buildBankPage(),
      QuestionGeneratorPage(
        aiSettings: _aiSettings,
        onRequireAiSettings: () async =>
            await _openAiSettings(required: true) ?? _aiSettings,
        onBankGenerated: (bank) {
          setState(() {
            _banks = [..._banks, bank];
            _selectedTarget ??= bank.name;
          });
          _showMessage('题库已生成并加入列表');
        },
      ),
      _buildRecordPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('考试练习系统'),
        actions: [
          IconButton(
            tooltip: 'AI 设置',
            onPressed: _loading ? null : () => _openAiSettings(),
            icon: const Icon(Icons.smart_toy_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                appVersion,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(child: pages[_tabIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.quiz_outlined), label: '练习'),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            label: '题库',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_fix_high_outlined),
            label: '生成',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            label: '记录',
          ),
        ],
      ),
    );
  }

  Widget _buildPracticePage() {
    final question = _currentExam.isEmpty ? null : _currentExam[_currentIndex];
    final availableQuestions = _questionsForSelection().length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('练习设置', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SegmentedButton<PracticeMode>(
                  segments: const [
                    ButtonSegment(
                      value: PracticeMode.bank,
                      icon: Icon(Icons.description_outlined),
                      label: Text('单卷'),
                    ),
                    ButtonSegment(
                      value: PracticeMode.group,
                      icon: Icon(Icons.folder_copy_outlined),
                      label: Text('分组'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (value) => _changeMode(value.first),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTarget,
                  decoration: const InputDecoration(labelText: '练习目标'),
                  items: _targets
                      .map(
                        (target) => DropdownMenuItem(
                          value: target,
                          child: Text(target, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTarget = value;
                      _resetExam();
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _questionCount.toDouble(),
                        min: 5,
                        max: 120,
                        divisions: 23,
                        label: '$_questionCount 题',
                        onChanged: (value) {
                          setState(() => _questionCount = value.round());
                        },
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        '$_questionCount 题',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                Text('当前目标共 $availableQuestions 题，会随机抽取不超过题库数量的题目。'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _startExam,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('开始练习'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(_resetExam),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重置'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (question != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '第 ${_currentIndex + 1} / ${_currentExam.length} 题',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        question.id.isEmpty ? question.sourceBank : question.id,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_currentIndex + 1) / _currentExam.length,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    question.text,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  for (final entry in question.options.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _finished
                            ? null
                            : () {
                                setState(() {
                                  _selectedAnswer = entry.key;
                                  _answerController.text = entry.key;
                                });
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _selectedAnswer == entry.key
                                ? Theme.of(context).colorScheme.primaryContainer
                                      .withValues(alpha: 0.55)
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedAnswer == entry.key
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _selectedAnswer == entry.key
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('${entry.key}. ${entry.value}'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  TextField(
                    controller: _answerController,
                    maxLength: 1,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: '手动输入答案',
                      hintText: 'A/B/C/D',
                      counterText: '',
                    ),
                    onChanged: (value) {
                      final normalized = value.trim().toUpperCase();
                      setState(() {
                        _selectedAnswer =
                            ['A', 'B', 'C', 'D'].contains(normalized)
                            ? normalized
                            : null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _finished ? null : _submitAnswer,
                        icon: const Icon(Icons.check),
                        label: const Text('提交答案'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _finished ? null : _nextQuestion,
                        icon: Icon(
                          _currentIndex == _currentExam.length - 1
                              ? Icons.flag_outlined
                              : Icons.navigate_next,
                        ),
                        label: Text(
                          _currentIndex == _currentExam.length - 1
                              ? '完成练习'
                              : '下一题',
                        ),
                      ),
                    ],
                  ),
                  if (_feedback != null) ...[
                    const SizedBox(height: 16),
                    _FeedbackBox(
                      feedback: _feedback!,
                      analysis: question.analysis,
                      correct: _answers[_currentIndex] == question.answer,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBankPage() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _banks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final bank = _banks[index];
        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(bank.name),
            subtitle: Text('${bank.examGroup} · ${bank.questions.length} 题'),
            children: [
              for (final question in bank.questions.take(12))
                ListTile(
                  dense: true,
                  title: Text(
                    question.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('答案：${question.answer}'),
                ),
              if (bank.questions.length > 12)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('仅预览前 12 题，其余题目可在练习中随机抽取。'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordPage() {
    if (_records.isEmpty) {
      return const Center(child: Text('还没有练习记录'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final record = _records[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(record.rate.round().toString())),
            title: Text(record.target),
            subtitle: Text(record.time),
            trailing: Text(
              '${record.correct}/${record.total}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
      },
    );
  }
}

class QuestionGeneratorPage extends StatefulWidget {
  const QuestionGeneratorPage({
    super.key,
    required this.aiSettings,
    required this.onRequireAiSettings,
    required this.onBankGenerated,
  });

  final AiSettings aiSettings;
  final Future<AiSettings> Function() onRequireAiSettings;
  final void Function(QuestionBank bank) onBankGenerated;

  @override
  State<QuestionGeneratorPage> createState() => _QuestionGeneratorPageState();
}

class _QuestionGeneratorPageState extends State<QuestionGeneratorPage> {
  final _pdfService = const PdfExtractionService();
  final _store = const GeneratedBankStore();
  final _bankNameController = TextEditingController();
  final _groupController = TextEditingController(text: '生成题库');
  final _prefixController = TextEditingController(text: 'Q');
  final _startPageController = TextEditingController(text: '1');
  final _endPageController = TextEditingController(text: '1');
  PdfInspection? _inspection;
  GenerationProgress? _progress;
  GenerationJob? _latestJob;
  QuestionBank? _lastBank;
  var _busy = false;
  var _cancelRequested = false;
  var _status = '';

  QuestionGenerationService get _generationService => QuestionGenerationService(
    aiService: const AiService(),
    pdfService: _pdfService,
    store: _store,
  );

  @override
  void initState() {
    super.initState();
    _loadLatestJob();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _groupController.dispose();
    _prefixController.dispose();
    _startPageController.dispose();
    _endPageController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestJob() async {
    final job = await _store.loadLatestIncompleteJob();
    if (!mounted) return;
    setState(() => _latestJob = job);
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _busy = true;
      _status = '正在读取 PDF 信息...';
      _progress = null;
      _lastBank = null;
    });
    try {
      final inspection = await _pdfService.inspect(path);
      if (!mounted) return;
      setState(() {
        _inspection = inspection;
        _bankNameController.text = _nameWithoutExtension(inspection.name);
        _startPageController.text = '1';
        _endPageController.text = inspection.totalPages.toString();
        _status = 'PDF 已载入';
      });
    } catch (error) {
      _showMessage('读取 PDF 失败：$error');
      setState(() => _status = '读取失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startGeneration({GenerationJob? resumeJob}) async {
    var settings = widget.aiSettings;
    if (!settings.isConfigured) {
      settings = await widget.onRequireAiSettings();
      if (!settings.isConfigured) {
        _showMessage('请先配置 AI API Key 和模型');
        return;
      }
    }

    final job = resumeJob ?? _newJob();
    if (job == null) return;
    await _runJob(job, settings);
  }

  GenerationJob? _newJob() {
    final inspection = _inspection;
    if (inspection == null) {
      _showMessage('请先选择 PDF');
      return null;
    }
    final bankName = _bankNameController.text.trim();
    final group = _groupController.text.trim();
    final prefix = _prefixController.text.trim().isEmpty
        ? 'Q'
        : _prefixController.text.trim();
    if (bankName.isEmpty || group.isEmpty) {
      _showMessage('请填写题库名称和考试分组');
      return null;
    }
    final start = int.tryParse(_startPageController.text.trim()) ?? 1;
    final end =
        int.tryParse(_endPageController.text.trim()) ?? inspection.totalPages;
    if (start < 1 || end < start || end > inspection.totalPages) {
      _showMessage('页码范围不正确');
      return null;
    }
    final now = DateTime.now();
    return GenerationJob(
      id: 'gen_${now.microsecondsSinceEpoch}',
      pdfPath: inspection.path,
      pdfName: inspection.name,
      bankName: bankName,
      examGroup: group,
      questionPrefix: prefix,
      startPage: start,
      endPage: end,
      totalPages: inspection.totalPages,
      nextChunkIndex: 0,
      completedQuestions: const [],
      errors: const [],
      completed: false,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );
  }

  Future<void> _runJob(GenerationJob job, AiSettings settings) async {
    setState(() {
      _busy = true;
      _cancelRequested = false;
      _status = '开始生成题库...';
      _lastBank = null;
    });
    await _store.saveJob(job);
    try {
      final bank = await _generationService.generate(
        initialJob: job,
        settings: settings,
        shouldCancel: () => _cancelRequested,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _status = progress.message.isEmpty
                ? progress.stage
                : progress.message;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _lastBank = bank;
        _latestJob = null;
        _status = '生成完成，共 ${bank.questions.length} 题';
      });
      widget.onBankGenerated(bank);
    } on GenerationCancelledException {
      await _loadLatestJob();
      if (mounted) setState(() => _status = '已暂停，可稍后继续');
    } catch (error) {
      await _loadLatestJob();
      if (mounted) setState(() => _status = '生成失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportLastBank() async {
    final bank = _lastBank;
    if (bank == null) {
      _showMessage('还没有可导出的题库');
      return;
    }
    final fileName = '${_safeFileName(bank.name)}.json';
    final dir = Directory.systemTemp.createTempSync('exam_bank_export_');
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(bank.toJson()),
    );
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final inspection = _inspection;
    final progress = _progress;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('题库生成', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _pickPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('选择 PDF'),
                    ),
                    if (_latestJob != null)
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _startGeneration(resumeJob: _latestJob),
                        icon: const Icon(Icons.replay_outlined),
                        label: const Text('继续上次任务'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _lastBank == null ? null : _exportLastBank,
                      icon: const Icon(Icons.ios_share_outlined),
                      label: const Text('导出 JSON'),
                    ),
                  ],
                ),
                if (inspection != null) ...[
                  const SizedBox(height: 12),
                  Text('文件：${inspection.name}'),
                  Text(
                    '页数：${inspection.totalPages}，大小：${_formatBytes(inspection.sizeBytes)}',
                  ),
                  Text(
                    '语言：${inspection.languageHint}，类型：${inspection.scannedLike ? '疑似扫描件' : '可抽取文本'}',
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _bankNameController,
                  decoration: const InputDecoration(labelText: '题库名称'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _groupController,
                  decoration: const InputDecoration(labelText: '考试分组'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _prefixController,
                        decoration: const InputDecoration(labelText: '题号前缀'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _startPageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '起始页'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _endPageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '结束页'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _startGeneration,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('开始生成'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? () => setState(() => _cancelRequested = true)
                          : null,
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('暂停'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('进度', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: progress?.value),
                const SizedBox(height: 10),
                Text(_status.isEmpty ? '等待选择 PDF' : _status),
                if (progress != null) ...[
                  Text('阶段：${progress.stage}'),
                  Text(
                    '页码：${progress.currentPage}/${progress.totalPages}，片段：${progress.currentChunk}/${progress.totalChunks}，已生成：${progress.successCount} 题',
                  ),
                  if (progress.warning.trim().isNotEmpty)
                    Text(
                      progress.warning,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _nameWithoutExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_').trim();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class AiSettingsDialog extends StatefulWidget {
  const AiSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.aiService,
    required this.forceSetup,
  });

  final AiSettings initialSettings;
  final AiService aiService;
  final bool forceSetup;

  @override
  State<AiSettingsDialog> createState() => _AiSettingsDialogState();
}

class _AiSettingsDialogState extends State<AiSettingsDialog> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  var _loading = false;
  var _message = '';
  List<String> _models = [];

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.initialSettings.baseUrl,
    );
    _apiKeyController = TextEditingController(
      text: widget.initialSettings.apiKey,
    );
    _modelController = TextEditingController(
      text: widget.initialSettings.model,
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  AiSettings get _settings => AiSettings(
    baseUrl: _baseUrlController.text.trim().isEmpty
        ? defaultAiBaseUrl
        : _baseUrlController.text.trim(),
    apiKey: _apiKeyController.text.trim(),
    model: _modelController.text.trim(),
  );

  Future<void> _fetchModels() async {
    setState(() {
      _loading = true;
      _message = '正在获取模型列表...';
    });
    try {
      final models = await widget.aiService.fetchModels(_settings);
      setState(() {
        _models = models;
        _message = models.isEmpty
            ? '未获取到模型，请手动填写模型名。'
            : '已获取 ${models.length} 个模型';
        if (_modelController.text.trim().isEmpty && models.isNotEmpty) {
          _modelController.text = models.first;
        }
      });
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _loading = true;
      _message = '正在测试连接...';
    });
    try {
      await widget.aiService.testConnection(_settings);
      setState(() => _message = '连接测试成功');
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _save() {
    final settings = _settings;
    if (!settings.isConfigured) {
      setState(() => _message = '请填写 API Key 和模型名称');
      return;
    }
    Navigator.of(context).pop(settings);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forceSetup,
      child: AlertDialog(
        title: const Text('AI 设置'),
        content: SizedBox(
          width: min(MediaQuery.of(context).size.width * 0.86, 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.forceSetup)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('首次打开软件需要配置 AI 接口。API Key 只保存在本机。'),
                  ),
                TextField(
                  controller: _baseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: defaultAiBaseUrl,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    hintText: 'sk-...',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: '模型',
                    hintText: defaultAiModel,
                  ),
                ),
                if (_models.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _models.contains(_modelController.text.trim())
                        ? _modelController.text.trim()
                        : null,
                    hint: const Text('选择获取到的模型'),
                    items: _models
                        .map(
                          (model) => DropdownMenuItem(
                            value: model,
                            child: Text(model, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _modelController.text = value;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _fetchModels,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('获取模型'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _testConnection,
                      icon: const Icon(Icons.network_check_outlined),
                      label: const Text('测试连接'),
                    ),
                  ],
                ),
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_message),
                ],
                if (_loading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (!widget.forceSetup)
            TextButton(
              onPressed: _loading ? null : () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          FilledButton(
            onPressed: _loading ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _FeedbackBox extends StatelessWidget {
  const _FeedbackBox({
    required this.feedback,
    required this.analysis,
    required this.correct,
  });

  final String feedback;
  final String analysis;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final color = correct ? Colors.green : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feedback,
            style: TextStyle(
              color: color.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (analysis.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('解析：$analysis'),
          ],
        ],
      ),
    );
  }
}

enum PracticeMode { bank, group }

Future<List<ExamRecord>> _loadRecords() async {
  try {
    final file = await _recordsFile();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    return (jsonDecode(content) as List<dynamic>)
        .map((item) => ExamRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> _saveRecords(List<ExamRecord> records) async {
  final file = await _recordsFile();
  await file.parent.create(recursive: true);
  await file.writeAsString(
    jsonEncode(records.map((item) => item.toJson()).toList()),
  );
}

Future<AiSettings> _loadAiSettings() async {
  try {
    final file = await _aiSettingsFile();
    if (!await file.exists()) return AiSettings.empty;
    final content = await file.readAsString();
    return AiSettings.fromJson(jsonDecode(content) as Map<String, dynamic>);
  } catch (_) {
    return AiSettings.empty;
  }
}

Future<void> _saveAiSettings(AiSettings settings) async {
  final file = await _aiSettingsFile();
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(settings.toJson()));
}

Future<File> _recordsFile() async =>
    File('${(await _appDataDirectory()).path}/$recordStorageKey.json');

Future<File> _aiSettingsFile() async =>
    File('${(await _appDataDirectory()).path}/$aiSettingsFileName');

Future<Directory> _generatedBanksDirectory() async => Directory(
  '${(await _appDataDirectory()).path}/$generatedBankDirectoryName',
);

Future<Directory> _generationJobsDirectory() async => Directory(
  '${(await _appDataDirectory()).path}/$generationJobDirectoryName',
);

Future<Directory> _appDataDirectory() async {
  try {
    final directory = await getApplicationSupportDirectory();
    return Directory('${directory.path}/ComprehensiveExamSystem');
  } catch (_) {
    final env = Platform.environment;
    final base = Platform.isWindows
        ? (env['APPDATA'] ?? Directory.systemTemp.path)
        : (env['HOME'] ?? Directory.systemTemp.path);
    return Directory('$base/ComprehensiveExamSystem');
  }
}

String _formatDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
