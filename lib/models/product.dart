class Product {
  final String id;
  final String name;
  final double mrpPrice; // MRP Price
  final double unitPrice; // Selling Price
  final double unitCostPrice; // Purchase / Cost Price
  final int stockQuantity; // Current stock count
  final int reorderLevel; // Low stock threshold alert
  final String category;
  final String sku;
  final String size; // Default size e.g. 'M', 'XL', 'Free Size'
  final List<String> availableSizes; // e.g. ['S', 'M', 'L', 'XL', 'XXL', '3XL']
  final String color; // e.g. 'Maroon', 'Navy Blue'
  final String material; // e.g. 'Pure Silk', 'Linen'
  final String unit; // e.g. 'Pcs', 'Meters', 'Sets'

  Product({
    required this.id,
    required this.name,
    required this.mrpPrice,
    required this.unitPrice,
    this.unitCostPrice = 0.0,
    required this.stockQuantity,
    this.reorderLevel = 10,
    this.category = 'General',
    this.sku = 'SKU-001',
    this.size = 'Free Size',
    this.availableSizes = const ['S', 'M', 'L', 'XL', 'XXL', '3XL', 'Free Size'],
    this.color = '',
    this.material = '',
    this.unit = 'Pcs',
  });

  bool get isLowStock => stockQuantity <= reorderLevel;

  // Profit per unit calculated from Selling Price minus Cost
  double get profitPerUnit => unitCostPrice > 0 ? unitPrice - unitCostPrice : 0.0;

  /// Checks if product matches a search query across text attributes,
  /// product ID, SKU string, or numeric ranges (e.g. "1496" inside "1490 to 1499").
  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (name.toLowerCase().contains(q)) return true;
    if (sku.toLowerCase().contains(q)) return true;
    if (category.toLowerCase().contains(q)) return true;
    if (color.toLowerCase().contains(q)) return true;
    if (material.toLowerCase().contains(q)) return true;
    if (size.toLowerCase().contains(q)) return true;
    if (id.toLowerCase().contains(q)) return true;

    // Range matching: e.g. searching "1496" matches range "1490 to 1499"
    final queryNum = int.tryParse(q);
    if (queryNum != null) {
      final matches = RegExp(r'(\d+)').allMatches(sku).map((m) => int.tryParse(m.group(1) ?? '')).whereType<int>().toList();
      if (matches.length >= 2) {
        final start = matches.first;
        final end = matches.last;
        if (start <= end && queryNum >= start && queryNum <= end) {
          return true;
        }
      } else if (matches.length == 1 && matches.first == queryNum) {
        return true;
      }
    }

    return false;
  }

  Product copyWith({
    String? id,
    String? name,
    double? mrpPrice,
    double? unitPrice,
    double? unitCostPrice,
    int? stockQuantity,
    int? reorderLevel,
    String? category,
    String? sku,
    String? size,
    List<String>? availableSizes,
    String? color,
    String? material,
    String? unit,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      mrpPrice: mrpPrice ?? this.mrpPrice,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCostPrice: unitCostPrice ?? this.unitCostPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      category: category ?? this.category,
      sku: sku ?? this.sku,
      size: size ?? this.size,
      availableSizes: availableSizes ?? this.availableSizes,
      color: color ?? this.color,
      material: material ?? this.material,
      unit: unit ?? this.unit,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mrpPrice': mrpPrice,
        'unitPrice': unitPrice,
        'unitCostPrice': unitCostPrice,
        'stockQuantity': stockQuantity,
        'reorderLevel': reorderLevel,
        'category': category,
        'sku': sku,
        'size': size,
        'availableSizes': availableSizes,
        'color': color,
        'material': material,
        'unit': unit,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        mrpPrice: (json['mrpPrice'] as num?)?.toDouble() ?? (json['unitPrice'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        unitCostPrice: (json['unitCostPrice'] as num?)?.toDouble() ?? 0.0,
        stockQuantity: json['stockQuantity'] as int,
        reorderLevel: (json['reorderLevel'] as int?) ?? 10,
        category: (json['category'] as String?) ?? 'General',
        sku: (json['sku'] as String?) ?? 'SKU-001',
        size: (json['size'] as String?) ?? 'Free Size',
        availableSizes: (json['availableSizes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const ['S', 'M', 'L', 'XL', 'XXL', '3XL', 'Free Size'],
        color: (json['color'] as String?) ?? '',
        material: (json['material'] as String?) ?? '',
        unit: (json['unit'] as String?) ?? 'Pcs',
      );
}
