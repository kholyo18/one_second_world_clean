// ===================== main.dart (Part 1/3) =====================
// ملاحظات:
// - تم إصلاح أخطاء التيرمنال بنقل جميع import إلى أعلى الملف.
// - لاحقًا عند التنقّل استخدمت FavoritesScreen() بدون const.
// - بقية الأسطر كما هي قدر الإمكان.

// -------------------- Imports (كلها في الأعلى) --------------------
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as thumb;
import 'package:video_compress/video_compress.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';

// ⚠️ تمت إزالة استيراد wallet/wallet_page.dart لأنه غير موجود.
// سنضيف WalletPage داخل هذا الملف في الجزء (2/3).

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final cams = await availableCameras();
  VideoCompress.setLogLevel(0);
  runApp(AppRoot(cameras: cams));
}

class AppRoot extends StatefulWidget {
  final List<CameraDescription> cameras;
  const AppRoot({super.key, required this.cameras});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _isDark = false;
  bool _loaded = false;
  Locale _locale = const Locale('ar');

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDark = prefs.getBool('isDark') ?? false;
      _locale = Locale(prefs.getString('lang') ?? 'ar');
      _loaded = true;
    });
  }

  Future<void> _setTheme(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', v);
    setState(() => _isDark = v);
  }

  Future<void> _setLocale(Locale v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', v.languageCode);
    setState(() => _locale = v);
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6), brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: GoogleFonts.cairoTextTheme(),
      scaffoldBackgroundColor:
          brightness == Brightness.dark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.cairo(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: scheme.onBackground,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'One Second World',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      supportedLocales: const [Locale('ar'), Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: _locale,
      home: AuthGate(
        cameras: widget.cameras,
        onThemeChanged: _setTheme,
        onLocaleChanged: _setLocale,
      ),
    );
  }
}

/// AuthGate: يوجه حسب حالة المصادقة
class AuthGate extends StatelessWidget {
  final List<CameraDescription> cameras;
  final ValueChanged<bool>? onThemeChanged;
  final ValueChanged<Locale>? onLocaleChanged;
  const AuthGate({
    super.key,
    required this.cameras,
    this.onThemeChanged,
    this.onLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const SignInScreen();
        return RecordScreen(
          cameras: cameras,
          onThemeChanged: onThemeChanged,
          onLocaleChanged: onLocaleChanged,
        );
      },
    );
  }
}

/// =======================
/// شاشة تسجيل الدخول (Google + بريد + هاتف)
/// =======================
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      setState(() => _error = 'فشل تسجيل الدخول: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_rounded, size: 72),
                  const SizedBox(height: 16),
                  Text('One Second World',
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'سجّل ثانية من حياتك كل يوم واحتفظ بذكرياتك 🌍',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                    ),
                  FilledButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    icon: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login),
                    label: Text(_loading ? 'جاري تسجيل الدخول...' : 'تسجيل الدخول باستخدام Google'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.alternate_email),
                    label: const Text('تسجيل بالبريد / إنشاء حساب'),
                    onPressed: _loading
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => EmailAuthScreen()),
                            ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.phone_iphone),
                    label: const Text('تسجيل برقم الهاتف'),
                    onPressed: _loading
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PhoneAuthScreen()),
                            ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'بتسجيل الدخول، ستُزامن سجلاتك مع حسابك الشخصي.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =======================
/// شاشة الإعدادات (زر يعمل + إعدادات مهمة)
/// =======================
class SettingsScreen extends StatefulWidget {
  final bool isDark;
  const SettingsScreen({super.key, required this.isDark});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ✅ لا نستخدم widget في مُهيّئات مباشرة
  late bool _dark;

  @override
  void initState() {
    super.initState();
    _dark = widget.isDark;
  }

  Future<void> _signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل الخروج بنجاح ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            ListTile(
              leading: CircleAvatar(
                radius: 28,
                backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child: user.photoURL == null ? const Icon(Icons.person, size: 32) : null,
              ),
              title: Text(user.displayName ?? user.email ?? 'حسابي'),
              subtitle: Text(user.email ?? ''),
            ),
          const Divider(),
          SwitchListTile(
            title: const Text('الوضع الداكن'),
            value: _dark,
            onChanged: (v) => setState(() => _dark = v),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('اللغة'),
            subtitle: const Text('العربية / Français / English'),
            onTap: () async {
              final code = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
              );
              if (code != null) {
                (context.findAncestorStateOfType<_AppRootState>())?._setLocale(Locale(code));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('معلومات شخصية'),
            subtitle: const Text('الاسم، الصورة، البريد'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('تغيير كلمة المرور'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('المحفظة (الكوينز)'),
            subtitle: const Text('اشترِ كوينز وادعم المقاطع'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('عن التطبيق'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('حفظ الإعدادات'),
            onPressed: () => Navigator.pop<bool>(context, _dark),
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
// ===================== نهاية الجزء 1/3 =====================
// ===================== main.dart (Part 2/3) =====================

// ملاحظة: لا تضف أي import في هذا الجزء. الاستيرادات كلها بالأعلى في الجزء 1.

/// أدوات مشتركة لتحميل فيديوهات الذكريات من التخزين المحلي
Future<List<File>> loadLocalVideos() async {
  final dir = await getApplicationDocumentsDirectory();
  final files = <File>[];
  if (!await dir.exists()) return files;

  final yearDirs = dir
      .listSync()
      .whereType<Directory>()
      .where((d) =>
          RegExp(r'^\d{4}$').hasMatch(d.path.split(Platform.pathSeparator).last))
      .toList();

  for (final y in yearDirs) {
    for (final m in y.listSync().whereType<Directory>()) {
      for (final f in m.listSync()) {
        if (f.path.endsWith('.mp4')) files.add(File(f.path));
      }
    }
  }
  files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return files;
}

String prettyDateFromFile(File f) {
  final name = f.uri.pathSegments.last;
  final reg = RegExp(r'one_sec_(.*)\.mp4');
  final match = reg.firstMatch(name);
  if (match == null) return name;
  final date = match.group(1)!.replaceAll('-', ':');
  try {
    final dt = DateTime.parse(date);
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  } catch (_) {
    return name;
  }
}

/// =======================
/// صفحة المحفظة (WalletPage) — شراء الكوينز مع تحويل فوري للدولار
/// =======================
class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  // سعر تقريبي: كل 1 كوين = 0.01$ (100 كوين = 1$)
  static const double usdPerCoin = 0.01;

  final TextEditingController _customCoinsCtrl = TextEditingController(text: '100');
  int _balance = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _balance = p.getInt('wallet_balance') ?? 0);
  }

  Future<void> _saveBalance(int v) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('wallet_balance', v);
    setState(() => _balance = v);
  }

  double _priceForCoins(int coins) => coins * usdPerCoin;

  Future<void> _fakePurchase(int coins) async {
    // محاكاة عملية شراء ناجحة
    await Future.delayed(const Duration(milliseconds: 600));
    await _saveBalance(_balance + coins);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم شراء $coins كوينز ✅')),
    );
  }

  Widget _packCard(int coins, {String? tag}) {
    final price = _priceForCoins(coins);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tag != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(tag, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 6),
            Text('$coins كوينز', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('\$${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => _fakePurchase(coins),
              child: const Text('شراء الآن'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    int customCoins = int.tryParse(_customCoinsCtrl.text) ?? 0;
    if (customCoins < 0) customCoins = 0;
    final customPrice = _priceForCoins(customCoins);

    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة (الكوينز)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الرصيد الحالي', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('$_balance كوينز',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _saveBalance(0),
                  icon: const Icon(Icons.refresh),
                  label: const Text('تصفير'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // باقات سريعة
          const Text('باقات سريعة', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _packCard(100, tag: 'شائع')),
              const SizedBox(width: 8),
              Expanded(child: _packCard(500)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _packCard(1000, tag: 'أفضل قيمة')),
              const SizedBox(width: 8),
              Expanded(child: _packCard(2500)),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // إدخال يدوي
          const Text('إدخال يدوي', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customCoinsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد الكوينز',
                    prefixIcon: Icon(Icons.numbers),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('\$${customPrice.toStringAsFixed(2)}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: customCoins > 0 ? () => _fakePurchase(customCoins) : null,
            icon: const Icon(Icons.shopping_cart_checkout_rounded),
            label: const Text('شراء الآن'),
          ),

          const SizedBox(height: 24),
          Text(
            'ملاحظة: عملية الشراء هنا محاكاة تجريبية بدون بوابة دفع. '
            'يمكن ربط مزود دفع لاحقًا (Stripe/PayPal) لإتمام الشراء الحقيقي.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// شاشة "ذكرياتي" (شبكة + مشاركة مع ضغط)
/// =======================
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  late Future<List<File>> _future;

  @override
  void initState() {
    super.initState();
    _future = loadLocalVideos();
  }

  Future<void> _refresh() async {
    setState(() => _future = loadLocalVideos());
  }

  Future<Uint8List?> _makeThumbnail(String path) async {
    try {
      return await thumb.VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: thumb.ImageFormat.JPEG,
        maxWidth: 300,
        quality: 75,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareCompressed(File original) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري ضغط الفيديو...'),
            ],
          ),
        ),
      ),
    );

    final before = await original.length();
    final info = await VideoCompress.compressVideo(
      original.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );

    if (context.mounted) Navigator.pop(context);

    final compressed = info?.file;
    if (compressed == null || !await compressed.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر الضغط. سنشارك النسخة الأصلية.')),
      );
      final xfile = XFile(original.path, mimeType: 'video/mp4');
      await Share.shareXFiles(
        [xfile],
        text: '🎬 ثانية من حياتي #One Second World',
        subject: 'One Second World',
      );
      return;
    }

    final after = await compressed.length();
    final savedKB =
        ((before - after) / 1024).clamp(0, double.infinity).toStringAsFixed(0);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('تم الضغط ✅ توفير ~${savedKB}KB')));

    final xfile = XFile(compressed.path, mimeType: 'video/mp4');
    await Share.shareXFiles(
      [xfile],
      text: '🎬 ثانية من حياتي #One Second World',
      subject: 'One Second World',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('ذكرياتي')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<File>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return const Center(
                child: Text('لا توجد ذكريات بعد.\nسجّل ثانية اليوم!'),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 9 / 16,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final file = items[i];
                return FutureBuilder<Uint8List?>(
                  future: _makeThumbnail(file.path),
                  builder: (context, tSnap) {
                    final thumbBytes = tSnap.data;
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PreviewScreen(videoFile: file),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: cs.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cs.outlineVariant),
                              image: thumbBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(thumbBytes),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: thumbBytes == null
                                ? const Center(
                                    child: Icon(Icons.videocam, size: 28),
                                  )
                                : null,
                          ),
                          Positioned(
                            left: 6,
                            right: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.play_arrow_rounded,
                                      size: 16, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      prettyDateFromFile(file),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _shareCompressed(file),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.45),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.ios_share,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                                _FavoriteButtonOverlay(file: file),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// زر حفظ للمفضلة صغير يُستخدم في بطاقات الشبكة
class _FavoriteButtonOverlay extends StatefulWidget {
  final File file;
  const _FavoriteButtonOverlay({required this.file});

  @override
  State<_FavoriteButtonOverlay> createState() => _FavoriteButtonOverlayState();
}

class _FavoriteButtonOverlayState extends State<_FavoriteButtonOverlay> {
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    FavoritesManager.isFavorite(widget.file.path).then((v) {
      if (mounted) setState(() => _isFav = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final newVal = await FavoritesManager.toggleFavorite(widget.file.path);
        if (!mounted) return;
        setState(() => _isFav = newVal);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newVal ? 'أُضيفت للمفضلة' : 'أُزيلت من المفضلة')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _isFav ? Icons.favorite : Icons.favorite_border,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// =======================
/// شاشة المعاينة + مشاركة بعد الضغط
/// =======================
class PreviewScreen extends StatefulWidget {
  final File videoFile;
  const PreviewScreen({super.key, required this.videoFile});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late VideoPlayerController _player;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _player = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _player.setLooping(true);
        _player.play();
      });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<File?> _compressVideo(File input) async {
    try {
      final info = await VideoCompress.compressVideo(
        input.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      return info?.file;
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareCompressed(File original) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري ضغط الفيديو...'),
            ],
          ),
        ),
      ),
    );

    final before = await original.length();
    final compressed = await _compressVideo(original);
    if (mounted) Navigator.pop(context);

    if (compressed == null || !await compressed.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر الضغط. سنشارك النسخة الأصلية.')),
      );
      final xfile = XFile(original.path, mimeType: 'video/mp4');
      await Share.shareXFiles(
        [xfile],
        text: '🎬 ثانية من حياتي #One Second World',
        subject: 'One Second World',
      );
      return;
    }

    final after = await compressed.length();
    final savedKB =
        ((before - after) / 1024).clamp(0, double.infinity).toStringAsFixed(0);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('تم الضغط ✅ توفير ~${savedKB}KB')));

    final xfile = XFile(compressed.path, mimeType: 'video/mp4');
    await Share.shareXFiles(
      [xfile],
      text: '🎬 ثانية من حياتي #One Second World',
      subject: 'One Second World',
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.videoFile.path.split(Platform.pathSeparator).last;
    return Scaffold(
      appBar: AppBar(
        title: Text('معاينة: $name'),
        actions: [
          IconButton(
            tooltip: 'مشاركة (مع ضغط)',
            onPressed: () => _shareCompressed(widget.videoFile),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: Center(
        child: _ready
            ? AspectRatio(
                aspectRatio: _player.value.aspectRatio,
                child: VideoPlayer(_player),
              )
            : const CircularProgressIndicator(),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.repeat),
                  label: const Text('إعادة التصوير'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم الحفظ محليًا ✅')),
                    );
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('تم'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// إدارة المفضلة محليًا
/// =======================
class FavoritesManager {
  static const _key = 'favorites';

  static Future<List<String>> _get() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_key) ?? [];
  }

  static Future<bool> isFavorite(String path) async {
    final list = await _get();
    return list.contains(path);
  }

  static Future<void> add(String path) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_key) ?? [];
    if (!list.contains(path)) {
      list.add(path);
      await p.setStringList(_key, list);
    }
  }

  static Future<void> remove(String path) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_key) ?? [];
    list.remove(path);
    await p.setStringList(_key, list);
  }

  static Future<bool> toggleFavorite(String path) async {
    final fav = await isFavorite(path);
    if (fav) {
      await remove(path);
      return false;
    } else {
      await add(path);
      return true;
    }
  }

  static Future<List<File>> allFiles() async {
    final paths = await _get();
    final files = <File>[];
    for (final pth in paths) {
      final f = File(pth);
      if (await f.exists()) files.add(f);
    }
    return files;
  }
}

/// =======================
/// شاشة التصفّح
/// =======================
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<File>> _future;
  final PageController _pageCtl = PageController();

  @override
  void initState() {
    super.initState();
    _future = loadLocalVideos();
  }

  @override
  void dispose() {
    _pageCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تصفّح'),
        actions: [
          IconButton(
            tooltip: 'المفضلة',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
            icon: const Icon(Icons.favorite_outline),
          ),
        ],
      ),
      body: FutureBuilder<List<File>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('لا توجد فيديوهات محليًا بعد.'));
          }
          return PageView.builder(
            controller: _pageCtl,
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final f = items[i];
              return _FeedVideoPage(
                file: f,
                onDragUp: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(filePath: f.path),
                    ),
                  );
                },
                onDragDown: () async {
                  final nowFav = await FavoritesManager.toggleFavorite(f.path);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            nowFav ? 'حُفِظ في المفضلة' : 'أزيل من المفضلة')),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FeedVideoPage extends StatefulWidget {
  final File file;
  final VoidCallback onDragUp;
  final VoidCallback onDragDown;

  const _FeedVideoPage({
    required this.file,
    required this.onDragUp,
    required this.onDragDown,
  });

  @override
  State<_FeedVideoPage> createState() => _FeedVideoPageState();
}

class _FeedVideoPageState extends State<_FeedVideoPage>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _ctl;
  bool _ready = false;
  double _accumDy = 0;
  late final AnimationController _slideHint;

  @override
  void initState() {
    super.initState();
    _ctl = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _ctl.setLooping(true);
        _ctl.play();
      });
    _slideHint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0,
      upperBound: 8,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _slideHint.dispose();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        if (_ctl.value.isPlaying) {
          _ctl.pause();
        } else {
          _ctl.play();
        }
        setState(() {});
      },
      onVerticalDragUpdate: (d) {
        _accumDy += d.primaryDelta ?? 0;
      },
      onVerticalDragEnd: (_) {
        if (_accumDy > 60) {
          widget.onDragDown(); // حفظ/نزول
        } else if (_accumDy < -60) {
          widget.onDragUp(); // فتح بروفايل
        }
        _accumDy = 0;
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: _ready
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _ctl.value.size.width,
                      height: _ctl.value.size.height,
                      child: VideoPlayer(_ctl),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          // ترويسة بسيطة (تاريخ + حفظ للمفضلة)
          Positioned(
            left: 12,
            bottom: 18,
            right: 12,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    prettyDateFromFile(widget.file),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const Spacer(),
                FutureBuilder<bool>(
                  future: FavoritesManager.isFavorite(widget.file.path),
                  builder: (_, favSnap) {
                    final fav = favSnap.data ?? false;
                    return InkWell(
                      onTap: () async {
                        final nowFav =
                            await FavoritesManager.toggleFavorite(widget.file.path);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                nowFav ? 'حُفِظ في المفضلة' : 'أزيل من المفضلة'),
                          ),
                        );
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(
                          fav ? Icons.favorite : Icons.favorite_border,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // تلميحة السحب
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _slideHint,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, -_slideHint.value),
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'اسحب لأعلى لزيارة الناشر — لأسفل للحفظ',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// شاشة المفضّلة
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<File>> _future;

  @override
  void initState() {
    super.initState();
    _future = FavoritesManager.allFiles();
  }

  Future<void> _refresh() async {
    setState(() => _future = FavoritesManager.allFiles());
  }

  Future<Uint8List?> _makeThumb(String path) async {
    try {
      return await thumb.VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: thumb.ImageFormat.JPEG,
        maxWidth: 300,
        quality: 75,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('المفضّلة')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<File>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return const Center(child: Text('لا توجد عناصر في المفضلة.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final f = items[i];
                return FutureBuilder<Uint8List?>(
                  future: _makeThumb(f.path),
                  builder: (context, tSnap) {
                    final bytes = tSnap.data;
                    return ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PreviewScreen(videoFile: f)),
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: bytes == null
                              ? Container(
                                  color: cs.surfaceVariant,
                                  child: const Icon(Icons.videocam),
                                )
                              : Image.memory(bytes, fit: BoxFit.cover),
                        ),
                      ),
                      title: Text(prettyDateFromFile(f)),
                      subtitle: Text(f.path.split(Platform.pathSeparator).last),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await FavoritesManager.remove(f.path);
                          if (!mounted) return;
                          _refresh();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('أزيل من المفضلة')),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ===================== نهاية الجزء 2/3 =====================
// ===================== نهاية الجزء 2/3 =====================
// ===================== main.dart (Part 3/3) =====================

/// =======================
/// بروفايل بسيط يُستدعى بالسحب للأعلى من صفحة التصفّح
/// =======================
class UserProfileScreen extends StatelessWidget {
  final String filePath; // نستعمله لاشتقاق اسم المستخدم تجريبياً
  const UserProfileScreen({super.key, required this.filePath});

  String _fakeUserFromPath() {
    final base = filePath.split(Platform.pathSeparator).last;
    final name = base.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (name.isEmpty) return 'user_onesec';
    return name.toLowerCase().substring(0, name.length.clamp(1, 10));
  }

  @override
  Widget build(BuildContext context) {
    final user = _fakeUserFromPath();
    return Scaffold(
      appBar: AppBar(title: Text('@$user')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 28, child: Icon(Icons.person)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@$user', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Text('منشئ محتوى — ثانية من كل يوم'),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم المتابعة ✅ (تجريبي)')),
                  );
                },
                child: const Text('متابعة'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'عنّي',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'أشارك ثانية من يومي على One Second World. تابعني لمزيد من اللحظات القصيرة!',
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('مشاركة الملف الأصلي'),
            onTap: () async {
              final x = XFile(filePath, mimeType: 'video/mp4');
              await Share.shareXFiles([x], text: 'من @$user');
            },
          ),
        ],
      ),
    );
  }
}

/// =======================
/// شاشة التسجيل (تسجيل ثانية/فيديو قصير) وحفظها محليًا
/// =======================
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isRecording = false;
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await ctrl.initialize();
      if (!mounted) return;
      setState(() => _controller = ctrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر فتح الكاميرا: $e')),
      );
    }
  }

  Future<Directory> _ensureMemoriesDir(DateTime now) async {
    final base = await getApplicationDocumentsDirectory();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final dir = Directory(
        '${base.path}${Platform.pathSeparator}$year${Platform.pathSeparator}$month');
    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _moveToMemories(String tmpPath, DateTime now) async {
    final dir = await _ensureMemoriesDir(now);
    final stamp =
        '${now.toIso8601String().split(".").first.replaceAll(":", "-")}';
    final dest = File(
        '${dir.path}${Platform.pathSeparator}one_sec_${stamp}.mp4');
    return File(tmpPath).rename(dest.path);
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isRecording) return;
    try {
      await _controller!.prepareForVideoRecording();
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _seconds = 0;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _seconds++);
        // تسجيل قصير (1–3 ثوانٍ)
        if (_seconds >= 3) _stopRecording(auto: true);
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل بدء التسجيل: $e')));
    }
  }

  Future<void> _stopRecording({bool auto = false}) async {
    if (_controller == null || !_controller!.value.isRecordingVideo) return;
    try {
      _timer?.cancel();
      final file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);

      // انقل إلى مجلد الذكريات بالصيغة المطلوبة
      final saved = await _moveToMemories(file.path, DateTime.now());
      if (!mounted) return;

      // بعد الحفظ، اعرض المعاينة
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PreviewScreen(videoFile: saved),
        ),
      );
    } catch (e) {
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل إيقاف التسجيل: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller != null && _controller!.value.isInitialized;

    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل ثانية')),
      body: Center(
        child: AspectRatio(
          aspectRatio: ready ? _controller!.value.aspectRatio : 9 / 16,
          child: ready
              ? CameraPreview(_controller!)
              : const ColoredBox(
                  color: Colors.black12,
                  child: Center(child: CircularProgressIndicator()),
                ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !_isRecording && ready ? _startRecording : null,
                  icon: const Icon(Icons.fiber_manual_record),
                  label: const Text('ابدأ'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isRecording ? _stopRecording : null,
                  icon: const Icon(Icons.stop),
                  label: Text(_isRecording ? 'أوقف (${_seconds}s)' : 'أوقف'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== نهاية الجزء 3/3 =====================
