import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

// ==================== ابزارهای تاریخ ====================

List<int> _gregorianToJalali(int gy, int gm, int gd) {
  const gDaysInMonth = <int>[
    0,
    31,
    59,
    90,
    120,
    151,
    181,
    212,
    243,
    273,
    304,
    334
  ];

  int jy;
  int gy2;
  if (gy > 1600) {
    jy = 979;
    gy2 = gy - 1600;
  } else {
    jy = 0;
    gy2 = gy - 621;
  }

  var days = 365 * gy2 +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) -
      80 +
      gd +
      gDaysInMonth[gm - 1];

  final isLeapGregorian = (gy % 4 == 0 && gy % 100 != 0) || (gy % 400 == 0);
  if (gm > 2 && isLeapGregorian) days++;

  jy += 33 * (days ~/ 12053);
  days %= 12053;

  jy += 4 * (days ~/ 1461);
  days %= 1461;

  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }

  final jm = days < 186 ? 1 + (days ~/ 31) : 7 + ((days - 186) ~/ 30);
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);

  return [jy, jm, jd];
}

String _toPersianDigits(String value) {
  const latin = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var result = value;
  for (var i = 0; i < latin.length; i++) {
    result = result.replaceAll(latin[i], persian[i]);
  }
  return result;
}

String _todayJalali() {
  final now = DateTime.now();
  final j = _gregorianToJalali(now.year, now.month, now.day);
  return '${_toPersianDigits(j[0].toString())}/${_toPersianDigits(j[1].toString().padLeft(2, '0'))}/${_toPersianDigits(j[2].toString().padLeft(2, '0'))}';
}

String _todayJalaliLong() {
  final now = DateTime.now();
  final j = _gregorianToJalali(now.year, now.month, now.day);
  const weekdays = [
    '',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
    'شنبه',
    'یکشنبه',
  ];
  const months = [
    '',
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  final weekday = weekdays[now.weekday];
  return '$weekday ${_toPersianDigits(j[2].toString())} ${months[j[1]]} ${_toPersianDigits(j[0].toString())}';
}

String _greetingByHour(int hour) {
  if (hour >= 5 && hour < 12) return 'صبح بخیر';
  if (hour >= 12 && hour < 18) return 'ظهر بخیر';
  return 'شب بخیر';
}

// ==================== ابزارهای فرمت قیمت ====================

String _formatPrice(int price) {
  return price.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
}

String _displayPrice(int price) {
  return '${_formatPrice(price)} ریال';
}

// ==================== شروع برنامه با Splash Screen ====================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatefulWidget {
  const DeliveryApp({super.key});

  @override
  State<DeliveryApp> createState() => _DeliveryAppState();
}

class _DeliveryAppState extends State<DeliveryApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حسابداری فروشگاه + بارنامه',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.green,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('fa'),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: SplashScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==================== Splash Screen ====================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    final profileCompleted = prefs.getBool('profile_completed') ?? false;
    final userName = prefs.getString('user_name') ?? '';

    if (mounted) {
      if (profileCompleted && userName.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DeliveryScreen(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade700,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 50,
                    spreadRadius: 10,
                  ),
                ],
                image: const DecorationImage(
                  image: AssetImage('assets/images/Logopit_1787568628075.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'بوستان فرهنگی مذهبی',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'لطفاً صبر کنید...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== صفحه ورود ====================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('user_name') ?? '';
    final savedLicense = prefs.getString('user_license') ?? '';

    if (mounted) {
      setState(() {
        _nameController.text = savedName;
        _licenseController.text = savedLicense;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final license = _licenseController.text.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_license', license);
    await prefs.setBool('profile_completed', true);

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DeliveryScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade300.withOpacity(0.5),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                      image: const DecorationImage(
                        image: AssetImage(
                            'assets/images/Logopit_1787568628075.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '🛍️ بوستان فرهنگی مذهبی',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'مدیریت بارنامه و فروش',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'نام و نام خانوادگی',
                      hintText: 'مثلاً رضا قاسمی',
                      prefixIcon:
                          const Icon(Icons.person_outline, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'وارد کردن نام الزامی است';
                      }
                      if (value.trim().split(RegExp(r'\s+')).length < 2) {
                        return 'لطفاً نام و نام خانوادگی را وارد کنید';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _licenseController,
                    decoration: InputDecoration(
                      labelText: 'لایسنس (اختیاری)',
                      hintText: 'کد لایسنس را وارد کنید',
                      prefixIcon: const Icon(Icons.vpn_key_outlined,
                          color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'ورود به برنامه',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Icon(Icons.arrow_forward),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.green.shade200.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'نسخه 2.2.0 | توسعه‌دهنده: رضا قاسمی',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
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

// ==================== ادامه کد (DeliveryScreen و بقیه کلاس‌ها) در پاسخ بعدی ====================
// ==================== صفحه اصلی برنامه ====================

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  List<DeliveryItem> _currentItems = [];
  List<DeliveryItem> _filteredItems = [];
  List<Map<String, dynamic>> _manifestSearchResults = [];
  List<DeliveryManifest> _savedManifests = [];
  List<String> _smartLogs = [];
  List<ProductDatabaseItem> _productDatabase = [];
  List<SalesInvoice> _salesInvoices = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _purchasePriceController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _packageSizeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isSearching = false;
  String _selectedUnit = 'عدد';
  bool _isLoading = false;
  bool _isPackageUnit = false;
  bool _isViewingManifest = false;
  DeliveryManifest? _viewingManifest;

  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadSavedManifests();
    _loadSmartLogs();
    _loadProductDatabase();
    _loadSalesInvoices();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _searchController.dispose();
    _barcodeController.dispose();
    _packageSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? '';
    });
  }

  String _formatNumber(String value) {
    if (value.isEmpty) return '';
    final number = int.tryParse(value.replaceAll(',', ''));
    if (number == null) return value;
    return number.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  int _getNextManifestNumber() {
    if (_savedManifests.isEmpty) return 1;
    return _savedManifests
            .map((e) => e.number)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  int _getNextInvoiceNumber() {
    if (_salesInvoices.isEmpty) return 1;
    return _salesInvoices.map((e) => e.number).reduce((a, b) => a > b ? a : b) +
        1;
  }

  Future<void> _scanBarcode({bool forSearchOnly = false}) async {
    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerScreen(),
        ),
      );

      if (!mounted) return;

      if (result != null && result.isNotEmpty) {
        if (forSearchOnly) {
          _searchController.text = result;
          _searchItems(result);
          _showBarcodeSearchResultDialog(result);
        } else {
          setState(() {
            _barcodeController.text = result;
          });

          final foundProduct = _productDatabase.firstWhere(
            (p) => p.barcode == result,
            orElse: () => ProductDatabaseItem(
                barcode: '', name: '', stock: 0, buyPrice: 0, sellPrice: 0),
          );

          if (foundProduct.barcode.isNotEmpty) {
            _nameController.text = foundProduct.name;
            _purchasePriceController.text = _formatPrice(foundProduct.buyPrice);
            _showSuccessMessage('کالا از بانک اطلاعاتی پیدا شد 🔍');
          } else {
            _showSuccessMessage('بارکد اسکن شد ✅');
          }
        }
      }
    } catch (e) {
      _showSuccessMessage('❌ خطا در اسکن بارکد');
    }
  }

  void _showBarcodeSearchResultDialog(String barcode) {
    final matches =
        _productDatabase.where((p) => p.barcode == barcode).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.qr_code_scanner, color: Colors.blue),
            SizedBox(width: 8),
            Text('نتیجه اسکن بارکد', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: matches.isEmpty
            ? Text('کالایی با بارکد $barcode در بانک اطلاعات پیدا نشد.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: matches.map((item) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📦 نام کالا: ${item.name}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('📊 موجودی: ${item.stock}',
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('🏷️ قیمت فروش: ${_displayPrice(item.sellPrice)}',
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.shopping_cart),
                          label: const Text('فروش این کالا'),
                          onPressed: () {
                            Navigator.pop(context);
                            _showSalesDialog(
                              productName: item.name,
                              productBarcode: item.barcode,
                              sellPrice: item.sellPrice,
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadProductDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString('product_database');
    if (dataStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(dataStr);
        setState(() {
          _productDatabase = decoded
              .map((item) => ProductDatabaseItem.fromJson(item))
              .toList();
        });
      } catch (e) {}
    }
  }

  Future<void> _saveProductDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    final dataJson = _productDatabase.map((p) => p.toJson()).toList();
    await prefs.setString('product_database', jsonEncode(dataJson));
  }

  PageRouteBuilder<T> _slideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }

  void _openManifestScreen() {
    Navigator.push(
      context,
      _slideRoute(
        ManifestScreen(
          manifests: _savedManifests,
          onDelete: _deleteManifest,
          onEdit: _startEditingManifest,
          onViewDetails: _viewManifestDetails,
          onShareReport: _shareManifestReport,
          onManifestSaved: _saveManifest,
        ),
      ),
    );
  }

  void _viewManifestDetails(DeliveryManifest manifest) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            const Icon(Icons.local_shipping, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              '📦 بارنامه شماره ${manifest.number}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('📅 تاریخ:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(manifest.date),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('📋 تعداد کالاها:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text('${manifest.items.length}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('💰 مجموع قیمت:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(
                          _displayPrice(manifest.totalPrice),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '🛒 لیست کالاها:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...manifest.items.map((item) => Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${item.quantity} ${item.unit}'),
                        const SizedBox(width: 8),
                        Text(
                          _displayPrice(item.purchasePrice),
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('اشتراک‌گذاری'),
            onPressed: () {
              Navigator.pop(context);
              _shareManifestReport(manifest);
            },
          ),
        ],
      ),
    );
  }

  // ==================== اشتراک‌گذاری بارنامه با PDF اصلاح‌شده ====================

  Future<void> _shareManifestReport(DeliveryManifest manifest) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    '📦 بارنامه شماره ${manifest.number}',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('📅 تاریخ:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text(manifest.date),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('📋 تعداد کالاها:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('${manifest.items.length}'),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Text('💰 مجموع قیمت:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('${_formatPrice(manifest.totalPrice)} ریال',
                              style: pw.TextStyle(
                                  color: PdfColors.green,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  '🛒 لیست کالاها:',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  tableWidth: pw.TableWidth.max,
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue100,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text('ردیف',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text('نام کالا',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text('تعداد',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text('قیمت',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...manifest.items.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final item = entry.value;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text('$index'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(item.name),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text('${item.quantity} ${item.unit}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                                '${_formatPrice(item.purchasePrice)} ریال'),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    '📌 تاریخ تهیه: ${_todayJalali()}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final tempFile =
          File('${Directory.systemTemp.path}/manifest_${manifest.number}.pdf');
      await tempFile.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: '📦 بارنامه شماره ${manifest.number}\nتاریخ: ${manifest.date}',
      );

      _showSuccessMessage('✅ گزارش بارنامه ارسال شد');
    } catch (e) {
      _showSuccessMessage('❌ خطا در ارسال گزارش: $e');
    }
  }

  // ==================== اشتراک‌گذاری گزارش فروش با PDF اصلاح‌شده ====================

  Future<void> _shareSalesReport() async {
    if (_salesInvoices.isEmpty) {
      _showSuccessMessage('⚠️ هیچ فاکتوری برای گزارش وجود ندارد');
      return;
    }

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            final totalSales =
                _salesInvoices.fold<int>(0, (sum, inv) => sum + inv.totalPrice);
            final totalCredit = _salesInvoices
                .where((inv) => inv.isCredit)
                .fold<int>(0, (sum, inv) => sum + inv.totalPrice);

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    '🧾 گزارش فروش',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('📊 تعداد فاکتورها:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('${_salesInvoices.length}'),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('💰 مجموع فروش:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('${_formatPrice(totalSales)} ریال',
                              style: pw.TextStyle(
                                  color: PdfColors.green,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('💳 مجموع نسیه:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('${_formatPrice(totalCredit)} ریال',
                              style: pw.TextStyle(
                                  color: PdfColors.orange,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  '📋 لیست فاکتورها:',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  tableWidth: pw.TableWidth.max,
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green100,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('ردیف',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('شماره',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('کالا',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('تعداد',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('قیمت',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('مشتری',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ..._salesInvoices.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final inv = entry.value;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('$index'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${inv.number}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(inv.productName),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${inv.quantity}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child:
                                pw.Text('${_formatPrice(inv.totalPrice)} ریال'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(inv.customerName.isEmpty
                                ? 'نقدی'
                                : inv.customerName),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    '📌 تاریخ تهیه: ${_todayJalali()}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final tempFile = File('${Directory.systemTemp.path}/sales_report.pdf');
      await tempFile.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: '📊 گزارش فروش\nتعداد فاکتورها: ${_salesInvoices.length}',
      );

      _showSuccessMessage('✅ گزارش فروش ارسال شد');
    } catch (e) {
      _showSuccessMessage('❌ خطا در ارسال گزارش فروش: $e');
    }
  }

  // ==================== ادامه بقیه متدها ====================

  void _viewInvoiceDetails(SalesInvoice invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              '🧾 فاکتور شماره ${invoice.number}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('📅 تاریخ:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(invoice.date),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('🏷️ کالا:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(invoice.productName),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('📊 تعداد:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text('${invoice.quantity}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('💰 قیمت واحد:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(_displayPrice(invoice.price)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('💵 مجموع:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(
                          _displayPrice(invoice.totalPrice),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    if (invoice.isCredit) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('👤 مشتری:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text(invoice.customerName),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('📱 موبایل:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text(invoice.customerPhone),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('💳 نوع:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: invoice.isCredit
                                ? Colors.orange.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            invoice.isCredit ? 'نسیه' : 'نقدی',
                            style: TextStyle(
                              color: invoice.isCredit
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('چاپ'),
            onPressed: () {
              Navigator.pop(context);
              _printInvoice(invoice);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _printInvoice(SalesInvoice invoice) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    '🧾 فاکتور فروش شماره ${invoice.number}',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('📅 تاریخ:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text(invoice.date),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('🏷️ کالا:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text(invoice.productName),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('📊 تعداد:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('${invoice.quantity}'),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('💰 قیمت واحد:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('${_formatPrice(invoice.price)} ریال'),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('💵 مجموع:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('${_formatPrice(invoice.totalPrice)} ریال',
                              style: pw.TextStyle(
                                  color: PdfColors.green,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      if (invoice.isCredit) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.Text('👤 مشتری:',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(width: 8),
                            pw.Text(invoice.customerName),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.Text('📱 موبایل:',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(width: 8),
                            pw.Text(invoice.customerPhone),
                          ],
                        ),
                      ],
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('💳 نوع:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text(invoice.isCredit ? 'نسیه' : 'نقدی'),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    '📌 تاریخ چاپ: ${_todayJalali()}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'invoice_${invoice.number}.pdf',
      );

      _showSuccessMessage('✅ فاکتور ارسال شد');
    } catch (e) {
      _showSuccessMessage('❌ خطا در چاپ فاکتور');
    }
  }

  void _openSalesInvoicesScreen() {
    Navigator.push(
      context,
      _slideRoute(
        SalesInvoicesScreen(
          invoices: _salesInvoices,
          onInvoiceDeleted: (invoiceId) {
            setState(() {
              _salesInvoices.removeWhere((inv) => inv.id == invoiceId);
            });
            _saveSalesInvoices();
            _addSmartLog('🗑️ فاکتور فروش حذف شد');
          },
          onInvoiceUpdated: (updatedInvoices) {
            setState(() {
              _salesInvoices = updatedInvoices;
            });
            _saveSalesInvoices();
          },
          onNewInvoice: _showSalesDialog,
          onViewDetails: _viewInvoiceDetails,
        ),
      ),
    );
  }

  Future<void> _loadSalesInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString('sales_invoices');
    if (dataStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(dataStr);
        setState(() {
          _salesInvoices =
              decoded.map((item) => SalesInvoice.fromJson(item)).toList();
        });
      } catch (e) {}
    }
  }

  Future<void> _saveSalesInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    final dataJson = _salesInvoices.map((p) => p.toJson()).toList();
    await prefs.setString('sales_invoices', jsonEncode(dataJson));
  }

  Future<void> _showSalesDialog({
    String? productName,
    String? productBarcode,
    int? sellPrice,
  }) async {
    final customerNameCtrl = TextEditingController();
    final customerPhoneCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    bool isCredit = false;
    final selected = <Map<String, dynamic>>[];

    if (productBarcode != null && productBarcode.isNotEmpty) {
      final product = _productDatabase.cast<ProductDatabaseItem?>().firstWhere(
            (p) => p?.barcode == productBarcode,
            orElse: () => null,
          );
      if (product != null) {
        selected.add({'product': product, 'quantity': 1});
      } else if (productName != null && productName.isNotEmpty) {
        selected.add({
          'product': ProductDatabaseItem(
            barcode: productBarcode,
            name: productName,
            stock: 0,
            buyPrice: 0,
            sellPrice: sellPrice ?? 0,
          ),
          'quantity': 1,
        });
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final query = searchCtrl.text.trim().toLowerCase();
            final products = _productDatabase.where((p) {
              if (query.isEmpty) return true;
              return p.name.toLowerCase().contains(query) ||
                  p.barcode.contains(query);
            }).toList();

            void addProduct(ProductDatabaseItem product) {
              final index = selected.indexWhere(
                (e) =>
                    (e['product'] as ProductDatabaseItem).barcode ==
                    product.barcode,
              );
              setSheetState(() {
                if (index >= 0) {
                  selected[index]['quantity'] =
                      (selected[index]['quantity'] as int) + 1;
                } else {
                  selected.add({'product': product, 'quantity': 1});
                }
              });
            }

            final total = selected.fold<int>(0, (sum, line) {
              final p = line['product'] as ProductDatabaseItem;
              return sum + p.sellPrice * (line['quantity'] as int);
            });

            return SafeArea(
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.78,
                minChildSize: 0.55,
                maxChildSize: 0.96,
                snap: true,
                snapSizes: const [0.55, 0.78, 0.96],
                builder: (context, scrollController) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        const Text('فاکتور فروش',
                            style: TextStyle(
                                fontSize: 21, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Row(children: [
                                const Icon(Icons.person_outline),
                                const SizedBox(width: 8),
                                const Expanded(
                                    child: Text('مشخصات مشتری',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                Switch(
                                    value: isCredit,
                                    onChanged: (v) =>
                                        setSheetState(() => isCredit = v)),
                                const Text('نسیه'),
                              ]),
                              if (isCredit) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: customerNameCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'نام مشتری *',
                                      prefixIcon: Icon(Icons.person)),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: customerPhoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                      labelText: 'شماره موبایل *',
                                      prefixIcon: Icon(Icons.phone)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: searchCtrl,
                              onChanged: (_) => setSheetState(() {}),
                              decoration: InputDecoration(
                                labelText: 'جستجوی کالا',
                                hintText: 'نام کالا یا بارکد',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: searchCtrl.text.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          searchCtrl.clear();
                                          setSheetState(() {});
                                        }),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: 'اسکن بارکد با دوربین',
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: () async {
                              final result = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const BarcodeScannerScreen()),
                              );
                              if (result == null || result.isEmpty) return;
                              final product = _productDatabase
                                  .cast<ProductDatabaseItem?>()
                                  .firstWhere(
                                    (p) => p?.barcode == result,
                                    orElse: () => null,
                                  );
                              if (product != null) {
                                addProduct(product);
                                searchCtrl.text = result;
                                setSheetState(() {});
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'کالایی با این بارکد در بانک اطلاعاتی پیدا نشد')));
                              }
                            },
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            children: [
                              if (selected.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text('اقلام فاکتور',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
                                ...selected.map((line) {
                                  final p =
                                      line['product'] as ProductDatabaseItem;
                                  final qty = line['quantity'] as int;
                                  return Card(
                                    child: ListTile(
                                      leading:
                                          CircleAvatar(child: Text('$qty')),
                                      title: Text(p.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                          'قیمت فروش: ${_displayPrice(p.sellPrice)} | موجودی: ${p.stock}'),
                                      trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                                icon: const Icon(Icons
                                                    .remove_circle_outline),
                                                onPressed: () =>
                                                    setSheetState(() {
                                                      if (qty > 1)
                                                        line['quantity'] =
                                                            qty - 1;
                                                      else
                                                        selected.remove(line);
                                                    })),
                                            Text('$qty'),
                                            IconButton(
                                                icon: const Icon(
                                                    Icons.add_circle_outline,
                                                    color: Colors.green),
                                                onPressed: () => setSheetState(
                                                    () => line['quantity'] =
                                                        qty + 1)),
                                          ]),
                                    ),
                                  );
                                }),
                                const Divider(),
                              ],
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('انتخاب کالا',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                              ...products.map((p) => Card(
                                    child: ListTile(
                                      onTap: () => addProduct(p),
                                      leading: const Icon(
                                          Icons.inventory_2_outlined),
                                      title: Text(p.name),
                                      subtitle: Text(
                                          'موجودی: ${p.stock}  •  قیمت فروش: ${_displayPrice(p.sellPrice)}'),
                                      trailing: const Icon(
                                          Icons.add_circle_outline,
                                          color: Colors.green),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                          child: Row(children: [
                            Expanded(
                                child: Text('مجموع: ${_displayPrice(total)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17))),
                            FilledButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('ثبت فاکتور'),
                              onPressed: selected.isEmpty
                                  ? null
                                  : () {
                                      if (isCredit &&
                                          (customerNameCtrl.text
                                                  .trim()
                                                  .isEmpty ||
                                              customerPhoneCtrl.text
                                                  .trim()
                                                  .isEmpty)) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'برای فروش نسیه، نام مشتری و شماره موبایل الزامی است')));
                                        return;
                                      }
                                      final invoiceNumber =
                                          _getNextInvoiceNumber();
                                      final now = DateTime.now()
                                          .millisecondsSinceEpoch
                                          .toString();
                                      for (final line in selected) {
                                        final p = line['product']
                                            as ProductDatabaseItem;
                                        final qty = line['quantity'] as int;
                                        final invoice = SalesInvoice(
                                          id: '$now-${p.barcode}',
                                          number: invoiceNumber,
                                          productName: p.name,
                                          barcode: p.barcode,
                                          price: p.sellPrice,
                                          quantity: qty,
                                          totalPrice: p.sellPrice * qty,
                                          customerName:
                                              customerNameCtrl.text.trim(),
                                          customerPhone:
                                              customerPhoneCtrl.text.trim(),
                                          isCredit: isCredit,
                                          date: _getTodayDate(),
                                          createdAt: now,
                                        );
                                        _salesInvoices.add(invoice);
                                        final productIndex =
                                            _productDatabase.indexWhere(
                                                (x) => x.barcode == p.barcode);
                                        if (productIndex != -1) {
                                          final newStock =
                                              _productDatabase[productIndex]
                                                      .stock -
                                                  qty;
                                          _productDatabase[productIndex] =
                                              ProductDatabaseItem(
                                            barcode: p.barcode,
                                            name: p.name,
                                            stock: newStock < 0 ? 0 : newStock,
                                            buyPrice: p.buyPrice,
                                            sellPrice: p.sellPrice,
                                          );
                                        }
                                      }
                                      _saveSalesInvoices();
                                      _saveProductDatabase();
                                      _addSmartLog(
                                          '💰 فاکتور شماره $invoiceNumber با ${selected.length} قلم ثبت شد');
                                      setState(() {});
                                      Navigator.pop(sheetContext);
                                      _showSuccessMessage(
                                          'فاکتور شماره $invoiceNumber ثبت شد ✅');
                                    },
                            ),
                          ]),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _openProductDatabaseScreen() {
    Navigator.push(
      context,
      _slideRoute(
        ProductDatabaseScreen(
          database: _productDatabase,
          onDatabaseUpdated: (updatedList) {
            setState(() {
              _productDatabase = updatedList;
            });
            _saveProductDatabase();
            _addSmartLog('🔄 بانک اطلاعاتی کالاها به‌روزرسانی شد');
          },
        ),
      ),
    );
  }

  void _openSettingsScreen() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _openSettingsPageFromDrawer() {
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      Navigator.push(
        context,
        _slideRoute(
          SettingsScreen(
            isDarkMode: false,
            userName: _userName,
            onSettingsChanged: (darkMode, name) {
              if (!mounted) return;
              setState(() {
                _userName = name;
              });
            },
          ),
        ),
      );
    });
  }

  void _showSuccessMessage(String message) {
    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height / 2 - 60,
        left: MediaQuery.of(context).size.width / 2 - 120,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 240,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: message.contains('❌') || message.contains('خطا')
                  ? Colors.red.shade700
                  : Colors.green.shade700,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  message.contains('❌') || message.contains('خطا')
                      ? Icons.error_outline
                      : Icons.check_circle,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  void _addSmartLog(String message) {
    setState(() {
      final timestamp = DateTime.now();
      final time =
          '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
      _smartLogs.insert(0, '[$time] $message');
    });
    _saveSmartLogs();
  }

  Future<void> _loadSmartLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getString('smart_logs');
    if (logsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(logsJson);
        setState(() {
          _smartLogs = decoded.map((item) => item.toString()).toList();
        });
      } catch (e) {}
    }
  }

  Future<void> _saveSmartLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('smart_logs', jsonEncode(_smartLogs));
  }

  void _clearSmartLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('پاک کردن گزارش هوشمند'),
        content:
            const Text('آیا از پاک کردن همه گزارش‌های هوشمند مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _smartLogs.clear();
              });
              _saveSmartLogs();
              Navigator.pop(context);
              _showSuccessMessage('گزارش‌ها پاک شدند 🗑️');
            },
            child: const Text('پاک کردن همه'),
          ),
        ],
      ),
    );
  }

  void _searchItems(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredItems.clear();
      _manifestSearchResults.clear();

      if (query.isEmpty) {
        _isSearching = false;
        return;
      }

      final searchTerm = query.toLowerCase().trim();

      final currentResults = _currentItems
          .where((item) =>
              item.name.toLowerCase().contains(searchTerm) ||
              item.barcode.contains(searchTerm))
          .toList();
      _filteredItems = currentResults;

      for (var manifest in _savedManifests) {
        for (var item in manifest.items) {
          if (item.name.toLowerCase().contains(searchTerm) ||
              item.barcode.contains(searchTerm)) {
            _manifestSearchResults.add({
              'manifest': manifest,
              'item': item,
            });
          }
        }
      }
    });
  }

  void _clearControllers() {
    _nameController.clear();
    _quantityController.clear();
    _purchasePriceController.clear();
    _barcodeController.clear();
    _packageSizeController.clear();
    setState(() {
      _selectedUnit = 'عدد';
      _isPackageUnit = false;
    });
  }

  void _removeItem(int index) {
    setState(() {
      if (_isSearching && _filteredItems.isNotEmpty) {
        final itemToRemove = _filteredItems[index];
        _currentItems.remove(itemToRemove);
        _filteredItems.removeAt(index);
        if (_filteredItems.isEmpty) {
          _isSearching = false;
          _searchController.clear();
        }
      } else {
        _currentItems.removeAt(index);
      }
    });
  }

  int get _totalPurchasePrice {
    int total = 0;
    for (var item in _currentItems) {
      total += item.purchasePrice * item.realQuantity;
    }
    return total;
  }

  void _submitDelivery() async {
    final TextEditingController dateController = TextEditingController();
    dateController.text = _getTodayDate();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'ثبت نهایی تحویل بار',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لطفاً تاریخ بارنامه را وارد کنید:'),
            const SizedBox(height: 16),
            TextFormField(
              controller: dateController,
              decoration: InputDecoration(
                labelText: 'تاریخ (مثلاً ۱۴۰۴/۰۵/۱۵)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.green.shade100],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تعداد کالاها: ${_currentItems.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'مجموع قیمت: ${_displayPrice(_totalPurchasePrice)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'شماره بارنامه: ${_getNextManifestNumber()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final manifestDate = dateController.text.isEmpty
                  ? _getTodayDate()
                  : dateController.text;

              final manifest = DeliveryManifest(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                number: _getNextManifestNumber(),
                date: manifestDate,
                items: List.from(_currentItems),
                totalPrice: _totalPurchasePrice,
                createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
              );

              await _saveManifest(manifest);

              _addSmartLog(
                  '📋 بارنامه شماره ${manifest.number} با ${manifest.items.length} کالا ثبت شد');

              setState(() {
                _currentItems.clear();
                _filteredItems.clear();
                _searchController.clear();
                _isSearching = false;
              });

              Navigator.pop(context);
              _showSuccessMessage('بارنامه ثبت شد ✅');
            },
            child: const Text('ثبت نهایی'),
          ),
        ],
      ),
    );
  }

  String _getTodayDate() => _todayJalali();

  Future<void> _saveManifest(DeliveryManifest manifest) async {
    final prefs = await SharedPreferences.getInstance();
    final manifestsJson = _savedManifests.map((m) => m.toJson()).toList();
    manifestsJson.add(manifest.toJson());
    await prefs.setString('delivery_manifests', jsonEncode(manifestsJson));

    setState(() {
      _savedManifests.add(manifest);
    });
  }

  Future<void> _loadSavedManifests() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final manifestsJson = prefs.getString('delivery_manifests');

    if (manifestsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(manifestsJson);
        setState(() {
          _savedManifests =
              decoded.map((item) => DeliveryManifest.fromJson(item)).toList();
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startEditingManifest(DeliveryManifest manifest) {
    final dateController = TextEditingController(text: manifest.date);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'ویرایش بارنامه شماره ${manifest.number}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: dateController,
                    decoration: InputDecoration(
                      labelText: 'تاریخ بارنامه',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.edit_calendar),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'لیست کالاها:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddDialog(targetManifest: manifest);
                        },
                        tooltip: 'افزودن کالا',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: manifest.items.length,
                      itemBuilder: (context, index) {
                        final item = manifest.items[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'تعداد: ${item.quantity} | ${_displayPrice(item.purchasePrice)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.red, size: 20),
                            onPressed: () {
                              setState(() {
                                final removedItem = manifest.items[index];
                                manifest.items.removeAt(index);
                                manifest.totalPrice -=
                                    removedItem.purchasePrice *
                                        removedItem.realQuantity;
                              });
                              setStateDialog(() {});
                              _addSmartLog(
                                  '❌ کالا "${item.name}" از بارنامه شماره ${manifest.number} حذف شد');
                              _saveManifestChanges(manifest);
                              _showSuccessMessage('کالا حذف شد ❌');
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final oldDate = manifest.date;
              final newDate = dateController.text;

              setState(() {
                manifest.date = newDate;
              });

              await _saveManifestChanges(manifest);

              if (oldDate != newDate) {
                _addSmartLog(
                    '📅 تاریخ بارنامه شماره ${manifest.number} از $oldDate به $newDate تغییر یافت');
              }

              Navigator.pop(context);
              _showSuccessMessage('تغییرات ذخیره شد ✅');
            },
            child: const Text('ذخیره تغییرات'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveManifestChanges(DeliveryManifest manifest) async {
    final prefs = await SharedPreferences.getInstance();
    final manifestsJson = _savedManifests.map((m) => m.toJson()).toList();
    await prefs.setString('delivery_manifests', jsonEncode(manifestsJson));
  }

  Future<void> _deleteManifest(DeliveryManifest manifest) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('حذف بارنامه شماره ${manifest.number}'),
        content: Text('آیا از حذف بارنامه تاریخ ${manifest.date} مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              setState(() {
                _savedManifests.remove(manifest);
              });

              final prefs = await SharedPreferences.getInstance();
              final manifestsJson =
                  _savedManifests.map((m) => m.toJson()).toList();
              await prefs.setString(
                  'delivery_manifests', jsonEncode(manifestsJson));

              _addSmartLog('🗑️ بارنامه شماره ${manifest.number} حذف شد');

              Navigator.pop(context);

              if (_isViewingManifest && _viewingManifest?.id == manifest.id) {
                setState(() {
                  _isViewingManifest = false;
                  _viewingManifest = null;
                });
              }

              _showSuccessMessage('بارنامه حذف شد 🗑️');
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _viewManifest(DeliveryManifest manifest) {
    setState(() {
      _viewingManifest = manifest;
      _isViewingManifest = true;
    });
  }

  void _goBackToMain() {
    setState(() {
      _isViewingManifest = false;
      _viewingManifest = null;
    });
  }

  void _cancelDelivery() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('لغو عملیات'),
        content: const Text(
            'آیا از لغو این محموله مطمئن هستید؟\nهمه کالاها حذف خواهند شد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              setState(() {
                _currentItems.clear();
                _filteredItems.clear();
                _searchController.clear();
                _isSearching = false;
              });
              _addSmartLog('❌ محموله لغو شد');
              Navigator.pop(context);
              _showSuccessMessage('محموله لغو شد ❌');
            },
            child: const Text('بله، لغو شود'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog({DeliveryManifest? targetManifest}) async {
    _clearControllers();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          targetManifest != null
              ? 'افزودن کالا به بارنامه شماره ${targetManifest.number}'
              : 'اضافه کردن کالا',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _barcodeController,
                        decoration: InputDecoration(
                          labelText: 'شماره بارکد',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          hintText: 'اسکن یا دستی وارد کنید',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.camera_alt,
                          color: Colors.blue, size: 30),
                      onPressed: () => _scanBarcode(forSearchOnly: false),
                      tooltip: 'اسکن بارکد با دوربین',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'نام کالا',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفاً نام کالا را وارد کنید';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('واحد سنجش:'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'جلد', child: Text('جلد')),
                          DropdownMenuItem(value: 'عدد', child: Text('عدد')),
                          DropdownMenuItem(value: 'جین', child: Text('جین')),
                          DropdownMenuItem(value: 'بسته', child: Text('بسته')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedUnit = value!;
                            _isPackageUnit =
                                (value == 'بسته' || value == 'جین');
                            if (!_isPackageUnit) {
                              _packageSizeController.clear();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText:
                        'تعداد (${(_selectedUnit == 'بسته' || _selectedUnit == 'جین') ? 'بسته' : _selectedUnit})',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintText:
                        (_selectedUnit == 'بسته' || _selectedUnit == 'جین')
                            ? 'تعداد ${_selectedUnit}'
                            : 'تعداد را وارد کنید',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفاً تعداد را وارد کنید';
                    }
                    if (int.tryParse(value) == null) {
                      return 'لطفاً یک عدد معتبر وارد کنید';
                    }
                    return null;
                  },
                ),
                if (_isPackageUnit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _packageSizeController,
                    decoration: InputDecoration(
                      labelText: 'تعداد داخل هر ${_selectedUnit} (اختیاری)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText:
                          'مثلاً 10 - اختیاری است؛ در صورت خالی بودن فقط تعداد ${_selectedUnit} ثبت می‌شود',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'قیمت خرید در بارنامه ثبت نمی‌شود و در بخش «خرید» ثبت خواهد شد.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final newItem = DeliveryItem(
                  name: _nameController.text,
                  quantity: int.parse(_quantityController.text),
                  realQuantity:
                      (_packageSizeController.text.isNotEmpty && _isPackageUnit)
                          ? int.parse(_quantityController.text) *
                              int.parse(_packageSizeController.text)
                          : int.parse(_quantityController.text),
                  purchasePrice: 0,
                  barcode: _barcodeController.text.trim(),
                  date: DateTime.now().millisecondsSinceEpoch.toString(),
                  unit: _selectedUnit,
                  packageSize: _packageSizeController.text.isNotEmpty
                      ? int.parse(_packageSizeController.text)
                      : 0,
                );

                if (targetManifest != null) {
                  setState(() {
                    targetManifest.items.add(newItem);
                    targetManifest.totalPrice = 0;
                  });
                  _addSmartLog(
                      '➕ کالا "${newItem.name}" به بارنامه شماره ${targetManifest.number} اضافه شد');
                  _saveManifestChanges(targetManifest);
                  Navigator.pop(context);
                  _showSuccessMessage('کالا اضافه شد ✅');
                } else {
                  setState(() {
                    _currentItems.add(newItem);
                    if (_searchController.text.isNotEmpty) {
                      _searchItems(_searchController.text);
                    }
                  });
                  _addSmartLog(
                      '✅ کالا "${_nameController.text}" با تعداد ${newItem.quantity} اضافه شد');
                  _clearControllers();
                  Navigator.pop(context);
                  _showSuccessMessage('کالا اضافه شد ✅');
                }
              }
            },
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchDbMatches = _productDatabase.where((p) {
      final term = _searchController.text.toLowerCase().trim();
      return p.name.toLowerCase().contains(term) || p.barcode.contains(term);
    }).toList();

    final totalResults = _filteredItems.length +
        _manifestSearchResults.length +
        searchDbMatches.length;

    if (totalResults == 0) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                '🔍 هیچ کالایی با این نام یا بارکد پیدا نشد',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '🔍 نتایج جستجو ($totalResults مورد):',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.blue,
              ),
            ),
          ),
          if (searchDbMatches.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '🗄️ از بانک اطلاعاتی کالاها:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            ...searchDbMatches.map((dbItem) => Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📦 نام کالا: ${dbItem.name}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('📊 موجودی: ${dbItem.stock}',
                          style: const TextStyle(fontSize: 13)),
                      Text('🏷️ قیمت فروش: ${_displayPrice(dbItem.sellPrice)}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                      if (dbItem.barcode.isNotEmpty)
                        Text('بارکد: ${dbItem.barcode}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                              ),
                              icon: const Icon(Icons.shopping_cart, size: 16),
                              label: const Text('فروش'),
                              onPressed: () {
                                _showSalesDialog(
                                  productName: dbItem.name,
                                  productBarcode: dbItem.barcode,
                                  sellPrice: dbItem.sellPrice,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
          ],
          if (_filteredItems.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '📦 کالاهای محموله جاری:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            ..._filteredItems.map((item) => _buildSearchResultItem(item, null)),
          ],
          if (_manifestSearchResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '📋 بارنامه‌های ذخیره شده:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            ..._manifestSearchResults.map((result) =>
                _buildManifestSearchResult(result['manifest'], result['item'])),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(DeliveryItem item, DeliveryManifest? manifest) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.blue.shade700, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'تعداد: ${item.quantity}',
            style: const TextStyle(fontSize: 13),
          ),
          Text(
            'قیمت: ${_displayPrice(item.purchasePrice)}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            ),
            icon: const Icon(Icons.shopping_cart, size: 16),
            label: const Text('فروش'),
            onPressed: () {
              _showSalesDialog(
                productName: item.name,
                productBarcode: item.barcode,
                sellPrice: item.purchasePrice * 2,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManifestSearchResult(
      DeliveryManifest manifest, DeliveryItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: Colors.green.shade700, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بارنامه شماره ${manifest.number}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '📌 ${item.name} | تعداد: ${item.quantity}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            ),
            icon: const Icon(Icons.shopping_cart, size: 16),
            label: const Text('فروش'),
            onPressed: () {
              _showSalesDialog(
                productName: item.name,
                productBarcode: item.barcode,
                sellPrice: item.purchasePrice * 2,
              );
            },
          ),
        ],
      ),
    );
  }

  // ==================== صفحه اصلی با هدر جدید ====================

  Widget _buildMainView() {
    final now = DateTime.now();
    final greeting = _greetingByHour(now.hour);
    final dateText = _todayJalaliLong();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadSavedManifests();
        await _loadProductDatabase();
        await _loadSalesInvoices();
        await _loadSmartLogs();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // ==================== هدر جدید با عکس و تاریخ ====================
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade700,
                  Colors.green.shade500,
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade300.withOpacity(.3),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // ==================== عکس فروشگاه ====================
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                    image: const DecorationImage(
                      image:
                          AssetImage('assets/images/Logopit_1787568628075.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // ==================== اطلاعات کاربر ====================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting ${_userName.isEmpty ? 'کاربر عزیز' : _userName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateText,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.90),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'مدیریت فروش، بارنامه و موجودی',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ==================== جستجو ====================
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'جستجو در کالاها و بارنامه‌ها',
                    hintText: 'نام کالا یا بارکد...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _isSearching = false;
                                _filteredItems.clear();
                                _manifestSearchResults.clear();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: _searchItems,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  iconSize: 29,
                  padding: const EdgeInsets.all(13),
                  onPressed: () => _scanBarcode(forSearchOnly: true),
                  tooltip: 'جستجو با اسکن بارکد',
                ),
              ),
            ],
          ),

          if (_isSearching) ...[
            const SizedBox(height: 12),
            _buildSearchResults(),
          ] else ...[
            const SizedBox(height: 20),

            // ==================== گزارش هوشمند ====================
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'گزارش هوشمند',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_smartLogs.isNotEmpty)
                  TextButton(
                    onPressed: _clearSmartLogs,
                    child: const Text('پاک کردن'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: _smartLogs.isEmpty
                  ? const Row(
                      children: [
                        Icon(Icons.insights_outlined, color: Colors.grey),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'هنوز گزارشی ثبت نشده؛ فعالیت‌های برنامه اینجا نمایش داده می‌شوند.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: _smartLogs.take(4).map((log) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.circle, size: 7),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  log,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 22),

            // ==================== ابزارها ====================
            const Text(
              'ابزارها',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.65,
              children: [
                _buildToolCard(
                  icon: Icons.local_shipping_outlined,
                  title: 'بارنامه',
                  subtitle: 'ثبت و مدیریت بار',
                  iconColor: Colors.blue,
                  onTap: _openManifestScreen,
                ),
                _buildToolCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'فروش',
                  subtitle: 'فاکتورهای فروش',
                  iconColor: Colors.green,
                  onTap: _openSalesInvoicesScreen,
                ),
                _buildToolCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'بانک اطلاعاتی',
                  subtitle: 'کالاها و پوشه‌ها',
                  iconColor: Colors.deepPurple,
                  onTap: _openProductDatabaseScreen,
                ),
                _buildToolCard(
                  icon: Icons.share_outlined,
                  title: 'اشتراک گزارش',
                  subtitle: 'گزارش فروش و بارنامه',
                  iconColor: Colors.orange,
                  onTap: _shareSalesReport,
                ),
                _buildToolCard(
                  icon: Icons.settings_outlined,
                  title: 'تنظیمات',
                  subtitle: 'پروفایل و ظاهر',
                  iconColor: Colors.grey,
                  onTap: _openSettingsScreen,
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ==================== محموله جاری (اگر کالا وجود داشته باشد) ====================
            if (_currentItems.isNotEmpty) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'محموله جاری',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _submitDelivery,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('ثبت نهایی'),
                  ),
                ],
              ),
              ...List.generate(
                _currentItems.length,
                (index) => _buildItemCard(index),
              ),
            ],

            const SizedBox(height: 10),

            Center(
              child: Text(
                'توسعه‌دهنده: رضا قاسمی',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _currentItems[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            '${(index + 1)}',
            style: TextStyle(color: Colors.blue.shade700),
          ),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.barcode.isNotEmpty)
              Text('بارکد: ${item.barcode}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text('واحد: ${item.unit}', style: const TextStyle(fontSize: 13)),
            Text('تعداد: ${item.quantity} ${item.unit}'),
            if (item.packageSize > 0)
              Text(
                  'تعداد داخل ${item.unit}: ${item.packageSize}  •  تعداد واقعی: ${item.realQuantity}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _removeItem(index),
        ),
      ),
    );
  }

  Widget _buildManifestView() {
    final manifest = _viewingManifest!;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('شماره بارنامه:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${manifest.number}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تاریخ:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(manifest.date),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تعداد کالاها:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${manifest.items.length}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('اقلام بارنامه:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${manifest.items.length} کالا'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: manifest.items.length,
            itemBuilder: (context, index) {
              final item = manifest.items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text('${index + 1}',
                        style: TextStyle(color: Colors.blue.shade700)),
                  ),
                  title: Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'تعداد: ${item.quantity}${item.packageSize > 0 ? ' (مجموع: ${item.realQuantity})' : ''}'),
                      Text('واحد: ${item.unit}'),
                      if (item.packageSize > 0)
                        Text('تعداد داخل ${item.unit}: ${item.packageSize}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.shopping_cart, color: Colors.green),
                    onPressed: () {
                      _showSalesDialog(
                        productName: item.name,
                        productBarcode: item.barcode,
                        sellPrice: item.purchasePrice * 2,
                      );
                    },
                    tooltip: 'فروش',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isViewingManifest && _currentItems.isEmpty,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (_isViewingManifest) {
            _goBackToMain();
          } else if (_currentItems.isNotEmpty) {
            _cancelDelivery();
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            _isViewingManifest
                ? 'بارنامه شماره ${_viewingManifest!.number}'
                : 'حسابداری فروشگاه + بارنامه',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          elevation: 0,
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          actions: [
            if (!_isViewingManifest)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'تنظیمات',
                onPressed: _openSettingsScreen,
              ),
            if (!_isViewingManifest)
              IconButton(
                icon: const Icon(Icons.person_outline),
                tooltip: 'پروفایل کاربر',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            if (_isViewingManifest) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.orange),
                onPressed: () => _startEditingManifest(_viewingManifest!),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteManifest(_viewingManifest!),
              ),
            ],
          ],
          leading: _isViewingManifest
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBackToMain,
                )
              : null,
        ),
        endDrawer: Drawer(
          width: MediaQuery.of(context).size.width * .82,
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade700,
                        Colors.green.shade500,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child:
                            Icon(Icons.person, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName.isEmpty ? 'کاربر عزیز' : _userName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text('تنظیمات برنامه',
                                style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('تنظیمات'),
                  subtitle: const Text('ظاهر، پروفایل و اطلاعات برنامه'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _openSettingsPageFromDrawer,
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('پروفایل کاربر'),
                  subtitle: const Text('تغییر نام کاربر'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 220), () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    });
                  },
                ),
                const Divider(),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('توسعه‌دهنده: رضا قاسمی',
                      style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isViewingManifest
                ? _buildManifestView()
                : _buildMainView(),
      ),
    );
  }
}

// ==================== ادامه کد (ManifestScreen, SalesInvoicesScreen و ...) در پاسخ بعدی ====================
// ==================== صفحه اختصاصی بارنامه‌ها ====================

class ManifestScreen extends StatefulWidget {
  final List<DeliveryManifest> manifests;
  final Function(DeliveryManifest) onDelete;
  final Function(DeliveryManifest) onEdit;
  final Function(DeliveryManifest) onViewDetails;
  final Function(DeliveryManifest) onShareReport;
  final Function(DeliveryManifest) onManifestSaved;

  const ManifestScreen({
    super.key,
    required this.manifests,
    required this.onDelete,
    required this.onEdit,
    required this.onViewDetails,
    required this.onShareReport,
    required this.onManifestSaved,
  });

  @override
  State<ManifestScreen> createState() => _ManifestScreenState();
}

class _ManifestScreenState extends State<ManifestScreen> {
  String _searchQuery = '';

  List<DeliveryManifest> get _filteredManifests {
    if (_searchQuery.isEmpty) return widget.manifests.reversed.toList();
    final query = _searchQuery.toLowerCase().trim();
    return widget.manifests.where((m) {
      if (m.number.toString().contains(query)) return true;
      if (m.date.contains(query)) return true;
      for (final item in m.items) {
        if (item.name.toLowerCase().contains(query)) return true;
        if (item.barcode.contains(query)) return true;
      }
      return false;
    }).toList();
  }

  Future<void> _showAddManifestDialog() async {
    final barcodeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final quantityCtrl = TextEditingController();
    final packageSizeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String selectedUnit = 'عدد';
    bool isPackageUnit = false;
    List<Map<String, dynamic>> tempItems = [];

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.85,
                minChildSize: 0.6,
                maxChildSize: 0.95,
                snap: true,
                snapSizes: const [0.6, 0.85, 0.95],
                builder: (context, scrollController) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_shipping,
                                  color: Colors.blue),
                              const SizedBox(width: 8),
                              const Text(
                                'بارنامه جدید',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  barcodeCtrl.clear();
                                  nameCtrl.clear();
                                  quantityCtrl.clear();
                                  packageSizeCtrl.clear();
                                  setSheetState(() {
                                    selectedUnit = 'عدد';
                                    isPackageUnit = false;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                label: const Text('پاک کردن'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: TextFormField(
                                  controller: barcodeCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'شماره بارکد (اختیاری)',
                                    hintText: 'بارکد را اسکن یا وارد کنید',
                                    prefixIcon: const Icon(Icons.qr_code),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt,
                                      color: Colors.white),
                                  onPressed: () async {
                                    final result = await Navigator.push<String>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const BarcodeScannerScreen(),
                                      ),
                                    );
                                    if (result != null && result.isNotEmpty) {
                                      barcodeCtrl.text = result;
                                      setSheetState(() {});
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'نام کالا *',
                              hintText: 'نام کالا را وارد کنید',
                              prefixIcon: const Icon(Icons.inventory_2),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'وارد کردن نام کالا الزامی است';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: selectedUnit,
                                  decoration: InputDecoration(
                                    labelText: 'واحد سنجش',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'عدد', child: Text('عدد')),
                                    DropdownMenuItem(
                                        value: 'جلد', child: Text('جلد')),
                                    DropdownMenuItem(
                                        value: 'جین', child: Text('جین')),
                                    DropdownMenuItem(
                                        value: 'بسته', child: Text('بسته')),
                                  ],
                                  onChanged: (value) {
                                    setSheetState(() {
                                      selectedUnit = value!;
                                      isPackageUnit =
                                          (value == 'بسته' || value == 'جین');
                                      if (!isPackageUnit) {
                                        packageSizeCtrl.clear();
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: quantityCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'تعداد',
                                    hintText: 'تعداد را وارد کنید',
                                    prefixIcon: const Icon(Icons.numbers),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'تعداد را وارد کنید';
                                    }
                                    if (int.tryParse(value) == null ||
                                        int.parse(value) <= 0) {
                                      return 'تعداد معتبر وارد کنید';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (isPackageUnit) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: packageSizeCtrl,
                              decoration: InputDecoration(
                                labelText:
                                    'تعداد داخل هر ${selectedUnit} (اختیاری)',
                                hintText:
                                    'مثلاً 10 - در صورت خالی بودن فقط تعداد ${selectedUnit} ثبت می‌شود',
                                prefixIcon: const Icon(Icons.inventory_2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('افزودن کالا به لیست'),
                              onPressed: () {
                                if (!formKey.currentState!.validate()) return;

                                final barcode = barcodeCtrl.text.trim();
                                final name = nameCtrl.text.trim();
                                final quantity = int.parse(quantityCtrl.text);
                                final packageSize =
                                    packageSizeCtrl.text.isNotEmpty
                                        ? int.parse(packageSizeCtrl.text)
                                        : 0;

                                final realQuantity =
                                    isPackageUnit && packageSize > 0
                                        ? quantity * packageSize
                                        : quantity;

                                final newItem = {
                                  'name': name,
                                  'quantity': quantity,
                                  'realQuantity': realQuantity,
                                  'barcode': barcode,
                                  'unit': selectedUnit,
                                  'packageSize': packageSize,
                                };

                                setSheetState(() {
                                  tempItems.add(newItem);
                                });

                                barcodeCtrl.clear();
                                nameCtrl.clear();
                                quantityCtrl.clear();
                                packageSizeCtrl.clear();
                                setSheetState(() {
                                  selectedUnit = 'عدد';
                                  isPackageUnit = false;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('✅ کالا به لیست اضافه شد')),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (tempItems.isNotEmpty) ...[
                            const Text(
                              '📦 کالاهای بارنامه:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: ListView.builder(
                                itemCount: tempItems.length,
                                itemBuilder: (context, index) {
                                  final item = tempItems[index];
                                  return Card(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 3),
                                    child: ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.blue.shade100,
                                        child: Text('${index + 1}',
                                            style:
                                                const TextStyle(fontSize: 10)),
                                      ),
                                      title: Text(
                                        item['name'],
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Text(
                                        'تعداد: ${item['quantity']} ${item['unit']}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red, size: 18),
                                        onPressed: () {
                                          setSheetState(() {
                                            tempItems.removeAt(index);
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ] else ...[
                            const Expanded(
                              child: Center(
                                child: Text(
                                  'هنوز کالایی اضافه نشده است',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.check_circle),
                              label: const Text('ثبت بارنامه'),
                              onPressed: tempItems.isEmpty
                                  ? null
                                  : () {
                                      final manifestNumber =
                                          widget.manifests.length + 1;

                                      final items = tempItems.map((item) {
                                        return DeliveryItem(
                                          name: item['name'],
                                          quantity: item['quantity'],
                                          realQuantity: item['realQuantity'],
                                          purchasePrice: 0,
                                          barcode: item['barcode'],
                                          date: DateTime.now()
                                              .millisecondsSinceEpoch
                                              .toString(),
                                          unit: item['unit'],
                                          packageSize: item['packageSize'],
                                        );
                                      }).toList();

                                      final manifest = DeliveryManifest(
                                        id: DateTime.now()
                                            .millisecondsSinceEpoch
                                            .toString(),
                                        number: manifestNumber,
                                        date: _getTodayDate(),
                                        items: items,
                                        totalPrice: 0,
                                        createdAt: DateTime.now()
                                            .millisecondsSinceEpoch
                                            .toString(),
                                      );

                                      widget.onManifestSaved(manifest);

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                '✅ بارنامه شماره $manifestNumber ثبت شد')),
                                      );

                                      Navigator.pop(sheetContext);
                                      setState(() {});
                                    },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  String _getTodayDate() {
    final now = DateTime.now();
    final j = _gregorianToJalali(now.year, now.month, now.day);
    return '${_toPersianDigits(j[0].toString())}/${_toPersianDigits(j[1].toString().padLeft(2, '0'))}/${_toPersianDigits(j[2].toString().padLeft(2, '0'))}';
  }

  @override
  Widget build(BuildContext context) {
    final manifests = _filteredManifests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 بارنامه‌ها'),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              if (widget.manifests.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('هیچ بارنامه‌ای برای گزارش وجود ندارد')),
                );
                return;
              }
              _shareAllManifests();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                labelText: '🔍 جستجو در بارنامه‌ها',
                hintText: 'شماره، تاریخ، نام کالا یا بارکد',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: manifests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.local_shipping_outlined,
                            size: 72, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('هنوز بارنامه‌ای ثبت نشده',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text('برای شروع، «بارنامه جدید» را بزنید.'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    itemCount: manifests.length,
                    itemBuilder: (context, index) {
                      final m = manifests[index];
                      final totalItems = m.items.length;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        child: InkWell(
                          onTap: () => widget.onViewDetails(m),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blue.shade100,
                                      child: Text(
                                        '${m.number}',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'بارنامه شماره ${m.number}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'تاریخ: ${m.date}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$totalItems کالا',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: m.items.take(3).map((item) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (m.items.length > 3)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'و ${m.items.length - 3} کالای دیگر...',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.share_outlined,
                                          size: 20, color: Colors.blue),
                                      onPressed: () => widget.onShareReport(m),
                                      tooltip: 'اشتراک‌گذاری',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 20, color: Colors.orange),
                                      onPressed: () => widget.onEdit(m),
                                      tooltip: 'ویرایش',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 20, color: Colors.red),
                                      onPressed: () => widget.onDelete(m),
                                      tooltip: 'حذف',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddManifestDialog,
        icon: const Icon(Icons.add),
        label: const Text('بارنامه جدید'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _shareAllManifests() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            final totalManifests = widget.manifests.length;
            final totalItems =
                widget.manifests.fold<int>(0, (sum, m) => sum + m.items.length);

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    '📊 گزارش کل بارنامه‌ها',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('📋 تعداد بارنامه‌ها:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('$totalManifests'),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Text('📦 تعداد کل کالاها:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('$totalItems'),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                ...widget.manifests.map((m) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '📌 بارنامه شماره ${m.number} - تاریخ: ${m.date}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      ...m.items.map((item) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 10),
                          child: pw.Text(
                              '• ${item.name} (${item.quantity} ${item.unit})'),
                        );
                      }),
                      pw.SizedBox(height: 10),
                      pw.Divider(),
                    ],
                  );
                }),
                pw.SizedBox(height: 20),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    '📌 تاریخ تهیه: ${_getTodayDate()}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final tempFile =
          File('${Directory.systemTemp.path}/all_manifests_report.pdf');
      await tempFile.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text:
            '📊 گزارش کل بارنامه‌ها\nتعداد بارنامه‌ها: ${widget.manifests.length}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ گزارش بارنامه‌ها ارسال شد')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطا در ارسال گزارش: $e')),
      );
    }
  }
}

// ==================== صفحه فاکتورهای فروش ====================

class SalesInvoicesScreen extends StatefulWidget {
  final List<SalesInvoice> invoices;
  final Function(String) onInvoiceDeleted;
  final Function(List<SalesInvoice>) onInvoiceUpdated;
  final Future<void> Function() onNewInvoice;
  final Function(SalesInvoice) onViewDetails;

  const SalesInvoicesScreen({
    super.key,
    required this.invoices,
    required this.onInvoiceDeleted,
    required this.onInvoiceUpdated,
    required this.onNewInvoice,
    required this.onViewDetails,
  });

  @override
  State<SalesInvoicesScreen> createState() => _SalesInvoicesScreenState();
}

class _SalesInvoicesScreenState extends State<SalesInvoicesScreen> {
  List<SalesInvoice> _invoices = [];
  bool _showOnlyCredit = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _invoices = List.from(widget.invoices);
  }

  List<SalesInvoice> _filteredLines() {
    var filtered = List<SalesInvoice>.from(_invoices);
    if (_showOnlyCredit) {
      filtered = filtered.where((inv) => inv.isCredit).toList();
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where((inv) =>
              inv.productName.toLowerCase().contains(query) ||
              inv.barcode.contains(query) ||
              inv.customerName.toLowerCase().contains(query) ||
              inv.customerPhone.contains(query) ||
              inv.number.toString().contains(query))
          .toList();
    }
    return filtered;
  }

  Map<int, List<SalesInvoice>> _groupInvoices(List<SalesInvoice> lines) {
    final groups = <int, List<SalesInvoice>>{};
    for (final line in lines) {
      groups.putIfAbsent(line.number, () => []).add(line);
    }
    return groups;
  }

  Future<void> _deleteInvoiceGroup(int number, List<SalesInvoice> group) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('حذف فاکتور شماره $number'),
        content: const Text(
            'آیا از حذف کل این فاکتور و تمام کالاهای آن مطمئن هستید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    for (final invoice in group) {
      widget.onInvoiceDeleted(invoice.id);
    }
    setState(() {
      _invoices.removeWhere((inv) => inv.number == number);
    });
    widget.onInvoiceUpdated(List.from(_invoices));
    _showSuccessMessage('فاکتور شماره $number حذف شد 🗑️');
  }

  @override
  Widget build(BuildContext context) {
    final lines = _filteredLines();
    final groups = _groupInvoices(lines);
    final totalSales = lines.fold<int>(0, (sum, inv) => sum + inv.totalPrice);
    final totalCredit = lines
        .where((inv) => inv.isCredit)
        .fold<int>(0, (sum, inv) => sum + inv.totalPrice);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧾 فاکتورهای فروش'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              if (_invoices.isEmpty) {
                _showSuccessMessage('⚠️ هیچ فاکتوری برای گزارش وجود ندارد');
                return;
              }
              _shareSalesReport();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: '🔍 جستجو در فاکتورها',
                      hintText: 'نام کالا، بارکد، مشتری یا شماره فاکتور',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('نسیه'),
                  selected: _showOnlyCredit,
                  onSelected: (value) =>
                      setState(() => _showOnlyCredit = value),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summary('تعداد فاکتور', '${groups.length}'),
                _summary('مجموع فروش', _displayPrice(totalSales)),
                _summary('مجموع نسیه', _displayPrice(totalCredit),
                    danger: true),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: groups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.receipt_long, size: 70, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('هنوز فاکتوری ثبت نشده',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text('برای شروع، «فاکتور جدید» را بزنید.'),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    children: groups.entries.map((entry) {
                      final number = entry.key;
                      final group = entry.value;
                      final first = group.first;
                      final groupTotal =
                          group.fold<int>(0, (sum, x) => sum + x.totalPrice);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: InkWell(
                          onTap: () => widget.onViewDetails(first),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      child: Text(
                                        '$number',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '🧾 فاکتور شماره $number',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            '📅 تاریخ: ${first.date}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _deleteInvoiceGroup(number, group),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 19),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        first.customerName.isEmpty
                                            ? 'مشتری: نقدی / بدون نام'
                                            : 'مشتری: ${first.customerName}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (first.isCredit)
                                      const Chip(
                                        label: Text('نسیه'),
                                        avatar: Icon(Icons.schedule, size: 16),
                                      ),
                                  ],
                                ),
                                if (first.customerPhone.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('📱 موبایل: ${first.customerPhone}',
                                      style: const TextStyle(fontSize: 13)),
                                ],
                                const SizedBox(height: 8),
                                const Text('📋 اقلام فاکتور',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                ...group.map((item) => Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 3),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                              child: Text(item.productName,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          Text(
                                              '${item.quantity} × ${_displayPrice(item.price)}'),
                                          const SizedBox(width: 8),
                                          Text(_displayPrice(item.totalPrice),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    )),
                                const Divider(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('💰 مجموع فاکتور',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(_displayPrice(groupTotal),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await widget.onNewInvoice();
          if (mounted) setState(() => _invoices = List.from(widget.invoices));
        },
        icon: const Icon(Icons.add),
        label: const Text('فاکتور جدید'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _summary(String title, String value, {bool danger = false}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: danger ? Colors.red : null)),
      ],
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareSalesReport() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            final totalSales =
                _invoices.fold<int>(0, (sum, inv) => sum + inv.totalPrice);
            final totalCredit = _invoices
                .where((inv) => inv.isCredit)
                .fold<int>(0, (sum, inv) => sum + inv.totalPrice);

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    '🧾 گزارش فروش',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('📊 تعداد فاکتورها:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('${_invoices.length}'),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Text('💰 مجموع فروش:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('${_formatPrice(totalSales)} ریال',
                              style: pw.TextStyle(
                                  color: PdfColors.green,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Text('💳 مجموع نسیه:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('${_formatPrice(totalCredit)} ریال',
                              style: pw.TextStyle(
                                  color: PdfColors.orange,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  '📋 لیست فاکتورها:',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  tableWidth: pw.TableWidth.max,
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green100,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text('ردیف',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text('شماره',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text('کالا',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text('تعداد',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text('قیمت',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text('مشتری',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ..._invoices.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final inv = entry.value;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text('$index'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text('${inv.number}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(inv.productName),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text('${inv.quantity}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child:
                                pw.Text('${_formatPrice(inv.totalPrice)} ریال'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(inv.customerName.isEmpty
                                ? 'نقدی'
                                : inv.customerName),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    '📌 تاریخ تهیه: ${_todayJalali()}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final tempFile = File('${Directory.systemTemp.path}/sales_report.pdf');
      await tempFile.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: '📊 گزارش فروش\nتعداد فاکتورها: ${_invoices.length}',
      );

      _showSuccessMessage('✅ گزارش فروش ارسال شد');
    } catch (e) {
      _showSuccessMessage('❌ خطا در ارسال گزارش فروش: $e');
    }
  }

  String _todayJalali() {
    final now = DateTime.now();
    final j = _gregorianToJalali(now.year, now.month, now.day);
    return '${_toPersianDigits(j[0].toString())}/${_toPersianDigits(j[1].toString().padLeft(2, '0'))}/${_toPersianDigits(j[2].toString().padLeft(2, '0'))}';
  }
}

// ==================== صفحه تنظیمات ====================

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final String userName;
  final Function(bool, String) onSettingsChanged;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.userName,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _darkMode;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.isDarkMode;
    _nameController = TextEditingController(text: widget.userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setString('user_name', _nameController.text);
    widget.onSettingsChanged(_darkMode, _nameController.text);
  }

  void _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'rezagasem.82@gmail.com',
      query: 'subject=پیشنهاد برای اپلیکیشن تحویل بار&body=سلام،%0A%0A',
    );
    try {
      await launchUrl(emailUri);
    } catch (e) {
      _showSnackbar('❌ خطا در باز کردن ایمیل');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ تنظیمات'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await _saveSettings();
              _showSnackbar('✅ تنظیمات ذخیره شد');
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🌓 ظاهر',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('حالت تاریک (دارک مود)'),
                    subtitle: Text(_darkMode ? 'فعال' : 'غیرفعال'),
                    value: _darkMode,
                    onChanged: (value) {
                      setState(() {
                        _darkMode = value;
                      });
                    },
                    secondary: Icon(
                      _darkMode ? Icons.dark_mode : Icons.light_mode,
                      color: _darkMode ? Colors.white : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '👤 اطلاعات کاربر',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'نام کامل',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📧 ارتباط با ما',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.email, color: Colors.blue),
                    title: const Text('ارسال ایمیل'),
                    subtitle: const Text('rezagasem.82@gmail.com'),
                    onTap: _sendEmail,
                  ),
                  ListTile(
                    leading: const Icon(Icons.feedback, color: Colors.orange),
                    title: const Text('ارسال پیشنهاد'),
                    subtitle: const Text(
                        'نظرات و پیشنهادات خود را با ما به اشتراک بگذارید'),
                    onTap: _sendEmail,
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.apps, size: 48, color: Colors.green),
                  const SizedBox(height: 8),
                  const Text(
                    'اپلیکیشن تحویل بار و فروش',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'نسخه 2.2.0',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'توسعه‌دهنده: رضا قاسمی',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '📧 rezagasem.82@gmail.com',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ادامه کد در پاسخ بعدی (ProductDatabaseScreen, BarcodeScannerScreen و مدل‌ها) ====================
// ==================== صفحه بانک اطلاعاتی کالاها ====================

class ProductDatabaseScreen extends StatefulWidget {
  final List<ProductDatabaseItem> database;
  final Function(List<ProductDatabaseItem>) onDatabaseUpdated;

  const ProductDatabaseScreen({
    super.key,
    required this.database,
    required this.onDatabaseUpdated,
  });

  @override
  State<ProductDatabaseScreen> createState() => _ProductDatabaseScreenState();
}

class _ProductDatabaseScreenState extends State<ProductDatabaseScreen> {
  late List<ProductDatabaseItem> _items;
  bool _isLoading = false;
  String _selectedFolder = 'همه';
  String _newItemFolder = 'عمومی';
  List<String> _customFolders = [];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.database);
    _loadFolders();
    final folders = _folders;
    if (folders.length > 1) {
      _newItemFolder = folders.firstWhere(
        (f) => f != 'عمومی',
        orElse: () => 'عمومی',
      );
    }
  }

  Future<void> _loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('product_folders') ?? [];
    if (!mounted) return;
    setState(() => _customFolders = saved);
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('product_folders', _customFolders);
  }

  List<String> get _folders {
    final values = <String>{'عمومی', ..._customFolders};
    for (final item in _items) {
      if (item.folder.trim().isNotEmpty) values.add(item.folder.trim());
    }
    return values.toList()
      ..sort((a, b) {
        if (a == 'عمومی') return -1;
        if (b == 'عمومی') return 1;
        return a.compareTo(b);
      });
  }

  List<ProductDatabaseItem> get _visibleItems {
    if (_selectedFolder == 'همه') return _items;
    return _items.where((item) => item.folder == _selectedFolder).toList();
  }

  void _notifyUpdate() {
    widget.onDatabaseUpdated(_items);
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  void _showNewFolderDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('📁 ایجاد پوشه جدید'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'نام پوشه',
            hintText: 'مثلاً نوشیدنی‌ها',
            prefixIcon: const Icon(Icons.folder_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              if (_folders.contains(name)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('این پوشه از قبل وجود دارد')),
                );
                return;
              }
              setState(() {
                _customFolders = [..._customFolders, name];
                _newItemFolder = name;
                _selectedFolder = name;
              });
              _saveFolders();
              Navigator.pop(context);
            },
            child: const Text('ایجاد'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showGuideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text('راهنمای فایل ورودی')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ساختار اکسل باید به این ترتیب باشد:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('A: شماره بارکد'),
              Text('B: نام کالا'),
              Text('C: تعداد موجودی'),
              Text('D: قیمت خرید (ریال)'),
              Text('E: قیمت فروش (ریال)'),
              SizedBox(height: 12),
              Text(
                'کالاهای واردشده از اکسل در پوشه «عمومی» قرار می‌گیرند و بعداً می‌توانید آن‌ها را در پوشه‌های موردنظر مدیریت کنید.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('متوجه شدم'),
          ),
        ],
      ),
    );
  }

  Future<void> _importExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() => _isLoading = true);

      final bytes = File(result.files.single.path!).readAsBytesSync();
      final excel = excel_lib.Excel.decodeBytes(bytes);
      int addedCount = 0;

      for (var table in excel.tables.keys) {
        final rows = excel.tables[table]?.rows;
        if (rows == null) continue;

        for (final row in rows) {
          if (row.length < 5) continue;

          final col0 = row[0]?.value?.toString().trim() ?? '';
          final col1 = row[1]?.value?.toString().trim() ?? '';

          if (col0.isEmpty && col1.isEmpty) continue;
          if (col0.contains('بارکد') || col1.contains('نام')) continue;

          final stock = int.tryParse(row[2]?.value?.toString() ?? '0') ?? 0;
          final buyPrice = int.tryParse(
                  row[3]?.value?.toString().replaceAll(',', '') ?? '0') ??
              0;
          final sellPrice = int.tryParse(
                  row[4]?.value?.toString().replaceAll(',', '') ?? '0') ??
              0;

          if (col1.isNotEmpty) {
            _items.add(ProductDatabaseItem(
              barcode: col0,
              name: col1,
              stock: stock,
              buyPrice: buyPrice,
              sellPrice: sellPrice,
              folder: 'عمومی',
            ));
            addedCount++;
          }
        }
      }

      setState(() => _isLoading = false);
      _notifyUpdate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$addedCount کالا با موفقیت از اکسل اضافه شد ✅')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در خواندن فایل اکسل ❌')),
      );
    }
  }

  Future<void> _importPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.single.path == null) return;
      _showSnackbar('⚠️ قابلیت وارد کردن PDF به زودی اضافه می‌شود');
    } catch (e) {
      _showSnackbar('❌ خطا در خواندن فایل PDF');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showAddManualDialog() {
    final barcodeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final buyCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var folder = _newItemFolder;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('➕ افزودن کالا به بانک'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: barcodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'شماره بارکد',
                      prefixIcon: Icon(Icons.qr_code_2),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'نام کالا',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'نام کالا الزامی است'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _folders.contains(folder) ? folder : 'عمومی',
                    decoration: const InputDecoration(
                      labelText: 'پوشه کالا',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                    items: _folders
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => folder = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: stockCtrl,
                    decoration:
                        const InputDecoration(labelText: 'تعداد موجودی'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: buyCtrl,
                    decoration:
                        const InputDecoration(labelText: 'قیمت خرید (ریال)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: sellCtrl,
                    decoration:
                        const InputDecoration(labelText: 'قیمت فروش (ریال)'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('ثبت'),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                setState(() {
                  _items.add(ProductDatabaseItem(
                    barcode: barcodeCtrl.text.trim(),
                    name: nameCtrl.text.trim(),
                    stock: int.tryParse(stockCtrl.text) ?? 0,
                    buyPrice:
                        int.tryParse(buyCtrl.text.replaceAll(',', '')) ?? 0,
                    sellPrice:
                        int.tryParse(sellCtrl.text.replaceAll(',', '')) ?? 0,
                    folder: folder,
                  ));
                  _newItemFolder = folder;
                });

                _notifyUpdate();
                Navigator.pop(dialogContext);
                _showSnackbar('✅ کالا در پوشه «$folder» ثبت شد');
              },
            ),
          ],
        ),
      ),
    ).then((_) {
      barcodeCtrl.dispose();
      nameCtrl.dispose();
      stockCtrl.dispose();
      buyCtrl.dispose();
      sellCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🗄️ بانک اطلاعاتی کالاها'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'پوشه جدید',
            onPressed: _showNewFolderDialog,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            tooltip: 'راهنمای ستون‌ها',
            onPressed: _showGuideDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'افزودن دستی',
            onPressed: _showAddManualDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(.65),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.table_chart_outlined),
                              label: const Text('ورود اکسل'),
                              onPressed: _importExcel,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade200),
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('ورود PDF'),
                              onPressed: _importPdf,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'پوشه‌ها',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _folderChip('همه'),
                            ..._folders.map(_folderChip),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open_outlined,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _selectedFolder == 'همه'
                                    ? 'بانک اطلاعاتی خالی است'
                                    : 'این پوشه خالی است',
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _showAddManualDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('افزودن کالا'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final item = visible[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.deepPurple.shade50,
                                  child: const Icon(Icons.inventory_2_outlined),
                                ),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'پوشه: ${item.folder}\n'
                                  'بارکد: ${item.barcode.isEmpty ? "ندارد" : item.barcode}\n'
                                  'موجودی: ${item.stock} | خرید: ${_formatPrice(item.buyPrice)} ریال',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('قیمت فروش:',
                                        style: TextStyle(fontSize: 10)),
                                    Text(
                                      '${_formatPrice(item.sellPrice)} ریال',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _folderChip(String folder) {
    final selected = _selectedFolder == folder;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        selected: selected,
        label: Text(folder == 'همه' ? 'همه کالاها' : '📁 $folder'),
        onSelected: (_) {
          setState(() {
            _selectedFolder = folder;
            if (folder != 'همه') _newItemFolder = folder;
          });
        },
      ),
    );
  }
}

// ==================== اسکنر بارکد ====================

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_scanned) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;

      if (value != null && value.isNotEmpty) {
        _scanned = true;
        _controller.stop();

        Navigator.pop(context, value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('اسکن بارکد'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 50,
            child: Text(
              'بارکد را داخل کادر قرار دهید',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== مدل‌های داده ====================

class ProductDatabaseItem {
  final String barcode;
  final String name;
  final int stock;
  final int buyPrice;
  final int sellPrice;
  final String folder;

  ProductDatabaseItem({
    required this.barcode,
    required this.name,
    required this.stock,
    required this.buyPrice,
    required this.sellPrice,
    this.folder = 'عمومی',
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'name': name,
        'stock': stock,
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
        'folder': folder,
      };

  factory ProductDatabaseItem.fromJson(Map<String, dynamic> json) =>
      ProductDatabaseItem(
        barcode: json['barcode'] ?? '',
        name: json['name'] ?? '',
        stock: json['stock'] ?? 0,
        buyPrice: json['buyPrice'] ?? 0,
        sellPrice: json['sellPrice'] ?? 0,
        folder: (json['folder'] ?? 'عمومی').toString(),
      );
}

class DeliveryItem {
  final String name;
  final int quantity;
  final int realQuantity;
  final int purchasePrice;
  final String barcode;
  final String date;
  final String unit;
  final int packageSize;

  DeliveryItem({
    required this.name,
    required this.quantity,
    required this.realQuantity,
    required this.purchasePrice,
    required this.barcode,
    required this.date,
    required this.unit,
    required this.packageSize,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'realQuantity': realQuantity,
        'purchasePrice': purchasePrice,
        'barcode': barcode,
        'date': date,
        'unit': unit,
        'packageSize': packageSize,
      };

  factory DeliveryItem.fromJson(Map<String, dynamic> json) => DeliveryItem(
        name: json['name'],
        quantity: json['quantity'],
        realQuantity: json['realQuantity'] ?? json['quantity'],
        purchasePrice: json['purchasePrice'] ?? 0,
        barcode: json['barcode'],
        date: json['date'],
        unit: json['unit'] ?? 'عدد',
        packageSize: json['packageSize'] ?? 0,
      );
}

class DeliveryManifest {
  String id;
  int number;
  String date;
  List<DeliveryItem> items;
  int totalPrice;
  String createdAt;

  DeliveryManifest({
    required this.id,
    required this.number,
    required this.date,
    required this.items,
    required this.totalPrice,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'date': date,
        'items': items.map((item) => item.toJson()).toList(),
        'totalPrice': totalPrice,
        'createdAt': createdAt,
      };

  factory DeliveryManifest.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List)
        .map((item) => DeliveryItem.fromJson(item))
        .toList();
    return DeliveryManifest(
      id: json['id'],
      number: json['number'] ?? 0,
      date: json['date'],
      items: itemsList,
      totalPrice: json['totalPrice'],
      createdAt: json['createdAt'],
    );
  }
}

class SalesInvoice {
  final String id;
  final int number;
  final String productName;
  final String barcode;
  final int price;
  final int quantity;
  final int totalPrice;
  final String customerName;
  final String customerPhone;
  final bool isCredit;
  final String date;
  final String createdAt;

  SalesInvoice({
    required this.id,
    required this.number,
    required this.productName,
    required this.barcode,
    required this.price,
    required this.quantity,
    required this.totalPrice,
    required this.customerName,
    required this.customerPhone,
    required this.isCredit,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'productName': productName,
        'barcode': barcode,
        'price': price,
        'quantity': quantity,
        'totalPrice': totalPrice,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'isCredit': isCredit,
        'date': date,
        'createdAt': createdAt,
      };

  factory SalesInvoice.fromJson(Map<String, dynamic> json) => SalesInvoice(
        id: json['id'],
        number: json['number'] ?? 0,
        productName: json['productName'] ?? '',
        barcode: json['barcode'] ?? '',
        price: json['price'] ?? 0,
        quantity: json['quantity'] ?? 0,
        totalPrice: json['totalPrice'] ?? 0,
        customerName: json['customerName'] ?? '',
        customerPhone: json['customerPhone'] ?? '',
        isCredit: json['isCredit'] ?? false,
        date: json['date'] ?? '',
        createdAt: json['createdAt'] ?? '',
      );
}
