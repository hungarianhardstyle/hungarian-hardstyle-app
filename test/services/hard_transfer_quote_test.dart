import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/hard_wallet_plan.dart';

void main() {
  test('a szerver-ajánlat feldolgozása', () {
    final quote = HardTransferQuote.fromMap({
      'transaction': 'AQID',
      'sender': 'SENDER',
      'recipient': 'RECIPIENT',
      'amount': '1.5',
    });
    expect(quote.transaction, 'AQID');
    expect(quote.sender, 'SENDER');
    expect(quote.recipient, 'RECIPIENT');
    expect(quote.amount, '1.5');
  });

  test('hiányos ajánlat hibát ad, nem üres tranzakciót', () {
    expect(
      () => HardTransferQuote.fromMap({'sender': 'S', 'recipient': 'R'}),
      throwsFormatException,
    );
  });
}
