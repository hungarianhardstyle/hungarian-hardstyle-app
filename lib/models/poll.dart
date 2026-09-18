/// Kozvelemenykutatas - Kerdőív modell.
///
/// A kerdes, a valaszlehetosegek es az időablak a WordPress-bol erkezik. Az app
/// szandekosan nem szamolja ki az ablakot: a szerver a webhely időzonajaban
/// dont, es mar csak akkor ad vissza kerdőívet, ha az nyitva van.
class HuhsPollOption {
  const HuhsPollOption({required this.index, required this.label});

  /// A valasz indexe a szerver listajaban; ezt kell visszakuldeni szavazaskor.
  final int index;
  final String label;

  factory HuhsPollOption.fromJson(Map<String, dynamic> json) {
    return HuhsPollOption(
      index: int.tryParse('${json['index']}') ?? 0,
      label: (json['label'] ?? '').toString().trim(),
    );
  }
}

class HuhsPoll {
  const HuhsPoll({
    required this.id,
    required this.question,
    required this.options,
  });

  final int id;
  final String question;
  final List<HuhsPollOption> options;

  /// Null, ha nincs nyitott kerdőív, vagy ha a valasz ertelmezhetetlen.
  static HuhsPoll? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = int.tryParse('${json['id']}') ?? 0;
    final question = (json['question'] ?? '').toString().trim();
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions
              .whereType<Map>()
              .map((item) => HuhsPollOption.fromJson(Map<String, dynamic>.from(item)))
              .where((option) => option.label.isNotEmpty)
              .toList(growable: false)
        : const <HuhsPollOption>[];
    if (id <= 0 || question.isEmpty || options.length < 2) return null;
    return HuhsPoll(id: id, question: question, options: options);
  }
}
