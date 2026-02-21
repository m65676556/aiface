import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../data/models/message.dart';
import '../../providers/providers.dart';

const _uuid = Uuid();

class WordCard {
  final String french;
  final String chinese;
  final String example;
  final String exampleTranslation;

  const WordCard({
    required this.french,
    required this.chinese,
    required this.example,
    required this.exampleTranslation,
  });

  factory WordCard.fromJson(Map<String, dynamic> json) {
    return WordCard(
      french: json['french'] as String,
      chinese: json['chinese'] as String,
      example: json['example'] as String,
      exampleTranslation: json['exampleTranslation'] as String,
    );
  }
}

class WordCardScreen extends ConsumerStatefulWidget {
  const WordCardScreen({super.key});

  @override
  ConsumerState<WordCardScreen> createState() => _WordCardScreenState();
}

class _WordCardScreenState extends ConsumerState<WordCardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  List<WordCard> _cards = [];
  int _currentIndex = 0;
  bool _isFront = true;
  bool _isLoading = true;
  String? _errorMessage;

  // Track which cards the user marked as "known"
  final Set<int> _knownIndices = {};

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchWords());
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _fetchWords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final llm = ref.read(llmServiceProvider);
    if (llm == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '请先在设置中配置 API Key';
      });
      return;
    }

    const prompt = '''请给我 10 个常用法语单词，以 JSON 数组格式返回，不要有任何其他文字。
格式如下：
[
  {
    "french": "bonjour",
    "chinese": "你好",
    "example": "Bonjour, comment ça va?",
    "exampleTranslation": "你好，你怎么样？"
  }
]
单词应该覆盖不同词性（名词、动词、形容词、副词等），适合初学者。''';

    try {
      final userMessage = Message(
        id: _uuid.v4(),
        conversationId: 'word-cards',
        role: 'user',
        content: prompt,
        createdAt: DateTime.now(),
      );
      final response = await llm.chat(
        [userMessage],
        systemPrompt:
            'You are a French language teaching assistant. Return only valid JSON, no extra text.',
      );

      // Extract JSON array from response
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']');
      if (jsonStart == -1 || jsonEnd == -1) {
        throw FormatException('No JSON array found in response');
      }
      final jsonStr = response.substring(jsonStart, jsonEnd + 1);
      final List<dynamic> parsed = jsonDecode(jsonStr);
      final cards =
          parsed.map((e) => WordCard.fromJson(e as Map<String, dynamic>)).toList();

      setState(() {
        _cards = cards;
        _currentIndex = 0;
        _isFront = true;
        _isLoading = false;
        _knownIndices.clear();
      });
      _flipController.reset();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '获取单词失败：$e';
      });
    }
  }

  void _flipCard() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  void _nextCard({required bool known}) {
    if (_cards.isEmpty) return;
    if (known) _knownIndices.add(_currentIndex);

    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _isFront = true;
      });
      _flipController.reset();
    } else {
      _showSummary();
    }
  }

  void _showSummary() {
    final known = _knownIndices.length;
    final total = _cards.length;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('练习完成！', style: TextStyle(color: AppTheme.textColor)),
        content: Text(
          '你认识了 $known / $total 个单词\n${known == total ? "太棒了！全部掌握！" : "继续加油！"}',
          style: const TextStyle(color: AppTheme.textColor),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _fetchWords();
            },
            child: const Text('再练一组'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('🇫🇷 法语单词卡片'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '换一组单词',
            onPressed: _isLoading ? null : _fetchWords,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI 正在为你准备单词...', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.accentColor, size: 48),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(color: AppTheme.textColor)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchWords,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _cards.isEmpty
                  ? const Center(
                      child: Text('没有单词数据', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  : Column(
                      children: [
                        // Progress bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                '${_currentIndex + 1} / ${_cards.length}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (_currentIndex + 1) / _cards.length,
                                    backgroundColor:
                                        AppTheme.surfaceColor,
                                    color: Colors.blue,
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '已掌握 ${_knownIndices.length}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Flip card
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: GestureDetector(
                              onTap: _flipCard,
                              child: AnimatedBuilder(
                                animation: _flipAnimation,
                                builder: (context, child) {
                                  final angle = _flipAnimation.value * pi;
                                  final isFrontVisible = angle < pi / 2;
                                  return Transform(
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.001)
                                      ..rotateY(angle),
                                    alignment: Alignment.center,
                                    child: isFrontVisible
                                        ? _buildFront(_cards[_currentIndex])
                                        : Transform(
                                            transform: Matrix4.identity()
                                              ..rotateY(pi),
                                            alignment: Alignment.center,
                                            child: _buildBack(_cards[_currentIndex]),
                                          ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // Hint text
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _isFront ? '点击卡片查看释义' : '点击卡片返回正面',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),

                        // Action buttons
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.close, color: AppTheme.accentColor),
                                  label: const Text(
                                    '再练 ✗',
                                    style: TextStyle(color: AppTheme.accentColor),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.accentColor),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => _nextCard(known: false),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check, color: Colors.white),
                                  label: const Text(
                                    '知道了 ✓',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => _nextCard(known: true),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildFront(WordCard card) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🇫🇷 法语',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Text(
            card.french,
            style: const TextStyle(
              color: AppTheme.textColor,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '点击翻转查看释义',
              style: TextStyle(color: Colors.blue, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack(WordCard card) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              card.french,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              card.chinese,
              style: const TextStyle(
                color: AppTheme.textColor,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.example,
                    style: const TextStyle(
                      color: AppTheme.textColor,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.exampleTranslation,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
