import 'invoice_item.dart';

enum InvoiceStatus { paid, pending, overdue, quotation }

extension InvoiceStatusExtension on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.pending:
        return 'Pending Khata';
      case InvoiceStatus.overdue:
        return 'Due / Overdue';
      case InvoiceStatus.quotation:
        return 'Quotation';
    }
  }
}

enum PaymentMethod { cash, upi, card, netBanking, cheque }

extension PaymentMethodExtension on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI / QR Code';
      case PaymentMethod.card:
        return 'Credit / Debit Card';
      case PaymentMethod.netBanking:
        return 'Net Banking';
      case PaymentMethod.cheque:
        return 'Cheque / Draft';
    }
  }
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final DateTime issueDate;
  final DateTime dueDate;
  final List<InvoiceItem> items;
  final double taxPercent;
  final double discountPercent;
  final double discountAmountValue;
  final bool isGstBill;
  final InvoiceStatus status;
  final PaymentMethod paymentMethod;
  final String paymentRef;
  final String notes;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    this.customerPhone = '',
    required this.issueDate,
    required this.dueDate,
    required this.items,
    this.taxPercent = 0.0,
    this.discountPercent = 0.0,
    this.discountAmountValue = 0.0,
    bool? isGstBill,
    required this.status,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentRef = '',
    this.notes = '',
  }) : isGstBill = isGstBill ?? (taxPercent > 0);

  // Total of line items before any line-item discounts (gross total)
  double get grossSubtotal => items.fold(0.0, (sum, item) => sum + item.grossPrice);

  // Total discounts applied across individual line items
  double get totalItemDiscounts => items.fold(0.0, (sum, item) => sum + item.discount);

  // Subtotal (sum of item.totalPrice, which is grossSubtotal - totalItemDiscounts)
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get taxAmount => isGstBill ? (subtotal * taxPercent) / 100.0 : 0.0;

  // Bill-level overall discount amount (from flat amount or percent)
  double get discountAmount {
    if (discountAmountValue > 0) {
      return discountAmountValue;
    }
    return (subtotal * discountPercent) / 100.0;
  }

  // Combined total discount on the bill (item-level discounts + bill-level discount)
  double get totalDiscount => totalItemDiscounts + discountAmount;

  // Final grand total payable
  double get totalAmount {
    final grand = subtotal + taxAmount - discountAmount;
    return grand < 0 ? 0.0 : grand;
  }

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    String? customerId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    DateTime? issueDate,
    DateTime? dueDate,
    List<InvoiceItem>? items,
    double? taxPercent,
    double? discountPercent,
    double? discountAmountValue,
    bool? isGstBill,
    InvoiceStatus? status,
    PaymentMethod? paymentMethod,
    String? paymentRef,
    String? notes,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      items: items ?? this.items,
      taxPercent: taxPercent ?? this.taxPercent,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmountValue: discountAmountValue ?? this.discountAmountValue,
      isGstBill: isGstBill ?? this.isGstBill,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentRef: paymentRef ?? this.paymentRef,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'customerId': customerId,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'customerPhone': customerPhone,
        'issueDate': issueDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'taxPercent': taxPercent,
        'discountPercent': discountPercent,
        'discountAmountValue': discountAmountValue,
        'isGstBill': isGstBill,
        'status': status.name,
        'paymentMethod': paymentMethod.name,
        'paymentRef': paymentRef,
        'notes': notes,
      };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'] as String,
        invoiceNumber: json['invoiceNumber'] as String,
        customerId: json['customerId'] as String,
        customerName: json['customerName'] as String,
        customerEmail: json['customerEmail'] as String,
        customerPhone: (json['customerPhone'] as String?) ?? '',
        issueDate: DateTime.parse(json['issueDate'] as String),
        dueDate: DateTime.parse(json['dueDate'] as String),
        items: (json['items'] as List<dynamic>)
            .map((itemJson) => InvoiceItem.fromJson(itemJson as Map<String, dynamic>))
            .toList(),
        taxPercent: (json['taxPercent'] as num?)?.toDouble() ?? 0.0,
        discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
        discountAmountValue: (json['discountAmountValue'] as num?)?.toDouble() ?? 0.0,
        isGstBill: json['isGstBill'] as bool?,
        status: InvoiceStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => InvoiceStatus.paid,
        ),
        paymentMethod: PaymentMethod.values.firstWhere(
          (e) => e.name == json['paymentMethod'],
          orElse: () => PaymentMethod.cash,
        ),
        paymentRef: (json['paymentRef'] as String?) ?? '',
        notes: (json['notes'] as String?) ?? '',
      );
}
