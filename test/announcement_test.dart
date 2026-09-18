import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_soundbox/core/announcement.dart';
import 'package:merchant_soundbox/core/payment_event.dart';

void main() {
  const formatter = AnnouncementFormatter();
  final event = PaymentEvent(
    source: 'PhonePe',
    amountPaise: 25050,
    reference: 'x',
    rawMasked: '',
    observedAt: DateTime(2026),
    confidence: ParseConfidence.confirmed,
  );
  test('formats exact amount in all supported voices', () {
    expect(
      formatter.confirmed(event, AnnouncementLanguage.english),
      'Payment received. 250.50 rupees.',
    );
    expect(
      formatter.confirmed(event, AnnouncementLanguage.hindi),
      'भुगतान मिला। 250.50 रुपये।',
    );
    expect(
      formatter.confirmed(event, AnnouncementLanguage.tamil),
      'பணம் வந்தது. 250.50 ரூபாய்.',
    );
  });
  test('drops paise decimals for whole rupees', () {
    final whole = PaymentEvent(
      source: 'Paytm',
      amountPaise: 20000,
      reference: null,
      rawMasked: '',
      observedAt: DateTime(2026),
      confidence: ParseConfidence.confirmed,
    );
    expect(
      formatter.confirmed(whole, AnnouncementLanguage.english),
      'Payment received. 200 rupees.',
    );
  });
}
