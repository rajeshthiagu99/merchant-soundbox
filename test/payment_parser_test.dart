import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_soundbox/core/payment_event.dart';
import 'package:merchant_soundbox/core/payment_parser.dart';

void main() {
  final parser = PaymentParser();
  final at = DateTime(2026, 9, 18, 5);
  test('confirms grounded incoming Google Pay amount', () {
    final e = parser.parse(
      PaymentNotification(
        'com.google.android.apps.nbu.paisa.user',
        'Payment received',
        'Received ₹250.50. UPI Ref: 123456789012',
        at,
      ),
    );
    expect(e.confidence, ParseConfidence.confirmed);
    expect(e.amountPaise, 25050);
    expect(e.reference, '123456789012');
  });
  test('confirms PhonePe incoming payment', () {
    final e = parser.parse(
      PaymentNotification(
        'com.phonepe.app',
        'Money received',
        'Rs. 1,200 received UTR 991122334455',
        at,
      ),
    );
    expect(e.confidence, ParseConfidence.confirmed);
    expect(e.amountPaise, 120000);
  });
  test(
    'never confirms outgoing, pending, failed, refund, or collect request',
    () {
      for (final text in [
        '₹50 sent',
        '₹50 payment pending',
        '₹50 failed',
        '₹50 refunded',
        '₹50 requested',
      ]) {
        expect(
          parser
              .parse(
                PaymentNotification(
                  'com.phonepe.app',
                  'Payment update',
                  text,
                  at,
                ),
              )
              .confidence,
          ParseConfidence.uncertain,
        );
      }
    },
  );
  test('unsupported source never announces', () {
    expect(
      parser
          .parse(
            PaymentNotification('random.app', 'Received', '₹999 received', at),
          )
          .confidence,
      ParseConfidence.unsupported,
    );
  });
  test('masks phone, VPA and account evidence', () {
    final e = parser.parse(
      PaymentNotification(
        'com.phonepe.app',
        'Received ₹1',
        'received from 9876543210 UPI ID: rajesh@okaxis account XX1234',
        at,
      ),
    );
    expect(e.rawMasked, isNot(contains('9876543210')));
    expect(e.rawMasked, isNot(contains('rajesh@okaxis')));
    expect(e.rawMasked, isNot(contains('XX1234')));
  });
}
