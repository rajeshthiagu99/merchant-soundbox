import 'payment_event.dart';

enum AuditOutcome { announced, duplicate, uncertain, unsupported }

class AuditEntry {
  final PaymentEvent event;
  final AuditOutcome outcome;
  const AuditEntry(this.event, this.outcome);
}

class AuditLedger {
  final Duration dedupeWindow;
  final Map<String, DateTime> _seen = {};
  final List<AuditEntry> entries = [];
  AuditLedger({this.dedupeWindow = const Duration(minutes: 5)});

  AuditOutcome record(PaymentEvent event) {
    if (event.confidence == ParseConfidence.unsupported) {
      return _add(event, AuditOutcome.unsupported);
    }
    if (event.confidence != ParseConfidence.confirmed) {
      return _add(event, AuditOutcome.uncertain);
    }
    _seen.removeWhere(
      (_, at) => event.observedAt.difference(at) > dedupeWindow,
    );
    final prior = _seen[event.dedupeKey];
    if (prior != null && event.observedAt.difference(prior) <= dedupeWindow) {
      return _add(event, AuditOutcome.duplicate);
    }
    _seen[event.dedupeKey] = event.observedAt;
    return _add(event, AuditOutcome.announced);
  }

  AuditOutcome _add(PaymentEvent event, AuditOutcome outcome) {
    entries.add(AuditEntry(event, outcome));
    return outcome;
  }
}
