import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../data/models/message.dart';
import '../../providers/providers.dart';
import '../../services/dating_api_service.dart';
import 'chat_room_screen.dart';

const _uuid = Uuid();

// ── 数据模型 ──────────────────────────────────────────────
class PersonalityProfile {
  final String summary;
  final List<String> traits;
  final List<String> interests;
  final String communicationStyle;
  final String values;

  const PersonalityProfile({
    required this.summary,
    required this.traits,
    required this.interests,
    required this.communicationStyle,
    required this.values,
  });

  factory PersonalityProfile.fromJson(Map<String, dynamic> json) {
    return PersonalityProfile(
      summary: json['summary'] as String? ?? '',
      traits: List<String>.from(json['traits'] as List? ?? []),
      interests: List<String>.from(json['interests'] as List? ?? []),
      communicationStyle: json['communicationStyle'] as String? ?? '',
      values: json['values'] as String? ?? '',
    );
  }
}

// ── 持久化 ───────────────────────────────────────────────
class DatingStorage {
  static const _photoKey = 'dating_photo_base64';
  static const _idealKey = 'dating_ideal_partner';
  static const _appearanceTagsKey = 'dating_appearance_tags';
  static const _appearanceDescKey = 'dating_appearance_desc';
  static const _deviceIdKey = 'dating_device_id';

  static Future<String> getDeviceId() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString(_deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await p.setString(_deviceIdKey, id);
    }
    return id;
  }

  static Future<void> savePhoto(String base64) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_photoKey, base64);
  }

  static Future<String?> loadPhoto() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_photoKey);
  }

  static Future<void> saveIdealPartner(String text) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_idealKey, text);
  }

  static Future<String?> loadIdealPartner() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_idealKey);
  }

  static Future<void> saveAppearanceTags(List<String> tags) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_appearanceTagsKey, tags);
  }

  static Future<List<String>> loadAppearanceTags() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_appearanceTagsKey) ?? [];
  }

  static Future<void> saveAppearanceDesc(String text) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_appearanceDescKey, text);
  }

  static Future<String?> loadAppearanceDesc() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_appearanceDescKey);
  }
}

// ── 主界面 ───────────────────────────────────────────────
class DatingProfileScreen extends ConsumerStatefulWidget {
  const DatingProfileScreen({super.key});

  @override
  ConsumerState<DatingProfileScreen> createState() =>
      _DatingProfileScreenState();
}

class _DatingProfileScreenState extends ConsumerState<DatingProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 性格分析
  PersonalityProfile? _profile;
  bool _isAnalyzing = false;
  String? _analysisError;

  // 头像
  Uint8List? _photoBytes;
  bool _uploadingPhoto = false;

  // 外貌偏好
  final _appearanceDescController = TextEditingController();
  final Set<String> _selectedTags = {};

  // 理想对象
  final _idealPartnerController = TextEditingController();

  // 发布 & 匹配
  bool _isPublishing = false;
  String? _publishError;
  List<Map<String, dynamic>> _matches = [];
  bool _loadingMatches = false;
  String? _deviceId;

  static const _appearanceOptions = [
    '清纯可爱', '成熟稳重', '帅气阳光', '甜美温柔',
    '酷感个性', '知性优雅', '活力运动', '文艺气质',
    '高挑修长', '小巧可爱',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSavedData();
    _initDeviceId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appearanceDescController.dispose();
    _idealPartnerController.dispose();
    super.dispose();
  }

  Future<void> _initDeviceId() async {
    final id = await DatingStorage.getDeviceId();
    if (mounted) setState(() => _deviceId = id);
  }

  Future<void> _loadSavedData() async {
    final photo = await DatingStorage.loadPhoto();
    final ideal = await DatingStorage.loadIdealPartner();
    final tags = await DatingStorage.loadAppearanceTags();
    final desc = await DatingStorage.loadAppearanceDesc();

    setState(() {
      if (photo != null) _photoBytes = base64Decode(photo);
      if (ideal != null) _idealPartnerController.text = ideal;
      if (desc != null) _appearanceDescController.text = desc;
      _selectedTags.addAll(tags);
    });
  }

  // ── 头像上传 ───────────────────────────────────────────
  Future<void> _pickPhoto() async {
    setState(() => _uploadingPhoto = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        await DatingStorage.savePhoto(base64Encode(bytes));
        setState(() => _photoBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败：$e')),
        );
      }
    } finally {
      setState(() => _uploadingPhoto = false);
    }
  }

  // ── 性格分析 ───────────────────────────────────────────
  Future<void> _analyzePersonality() async {
    final llm = ref.read(llmServiceProvider);
    if (llm == null) {
      setState(() => _analysisError = '请先在设置中配置 API Key');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });

    final db = ref.read(databaseProvider);
    final conversations = await db.getAllConversations();

    List<String> allMessages = [];
    for (final conv in conversations.take(5)) {
      final msgs = await db.getMessages(conv.id);
      for (final msg in msgs) {
        if (msg.role == 'user' && msg.content.isNotEmpty) {
          allMessages.add(msg.content);
        }
      }
    }

    if (allMessages.isEmpty) {
      setState(() {
        _isAnalyzing = false;
        _analysisError = '还没有聊天记录，先和 AI 聊几句吧！';
      });
      return;
    }

    final recentMessages =
        allMessages.reversed.take(50).toList().reversed.join('\n');

    const systemPrompt = '''你是一个专业的性格分析师。
根据用户的聊天记录，分析他/她的性格特征。
只返回 JSON，不要有任何其他文字。

格式：
{
  "summary": "一句话总结这个人的性格（20字以内）",
  "traits": ["性格特征1", "性格特征2", "性格特征3", "性格特征4"],
  "interests": ["兴趣1", "兴趣2", "兴趣3"],
  "communicationStyle": "沟通风格描述（15字以内）",
  "values": "核心价值观（15字以内）"
}''';

    final prompt = '以下是这个人的聊天记录：\n\n$recentMessages\n\n请分析他/她的性格。';

    try {
      final userMessage = Message(
        id: _uuid.v4(),
        conversationId: 'dating-analysis',
        role: 'user',
        content: prompt,
        createdAt: DateTime.now(),
      );

      final response = await llm.chat([userMessage], systemPrompt: systemPrompt);

      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) throw FormatException('No JSON');

      final json = jsonDecode(response.substring(jsonStart, jsonEnd + 1));
      setState(() {
        _profile = PersonalityProfile.fromJson(json);
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _analysisError = '分析失败：$e';
      });
    }
  }

  // ── 保存外貌偏好 ──────────────────────────────────────
  Future<void> _saveAppearance() async {
    await DatingStorage.saveAppearanceTags(_selectedTags.toList());
    await DatingStorage.saveAppearanceDesc(_appearanceDescController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('外貌偏好已保存 ✓')),
      );
    }
  }

  // ── 保存理想对象 ──────────────────────────────────────
  Future<void> _saveIdealPartner() async {
    await DatingStorage.saveIdealPartner(_idealPartnerController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存 💕')),
      );
    }
  }

  // ── 发布档案 ──────────────────────────────────────────
  Future<void> _publishProfile() async {
    if (_deviceId == null) return;
    if (_profile == null) {
      setState(() => _publishError = '请先分析性格');
      return;
    }

    setState(() {
      _isPublishing = true;
      _publishError = null;
    });

    try {
      final photoB64 = await DatingStorage.loadPhoto();
      final tags = await DatingStorage.loadAppearanceTags();

      await DatingApiService.publishProfile({
        'device_id': _deviceId,
        'photo_base64': photoB64,
        'personality_summary': _profile!.summary,
        'traits': jsonEncode(_profile!.traits),
        'interests': jsonEncode(_profile!.interests),
        'communication_style': _profile!.communicationStyle,
        'values_text': _profile!.values,
        'appearance_tags': jsonEncode(tags),
        'appearance_desc': _appearanceDescController.text.trim(),
        'ideal_partner': _idealPartnerController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('档案已发布 🎉')),
        );
        _tabController.animateTo(3);
        _loadMatches();
      }
    } catch (e) {
      setState(() => _publishError = '发布失败：$e');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  // ── 拉取匹配列表 ─────────────────────────────────────
  Future<void> _loadMatches() async {
    if (_deviceId == null) return;
    setState(() => _loadingMatches = true);
    try {
      final list = await DatingApiService.fetchMatches(_deviceId!);
      if (mounted) setState(() => _matches = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载匹配列表失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMatches = false);
    }
  }

  // ── UI ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('💕 交友档案'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pink,
          labelColor: Colors.pink,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: '我的资料'),
            Tab(text: '外貌偏好'),
            Tab(text: '理想对象'),
            Tab(text: '💘 匹配'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyProfileTab(),
          _buildAppearanceTab(),
          _buildIdealPartnerTab(),
          _buildMatchesTab(),
        ],
      ),
    );
  }

  // ── Tab 1：我的资料 ────────────────────────────────────
  Widget _buildMyProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 头像区域
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surfaceColor,
                      border: Border.all(color: Colors.pink, width: 2.5),
                      image: _photoBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_photoBytes!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _photoBytes == null
                        ? const Icon(Icons.person,
                            size: 50, color: AppTheme.textSecondary)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.pink,
                        shape: BoxShape.circle,
                      ),
                      child: _uploadingPhoto
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt,
                              size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Text(
            _photoBytes == null ? '点击上传头像' : '点击更换头像',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),

          const SizedBox(height: 28),

          // 性格分析
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.psychology),
              label: Text(_isAnalyzing ? '分析中...' : '分析我的性格'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isAnalyzing ? null : _analyzePersonality,
            ),
          ),

          if (_analysisError != null) ...[
            const SizedBox(height: 10),
            Text(_analysisError!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],

          if (_profile != null) ...[
            const SizedBox(height: 20),
            _buildProfileCard(_profile!),
          ],

          const SizedBox(height: 20),

          // 发布档案按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isPublishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_isPublishing ? '发布中...' : '发布档案 & 查看匹配'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isPublishing ? null : _publishProfile,
            ),
          ),

          if (_publishError != null) ...[
            const SizedBox(height: 8),
            Text(_publishError!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],

          const SizedBox(height: 20),
          _buildRoadmap(),
        ],
      ),
    );
  }

  // ── Tab 2：外貌偏好 ────────────────────────────────────
  Widget _buildAppearanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('✨ 你喜欢什么类型的外表？'),
          const SizedBox(height: 4),
          Text('可多选', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 14),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _appearanceOptions.map((tag) {
              final selected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () => setState(() {
                  selected ? _selectedTags.remove(tag) : _selectedTags.add(tag);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.pink
                        : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected ? Colors.pink : AppTheme.textSecondary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: selected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          _sectionHeader('📝 详细描述（可选）'),
          const SizedBox(height: 10),
          TextField(
            controller: _appearanceDescController,
            maxLines: 4,
            style: const TextStyle(color: AppTheme.textColor),
            decoration: InputDecoration(
              hintText: '更具体地描述你的外貌偏好...\n例如：喜欢留长发、眼睛大、气质好的',
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('保存外貌偏好'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saveAppearance,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 3：理想对象 ────────────────────────────────────
  Widget _buildIdealPartnerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.pink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.pink.withOpacity(0.3)),
            ),
            child: const Text(
              '💡 用自然语言描述你想找的人，越详细越好。AI 会用这段描述来帮你匹配。',
              style: TextStyle(color: Colors.pink, fontSize: 13, height: 1.6),
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('💝 我想找的人是…'),
          const SizedBox(height: 10),

          TextField(
            controller: _idealPartnerController,
            maxLines: 8,
            style: const TextStyle(color: AppTheme.textColor, height: 1.6),
            decoration: InputDecoration(
              hintText: '例如：\n性格温柔有耐心，喜欢安静的生活，有自己的爱好和目标。平时喜欢看书或者看电影，不喜欢太吵闹的场合。能接受我内向的一面，不需要每天都见面...',
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.favorite),
              label: const Text('保存'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saveIdealPartner,
            ),
          ),

          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🗺️ 下一步',
                    style: TextStyle(
                        color: AppTheme.textColor,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  '保存后回到「我的资料」，点击「发布档案」即可与其他用户匹配，并可开始私聊。',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 4：匹配列表 ────────────────────────────────────
  Widget _buildMatchesTab() {
    return RefreshIndicator(
      onRefresh: _loadMatches,
      color: Colors.pink,
      child: _loadingMatches
          ? const Center(
              child: CircularProgressIndicator(color: Colors.pink),
            )
          : _matches.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: 300,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('还没有匹配用户',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pink,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _loadMatches,
                              child: const Text('刷新'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _matches.length,
                  itemBuilder: (_, i) => _buildMatchCard(_matches[i]),
                ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final theirId = match['device_id'] as String? ?? '';
    final summary = match['personality_summary'] as String? ?? '';
    final traitsRaw = match['traits'] as String? ?? '[]';
    final photoB64 = match['photo_base64'] as String?;

    List<String> traits = [];
    try {
      traits = List<String>.from(jsonDecode(traitsRaw) as List);
    } catch (_) {}

    Uint8List? photoBytes;
    if (photoB64 != null && photoB64.isNotEmpty) {
      try {
        photoBytes = base64Decode(photoB64);
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () {
        if (_deviceId == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              myId: _deviceId!,
              theirId: theirId,
              theirSummary: summary,
              theirPhotoBase64: photoB64,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.pink.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.pink.withOpacity(0.15),
              backgroundImage:
                  photoBytes != null ? MemoryImage(photoBytes) : null,
              child: photoBytes == null
                  ? const Icon(Icons.person, color: Colors.pink, size: 28)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.isNotEmpty ? '"$summary"' : '神秘用户',
                    style: const TextStyle(
                        color: AppTheme.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (traits.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: traits
                          .take(3)
                          .map((t) => _chip(t, Colors.pink))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  // ── 通用组件 ──────────────────────────────────────────
  Widget _buildProfileCard(PersonalityProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.pink.withOpacity(0.12),
            Colors.purple.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.pink.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('"${profile.summary}"',
              style: const TextStyle(
                  color: AppTheme.textColor,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  height: 1.5)),
          const SizedBox(height: 14),
          _sectionLabel('性格特征'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children:
                profile.traits.map((t) => _chip(t, Colors.pink)).toList(),
          ),
          const SizedBox(height: 12),
          _sectionLabel('兴趣爱好'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: profile.interests
                .map((t) => _chip(t, Colors.purple))
                .toList(),
          ),
          const SizedBox(height: 12),
          _infoRow('💬', '沟通风格', profile.communicationStyle),
          const SizedBox(height: 6),
          _infoRow('💎', '核心价值观', profile.values),
        ],
      ),
    );
  }

  Widget _buildRoadmap() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🗺️ 功能路线图',
              style: TextStyle(
                  color: AppTheme.textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _roadmapItem('✅', '性格分析'),
          _roadmapItem('✅', '头像上传'),
          _roadmapItem('✅', '外貌偏好 + 理想对象'),
          _roadmapItem('✅', '与其他用户匹配'),
          _roadmapItem('✅', '私聊功能'),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Text(
        text,
        style: const TextStyle(
            color: AppTheme.textColor,
            fontSize: 15,
            fontWeight: FontWeight.bold),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500),
      );

  Widget _chip(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 12)),
      );

  Widget _infoRow(String emoji, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji ', style: const TextStyle(fontSize: 13)),
          Text('$label：',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppTheme.textColor, fontSize: 13)),
          ),
        ],
      );

  Widget _roadmapItem(String icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text('$icon  $text',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13)),
      );
}
