import 'payment_event.dart';

enum AnnouncementLanguage { english, hindi, tamil }

extension AnnouncementLanguageText on AnnouncementLanguage {
  String get tag => switch (this) {
    AnnouncementLanguage.english => 'en-IN',
    AnnouncementLanguage.hindi => 'hi-IN',
    AnnouncementLanguage.tamil => 'ta-IN',
  };
  String get label => switch (this) {
    AnnouncementLanguage.english => 'English',
    AnnouncementLanguage.hindi => 'Hindi',
    AnnouncementLanguage.tamil => 'Tamil',
  };
}

class AnnouncementFormatter {
  const AnnouncementFormatter();
  String confirmed(PaymentEvent event, AnnouncementLanguage language) {
    final amount = _amount(event.amountPaise);
    return switch (language) {
      AnnouncementLanguage.english => 'Payment received. $amount rupees.',
      AnnouncementLanguage.hindi => 'भुगतान मिला। $amount रुपये।',
      AnnouncementLanguage.tamil => 'பணம் வந்தது. $amount ரூபாய்.',
    };
  }

  String _amount(int paise) {
    if (paise % 100 == 0) return '${paise ~/ 100}';
    return (paise / 100).toStringAsFixed(2);
  }
}
