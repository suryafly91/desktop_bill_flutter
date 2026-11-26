import 'default_logo.dart';

enum BillPaperSize {
  mm58('58mm', '58mm Thermal', 260.0),
  mm80('80mm', '80mm Thermal', 380.0),
  mm127('127mm', '127mm (5 Inch)', 520.0),
  a5('A5', 'A5 — 148 × 210 mm', 660.0),
  a4('A4', 'A4 — 210 × 297 mm', 840.0);

  final String id;
  final String label;
  final double widthPx;

  const BillPaperSize(this.id, this.label, this.widthPx);

  static BillPaperSize fromId(String? id) {
    switch (id) {
      case '58mm':
      case 'mm58':
      case '58':
        return BillPaperSize.mm58;
      case '127mm':
        return BillPaperSize.mm127;
      case 'A5':
      case 'a5':
        return BillPaperSize.a5;
      case 'A4':
      case 'a4':
        return BillPaperSize.a4;
      case '80mm':
      default:
        return BillPaperSize.mm80;
    }
  }
}

class ShopProfile {
  final String companyId;
  final String shopName;
  final String ownerName;
  final String address;
  final String mobile;
  final String gstin;
  final double gstPercentage;
  final String email;
  final String logoPreset; // e.g. 'store', 'shopping', 'tech', 'pos'
  final String logoBase64; // Base64 encoded image string for print header
  final String paperSize; // e.g. '80mm', '127mm', 'A5', 'A4'
  final bool isConfigured;
  final String bankName;
  final String accountNumber;
  final String ifscCode;

  BillPaperSize get paperSizeEnum => BillPaperSize.fromId(paperSize);

  ShopProfile({
    this.companyId = 'default-comp',
    required this.shopName,
    required this.ownerName,
    required this.address,
    required this.mobile,
    this.gstin = '',
    this.gstPercentage = 18.0,
    this.email = '',
    this.logoPreset = 'store',
    this.logoBase64 = '',
    this.paperSize = '80mm',
    this.isConfigured = true,
    this.bankName = '',
    this.accountNumber = '',
    this.ifscCode = '',
  });

  factory ShopProfile.defaultProfile({String companyId = 'default-comp'}) {
    return ShopProfile(
      companyId: companyId,
      shopName: 'My Store',
      ownerName: 'Store Owner',
      address: '',
      mobile: '',
      gstin: '',
      gstPercentage: 18.0,
      email: '',
      logoPreset: 'store',
      logoBase64: '',
      paperSize: '80mm',
      isConfigured: true,
      bankName: '',
      accountNumber: '',
      ifscCode: '',
    );
  }

  ShopProfile copyWith({
    String? companyId,
    String? shopName,
    String? ownerName,
    String? address,
    String? mobile,
    String? gstin,
    double? gstPercentage,
    String? email,
    String? logoPreset,
    String? logoBase64,
    String? paperSize,
    bool? isConfigured,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
  }) {
    return ShopProfile(
      companyId: companyId ?? this.companyId,
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      address: address ?? this.address,
      mobile: mobile ?? this.mobile,
      gstin: gstin ?? this.gstin,
      gstPercentage: gstPercentage ?? this.gstPercentage,
      email: email ?? this.email,
      logoPreset: logoPreset ?? this.logoPreset,
      logoBase64: logoBase64 ?? this.logoBase64,
      paperSize: paperSize ?? this.paperSize,
      isConfigured: isConfigured ?? this.isConfigured,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'companyId': companyId,
        'shopName': shopName,
        'ownerName': ownerName,
        'address': address,
        'mobile': mobile,
        'gstin': gstin,
        'gstPercentage': gstPercentage,
        'email': email,
        'logoPreset': logoPreset,
        'logoBase64': logoBase64,
        'paperSize': paperSize,
        'isConfigured': isConfigured,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'ifscCode': ifscCode,
      };

  factory ShopProfile.fromJson(Map<String, dynamic> json, {String? defaultCompanyId}) {
    final rawBase64 = json['logoBase64'] as String? ?? '';
    final name = (json['shopName'] as String? ?? '').trim();
    final email = (json['email'] as String? ?? '').trim();
    final isFlyTowardsLogo = rawBase64 == kDefaultFlyTowardsLogoBase64;
    return ShopProfile(
      companyId: json['companyId'] as String? ?? defaultCompanyId ?? 'default-comp',
      shopName: (name.isEmpty ||
              name.toLowerCase() == 'flytowards digital innovation' ||
              name.toLowerCase() == 'flytowards')
          ? 'My Store'
          : name,
      ownerName: json['ownerName'] as String? ?? '',
      address: json['address'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      gstin: json['gstin'] as String? ?? '',
      gstPercentage: (json['gstPercentage'] as num?)?.toDouble() ?? 18.0,
      email: (email.toLowerCase() == 'info@flytowardsdigitalinnovation.com' ||
              email.toLowerCase() == 'contact@flytowards.com')
          ? ''
          : email,
      logoPreset: json['logoPreset'] as String? ?? 'store',
      logoBase64: isFlyTowardsLogo ? '' : rawBase64,
      paperSize: json['paperSize'] as String? ?? '80mm',
      isConfigured: json['isConfigured'] as bool? ?? true,
      bankName: json['bankName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      ifscCode: json['ifscCode'] as String? ?? '',
    );
  }
}

