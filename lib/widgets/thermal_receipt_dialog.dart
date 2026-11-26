import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../models/shop_profile.dart';
import 'invoice_preview_dialog.dart';

typedef ThermalReceipt5InchDialog = ThermalReceipt3InchDialog;
typedef ThermalReceipt2InchDialog = ThermalReceipt3InchDialog;

class ThermalReceipt3InchDialog extends StatelessWidget {
  final Invoice invoice;
  final BillPaperSize? paperSize;

  const ThermalReceipt3InchDialog({
    super.key,
    required this.invoice,
    this.paperSize,
  });

  @override
  Widget build(BuildContext context) {
    return InvoicePreviewDialog(
      invoice: invoice,
      initialPaperSize: paperSize ?? BillPaperSize.mm80,
    );
  }
}
