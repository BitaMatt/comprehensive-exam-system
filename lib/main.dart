import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

const appVersion = 'v1.2.0';
const recordStorageKey = 'exam_records_v1';
const aiSettingsFileName = 'ai_settings.json';
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

class ExamHomePage extends StatefulWidget {
  const ExamHomePage({super.key});

  @override
  State<ExamHomePage> createState() => _ExamHomePageState();
}

class _ExamHomePageState extends State<ExamHomePage> {
  final _random = Random();
  final _answerController = TextEditingController();
  final _aiService = const AiService();

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

    if (!mounted) return;
    setState(() {
      _banks = banks;
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

  Future<void> _openAiSettings({bool required = false}) async {
    final result = await showDialog<AiSettings>(
      context: context,
      barrierDismissible: !required,
      builder: (context) => AiSettingsDialog(
        initialSettings: _aiSettings,
        aiService: _aiService,
        forceSetup: required,
      ),
    );
    if (result == null) return;
    await _saveAiSettings(result);
    if (!mounted) return;
    setState(() => _aiSettings = result);
    _showMessage('AI 设置已保存');
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
    final pages = [_buildPracticePage(), _buildBankPage(), _buildRecordPage()];

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
    final file = _recordsFile();
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
  final file = _recordsFile();
  await file.parent.create(recursive: true);
  await file.writeAsString(
    jsonEncode(records.map((item) => item.toJson()).toList()),
  );
}

Future<AiSettings> _loadAiSettings() async {
  try {
    final file = _aiSettingsFile();
    if (!await file.exists()) return AiSettings.empty;
    final content = await file.readAsString();
    return AiSettings.fromJson(jsonDecode(content) as Map<String, dynamic>);
  } catch (_) {
    return AiSettings.empty;
  }
}

Future<void> _saveAiSettings(AiSettings settings) async {
  final file = _aiSettingsFile();
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(settings.toJson()));
}

File _recordsFile() =>
    File('${_appDataDirectory().path}/$recordStorageKey.json');

File _aiSettingsFile() =>
    File('${_appDataDirectory().path}/$aiSettingsFileName');

Directory _appDataDirectory() {
  final env = Platform.environment;
  final base = Platform.isWindows
      ? (env['APPDATA'] ?? Directory.systemTemp.path)
      : (env['HOME'] ?? Directory.systemTemp.path);
  return Directory('$base/ComprehensiveExamSystem');
}

String _formatDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
