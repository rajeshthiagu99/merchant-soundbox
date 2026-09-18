import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_soundbox/core/audit_ledger.dart';
import 'package:merchant_soundbox/core/payment_event.dart';

PaymentEvent event(
  DateTime t, {
  String? ref = 'abc12345',
  ParseConfidence confidence = ParseConfidence.confirmed,
}) => PaymentEvent(
  source: 'PhonePe',
  amountPaise: 5000,
  reference: ref,
  rawMasked: 'masked',
  observedAt: t,
  confidence: confidence,
);
void main() {
  test('same reference announces once inside dedupe window', () {
    final l = AuditLedger();
    final t = DateTime(2026, 9, 18, 5);
    expect(l.record(event(t)), AuditOutcome.announced);
    expect(
      l.record(event(t.add(const Duration(seconds: 20)))),
      AuditOutcome.duplicate,
    );
  });
  test('reference-free repeat dedupes in same 30-second bucket', () {
    final l = AuditLedger();
    final t = DateTime.fromMillisecondsSinceEpoch(180000);
    expect(l.record(event(t, ref: null)), AuditOutcome.announced);
    expect(
      l.record(event(t.add(const Duration(seconds: 5)), ref: null)),
      AuditOutcome.duplicate,
    );
  });
  test('uncertain input is logged but never announced', () {
    final l = AuditLedger();
    expect(
      l.record(event(DateTime.now(), confidence: ParseConfidence.uncertain)),
      AuditOutcome.uncertain,
    );
  });
}
