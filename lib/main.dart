// ===================== main.dart (Part 1/3) =====================
// - تم جمع كل import في أعلى الملف (لا توجد import لاحقًا).
// - أبقيت بقية الأسطر كما هي إلا عند الحاجة للتصحيح الطفيف.
// - هذا الجزء: التمهيد + الثيم/اللغات + AuthGate + SignInScreen + RecordScreen.

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
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6),
      brightness: brightness,
    );
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

/// يوجه حسب حالة المصادقة
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

/// شاشة تسجيل الدخول
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
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.error),
                      ),
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
                        : () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmailAuthScreen())),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.phone_iphone),
                    label: const Text('تسجيل برقم الهاتف'),
                    onPressed: _loading
                        ? null
                        : () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhoneAuthScreen())),
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

/// شاشة التسجيل الرئيسية (تسجيل حتى 60 ثانية بالضغط المطوّل)
class RecordScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ValueChanged<bool>? onThemeChanged;
  final ValueChanged<Locale>? onLocaleChanged;

  const RecordScreen({
    super.key,
    required this.cameras,
    this.onThemeChanged,
    this.onLocaleChanged,
  });

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with SingleTickerProviderStateMixin {
  static final _scaffoldKey = GlobalKey<ScaffoldState>();

  CameraController? _controller;
  bool _initializing = true;
  bool _isRecording = false;
  bool _alreadyRecordedToday = false;
  bool _usingFront = false;
  bool _flashOn = false;

  double _progress = 0.0;
  Timer? _timer;
  final int _maxMs = 60000;
  int _elapsed = 0;

  late final AnimationController _pulse;
  String _mode = 'sec'; // 'text' | 'photo' | 'sec'

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.95,
      upperBound: 1.05,
    )..repeat(reverse: true);
    _initCamera();
    _checkRecordedToday();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() => _initializing = true);
    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    if (!camStatus.isGranted || !micStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى السماح بصلاحيات الكاميرا والمايك')),
        );
      }
      return;
    }
    final direction = _usingFront ? CameraLensDirection.front : CameraLensDirection.back;
    final cam = widget.cameras.firstWhere(
      (c) => c.lensDirection == direction,
      orElse: () => widget.cameras.first,
    );
    _controller = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    if (_flashOn) {
      try {
        await _controller!.setFlashMode(FlashMode.torch);
      } catch (_) {}
    }
    if (mounted) setState(() => _initializing = false);
  }

  void _toggleCamera() {
    setState(() => _usingFront = !_usingFront);
    _initCamera();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    try {
      _flashOn = !_flashOn;
      await _controller!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا يمكن تغيير الفلاش: $e')));
    }
  }

  Future<void> _checkRecordedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final savedDate = prefs.getString("lastRecordedDate");
    if (savedDate != null) {
      final lastDate = DateTime.tryParse(savedDate);
      if (lastDate != null &&
          lastDate.year == today.year &&
          lastDate.month == today.month &&
          lastDate.day == today.day) {
        setState(() => _alreadyRecordedToday = true);
      }
    }
  }

  Future<void> _saveRecordedDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("lastRecordedDate", DateTime.now().toIso8601String());
    setState(() => _alreadyRecordedToday = true);
  }

  Future<File> _moveToMemories(String srcPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final folder = Directory('${dir.path}/${now.year}/${now.month.toString().padLeft(2, '0')}');
    if (!await folder.exists()) await folder.create(recursive: true);
    final ts = now.toIso8601String().replaceAll(':', '-');
    final newPath = '${folder.path}/one_sec_$ts.mp4';
    return File(srcPath).copy(newPath);
  }

  Future<void> _startRecording() async {
    if (_controller == null || _initializing || _isRecording) return;
    try {
      await _controller!.prepareForVideoRecording();
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _progress = 0.0;
        _elapsed = 0;
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 16), (t) async {
        _elapsed += 16;
        final p = (_elapsed / _maxMs).clamp(0.0, 1.0);
        if (mounted) setState(() => _progress = p);
        if (_elapsed >= _maxMs) {
          t.cancel();
          await _stopRecording(auto: true);
        }
      });
    } catch (e) {
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء بدء التسجيل: $e')));
    }
  }

  Future<void> _stopRecording({bool auto = false}) async {
    if (_controller == null || !_isRecording) return;
    try {
      _timer?.cancel();
      final file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);

      final saved = await _moveToMemories(file.path);
      await _saveRecordedDate();

      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PreviewScreen(videoFile: saved),
      ));
    } catch (e) {
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر إنهاء التسجيل: $e')));
    }
  }

  Widget _buildMiniTab(String label, String value) {
    final selected = _mode == value;
    return InkWell(
      onTap: () => setState(() => _mode = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? Theme.of(context).colorScheme.secondaryContainer : Colors.black26,
        ),
        child: Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildRightRail(ColorScheme cs) {
    Widget item(IconData icon, String label, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(26)),
                child: Icon(icon, color: Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            item(Icons.cameraswitch_rounded, 'قلب', _toggleCamera),
            item(Icons.timer_outlined, 'مؤقت', () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المؤقت قادم قريبًا')));
            }),
            item(Icons.grid_view_rounded, 'شبكة', () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الشبكة قادمة قريبًا')));
            }),
            item(_flashOn ? Icons.flash_on : Icons.flash_off, 'فلاش', _toggleFlash),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureControls(ColorScheme cs) {
    final disabled = _alreadyRecordedToday;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _buildMiniTab('نص', 'text'),
              const SizedBox(width: 12),
              _buildMiniTab('صورة', 'photo'),
              const SizedBox(width: 12),
              _buildMiniTab('فيديو', 'sec'),
            ]),
            const SizedBox(height: 12),
            Center(
              child: ScaleTransition(
                scale: _isRecording ? _pulse : const AlwaysStoppedAnimation(1),
                child: GestureDetector(
                  onTapDown: (_mode != 'sec' || disabled) ? null : (_) => _startRecording(),
                  onTapUp: (_mode != 'sec' || disabled) ? null : (_) => _stopRecording(),
                  onTapCancel: (_mode != 'sec' || disabled) ? null : () => _stopRecording(),
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: disabled ? cs.surfaceVariant : (_isRecording ? cs.error : cs.primary),
                    ),
                    child: const Center(
                      child: Icon(Icons.videocam_rounded, size: 36, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_isRecording)
              LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: cs.surfaceVariant,
              ),
            const SizedBox(height: 8),
            Text(
              _isRecording
                  ? 'جارٍ التسجيل… ارفع إصبعك للإيقاف'
                  : (_alreadyRecordedToday ? 'تم التسجيل اليوم ✅' : 'اضغط مطولًا للتسجيل (حتى 60 ثانية)'),
              style: TextStyle(
                color: _alreadyRecordedToday ? cs.onSurfaceVariant : cs.onBackground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(ColorScheme cs) {
    final user = FirebaseAuth.instance.currentUser;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (user != null)
              UserAccountsDrawerHeader(
                accountName: Text(user.displayName ?? 'مستخدم'),
                accountEmail: Text(user.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                  child: user.photoURL == null ? const Icon(Icons.person) : null,
                ),
              ),
            ListTile(
              leading: const Icon(Icons.slideshow),
              title: const Text('تصفّح الفيديوهات'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('المفضّلة'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritesScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_rounded),
              title: const Text('ذكرياتي'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MemoriesScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('اللغة'),
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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalInfoScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('تغيير كلمة المرور'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('عن التطبيق'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('تسجيل الخروج'),
              onTap: () async {
                await GoogleSignIn().signOut();
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('تم تسجيل الخروج ✅')));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(cs),
      appBar: AppBar(
        title: const Text('ثانية من حياتك'),
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'الإعدادات والروابط',
        ),
        actions: [
          IconButton(
            tooltip: 'تصفّح الفيديوهات',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeedScreen())),
            icon: const Icon(Icons.slideshow),
          ),
          IconButton(
            tooltip: 'المفضّلة',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritesScreen())),
            icon: const Icon(Icons.favorite_outline),
          ),
          IconButton(
            tooltip: 'تبديل الوضع',
            onPressed: () {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              widget.onThemeChanged?.call(!isDark);
            },
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.wb_sunny_outlined
                  : Icons.nights_stay_outlined,
            ),
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : (_controller == null || !_controller!.value.isInitialized)
              ? const Center(child: Text('تعذّر تهيئة الكاميرا'))
              : Stack(
                  children: [
                    Positioned.fill(child: CameraPreview(_controller!)),
                    _buildRightRail(cs),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _buildCaptureControls(cs),
                    ),
                  ],
                ),
    );
  }
}
// ===================== نهاية الجزء 1/3 =====================
// ===================== main.dart (Part 2/3) =====================
// ⚠️ ملاحظة: لا توجد import هنا. كل الاستيرادات موجودة في الجزء 1/3.
// هذا الجزء يتضمن:
// - أدوات الملفات المحلية loadLocalVideos + prettyDateFromFile
// - WalletPage (المحفظة والشراء مع إدخال يدوي وحساب بالدولار)
// - MemoriesScreen (شبكة الذكريات + مشاركة مع ضغط)
// - PreviewScreen (معاينة ومشاركة مع ضغط)
// - FavoritesManager (إدارة مفضلة محليًا)
// - FeedScreen + _FeedVideoPage (تصفّح أفقي مع سحب لأعلى/أسفل)

/// تحميل كل الفيديوهات المخزّنة محليًا داخل Documents مجزأة بالسنة/الشهر
Future<List<File>> loadLocalVideos() async {
  final dir = await getApplicationDocumentsDirectory();
  final files = <File>[];
  if (!await dir.exists()) return files;

  final yearDirs = dir
      .listSync()
      .whereType<Directory>()
      .where((d) => RegExp(r'^\d{4}$').hasMatch(d.path.split(Platform.pathSeparator).last))
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
/// صفحة المحفظة (WalletPage) — شراء الكوينز + إدخال يدوي مع تحويل للدولار
/// =======================
class WalletPage extends StatefulWidget {
  const WalletPage({super.key});
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  // سعر افتراضي: 1 كوين = 0.01$ (100 كوين = 1$)
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
    await Future.delayed(const Duration(milliseconds: 600)); // محاكاة دفع ناجح
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
            FilledButton(onPressed: () => _fakePurchase(coins), child: const Text('شراء الآن')),
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
          // الرصيد
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

          // إدخال يدوي + إظهار السعر
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
            'ملاحظة: هذه محاكاة شراء بدون بوابة دفع حقيقية. يمكن لاحقًا ربط Stripe/PayPal.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// شاشة "ذكرياتي" (شبكة + مشاركة بعد ضغط الفيديو)
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
    final savedKB = ((before - after) / 1024).clamp(0, double.infinity).toStringAsFixed(0);
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
                        MaterialPageRoute(builder: (_) => PreviewScreen(videoFile: file)),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: cs.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cs.outlineVariant),
                              image: thumbBytes != null
                                  ? DecorationImage(image: MemoryImage(thumbBytes), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: thumbBytes == null
                                ? const Center(child: Icon(Icons.videocam, size: 28))
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
                                  const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      prettyDateFromFile(file),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
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
                                    child: const Icon(Icons.ios_share, size: 16, color: Colors.white),
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

/// زر صغير لحفظ/إزالة من المفضلة داخل بطاقات الشبكة
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
        child: Icon(_isFav ? Icons.favorite : Icons.favorite_border, size: 16, color: Colors.white),
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
    final savedKB = ((before - after) / 1024).clamp(0, double.infinity).toStringAsFixed(0);
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
/// إدارة المفضلة محليًا (SharedPreferences)
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
/// شاشة التصفّح الأفقي (محليًا): FeedScreen + _FeedVideoPage
/// =======================
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late Future<List<File>> _future;
  final PageController _pageCtl = PageController();
  late final AnimationController _slideHint;

  @override
  void initState() {
    super.initState();
    _future = loadLocalVideos();
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
                slideHint: _slideHint,
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
                    SnackBar(content: Text(nowFav ? 'حُفِظ في المفضلة' : 'أزيل من المفضلة')),
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
  final AnimationController slideHint;

  const _FeedVideoPage({
    required this.file,
    required this.onDragUp,
    required this.onDragDown,
    required this.slideHint,
  });

  @override
  State<_FeedVideoPage> createState() => _FeedVideoPageState();
}

class _FeedVideoPageState extends State<_FeedVideoPage> {
  late VideoPlayerController _ctl;
  bool _ready = false;
  double _accumDy = 0;

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
  }

  @override
  void dispose() {
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
      onVerticalDragUpdate: (d) => _accumDy += d.primaryDelta ?? 0,
      onVerticalDragEnd: (_) {
        if (_accumDy > 60) {
          widget.onDragDown(); // حفظ للمفضلة
        } else if (_accumDy < -60) {
          widget.onDragUp(); // فتح بروفايل الناشر
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
          // ترويسة بسيطة (تاريخ + قلب)
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
                  child: Text(prettyDateFromFile(widget.file), style: const TextStyle(color: Colors.white)),
                ),
                const Spacer(),
                FutureBuilder<bool>(
                  future: FavoritesManager.isFavorite(widget.file.path),
                  builder: (_, favSnap) {
                    final fav = favSnap.data ?? false;
                    return InkWell(
                      onTap: () async {
                        final nowFav = await FavoritesManager.toggleFavorite(widget.file.path);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(nowFav ? 'حُفِظ في المفضلة' : 'أزيل من المفضلة')),
                        );
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(22)),
                        child: Icon(fav ? Icons.favorite : Icons.favorite_border, color: Colors.white),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // تلميحة السحب تهتز للأعلى/الأسفل قليلاً
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: widget.slideHint,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, -widget.slideHint.value),
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
// ===================== نهاية الجزء 2/3 =====================
// ===================== main.dart (Part 3/3) =====================
// ⚠️ لا توجد import هنا. الاستيرادات كلها موجودة في الجزء 1/3.
// هذا الجزء يتضمّن:
// - UserProfileScreen
// - AboutScreen
// - LanguageSettingsScreen
// - PersonalInfoScreen
// - ChangePasswordScreen
// - EmailAuthScreen
// - PhoneAuthScreen
//
// ملاحظة: الدوال/الكلاسات المستخدَمة من الأجزاء السابقة مثل prettyDateFromFile()
// و SharedPreferences/FirebaseAuth متوفرة من الأجزاء 1/3 و 2/3.

/// =======================
/// شاشة البروفايل (تظهر عند السحب لأعلى من شاشة التصفّح)
/// =======================
class UserProfileScreen extends StatelessWidget {
  final String filePath;
  const UserProfileScreen({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    final f = File(filePath);
    final datePretty = f.existsSync() ? prettyDateFromFile(f) : '—';
    return Scaffold(
      appBar: AppBar(title: const Text('ملف المستخدم')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 48,
                backgroundImage: AssetImage('assets/icon.png'),
              ),
              const SizedBox(height: 16),
              const Text('اسم المستخدم (محلي)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('تاريخ الفيديو: $datePretty', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت المتابعة (تجريبياً) ✅')),
                  );
                },
                icon: const Icon(Icons.person_add_alt),
                label: const Text('متابعة'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الرسائل الخاصة قادمة قريبًا')),
                  );
                },
                icon: const Icon(Icons.message_outlined),
                label: const Text('مراسلة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// شاشة "حول التطبيق"
/// =======================
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle(
          style: TextStyle(color: cs.onBackground),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تطبيق One Second World',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              SizedBox(height: 12),
              Text(
                'سجّل ثانية واحدة من حياتك يوميًا واحتفظ بذكرياتك للأبد.\n'
                'إصدار 1.0.0\n\n'
                'تم التطوير باستخدام Flutter ❤️',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// شاشة اختيار اللغة
/// =======================
class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String _selected = 'ar';
  final langs = const {
    'ar': 'العربية',
    'en': 'English',
    'fr': 'Français',
  };

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() => _selected = p.getString('lang') ?? 'ar');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختيار اللغة')),
      body: ListView(
        children: langs.entries.map((e) {
          final code = e.key;
          final name = e.value;
          return RadioListTile<String>(
            value: code,
            groupValue: _selected,
            title: Text(name),
            onChanged: (v) {
              setState(() => _selected = v!);
              Navigator.pop(context, v);
            },
          );
        }).toList(),
      ),
    );
  }
}

/// =======================
/// شاشة المعلومات الشخصية
/// =======================
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final cardCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    nameCtrl.text = user?.displayName ?? '';
    emailCtrl.text = user?.email ?? '';
    _loadExtra();
  }

  Future<void> _loadExtra() async {
    final p = await SharedPreferences.getInstance();
    phoneCtrl.text = p.getString('profile_phone') ?? '';
    cardCtrl.text = p.getString('profile_card_hint') ?? '';
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      if (user != null) {
        await user.updateDisplayName(nameCtrl.text);
        if (emailCtrl.text.isNotEmpty && emailCtrl.text != user.email) {
          await user.updateEmail(emailCtrl.text);
        }
      }
      final p = await SharedPreferences.getInstance();
      await p.setString('profile_phone', phoneCtrl.text);
      await p.setString('profile_card_hint', cardCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم الحفظ ✅')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('معلومات شخصية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'الاسم'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف (اختياري)',
              hintText: '+213xxxxxxxxx',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cardCtrl,
            decoration: const InputDecoration(
              labelText: 'بطاقة بنكية (آخر 4 أرقام فقط)',
              hintText: 'مثال: **** **** **** 1234',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('حفظ'),
          ),
          const SizedBox(height: 8),
          Text(
            'ملاحظة: يتم حفظ رقم الهاتف وتلميح البطاقة محليًا فقط لأغراض العرض، '
            'ولا تتم أي مدفوعات فعلية من هذه الشاشة.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// شاشة تغيير كلمة المرور
/// =======================
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // قد تتطلب العملية إعادة مصادقة في بعض الحالات.
      await user.updatePassword(newCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تغيير كلمة المرور')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: oldCtrl,
              decoration:
                  const InputDecoration(labelText: 'كلمة المرور الحالية'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              decoration:
                  const InputDecoration(labelText: 'كلمة المرور الجديدة'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock_reset),
              label: const Text('تغيير'),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// شاشة تسجيل بالبريد
/// =======================
class EmailAuthScreen extends StatelessWidget {
  const EmailAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    Future<void> _signIn() async {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
        );
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }

    Future<void> _signUp() async {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
        );
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل بالبريد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailCtrl,
              decoration:
                  const InputDecoration(labelText: 'البريد الإلكتروني'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              decoration:
                  const InputDecoration(labelText: 'كلمة المرور'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                      onPressed: _signIn, child: const Text('تسجيل الدخول')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                      onPressed: _signUp, child: const Text('إنشاء حساب')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// شاشة تسجيل برقم الهاتف (واجهة مبدئية)
/// =======================
class PhoneAuthScreen extends StatelessWidget {
  const PhoneAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final phoneCtrl = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل برقم الهاتف')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'رقم الهاتف'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('قريبًا...')),
                );
              },
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== نهاية الجزء 3/3 =====================
