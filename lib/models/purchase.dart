import 'invoice_item.dart';

class Purchase {
  final String id;
  final String purchaseNumber;
  final String supplierId;
  final String supplierName;
  final DateTime date;
  final List<InvoiceItem> items;
  final double totalAmount;
  final String paymentStatus; // Paid, Pending, Partial
  final String notes;

  Purchase({
    required this.id,
    required this.purchaseNumber,
    required this.supplierId,
    required this.supplierName,
    required this.date,
    required this.items,
    required this.totalAmount,
    this.paymentStatus = 'Paid',
    this.notes = '',
  });

  Purchase copyWith({
    String? id,
    String? purchaseNumber,
    String? supplierId,
    String? supplierName,
    DateTime? date,
    List<InvoiceItem>? items,
    double? totalAmount,
    String? paymentStatus,
    String? notes,
  }) {
    return Purchase(
      id: id ?? this.id,
      purchaseNumber: purchaseNumber ?? this.purchaseNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      date: date ?? this.date,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'purchaseNumber': purchaseNumber,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'date': date.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'totalAmount': totalAmount,
        'paymentStatus': paymentStatus,
        'notes': notes,
      };

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: json['id'] as String? ?? '',
        purchaseNumber: json['purchaseNumber'] as String? ?? '',
        supplierId: json['supplierId'] as String? ?? '',
        supplierName: json['supplierName'] as String? ?? '',
        date: json['date'] != null ? DateTime.tryParse(json['date'] as String) ?? DateTime.now() : DateTime.now(),
        items: (json['items'] as List<dynamic>?)?.map((i) => InvoiceItem.fromJson(i as Map<String, dynamic>)).toList() ?? [],
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        paymentStatus: json['paymentStatus'] as String? ?? 'Paid',
        notes: json['notes'] as String? ?? '',
      );
}
