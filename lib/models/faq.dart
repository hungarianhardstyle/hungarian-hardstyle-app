class FaqItem {
  final int id;
  final String question;
  final String answer;
  final String category;
  final int order;

  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.order,
  });

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['order'];
    return FaqItem(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      question: (json['question'] ?? json['title'] ?? '').toString(),
      answer: (json['answer'] ?? json['content'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      order: rawOrder is num
          ? rawOrder.toInt()
          : int.tryParse('$rawOrder') ?? 0,
    );
  }
}
