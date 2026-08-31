import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/input/sentence_capitalization_formatter.dart';

void main() {
  const formatter = SentenceCapitalizationFormatter();

  test('a mondat elejét nagybetűvel kezdi', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: 'árnyék'),
    );

    expect(result.text, 'Árnyék');
  });

  test('pont és szóköz után nagybetűvel kezd', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: 'Első mondat. második mondat.'),
    );

    expect(result.text, 'Első mondat. Második mondat.');
  });
}
