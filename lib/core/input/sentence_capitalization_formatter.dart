import 'package:flutter/services.dart';

/// Keeps sentence starts capitalized for both physical and software keyboards.
class SentenceCapitalizationFormatter extends TextInputFormatter {
  const SentenceCapitalizationFormatter();

  static final _sentenceStart = RegExp(
    r'(^\s*|\.\s+)([a-záéíóöőúüű])',
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final formatted = newValue.text.replaceAllMapped(
      _sentenceStart,
      (match) => '${match.group(1)}${match.group(2)!.toUpperCase()}',
    );
    if (formatted == newValue.text) return newValue;
    return newValue.copyWith(text: formatted);
  }
}
