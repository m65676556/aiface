class Memory {
  final String id;
  final String content;
  final String category; // 'preference', 'fact', 'context'
  final DateTime createdAt;
  final int importance; // 1-5

  const Memory({
    required this.id,
    required this.content,
    required this.category,
    required this.createdAt,
    this.importance = 3,
  });
}
