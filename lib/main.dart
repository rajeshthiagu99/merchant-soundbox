import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/announcement.dart';
import 'core/audit_ledger.dart';
import 'core/payment_event.dart';
import 'core/payment_parser.dart';
import 'core/soundbox_platform.dart';

const green = Color(0xff08795b),
    dark = Color(0xff101a16),
    cream = Color(0xfffffbf2),
    pale = Color(0xffdff4e9),
    muted = Color(0xff6d776f);
bool hasExactTrial(List<({int priceMicros, String period})> phases) =>
    phases.any((p) => p.priceMicros == 0 && p.period == 'P3D');
void main() => runApp(const SoundboxApp());
void ignoreLanguage(AnnouncementLanguage _) {}

class SoundboxApp extends StatelessWidget {
  const SoundboxApp({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Merchant UPI Soundbox',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      scaffoldBackgroundColor: cream,
      useMaterial3: true,
      fontFamily: 'NotoSans',
    ),
    home: const String.fromEnvironment('SCREEN') == 'paywall'
        ? Paywall(onUnlocked: ignore)
        : const String.fromEnvironment('SCREEN') == 'home'
        ? const Dashboard(preview: true)
        : const String.fromEnvironment('SCREEN') == 'language'
        ? _LanguageStep(onSelected: ignoreLanguage)
        : const Gate(),
  );
  static void ignore() {}
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool loading = true, unlocked = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted)
      setState(() {
        unlocked = p.getBool('premium') ?? false;
        loading = false;
      });
  }

  @override
  Widget build(c) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!unlocked)
      return Paywall(
        onUnlocked: () async {
          final p = await SharedPreferences.getInstance();
          await p.setBool('premium', true);
          if (mounted) setState(() => unlocked = true);
        },
      );
    return const Dashboard();
  }
}

class Paywall extends StatefulWidget {
  final VoidCallback onUnlocked;
  const Paywall({super.key, required this.onUnlocked});
  @override
  State<Paywall> createState() => _PaywallState();
}

class _PaywallState extends State<Paywall> {
  bool annual = true, busy = false;
  GooglePlayProductDetails? yearly, monthly;
  String? yearlyToken, monthlyToken;
  String yearlyPrice = '₹999', monthlyPrice = '₹200';
  late StreamSubscription<List<PurchaseDetails>> sub;
  @override
  void initState() {
    super.initState();
    if (const String.fromEnvironment('SCREEN') == 'paywall') {
      sub = const Stream<List<PurchaseDetails>>.empty().listen(_purchases);
    } else {
      sub = InAppPurchase.instance.purchaseStream.listen(_purchases);
      _load();
    }
  }

  Future<void> _load() async {
    if (!await InAppPurchase.instance.isAvailable()) return;
    final r = await InAppPurchase.instance.queryProductDetails({
      'merchant_soundbox_premium',
    });
    for (final p in r.productDetails.whereType<GooglePlayProductDetails>()) {
      final i = p.subscriptionIndex;
      if (i == null) continue;
      final o = p.productDetails.subscriptionOfferDetails![i];
      final phases = o.pricingPhases
          .map(
            (x) => (priceMicros: x.priceAmountMicros, period: x.billingPeriod),
          )
          .toList();
      if (!hasExactTrial(phases)) continue;
      final paid = o.pricingPhases.where((x) => x.priceAmountMicros > 0);
      if (paid.isEmpty) continue;
      if (o.basePlanId == 'annual' && paid.first.billingPeriod == 'P1Y') {
        yearly = p;
        yearlyToken = o.offerIdToken;
        yearlyPrice = paid.first.formattedPrice;
      }
      if (o.basePlanId == 'monthly' && paid.first.billingPeriod == 'P1M') {
        monthly = p;
        monthlyToken = o.offerIdToken;
        monthlyPrice = paid.first.formattedPrice;
      }
    }
    if (mounted) setState(() {});
  }

  void _purchases(List<PurchaseDetails> ps) {
    for (final p in ps) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored)
        widget.onUnlocked();
      if (p.pendingCompletePurchase) InAppPurchase.instance.completePurchase(p);
    }
  }

  Future<void> buy() async {
    final p = annual ? yearly : monthly,
        t = annual ? yearlyToken : monthlyToken;
    if (p == null || t == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The selected 3-day trial is unavailable. No purchase was started.',
            ),
          ),
        );
      return;
    }
    setState(() => busy = true);
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: GooglePlayPurchaseParam(productDetails: p, offerToken: t),
    );
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(c) => Scaffold(
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
            ),
            onPressed: busy ? null : buy,
            child: Text(
              busy ? 'Opening Google Play…' : 'Start my 3-day free trial',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            annual
                ? 'Then $yearlyPrice/year. Cancel anytime in Google Play.'
                : 'Then $monthlyPrice/month. Cancel anytime in Google Play.',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Brand(),
          const SizedBox(height: 44),
          const Icon(Icons.volume_up_rounded, size: 70, color: green),
          const SizedBox(height: 18),
          const Text(
            'Hear every confirmed payment.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your phone announces the amount while you serve the next customer.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, color: muted),
          ),
          const SizedBox(height: 30),
          for (final x in [
            'Confirmed UPI amounts aloud',
            'English, Hindi and Tamil',
            'On-device payment history',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: green),
                  const SizedBox(width: 12),
                  Text(
                    x,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          Plan(
            title: 'Annual',
            price: '$yearlyPrice / year',
            detail: 'Best value',
            selected: annual,
            onTap: () => setState(() => annual = true),
          ),
          const SizedBox(height: 10),
          Plan(
            title: 'Monthly',
            price: '$monthlyPrice / month',
            detail: 'Flexible billing',
            selected: !annual,
            onTap: () => setState(() => annual = false),
          ),
          const SizedBox(height: 12),
          const Text(
            'No charge today.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
          TextButton(
            onPressed: () => InAppPurchase.instance.restorePurchases(),
            child: const Text('Restore purchase'),
          ),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(
                'https://play.google.com/store/account/subscriptions?sku=merchant_soundbox_premium&package=com.rajesht.merchant_soundbox',
              ),
            ),
            child: const Text('Manage subscription'),
          ),
        ],
      ),
    ),
  );
}

class Plan extends StatelessWidget {
  final String title, price, detail;
  final bool selected;
  final VoidCallback onTap;
  const Plan({
    super.key,
    required this.title,
    required this.price,
    required this.detail,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(c) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: selected ? pale : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? green : Colors.black12,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 25,
                  ),
                ),
                Text(detail, style: const TextStyle(color: muted)),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: green,
          ),
        ],
      ),
    ),
  );
}

class Dashboard extends StatefulWidget {
  final bool preview;
  const Dashboard({super.key, this.preview = false});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  final platform = SoundboxPlatform(),
      parser = PaymentParser(),
      ledger = AuditLedger();
  StreamSubscription<PaymentNotification>? sub;
  bool checking = true, access = false;
  AnnouncementLanguage language = AnnouncementLanguage.english;
  PaymentEvent? latest;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.preview) {
      checking = false;
      access = true;
      latest = PaymentEvent(
        source: 'Google Pay',
        amountPaise: 50000,
        reference: 'preview',
        rawMasked: '',
        observedAt: DateTime.now(),
        confidence: ParseConfidence.confirmed,
      );
    } else {
      _check();
      sub = platform.notifications.listen(_on);
    }
  }

  Future<void> _check() async {
    final a = await platform.hasNotificationAccess();
    if (mounted)
      setState(() {
        access = a;
        checking = false;
      });
  }

  Future<void> _on(PaymentNotification n) async {
    final e = parser.parse(n);
    if (ledger.record(e) != AuditOutcome.announced) return;
    if (mounted) setState(() => latest = e);
    await platform.announce(
      AnnouncementFormatter().confirmed(e, language),
      language: language.tag,
    );
  }

  @override
  void didChangeAppLifecycleState(s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(c) {
    if (checking)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!access) return _AccessStep(onOpen: platform.openNotificationAccess);
    return Scaffold(
      appBar: AppBar(
        title: const Brand(compact: true),
        backgroundColor: Colors.transparent,
        actions: [
          PopupMenuButton<AnnouncementLanguage>(
            initialValue: language,
            onSelected: (v) => setState(() => language = v),
            itemBuilder: (_) => AnnouncementLanguage.values
                .map((v) => PopupMenuItem(value: v, child: Text(v.label)))
                .toList(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            greeting(),
            style: const TextStyle(color: green, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your counter is listening.',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: pale,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                const Icon(Icons.volume_up_rounded, color: green, size: 54),
                const SizedBox(height: 14),
                Text(
                  latest == null
                      ? 'Ready for the next payment.'
                      : '₹${(latest!.amountPaise / 100).toStringAsFixed(latest!.amountPaise % 100 == 0 ? 0 : 2)} received',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  latest == null
                      ? 'Confirmed payments will appear here.'
                      : latest!.source,
                  style: const TextStyle(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Today',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Metric(
                  label: 'Payments',
                  value: latest == null ? '0' : '1',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Metric(
                  label: 'Received',
                  value: latest == null
                      ? '₹0'
                      : '₹${(latest!.amountPaise / 100).round()}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shield_outlined, color: green),
              title: const Text('Notification access'),
              subtitle: Text(access ? 'Connected' : 'Needs access'),
              trailing: const Icon(Icons.chevron_right),
              onTap: platform.openNotificationAccess,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language, color: green),
              title: const Text('Announcement voice'),
              subtitle: Text(language.label),
            ),
          ),
        ],
      ),
    );
  }

  String greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'GOOD MORNING'
        : h < 17
        ? 'GOOD AFTERNOON'
        : 'GOOD EVENING';
  }
}

class Metric extends StatelessWidget {
  final String label, value;
  const Metric({super.key, required this.label, required this.value});
  @override
  Widget build(c) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.black12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: muted)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class Brand extends StatelessWidget {
  final bool compact;
  const Brand({super.key, this.compact = false});
  @override
  Widget build(c) => Row(
    mainAxisAlignment: compact
        ? MainAxisAlignment.start
        : MainAxisAlignment.center,
    mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
    children: [
      Container(
        width: compact ? 34 : 44,
        height: compact ? 34 : 44,
        decoration: BoxDecoration(
          color: green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.volume_up_rounded, color: Colors.white),
      ),
      const SizedBox(width: 10),
      Text(
        'Merchant UPI Soundbox',
        style: TextStyle(
          fontSize: compact ? 18 : 21,
          fontWeight: FontWeight.w900,
          color: dark,
        ),
      ),
    ],
  );
}

class _AccessStep extends StatelessWidget {
  final Future<void> Function() onOpen;
  const _AccessStep({required this.onOpen});
  @override
  Widget build(c) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Brand(),
            const Spacer(),
            const Icon(
              Icons.notifications_active_outlined,
              size: 64,
              color: green,
            ),
            const SizedBox(height: 22),
            const Text(
              'Hear every confirmed UPI payment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 26),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: onOpen,
              child: const Text('Allow notification access'),
            ),
            const Spacer(),
          ],
        ),
      ),
    ),
  );
}

class _LanguageStep extends StatelessWidget {
  final ValueChanged<AnnouncementLanguage> onSelected;
  const _LanguageStep({required this.onSelected});
  @override
  Widget build(c) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose your voice.',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          for (final l in AnnouncementLanguage.values)
            FilledButton.tonal(
              onPressed: () => onSelected(l),
              child: Text(l.label),
            ),
        ],
      ),
    ),
  );
}
