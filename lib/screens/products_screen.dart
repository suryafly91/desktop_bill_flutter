import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _searchQuery = '';

  void _showAdjustStockDialog(BuildContext context, Product product) {
    final stockController = TextEditingController(text: product.stockQuantity.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.invoiceCard,
          title: Text(
            'Adjust Stock Quantity',
            style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product: ${product.name}',
                style: AppTheme.timesFont(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Current Stock: ${product.stockQuantity} units',
                style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: stockController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'New Stock Level (Units) *',
                  prefixIcon: Icon(Icons.inventory_2_rounded, color: AppColors.primary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: AppTheme.timesFont(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final newStock = int.tryParse(stockController.text);
                if (newStock != null) {
                  final provider = Provider.of<BillingProvider>(context, listen: false);
                  provider.adjustProductStock(product.id, newStock);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stock updated to $newStock units for ${product.name}.', style: AppTheme.timesFont()),
                      backgroundColor: AppColors.paid,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save Stock'),
            ),
          ],
        );
      },
    );
  }

  void _showAddProductDialog(BuildContext context, {Product? editProduct}) {
    final provider = Provider.of<BillingProvider>(context, listen: false);
    final nameController = TextEditingController(text: editProduct?.name ?? '');
    final mrpPriceController = TextEditingController(text: editProduct != null ? editProduct.mrpPrice.toStringAsFixed(2) : '');
    final sellingPriceController = TextEditingController(text: editProduct != null ? editProduct.unitPrice.toStringAsFixed(2) : '');
    final stockController = TextEditingController(text: editProduct != null ? editProduct.stockQuantity.toString() : '');
    final costPriceController = TextEditingController(text: editProduct != null ? editProduct.unitCostPrice.toStringAsFixed(2) : '');
    final categoryController = TextEditingController(text: editProduct?.category ?? '');
    final colorController = TextEditingController(text: editProduct?.color ?? '');
    final materialController = TextEditingController(text: editProduct?.material ?? '');

    String selectedSize = editProduct?.size ?? 'Free Size';
    String selectedUnit = editProduct?.unit ?? 'Pcs';
    const sizeOptions = ['S', 'M', 'L', 'XL', 'XXL', '3XL', 'Free Size', 'Meter', 'N/A'];
    const unitOptions = ['Pcs', 'Meters', 'Sets', 'Rolls'];
    if (!sizeOptions.contains(selectedSize)) selectedSize = 'Free Size';
    if (!unitOptions.contains(selectedUnit)) selectedUnit = 'Pcs';

    final isEdit = editProduct != null;

    final initialStock = int.tryParse(stockController.text) ?? 0;
    final initialSku = isEdit ? editProduct.sku : (initialStock > 0 ? provider.calculateProductSkuRange(initialStock) : '');
    final skuController = TextEditingController(text: initialSku);

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEdit ? 'Edit Product' : 'Add New Product (ID: ${provider.nextProductId})',
                            style: AppTheme.timesFont(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: nameController,
                        autofocus: !isEdit,
                        decoration: InputDecoration(
                          labelText: 'Product Name *',
                          prefixIcon: Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Product name is required' : null,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedSize,
                              decoration: InputDecoration(
                                labelText: 'Garment Size *',
                                prefixIcon: Icon(Icons.straighten_rounded, color: AppColors.primary),
                              ),
                              items: sizeOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedSize = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: colorController,
                              decoration: InputDecoration(
                                labelText: 'Color / Pattern',
                                prefixIcon: Icon(Icons.palette_outlined, color: AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: materialController,
                              decoration: InputDecoration(
                                labelText: 'Material / Fabric',
                                prefixIcon: Icon(Icons.texture_rounded, color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedUnit,
                              decoration: InputDecoration(
                                labelText: 'Billing Unit *',
                                prefixIcon: Icon(Icons.square_foot_rounded, color: AppColors.primary),
                              ),
                              items: unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedUnit = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: mrpPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'MRP Price (₹) *',
                                prefixIcon: Icon(Icons.sell_outlined, color: AppColors.primary),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'MRP is required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: sellingPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Selling Price (₹) *',
                                prefixIcon: Icon(Icons.payments_outlined, color: AppColors.primary),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Selling price is required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: stockController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Stock Qty *',
                                prefixIcon: Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                              ),
                              onChanged: (v) {
                                final stockVal = int.tryParse(v) ?? 0;
                                if (!isEdit) {
                                  final newRange = provider.calculateProductSkuRange(stockVal);
                                  setModalState(() {
                                    skuController.text = newRange;
                                  });
                                }
                              },
                              validator: (v) => v == null || v.trim().isEmpty ? 'Stock is required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: costPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Cost Price (Optional ₹)',
                                prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: categoryController,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                prefixIcon: Icon(Icons.category_outlined, color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: skuController,
                              decoration: InputDecoration(
                                labelText: 'Product ID / Stock Range',
                                prefixIcon: Icon(Icons.qr_code_outlined, color: AppColors.primary),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.auto_awesome, size: 18),
                                  tooltip: 'Auto-calculate Next Sequential Range',
                                  onPressed: () {
                                    final stockVal = int.tryParse(stockController.text) ?? 1;
                                    final newRange = provider.calculateProductSkuRange(
                                      stockVal,
                                      excludeProductId: editProduct?.id,
                                    );
                                    setModalState(() {
                                      skuController.text = newRange;
                                    });
                                  },
                                ),
                              ),
                              validator: (v) {
                                if (v != null && v.trim().isNotEmpty) {
                                  if (provider.isSkuDuplicate(v.trim(), excludeProductId: editProduct?.id)) {
                                    return 'Product ID already in use';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.tableHeader,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isEdit
                                    ? 'Assigned Product ID / Range: ${skuController.text}'
                                    : 'Auto Product Range: ${skuController.text}',
                                style: AppTheme.timesFont(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              final mrp = double.tryParse(mrpPriceController.text.trim()) ?? 0.0;
                              final selling = double.tryParse(sellingPriceController.text.trim()) ?? 0.0;
                              final cost = double.tryParse(costPriceController.text.trim()) ?? (mrp > 0 ? mrp : selling);
                              final stock = int.tryParse(stockController.text.trim()) ?? 0;
                              final name = nameController.text.trim();
                              final category = categoryController.text.trim().isEmpty ? 'General' : categoryController.text.trim();
                              final sku = skuController.text.trim().isEmpty
                                  ? provider.calculateProductSkuRange(stock, excludeProductId: editProduct?.id)
                                  : skuController.text.trim();
                              final color = colorController.text.trim();
                              final material = materialController.text.trim();

                              if (isEdit) {
                                final updated = editProduct.copyWith(
                                  name: name,
                                  mrpPrice: mrp,
                                  unitPrice: selling,
                                  unitCostPrice: cost,
                                  stockQuantity: stock,
                                  category: category,
                                  sku: sku,
                                  size: selectedSize,
                                  color: color,
                                  material: material,
                                  unit: selectedUnit,
                                );
                                provider.updateProduct(updated);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Product "$name" updated successfully!', style: AppTheme.timesFont()), backgroundColor: AppColors.paid),
                                );
                              } else {
                                final newProduct = Product(
                                  id: 'prod-${provider.nextProductId}',
                                  name: name,
                                  mrpPrice: mrp,
                                  unitPrice: selling,
                                  unitCostPrice: cost,
                                  stockQuantity: stock,
                                  reorderLevel: 10,
                                  category: category,
                                  sku: sku,
                                  size: selectedSize,
                                  color: color,
                                  material: material,
                                  unit: selectedUnit,
                                );
                                provider.addProduct(newProduct);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Product "$name" added with SKU range "$sku"!', style: AppTheme.timesFont()), backgroundColor: AppColors.paid),
                                );
                              }
                              Navigator.of(context).pop();
                            }
                          },
                          icon: Icon(isEdit ? Icons.check_circle_outline : Icons.add_circle_outline, size: 20),
                          label: Text(isEdit ? 'Update Product' : 'Save Product'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final provider = Provider.of<BillingProvider>(context);

    final filteredProducts = provider.products.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.matchesQuery(_searchQuery);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Title Header on Mobile
              if (isMobile) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Products & Stock',
                      style: AppTheme.timesFont(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddProductDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Search Bar & Desktop Add Button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        labelText: 'Search Products',
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddProductDialog(context),
                      icon: const Icon(Icons.add_box_rounded, size: 18),
                      label: const Text('+ Add Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Summary Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStatCard(
                      'Total Items',
                      '${provider.products.length}',
                      Icons.inventory_2_outlined,
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniStatCard(
                      'Low Stock Alerts',
                      '${provider.lowStockProducts.length}',
                      Icons.warning_amber_rounded,
                      provider.lowStockProducts.isNotEmpty ? AppColors.dueOverdue : AppColors.paid,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Product List Section
              filteredProducts.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_outlined, size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'No products found',
                            style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "+ Add Product" to create your first product inventory item.',
                            style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : isMobile
                      ? ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredProducts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final p = filteredProducts[index];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: p.isLowStock ? AppColors.dueOverdue.withValues(alpha: 0.5) : AppColors.border,
                                  width: p.isLowStock ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.name,
                                          style: AppTheme.timesFont(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: p.isLowStock ? AppColors.dueOverdue.withValues(alpha: 0.1) : AppColors.paid.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Stock: ${p.stockQuantity}',
                                          style: AppTheme.timesFont(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: p.isLowStock ? AppColors.dueOverdue : AppColors.paid,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'SKU: ${p.sku} • Category: ${p.category} • Unit: ${p.unit}',
                                    style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('Size: ${p.size}', style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      ),
                                      if (p.color.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text('Color: ${p.color}', style: AppTheme.timesFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent)),
                                        ),
                                      if (p.material.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.border,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text('Fabric: ${p.material}', style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary)),
                                        ),
                                    ],
                                  ),
                                  const Divider(height: 16, color: AppColors.border),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'MRP Price',
                                            style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                          Text(
                                            currencyFormatter.format(p.mrpPrice),
                                            style: AppTheme.timesFont(
                                              fontSize: 13,
                                              decoration: TextDecoration.lineThrough,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Selling Price',
                                            style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                          Text(
                                            currencyFormatter.format(p.unitPrice),
                                            style: AppTheme.timesFont(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                                            onPressed: () => _showAddProductDialog(context, editProduct: p),
                                            tooltip: 'Edit Product',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.paid),
                                            onPressed: () => _showAdjustStockDialog(context, p),
                                            tooltip: 'Adjust Stock',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth - 48),
                              child: Column(
                                children: [
                                  // Header Bar
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    decoration: BoxDecoration(color: AppColors.tableHeader,
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 140, child: Text('SKU Code', style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.primary))),
                                        SizedBox(width: 250, child: Text('Product & Textile Specs', style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.primary))),
                                        SizedBox(width: 110, child: Text('MRP Price', textAlign: TextAlign.right, style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.primary))),
                                        SizedBox(width: 120, child: Text('Selling Price', textAlign: TextAlign.right, style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.primary))),
                                        SizedBox(width: 130, child: Text('Current Stock', textAlign: TextAlign.center, style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.primary))),
                                        SizedBox(width: 130, child: Text('Actions', textAlign: TextAlign.right, style: AppTheme.timesFont(fontWeight: FontWeight.bold, color: AppColors.primary))),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: filteredProducts.map((p) {




                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        child: Row(
                                          children: [
                                            SizedBox(width: 140, child: Text(p.sku, style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary))),
                                            SizedBox(
                                              width: 250,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(p.name, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                                  const SizedBox(height: 2),
                                                  Wrap(
                                                    spacing: 4,
                                                    runSpacing: 2,
                                                    children: [
                                                      Text('${p.category} • ', style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary)),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.primary.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text('Size: ${p.size}', style: AppTheme.timesFont(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                                      ),
                                                      if (p.color.isNotEmpty)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.accent.withValues(alpha: 0.15),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(p.color, style: AppTheme.timesFont(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent)),
                                                        ),
                                                      if (p.unit != 'Pcs')
                                                        Text('(${p.unit})', style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 110,
                                              child: Text(
                                                currencyFormatter.format(p.mrpPrice),
                                                textAlign: TextAlign.right,
                                                style: AppTheme.timesFont(fontSize: 13, decoration: TextDecoration.lineThrough, color: AppColors.textSecondary),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 120,
                                              child: Text(
                                                currencyFormatter.format(p.unitPrice),
                                                textAlign: TextAlign.right,
                                                style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 130,
                                              child: Center(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: p.isLowStock ? AppColors.dueOverdue.withValues(alpha: 0.12) : AppColors.paid.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: p.isLowStock ? AppColors.dueOverdue : AppColors.paid),
                                                  ),
                                                  child: Text(
                                                    '${p.stockQuantity} units',
                                                    style: AppTheme.timesFont(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: p.isLowStock ? AppColors.dueOverdue : AppColors.paid,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 130,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                                    onPressed: () => _showAddProductDialog(context, editProduct: p),
                                                    tooltip: 'Edit',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.paid),
                                                    onPressed: () => _showAdjustStockDialog(context, p),
                                                    tooltip: 'Stock',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.dueOverdue),
                                                    onPressed: () {
                                                      provider.deleteProduct(p.id);
                                                    },
                                                    tooltip: 'Delete',
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStatCard(String title, String count, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary)),
              Text(count, style: AppTheme.timesFont(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}


