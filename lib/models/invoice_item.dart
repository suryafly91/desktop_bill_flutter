class InvoiceItem {
  final String id;
  final String description;
  final int quantity;
  final double unitPrice; // Selling Price
  final double mrpPrice; // MRP Price
  final double costPrice; // Purchase / Cost Price
  final double discount; // Line Item Discount (₹)
  final String size; // e.g. 'M', 'L', 'XL', 'XXL', 'Free Size', '2.5m'
  final String color; // e.g. 'Red/Gold', 'Navy Blue'
  final String unit; // e.g. 'Pcs', 'Meters', 'Sets'

  InvoiceItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.mrpPrice = 0.0,
    this.costPrice = 0.0,
    this.discount = 0.0,
    this.size = '',
    this.color = '',
    this.unit = 'Pcs',
  });

  // Display label with size and color for receipts & invoices
  String get fullDescription {
    final cleanDesc = description.replaceAll(RegExp(r'\s*\([sS]ize\s*:\s*[mM]\)', caseSensitive: false), '').trim();
    final details = <String>[];
    final cleanSize = size.trim();
    if (cleanSize.isNotEmpty &&
        cleanSize.toUpperCase() != 'M' &&
        cleanSize != 'N/A' &&
        cleanSize != 'Free Size' &&
        cleanSize.toLowerCase() != 'none') {
      details.add('Size: $cleanSize');
    }
    final cleanColor = color.trim();
    if (cleanColor.isNotEmpty &&
        cleanColor != 'N/A' &&
        cleanColor.toLowerCase() != 'none') {
      details.add('Color: $cleanColor');
    }
    if (details.isEmpty) return cleanDesc;
    return '$cleanDesc (${details.join(', ')})';
  }

  // Gross selling price without item discount
  double get grossPrice => quantity * unitPrice;

  // Total Selling Price for this line item (accounting for line-item discount)
  double get totalPrice {
    final total = (quantity * unitPrice) - discount;
    return total < 0 ? 0.0 : total;
  }

  // Total MRP Price for this line item
  double get totalMrp => quantity * (mrpPrice > 0 ? mrpPrice : unitPrice);

  // Total Cost Price for this line item (falls back to Selling Price if unassigned)
  double get totalCost => quantity * (costPrice > 0 ? costPrice : unitPrice);

  // Item Gross Profit (Selling Total - Cost Total)
  double get itemProfit => totalPrice - totalCost;

  InvoiceItem copyWith({
    String? id,
    String? description,
    int? quantity,
    double? unitPrice,
    double? mrpPrice,
    double? costPrice,
    double? discount,
    String? size,
    String? color,
    String? unit,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      mrpPrice: mrpPrice ?? this.mrpPrice,
      costPrice: costPrice ?? this.costPrice,
      discount: discount ?? this.discount,
      size: size ?? this.size,
      color: color ?? this.color,
      unit: unit ?? this.unit,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'mrpPrice': mrpPrice,
        'costPrice': costPrice,
        'discount': discount,
        'size': size,
        'color': color,
        'unit': unit,
      };

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final rawDesc = (json['description'] as String? ?? '').trim();
    final cleanDesc = rawDesc.replaceAll(RegExp(r'\s*\([sS]ize\s*:\s*[mM]\)', caseSensitive: false), '').trim();
    final rawSize = (json['size'] as String?) ?? '';
    final cleanSize = (rawSize.trim().toUpperCase() == 'M') ? '' : rawSize.trim();
    return InvoiceItem(
      id: json['id'] as String? ?? '',
      description: cleanDesc,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      mrpPrice: (json['mrpPrice'] as num?)?.toDouble() ?? 0.0,
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      size: cleanSize,
      color: (json['color'] as String?) ?? '',
      unit: (json['unit'] as String?) ?? 'Pcs',
    );
  }
}
