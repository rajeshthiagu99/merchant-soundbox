import 'payment_event.dart';

class PaymentNotification {
  final String packageName;
  final String title;
  final String body;
  final DateTime observedAt;
  const PaymentNotification(
    this.packageName,
    this.title,
    this.body,
    this.observedAt,
  );
}

class PaymentParser {
  static const supportedPackages = {
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'com.phonepe.app': 'PhonePe',
    'net.one97.paytm': 'Paytm',
    'in.org.npci.upiapp': 'BHIM',
  };

  PaymentEvent parse(PaymentNotification input) {
    final source = supportedPackages[input.packageName];
    final masked = _mask('${input.title} ${input.body}');
    if (source == null) {
      return _event(
        'Unsupported',
        0,
        null,
        masked,
        input,
        ParseConfidence.unsupported,
      );
    }

    final text = '${input.title} ${input.body}'.replaceAll(
      RegExp(r'(?<=\d),(?=\d{3}(?:\D|$))'),
      '',
    );
    final amount = RegExp(
      r'(?:₹|Rs\.?|INR)\s*([0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    final positive = RegExp(
      r'\b(received|credited|payment received|money received|paid to you)\b',
      caseSensitive: false,
    ).hasMatch(text);
    final negative = RegExp(
      r'\b(failed|declined|requested|pending|sent|paid by you|debited|refunded)\b',
      caseSensitive: false,
    ).hasMatch(text);
    if (amount == null || !positive || negative) {
      return _event(source, 0, null, masked, input, ParseConfidence.uncertain);
    }

    final parsed = double.tryParse(amount.group(1)!);
    if (parsed == null || parsed <= 0 || parsed > 1000000) {
      return _event(source, 0, null, masked, input, ParseConfidence.uncertain);
    }
    final ref = RegExp(
      r'(?:UPI Ref(?:erence)?|UTR|Txn ID|transaction id)[: #\-]*([A-Za-z0-9]{6,35})',
      caseSensitive: false,
    ).firstMatch(text)?.group(1);
    return _event(
      source,
      (parsed * 100).round(),
      ref,
      masked,
      input,
      ParseConfidence.confirmed,
    );
  }

  PaymentEvent _event(
    String source,
    int amount,
    String? reference,
    String raw,
    PaymentNotification n,
    ParseConfidence c,
  ) => PaymentEvent(
    source: source,
    amountPaise: amount,
    reference: reference,
    rawMasked: raw,
    observedAt: n.observedAt,
    confidence: c,
  );

  String _mask(String value) => value
      .replaceAll(RegExp(r'\b\d{10}\b'), '••••••••••')
      .replaceAll(
        RegExp(r'(?:vpa|upi id)[: ]+[\w.\-]+@[\w]+', caseSensitive: false),
        'UPI ID: ••••',
      )
      .replaceAll(
        RegExp(
          r'(?:a/c|account)\s*(?:no\.?\s*)?[xX*\d]{4,}',
          caseSensitive: false,
        ),
        'account ••••',
      );
}
