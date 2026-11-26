import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/expense.dart';
import '../models/supplier.dart';
import '../models/purchase.dart';
import '../models/shop_profile.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';

enum UserRole {
  admin;

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
    }
  }
}

class BillingProvider extends ChangeNotifier {
  bool _isDataCleared = false;
  bool get isDataCleared => _isDataCleared;

  // Multi-Tenant Company & Auth State
  String? _currentCompanyId;
  String? get currentCompanyId => _currentCompanyId;

  bool _isLoggedIn = false;
  UserRole _userRole = UserRole.admin;

  bool get isLoggedIn => _isLoggedIn;
  UserRole get userRole => _userRole;
  bool get isAdmin => true;
  bool get isEmployee => false;

  // Stream Subscriptions for Company Data Isolation
  StreamSubscription? _companySub;
  StreamSubscription? _productsSub;
  StreamSubscription? _customersSub;
  StreamSubscription? _invoicesSub;
  StreamSubscription? _expensesSub;
  StreamSubscription? _suppliersSub;
  StreamSubscription? _purchasesSub;

  // Theme Customization & Persistence State
  CustomTheme _customTheme = const CustomTheme();
  CustomTheme _previewTheme = const CustomTheme();
  bool _isThemeModified = false;

  CustomTheme get customTheme => _customTheme;
  CustomTheme get previewTheme => _previewTheme;
  bool get isThemeModified => _isThemeModified;
  ThemeData get themeData => AppTheme.getThemeData(_previewTheme);

  static const _kPrimaryColorKey = 'theme_primary';
  static const _kSecondaryColorKey = 'theme_secondary';
  static const _kBackgroundColorKey = 'theme_background';
  static const _kButtonColorKey = 'theme_button';
  static const _kTextColorKey = 'theme_text';
  static const _kInvoiceHeaderColorKey = 'theme_invoice_header';

  Future<void> loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_kPrimaryColorKey)) {
        final primary = Color(prefs.getInt(_kPrimaryColorKey)!);
        final secondary = Color(prefs.getInt(_kSecondaryColorKey)!);
        final bg = Color(prefs.getInt(_kBackgroundColorKey)!);
        final button = Color(prefs.getInt(_kButtonColorKey)!);
        final text = Color(prefs.getInt(_kTextColorKey)!);
        final invHeader = Color(prefs.getInt(_kInvoiceHeaderColorKey)!);

        _customTheme = CustomTheme(
          primaryColor: primary,
          secondaryColor: secondary,
          backgroundColor: bg,
          buttonColor: button,
          textColor: text,
          invoiceHeaderColor: invHeader,
        );
        _previewTheme = _customTheme;
        AppColors.currentTheme = _customTheme;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved theme: $e');
    }
  }

  void updatePreviewColor(String key, Color newColor) {
    switch (key) {
      case 'primary':
        _previewTheme = _previewTheme.copyWith(primaryColor: newColor);
        break;
      case 'secondary':
        _previewTheme = _previewTheme.copyWith(secondaryColor: newColor);
        break;
      case 'background':
        _previewTheme = _previewTheme.copyWith(backgroundColor: newColor);
        break;
      case 'button':
        _previewTheme = _previewTheme.copyWith(buttonColor: newColor);
        break;
      case 'text':
        _previewTheme = _previewTheme.copyWith(textColor: newColor);
        break;
      case 'invoiceHeader':
        _previewTheme = _previewTheme.copyWith(invoiceHeaderColor: newColor);
        break;
    }
    _isThemeModified = true;
    AppColors.currentTheme = _previewTheme;
    notifyListeners();
  }

  void applyPresetTheme(CustomTheme preset) {
    _previewTheme = preset;
    _isThemeModified = true;
    AppColors.currentTheme = _previewTheme;
    notifyListeners();
  }

  Future<void> saveTheme() async {
    _customTheme = _previewTheme;
    AppColors.currentTheme = _customTheme;
    _isThemeModified = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrimaryColorKey, _customTheme.primaryColor.toARGB32());
      await prefs.setInt(_kSecondaryColorKey, _customTheme.secondaryColor.toARGB32());
      await prefs.setInt(_kBackgroundColorKey, _customTheme.backgroundColor.toARGB32());
      await prefs.setInt(_kButtonColorKey, _customTheme.buttonColor.toARGB32());
      await prefs.setInt(_kTextColorKey, _customTheme.textColor.toARGB32());
      await prefs.setInt(_kInvoiceHeaderColorKey, _customTheme.invoiceHeaderColor.toARGB32());
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  Future<void> resetTheme() async {
    _customTheme = const CustomTheme();
    _previewTheme = _customTheme;
    AppColors.currentTheme = _customTheme;
    _isThemeModified = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrimaryColorKey);
      await prefs.remove(_kSecondaryColorKey);
      await prefs.remove(_kBackgroundColorKey);
      await prefs.remove(_kButtonColorKey);
      await prefs.remove(_kTextColorKey);
      await prefs.remove(_kInvoiceHeaderColorKey);
    } catch (e) {
      debugPrint('Error resetting theme: $e');
    }
  }

  // --- Authentication & Company Registration Actions ---

  Future<AuthResult> registerCompany({
    required String emailOrMobile,
    required String password,
    required String shopName,
    required String address,
    required String mobile,
    required String logoPreset,
    String gstin = '',
    String ownerName = '',
    String bankName = '',
    String accountNumber = '',
    String ifscCode = '',
  }) async {
    final result = await FirebaseService.registerCompany(
      emailOrMobile: emailOrMobile,
      password: password,
      shopName: shopName,
      address: address,
      mobile: mobile,
      logoPreset: logoPreset,
      gstin: gstin,
      ownerName: ownerName,
      bankName: bankName,
      accountNumber: accountNumber,
      ifscCode: ifscCode,
    );

    if (result.success) {
      _currentCompanyId = result.companyId;
      _shopProfile = result.shopProfile!;
      _userRole = UserRole.admin;
      _isLoggedIn = true;
      _saveShopProfileLocally(_shopProfile);
      _initCompanyFirestoreSync(_currentCompanyId!);
      notifyListeners();
    }
    return result;
  }

  Future<AuthResult> loginWithCredentials({
    required String emailOrMobile,
    required String password,
    UserRole requestedRole = UserRole.admin,
  }) async {
    final result = await FirebaseService.loginCompany(
      emailOrMobile: emailOrMobile,
      password: password,
      requestedRole: 'admin',
    );

    if (result.success) {
      _currentCompanyId = result.companyId;
      _shopProfile = result.shopProfile!;
      _isLoggedIn = true;
      _saveShopProfileLocally(_shopProfile);

      _initCompanyFirestoreSync(_currentCompanyId!);
      notifyListeners();
    }
    return result;
  }

  void login(UserRole role) {
    _isLoggedIn = true;
    if (_currentCompanyId == null) {
      _currentCompanyId = 'default-comp';
      _initCompanyFirestoreSync(_currentCompanyId!);
    }
    notifyListeners();
  }

  void logout() {
    _cancelStreamSubscriptions();
    try {
      FirebaseService.auth.signOut();
    } catch (e) {
      debugPrint('Sign out note: $e');
    }
    _isLoggedIn = false;
    _currentCompanyId = null;
    _invoices.clear();
    _customers.clear();
    _products.clear();
    _expenses.clear();
    _suppliers.clear();
    _purchases.clear();
    notifyListeners();
  }

  void _cancelStreamSubscriptions() {
    _companySub?.cancel();
    _productsSub?.cancel();
    _customersSub?.cancel();
    _invoicesSub?.cancel();
    _expensesSub?.cancel();
    _suppliersSub?.cancel();
    _purchasesSub?.cancel();
  }

  bool canAccessNavIndex(int index) {
    return true;
  }

  int _currentNavIndex = 0;
  int get currentNavIndex => _currentNavIndex;

  void setNavIndex(int index) {
    if (!canAccessNavIndex(index)) {
      return;
    }
    _currentNavIndex = index;
    notifyListeners();
  }

  // Shop Profile State & Local Persistence Keys
  static const String _kSavedShopProfileKey = 'saved_shop_profile';
  static const String _kSavedCompanyIdKey = 'saved_company_id';

  ShopProfile _shopProfile = ShopProfile.defaultProfile();
  ShopProfile get shopProfile => _shopProfile;

  Future<void> loadSavedShopProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_kSavedShopProfileKey);
      if (savedJson != null && savedJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(savedJson);
        _shopProfile = ShopProfile.fromJson(data);
        notifyListeners();
      }
      final savedCompId = prefs.getString(_kSavedCompanyIdKey);
      if (savedCompId != null && savedCompId.isNotEmpty && _currentCompanyId == null) {
        _currentCompanyId = savedCompId;
      }
    } catch (e) {
      debugPrint('Error loading saved shop profile: $e');
    }
  }

  Future<void> _saveShopProfileLocally(ShopProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSavedShopProfileKey, jsonEncode(profile.toJson()));
      if (_currentCompanyId != null && _currentCompanyId!.isNotEmpty) {
        await prefs.setString(_kSavedCompanyIdKey, _currentCompanyId!);
      }
    } catch (e) {
      debugPrint('Error saving shop profile locally: $e');
    }
  }

  void updateShopProfile(ShopProfile profile) {
    _shopProfile = profile;
    _saveShopProfileLocally(profile);
    notifyListeners();
    if (_currentCompanyId != null) {
      FirebaseService.updateCompanyDetails(profile);
    }
  }

  // Data Lists
  final List<Invoice> _invoices = [];
  final List<Customer> _customers = [];
  final List<Product> _products = [];
  final List<Expense> _expenses = [];
  final List<Supplier> _suppliers = [];
  final List<Purchase> _purchases = [];

  List<Invoice> get invoices => List.unmodifiable(_invoices);
  List<Customer> get customers => List.unmodifiable(_customers);
  List<Product> get products => List.unmodifiable(_products.reversed);
  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<Supplier> get suppliers => List.unmodifiable(_suppliers);
  List<Purchase> get purchases => List.unmodifiable(_purchases);

  BillingProvider() {
    loadSavedTheme();
    loadSavedShopProfile();
    _initSeedData();
  }

  void _initSeedData() {
    _customers.clear();
    _products.clear();
    _suppliers.clear();
    _purchases.clear();
    _expenses.clear();
    _invoices.clear();
  }

  /// Synchronize company-specific data under `companies/{companyId}/...`
  void _initCompanyFirestoreSync(String companyId) {
    _cancelStreamSubscriptions();
    try {
      final compDocRef = FirebaseFirestore.instance.collection('companies').doc(companyId);

      // 1. Sync Company Profile
      _companySub = compDocRef.snapshots().listen((snap) {
        if (snap.exists && snap.data() != null) {
          _shopProfile = ShopProfile.fromJson(snap.data()!, defaultCompanyId: companyId);
          _saveShopProfileLocally(_shopProfile);
          notifyListeners();
        }
      }, onError: (e) => debugPrint('Firestore company profile sync note: $e'));

      // 2. Sync Products
      _productsSub = compDocRef.collection('products').snapshots().listen((snap) {
        _products.clear();
        if (snap.docs.isNotEmpty) {
          final items = snap.docs.map((d) => Product.fromJson(d.data())).toList();
          _products.addAll(items);
        }
        notifyListeners();
      }, onError: (e) => debugPrint('Firestore company products sync note: $e'));

      // 3. Sync Customers
      _customersSub = compDocRef.collection('customers').snapshots().listen((snap) {
        _customers.clear();
        if (snap.docs.isNotEmpty) {
          final items = snap.docs.map((d) => Customer.fromJson(d.data())).toList();
          _customers.addAll(items);
        }
        notifyListeners();
      }, onError: (e) => debugPrint('Firestore company customers sync note: $e'));

      // 4. Sync Invoices
      _invoicesSub = compDocRef.collection('invoices').snapshots().listen((snap) {
        _invoices.clear();
        if (snap.docs.isNotEmpty) {
          final items = snap.docs.map((d) => Invoice.fromJson(d.data())).toList();
          _invoices.addAll(items);
          _invoices.sort((a, b) => b.issueDate.compareTo(a.issueDate));
        }
        notifyListeners();
      }, onError: (e) => debugPrint('Firestore company invoices sync note: $e'));

      // 5. Sync Expenses
      _expensesSub = compDocRef.collection('expenses').snapshots().listen((snap) {
        _expenses.clear();
        if (snap.docs.isNotEmpty) {
          final items = snap.docs.map((d) => Expense.fromJson(d.data())).toList();
          _expenses.addAll(items);
          _expenses.sort((a, b) => b.date.compareTo(a.date));
        }
        notifyListeners();
      }, onError: (e) => debugPrint('Firestore company expenses sync note: $e'));

      // 6. Sync Suppliers
      _suppliersSub = compDocRef.collection('suppliers').snapshots().listen((snap) {
        _suppliers.clear();
        if (snap.docs.isNotEmpty) {
          final items = snap.docs.map((d) => Supplier.fromJson(d.data())).toList();
          _suppliers.addAll(items);
        }
        notifyListeners();
      }, onError: (e) => debugPrint('Firestore company suppliers sync note: $e'));

      // 7. Sync Purchases
      _purchasesSub = compDocRef.collection('purchases').snapshots().listen((snap) {
        _purchases.clear();
        if (snap.docs.isNotEmpty) {
          final items = snap.docs.map((d) => Purchase.fromJson(d.data())).toList();
          _purchases.addAll(items);
        }
        notifyListeners();
      }, onError: (e) => debugPrint('Firestore company purchases sync note: $e'));
    } catch (e) {
      debugPrint('Company Firestore sync note: $e');
    }
  }

  // --- Sequential Invoice & Product Stock Range Generators ---
  String get nextInvoiceNumber {
    int maxNum = 0;
    for (var inv in _invoices) {
      final matches = RegExp(r'(\d+)').allMatches(inv.invoiceNumber);
      if (matches.isNotEmpty) {
        final lastNumStr = matches.last.group(1);
        if (lastNumStr != null) {
          final val = int.tryParse(lastNumStr) ?? 0;
          if (val > maxNum) {
            maxNum = val;
          }
        }
      }
    }
    final next = maxNum + 1;
    return next.toString().padLeft(3, '0');
  }

  int get totalStockUnits {
    return _products.fold(0, (acc, p) => acc + p.stockQuantity);
  }

  /// Finds the highest numeric ID or SKU unit number across all registered products.
  int getMaxSkuUnit({String? excludeProductId}) {
    int maxNum = 0;
    for (var p in _products) {
      if (excludeProductId != null && p.id == excludeProductId) continue;
      // Extract numbers from SKU (e.g. "1490 to 1499", "1499", "SKU-1499")
      final skuMatches = RegExp(r'(\d+)').allMatches(p.sku);
      for (var m in skuMatches) {
        final val = int.tryParse(m.group(1) ?? '') ?? 0;
        if (val > maxNum) {
          maxNum = val;
        }
      }
      // Also check numeric parts in product ID if formatted with digits (e.g. "prod-1499")
      final idMatches = RegExp(r'(\d+)').allMatches(p.id);
      for (var m in idMatches) {
        final val = int.tryParse(m.group(1) ?? '') ?? 0;
        if (val > maxNum) {
          maxNum = val;
        }
      }
    }
    return maxNum;
  }

  /// Calculates the next sequential product ID to guarantee unique, monotonically
  /// increasing IDs that never collide or reverse when products are deleted or sold.
  String get nextProductId {
    int maxNum = 0;
    for (var p in _products) {
      final matches = RegExp(r'(\d+)').allMatches(p.id);
      if (matches.isNotEmpty) {
        final lastNumStr = matches.last.group(1);
        if (lastNumStr != null) {
          final val = int.tryParse(lastNumStr) ?? 0;
          if (val > maxNum) {
            maxNum = val;
          }
        }
      }
    }
    final next = maxNum > 0 ? maxNum + 1 : (_products.length + 1);
    return next.toString().padLeft(3, '0');
  }

  /// Calculates the next sequential Product ID / SKU range.
  /// Uses the highest previously assigned SKU/ID number instead of volatile current stock
  /// so that ranges NEVER reverse backwards or overlap when items are sold from inventory.
  String calculateProductSkuRange(int newStockQty, {String? excludeProductId}) {
    final maxNum = getMaxSkuUnit(excludeProductId: excludeProductId);
    final startUnit = maxNum > 0 ? maxNum + 1 : 1;
    final qty = newStockQty > 0 ? newStockQty : 1;
    final endUnit = startUnit + qty - 1;
    final startStr = startUnit.toString().padLeft(4, '0');
    final endStr = endUnit.toString().padLeft(4, '0');
    if (qty <= 1) {
      return startStr;
    }
    return '$startStr to $endStr';
  }

  /// Checks if a given SKU / Product ID is already assigned to another product.
  bool isSkuDuplicate(String sku, {String? excludeProductId}) {
    final clean = sku.trim().toLowerCase();
    if (clean.isEmpty) return false;
    for (var p in _products) {
      if (excludeProductId != null && p.id == excludeProductId) continue;
      if (p.sku.trim().toLowerCase() == clean) return true;
    }
    return false;
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  List<Invoice> get todayInvoices {
    final now = DateTime.now();
    return _invoices.where((inv) => _isSameDay(inv.issueDate, now)).toList();
  }

  List<Expense> get todayExpensesList {
    final now = DateTime.now();
    return _expenses.where((exp) => _isSameDay(exp.date, now)).toList();
  }

  double get todaySalesTotal {
    return todayInvoices.fold(0.0, (acc, inv) => acc + inv.totalAmount);
  }

  double get todayMrpTotal {
    double total = 0.0;
    for (var inv in todayInvoices) {
      for (var item in inv.items) {
        total += item.totalMrp;
      }
    }
    return total;
  }

  double get todayCostTotal {
    double total = 0.0;
    for (var inv in todayInvoices) {
      for (var item in inv.items) {
        total += item.totalCost;
      }
    }
    return total;
  }

  double get todayGrossProfit {
    double profit = 0.0;
    for (var inv in todayInvoices) {
      for (var item in inv.items) {
        profit += item.itemProfit;
      }
    }
    return profit;
  }

  double get todayExpensesTotal {
    return todayExpensesList.fold(0.0, (acc, exp) => acc + exp.amount);
  }

  double get todayNetProfit {
    return todayGrossProfit - todayExpensesTotal;
  }

  double get totalSales => _invoices.fold(0.0, (acc, inv) => acc + inv.totalAmount);

  double get totalExpenses => _expenses.fold(0.0, (acc, exp) => acc + exp.amount);

  double get netProfit => totalSales - totalExpenses;

  double get totalCustomerDues => _customers.fold(0.0, (acc, c) => acc + c.dueBalance);

  double get totalSupplierDues => _suppliers.fold(0.0, (acc, s) => acc + s.balanceDue);

  List<Product> get lowStockProducts => _products.where((p) => p.isLowStock).toList();

  double get paidAmount => _invoices
      .where((inv) => inv.status == InvoiceStatus.paid)
      .fold(0.0, (acc, inv) => acc + inv.totalAmount);

  double get pendingAmount => _invoices
      .where((inv) => inv.status == InvoiceStatus.pending)
      .fold(0.0, (acc, inv) => acc + inv.totalAmount);

  double get overdueAmount => _invoices
      .where((inv) => inv.status == InvoiceStatus.overdue)
      .fold(0.0, (acc, inv) => acc + inv.totalAmount);

  int get paidCount => _invoices.where((inv) => inv.status == InvoiceStatus.paid).length;
  int get pendingCount => _invoices.where((inv) => inv.status == InvoiceStatus.pending).length;
  int get overdueCount => _invoices.where((inv) => inv.status == InvoiceStatus.overdue).length;

  DocumentReference? _getCompanySubDoc(String collection, String id) {
    if (_currentCompanyId == null) return null;
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(_currentCompanyId)
        .collection(collection)
        .doc(id);
  }

  // --- Helper to find product by Name, Price & Size (or fallback by Name) ---
  int findProductIndex({required String name, double? price, String? size}) {
    final cleanName = name.trim().toLowerCase();
    final cleanSize = size?.trim().toLowerCase() ?? '';

    // 1. First attempt exact match: Name + Price + Size
    if (price != null) {
      final exactIndex = _products.indexWhere((p) {
        final matchesName = p.name.trim().toLowerCase() == cleanName;
        final matchesPrice = (p.unitPrice - price).abs() < 0.01;
        final pSize = p.size.trim().toLowerCase();
        final matchesSize = cleanSize.isEmpty || cleanSize == 'free size' || cleanSize == 'n/a' || cleanSize == 'none'
            ? (pSize.isEmpty || pSize == 'free size' || pSize == 'n/a' || pSize == 'none')
            : pSize == cleanSize;
        return matchesName && matchesPrice && matchesSize;
      });
      if (exactIndex != -1) return exactIndex;

      // 2. Secondary attempt: Name + Size
      if (cleanSize.isNotEmpty && cleanSize != 'free size' && cleanSize != 'n/a' && cleanSize != 'none') {
        final sizeIndex = _products.indexWhere((p) {
          final matchesName = p.name.trim().toLowerCase() == cleanName;
          final pSize = p.size.trim().toLowerCase();
          return matchesName && pSize == cleanSize;
        });
        if (sizeIndex != -1) return sizeIndex;
      }
    }

    // 3. Fallback: match by Name alone
    return _products.indexWhere((p) => p.name.trim().toLowerCase() == cleanName);
  }

  // --- Data Mutation Actions ---

  void addInvoice(Invoice invoice) {
    final updatedItems = invoice.items.map((item) {
      final pIndex = findProductIndex(name: item.description, price: item.unitPrice, size: item.size);
      if (pIndex != -1) {
        final prod = _products[pIndex];
        return item.copyWith(
          mrpPrice: item.mrpPrice > 0 ? item.mrpPrice : prod.mrpPrice,
          costPrice: item.costPrice > 0 ? item.costPrice : prod.unitCostPrice,
          discount: item.discount,
        );
      }
      return item;
    }).toList();

    final finalInvoice = invoice.copyWith(items: updatedItems);
    _invoices.insert(0, finalInvoice);
    
    for (var item in finalInvoice.items) {
      final pIndex = findProductIndex(name: item.description, price: item.unitPrice, size: item.size);
      if (pIndex != -1) {
        final currentStock = _products[pIndex].stockQuantity;
        final newStock = (currentStock - item.quantity).clamp(0, 999999);
        _products[pIndex] = _products[pIndex].copyWith(stockQuantity: newStock);
      }
    }

    if (invoice.status != InvoiceStatus.paid) {
      final cIndex = _customers.indexWhere((c) => c.id == invoice.customerId || c.name.toLowerCase() == invoice.customerName.toLowerCase());
      if (cIndex != -1) {
        _customers[cIndex] = _customers[cIndex].copyWith(
          dueBalance: _customers[cIndex].dueBalance + invoice.totalAmount,
        );
      } else if (invoice.customerName.isNotEmpty) {
        _customers.add(
          Customer(
            id: invoice.customerId,
            name: invoice.customerName,
            email: invoice.customerEmail,
            phone: invoice.customerPhone,
            address: 'Retail Customer',
            dueBalance: invoice.totalAmount,
          ),
        );
      }
    }
    notifyListeners();

    try {
      _getCompanySubDoc('invoices', finalInvoice.id)?.set(finalInvoice.toJson());
      for (var item in finalInvoice.items) {
        final pIndex = findProductIndex(name: item.description, price: item.unitPrice, size: item.size);
        if (pIndex != -1) {
          _getCompanySubDoc('products', _products[pIndex].id)?.set(_products[pIndex].toJson());
        }
      }
      if (invoice.status != InvoiceStatus.paid) {
        final cIndex = _customers.indexWhere((c) => c.id == invoice.customerId || c.name.toLowerCase() == invoice.customerName.toLowerCase());
        if (cIndex != -1) {
          _getCompanySubDoc('customers', _customers[cIndex].id)?.set(_customers[cIndex].toJson());
        }
      }
    } catch (e) {
      debugPrint('Firestore addInvoice sync note: $e');
    }
  }

  void updateInvoiceStatus(String invoiceId, InvoiceStatus newStatus) {
    final index = _invoices.indexWhere((inv) => inv.id == invoiceId);
    if (index != -1) {
      final oldStatus = _invoices[index].status;
      _invoices[index] = _invoices[index].copyWith(status: newStatus);

      if (oldStatus != InvoiceStatus.paid && newStatus == InvoiceStatus.paid) {
        final cIndex = _customers.indexWhere((c) => c.id == _invoices[index].customerId);
        if (cIndex != -1) {
          final newDue = (_customers[cIndex].dueBalance - _invoices[index].totalAmount).clamp(0.0, 999999.0);
          _customers[cIndex] = _customers[cIndex].copyWith(dueBalance: newDue);
        }
      }
      notifyListeners();

      try {
        _getCompanySubDoc('invoices', invoiceId)?.set(_invoices[index].toJson());
        final cIndex = _customers.indexWhere((c) => c.id == _invoices[index].customerId);
        if (cIndex != -1) {
          _getCompanySubDoc('customers', _customers[cIndex].id)?.set(_customers[cIndex].toJson());
        }
      } catch (e) {
        debugPrint('Firestore updateInvoiceStatus sync note: $e');
      }
    }
  }

  void updateInvoice(Invoice invoice) {
    final index = _invoices.indexWhere((inv) => inv.id == invoice.id);
    if (index != -1) {
      _invoices[index] = invoice;
      notifyListeners();
      try {
        _getCompanySubDoc('invoices', invoice.id)?.set(invoice.toJson());
      } catch (e) {
        debugPrint('Firestore updateInvoice sync note: $e');
      }
    }
  }

  void deleteInvoice(String invoiceId) {
    _invoices.removeWhere((inv) => inv.id == invoiceId);
    notifyListeners();
    try {
      _getCompanySubDoc('invoices', invoiceId)?.delete();
    } catch (e) {
      debugPrint('Firestore deleteInvoice sync note: $e');
    }
  }

  void addProduct(Product product) {
    _products.add(product);
    notifyListeners();
    try {
      _getCompanySubDoc('products', product.id)?.set(product.toJson());
    } catch (e) {
      debugPrint('Firestore addProduct sync note: $e');
    }
  }

  void updateProduct(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
      notifyListeners();
      try {
        _getCompanySubDoc('products', product.id)?.set(product.toJson());
      } catch (e) {
        debugPrint('Firestore updateProduct sync note: $e');
      }
    }
  }

  void deleteProduct(String productId) {
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
    try {
      _getCompanySubDoc('products', productId)?.delete();
    } catch (e) {
      debugPrint('Firestore deleteProduct sync note: $e');
    }
  }

  void adjustProductStock(String productId, int newStock) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index] = _products[index].copyWith(stockQuantity: newStock);
      notifyListeners();
      try {
        _getCompanySubDoc('products', productId)?.set(_products[index].toJson());
      } catch (e) {
        debugPrint('Firestore adjustProductStock sync note: $e');
      }
    }
  }

  void addCustomer(Customer customer) {
    _customers.add(customer);
    notifyListeners();
    try {
      _getCompanySubDoc('customers', customer.id)?.set(customer.toJson());
    } catch (e) {
      debugPrint('Firestore addCustomer sync note: $e');
    }
  }

  void updateCustomer(Customer customer) {
    final index = _customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      _customers[index] = customer;
      notifyListeners();
      try {
        _getCompanySubDoc('customers', customer.id)?.set(customer.toJson());
      } catch (e) {
        debugPrint('Firestore updateCustomer sync note: $e');
      }
    }
  }

  void deleteCustomer(String customerId) {
    _customers.removeWhere((c) => c.id == customerId);
    notifyListeners();
    try {
      _getCompanySubDoc('customers', customerId)?.delete();
    } catch (e) {
      debugPrint('Firestore deleteCustomer sync note: $e');
    }
  }

  void recordCustomerPayment(String customerId, double amountPaid) {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      final currentDue = _customers[index].dueBalance;
      final newDue = (currentDue - amountPaid).clamp(0.0, 999999.0);
      _customers[index] = _customers[index].copyWith(
        dueBalance: newDue,
        lastContactDate: DateTime.now(),
      );
      notifyListeners();
      try {
        _getCompanySubDoc('customers', customerId)?.set(_customers[index].toJson());
      } catch (e) {
        debugPrint('Firestore recordCustomerPayment sync note: $e');
      }
    }
  }

  void updateCustomerFollowUp(String customerId, String notes, DateTime? nextDate) {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      _customers[index] = _customers[index].copyWith(
        followUpNotes: notes,
        nextFollowUpDate: nextDate,
        lastContactDate: DateTime.now(),
      );
      notifyListeners();
      try {
        _getCompanySubDoc('customers', customerId)?.set(_customers[index].toJson());
      } catch (e) {
        debugPrint('Firestore updateCustomerFollowUp sync note: $e');
      }
    }
  }

  void addSupplier(Supplier supplier) {
    _suppliers.add(supplier);
    notifyListeners();
    try {
      _getCompanySubDoc('suppliers', supplier.id)?.set(supplier.toJson());
    } catch (e) {
      debugPrint('Firestore addSupplier sync note: $e');
    }
  }

  void addPurchase(Purchase purchase) {
    _purchases.insert(0, purchase);
    for (var item in purchase.items) {
      final pIndex = findProductIndex(name: item.description, price: item.unitPrice, size: item.size);
      if (pIndex != -1) {
        final currentStock = _products[pIndex].stockQuantity;
        _products[pIndex] = _products[pIndex].copyWith(stockQuantity: currentStock + item.quantity);
        _getCompanySubDoc('products', _products[pIndex].id)?.set(_products[pIndex].toJson());
      }
    }
    notifyListeners();
    try {
      _getCompanySubDoc('purchases', purchase.id)?.set(purchase.toJson());
    } catch (e) {
      debugPrint('Firestore addPurchase sync note: $e');
    }
  }

  void addExpense(Expense expense) {
    _expenses.insert(0, expense);
    notifyListeners();
    try {
      _getCompanySubDoc('expenses', expense.id)?.set(expense.toJson());
    } catch (e) {
      debugPrint('Firestore addExpense sync note: $e');
    }
  }

  void deleteExpense(String expenseId) {
    _expenses.removeWhere((e) => e.id == expenseId);
    notifyListeners();
    try {
      _getCompanySubDoc('expenses', expenseId)?.delete();
    } catch (e) {
      debugPrint('Firestore deleteExpense sync note: $e');
    }
  }

  Future<bool> sendWhatsAppDueReminder(Customer customer) async {
    final cleanPhone = customer.phone.replaceAll(RegExp(r'[^\d+]'), '');
    final gstinText = _shopProfile.gstin.trim().isNotEmpty ? 'GSTIN: ${_shopProfile.gstin}\n' : '';

    final messageText = '''
🔔 *PAYMENT REMINDER - ${_shopProfile.shopName}*
Dear ${customer.name},

This is a gentle reminder regarding your outstanding balance.

*Current Balance Due*: ₹${customer.dueBalance.toStringAsFixed(2)}

Kindly remit payment at your earliest convenience via Cash / UPI to:
${gstinText}Mobile / UPI: ${_shopProfile.mobile}

For any queries, please contact ${_shopProfile.shopName} at ${_shopProfile.mobile}.
Thank you for your business!
''';

    final encodedText = Uri.encodeComponent(messageText);
    final String urlString = cleanPhone.isNotEmpty
        ? 'https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedText'
        : 'https://api.whatsapp.com/send?text=$encodedText';

    final Uri url = Uri.parse(urlString);

    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final Uri fallbackUrl = Uri.parse('https://wa.me/?text=$encodedText');
      return await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool> shareInvoiceToWhatsApp(Invoice invoice) async {
    final cleanPhone = invoice.customerPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final itemsListText = invoice.items
        .map((item) => '• ${item.description} (x${item.quantity}) - ₹${item.totalPrice.toStringAsFixed(2)}')
        .join('\n');
    final gstinText = _shopProfile.gstin.trim().isNotEmpty ? 'GSTIN: ${_shopProfile.gstin}\n' : '';

    final messageText = '''
🧾 *OFFICIAL BILL RECEIPT - ${_shopProfile.shopName}*
*Invoice #*: ${invoice.invoiceNumber}
*Customer*: ${invoice.customerName}
----------------------------------------
*Items*:
$itemsListText

*Grand Total*: ₹${invoice.totalAmount.toStringAsFixed(2)}
*Payment Method*: ${invoice.paymentMethod.label}
*Status*: ${invoice.status.label.toUpperCase()}
----------------------------------------
*Shop Details*:
${_shopProfile.shopName}
${_shopProfile.address}
Mobile: ${_shopProfile.mobile}
$gstinText
Thank you for shopping with us!
''';

    final encodedText = Uri.encodeComponent(messageText);
    final String urlString = cleanPhone.isNotEmpty
        ? 'https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedText'
        : 'https://api.whatsapp.com/send?text=$encodedText';

    final Uri url = Uri.parse(urlString);

    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final Uri fallbackUrl = Uri.parse('https://wa.me/?text=$encodedText');
      return await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
    }
  }

  void clearAllData() {
    _isDataCleared = true;
    _invoices.clear();
    _customers.clear();
    _products.clear();
    _expenses.clear();
    _suppliers.clear();
    _purchases.clear();
    _shopProfile = ShopProfile.defaultProfile(companyId: _currentCompanyId ?? 'default-comp');
    notifyListeners();

    if (_currentCompanyId != null) {
      try {
        final compRef = FirebaseFirestore.instance.collection('companies').doc(_currentCompanyId);
        final collections = ['invoices', 'customers', 'products', 'expenses', 'suppliers', 'purchases'];
        for (var colName in collections) {
          compRef.collection(colName).get().then((snap) {
            for (var doc in snap.docs) {
              doc.reference.delete();
            }
          });
        }
      } catch (e) {
        debugPrint('Firestore clearAllData note: $e');
      }
    }
  }
}
