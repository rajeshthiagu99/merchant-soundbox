import 'dart:async';

import 'package:flutter/material.dart';

import 'core/announcement.dart';
import 'core/audit_ledger.dart';
import 'core/payment_event.dart';
import 'core/payment_parser.dart';
import 'core/soundbox_platform.dart';

void main() => runApp(const SoundboxApp());

void _ignoreLanguage(AnnouncementLanguage value) {}

class SoundboxApp extends StatelessWidget {
  const SoundboxApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'UPI Soundbox',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff076b4c)),
      scaffoldBackgroundColor: const Color(0xfff5f5ef),
      useMaterial3: true,
      fontFamily: 'NotoSans',
    ),
    home: const String.fromEnvironment('SCREEN') == 'ready'
        ? const _ReadyScreen(language: AnnouncementLanguage.english, lastPayment: null)
        : const String.fromEnvironment('SCREEN') == 'language'
            ? _LanguageStep(onSelected: _ignoreLanguage)
            : const SoundboxHome(),
  );
}

class SoundboxHome extends StatefulWidget {
  const SoundboxHome({super.key});
  @override
  State<SoundboxHome> createState() => _SoundboxHomeState();
}

class _SoundboxHomeState extends State<SoundboxHome>
    with WidgetsBindingObserver {
  final _platform = SoundboxPlatform();
  final _parser = PaymentParser();
  final _ledger = AuditLedger();
  final _formatter = AnnouncementFormatter();
  StreamSubscription<PaymentNotification>? _subscription;
  bool _hasAccess = false;
  bool _checking = true;
  AnnouncementLanguage? _language;
  PaymentEvent? _lastPayment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccess();
    _subscription = _platform.notifications.listen(_onNotification);
  }

  Future<void> _checkAccess() async {
    final access = await _platform.hasNotificationAccess();
    if (mounted) {
      setState(() {
        _hasAccess = access;
        _checking = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccess();
    }
  }

  Future<void> _onNotification(PaymentNotification notification) async {
    final event = _parser.parse(notification);
    final outcome = _ledger.record(event);
    if (outcome != AuditOutcome.announced || _language == null) {
      return;
    }
    setState(() => _lastPayment = event);
    await _platform.announce(
      _formatter.confirmed(event, _language!),
      language: _language!.tag,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasAccess) {
      return _AccessStep(onOpen: _platform.openNotificationAccess);
    }
    if (_language == null) {
      return _LanguageStep(
        onSelected: (value) => setState(() => _language = value),
      );
    }
    return _ReadyScreen(language: _language!, lastPayment: _lastPayment);
  }
}

class _AccessStep extends StatelessWidget {
  final Future<void> Function() onOpen;
  const _AccessStep({required this.onOpen});
  @override
  Widget build(BuildContext context) => _StepShell(
    icon: Icons.notifications_active_outlined,
    line: 'Hear every confirmed UPI payment.',
    button: 'Allow notification access',
    onPressed: onOpen,
  );
}

class _LanguageStep extends StatelessWidget {
  final ValueChanged<AnnouncementLanguage> onSelected;
  const _LanguageStep({required this.onSelected});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.volume_up_outlined,
              size: 56,
              color: Color(0xff076b4c),
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose the voice you understand.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 32),
            for (final language in AnnouncementLanguage.values) ...[
              FilledButton.tonal(
                onPressed: () => onSelected(language),
                child: Text(language.label),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ReadyScreen extends StatelessWidget {
  final AnnouncementLanguage language;
  final PaymentEvent? lastPayment;
  const _ReadyScreen({required this.language, required this.lastPayment});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xffdff4e9),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 58,
                    color: Color(0xff076b4c),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lastPayment == null
                        ? 'Ready for the next payment.'
                        : '₹${(lastPayment!.amountPaise / 100).toStringAsFixed(lastPayment!.amountPaise % 100 == 0 ? 0 : 2)} received',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Voice: ${language.label}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    ),
  );
}

class _StepShell extends StatelessWidget {
  final IconData icon;
  final String line;
  final String button;
  final Future<void> Function() onPressed;
  const _StepShell({
    required this.icon,
    required this.line,
    required this.button,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, size: 56, color: const Color(0xff076b4c)),
            const SizedBox(height: 24),
            Text(
              line,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: onPressed, child: Text(button)),
          ],
        ),
      ),
    ),
  );
}
