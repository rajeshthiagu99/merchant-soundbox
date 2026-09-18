enum ParseConfidence { confirmed, uncertain, unsupported }

class PaymentEvent {
  final String source;
  final int amountPaise;
  final String? reference;
  final String rawMasked;
  final DateTime observedAt;
  final ParseConfidence confidence;

  const PaymentEvent({
    required this.source,
    required this.amountPaise,
    required this.reference,
    required this.rawMasked,
    required this.observedAt,
    required this.confidence,
  });

  String get dedupeKey => reference?.isNotEmpty == true
      ? '$source:${reference!.toLowerCase()}'
      : '$source:$amountPaise:${observedAt.millisecondsSinceEpoch ~/ 30000}';
}
