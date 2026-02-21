class Message {
  final String id;
  final String conversationId;
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final String? imageBase64;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.imageBase64,
    required this.createdAt,
  });

  Message copyWith({
    String? id,
    String? conversationId,
    String? role,
    String? content,
    String? imageBase64,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      imageBase64: imageBase64 ?? this.imageBase64,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'role': role,
        'content': content,
        'imageBase64': imageBase64,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        imageBase64: json['imageBase64'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
