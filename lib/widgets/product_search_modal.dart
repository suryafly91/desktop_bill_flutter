import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';

class TrendingProductSearchModal extends StatefulWidget {
  final Map<String, int> initialSelectedQuantities;
  final Function(Product product) onAddProduct;
  final Function(Product product, int newQuantity)? onUpdateQuantity;

  const TrendingProductSearchModal({
    super.key,
    required this.initialSelectedQuantities,
    required this.onAddProduct,
    this.onUpdateQuantity,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, int> initialSelectedQuantities,
    required Function(Product product) onAddProduct,
    Function(Product product, int newQuantity)? onUpdateQuantity,
    String? initialSearchQuery,
    String? initialCategory,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: TrendingProductSearchModal(
            initialSelectedQuantities: initialSelectedQuantities,
            onAddProduct: onAddProduct,
            onUpdateQuantity: onUpdateQuantity,
          ),
        );
      },
    );
  }

  @override
  State<TrendingProductSearchModal> createState() => _TrendingProductSearchModalState();
}

class _TrendingProductSearchModalState extends State<TrendingProductSearchModal> {
  late TextEditingController _searchController;
  String _selectedCategory = 'All';
  String _sortBy = 'Recommended'; // Recommended, PriceLowToHigh, PriceHighToLow, StockHighToLow
  bool _isGridView = true;
  bool _onlyInStock = false;
  late Map<String, int> _selectedQuantities;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedQuantities = Map<String, int>.from(widget.initialSelectedQuantities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'sarees':
        return const Color(0xFFE11D48); // Rose
      case 'fabrics':
        return const Color(0xFF0284C7); // Sky Blue
      case 'dress materials':
        return const Color(0xFF059669); // Emerald
      case 'shirtings':
        return const Color(0xFF7C3AED); // Violet
      case 'suitings':
        return const Color(0xFFD97706); // Amber
      case 'dupattas':
        return const Color(0xFFDB2777); // Pink
      default:
        return AppColors.primary;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'sarees':
        return Icons.woman_rounded;
      case 'fabrics':
        return Icons.texture_rounded;
      case 'dress materials':
        return Icons.style_rounded;
      case 'shirtings':
        return Icons.checkroom_rounded;
      case 'suitings':
        return Icons.dry_cleaning_rounded;
      case 'dupattas':
        return Icons.content_cut_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  int get _totalSelectedItemsCount {
    return _selectedQuantities.values.fold(0, (sum, q) => sum + q);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BillingProvider>(context);
    final allProducts = provider.products;

    // Build Categories List
    final categories = ['All', ...allProducts.map((p) => p.category).toSet().where((c) => c.isNotEmpty)];

    // Filter products
    List<Product> filteredProducts = allProducts.where((product) {
      final matchesQuery = product.matchesQuery(_searchController.text);
      final matchesCategory = _selectedCategory == 'All' || product.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesStock = !_onlyInStock || product.stockQuantity > 0;

      return matchesQuery && matchesCategory && matchesStock;
    }).toList();

    // Sort products
    if (_sortBy == 'PriceLowToHigh') {
      filteredProducts.sort((a, b) => a.unitPrice.compareTo(b.unitPrice));
    } else if (_sortBy == 'PriceHighToLow') {
      filteredProducts.sort((a, b) => b.unitPrice.compareTo(a.unitPrice));
    } else if (_sortBy == 'StockHighToLow') {
      filteredProducts.sort((a, b) => b.stockQuantity.compareTo(a.stockQuantity));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;
        final gridCrossAxisCount = constraints.maxWidth > 1000 ? 3 : (constraints.maxWidth > 650 ? 2 : 1);

        return Container(
          width: isDesktop ? 900 : double.infinity,
          height: isDesktop ? 720 : MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Trending Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0818A8), Color(0xFF1E2CB8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.manage_search_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Products for Bill',
                            style: AppTheme.timesFont(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${filteredProducts.length} items found • ${allProducts.length} total in catalog',
                            style: AppTheme.timesFont(
                              fontSize: 12,
                              color: const Color(0xFFCCCCFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close Modal',
                    ),
                  ],
                ),
              ),

              // 2. Search & Controls Ribbon
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search product by name, SKU, color, size, material...',
                              prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                        });
                                      },
                                    )
                                  : Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
                                    ),
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Sort Selector Button
                        PopupMenuButton<String>(
                          initialValue: _sortBy,
                          tooltip: 'Sort Products',
                          onSelected: (val) {
                            setState(() {
                              _sortBy = val;
                            });
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'Recommended', child: Text('🔥 Recommended')),
                            const PopupMenuItem(value: 'PriceLowToHigh', child: Text('💰 Price: Low to High')),
                            const PopupMenuItem(value: 'PriceHighToLow', child: Text('💎 Price: High to Low')),
                            const PopupMenuItem(value: 'StockHighToLow', child: Text('📦 Stock: High to Low')),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sort_rounded, color: AppColors.primary, size: 20),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Layout Toggle Button
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.grid_view_rounded,
                                  color: _isGridView ? AppColors.primary : Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _isGridView = true),
                                tooltip: 'Grid View',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.format_list_bulleted_rounded,
                                  color: !_isGridView ? AppColors.primary : Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _isGridView = false),
                                tooltip: 'List View',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filter Pills & Sort Bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...categories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            final count = cat == 'All'
                                ? allProducts.length
                                : allProducts.where((p) => p.category.toLowerCase() == cat.toLowerCase()).length;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                avatar: cat == 'All'
                                    ? const Icon(Icons.apps_rounded, size: 14)
                                    : Icon(_getCategoryIcon(cat), size: 14, color: isSelected ? Colors.white : _getCategoryColor(cat)),
                                label: Text('$cat ($count)'),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                labelStyle: AppTheme.timesFont(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                backgroundColor: const Color(0xFFF1F5F9),
                                onSelected: (sel) {
                                  if (sel) setState(() => _selectedCategory = cat);
                                },
                              ),
                            );
                          }),
                          const VerticalDivider(width: 16, thickness: 1),
                          FilterChip(
                            avatar: const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.paid),
                            label: const Text('In Stock Only'),
                            selected: _onlyInStock,
                            selectedColor: const Color(0xFFDCFCE7),
                            labelStyle: AppTheme.timesFont(
                              color: _onlyInStock ? const Color(0xFF15803D) : AppColors.textPrimary,
                              fontWeight: _onlyInStock ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (val) => setState(() => _onlyInStock = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Product Catalog Grid/List View
              Expanded(
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_rounded, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'No products match your search query',
                              style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try clearing filters or search by a different keyword',
                              style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _selectedCategory = 'All';
                                  _onlyInStock = false;
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Reset All Filters'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            ),
                          ],
                        ),
                      )
                    : _isGridView
                        ? GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridCrossAxisCount,
                              childAspectRatio: 1.25,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              return _buildProductGridCard(product);
                            },
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredProducts.length,
                            separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              return _buildProductListTile(product);
                            },
                          ),
              ),

              // 4. Trending Bottom Action Ribbon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.shopping_basket_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_totalSelectedItemsCount units selected in Bill',
                          style: AppTheme.timesFont(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Tap + or - to adjust item quantities live',
                          style: AppTheme.timesFont(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text('Done & Review Bill ($_totalSelectedItemsCount)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductGridCard(Product product) {
    final qtyInBill = _selectedQuantities[product.id] ?? 0;
    final catColor = _getCategoryColor(product.category);
    final discountPercent = product.mrpPrice > product.unitPrice
        ? (((product.mrpPrice - product.unitPrice) / product.mrpPrice) * 100).round()
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: qtyInBill > 0 ? AppColors.primary : AppColors.border,
          width: qtyInBill > 0 ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: qtyInBill > 0 ? AppColors.primary.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Category & Stock Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getCategoryIcon(product.category), size: 12, color: catColor),
                      const SizedBox(width: 4),
                      Text(
                        product.category,
                        style: AppTheme.timesFont(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: catColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: product.isLowStock ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product.stockQuantity > 0 ? '${product.stockQuantity} ${product.unit}' : 'Out of Stock',
                    style: AppTheme.timesFont(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: product.isLowStock ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Product Name & Variant info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTheme.timesFont(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Size: ${product.size}${product.color.isNotEmpty ? ' • ${product.color}' : ''}',
                  style: AppTheme.timesFont(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Price & Add to bill Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '₹${product.unitPrice.toStringAsFixed(0)}',
                          style: AppTheme.timesFont(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        if (discountPercent > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$discountPercent% OFF',
                              style: AppTheme.timesFont(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (product.mrpPrice > product.unitPrice)
                      Text(
                        'MRP: ₹${product.mrpPrice.toStringAsFixed(0)}',
                        style: AppTheme.timesFont(
                          fontSize: 10,
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),

                // Live Add Controller
                if (qtyInBill == 0)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedQuantities[product.id] = 1;
                      });
                      widget.onAddProduct(product);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 14),
                        const SizedBox(width: 2),
                        Text('Add', style: AppTheme.timesFont(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              final current = _selectedQuantities[product.id] ?? 1;
                              if (current <= 1) {
                                _selectedQuantities.remove(product.id);
                                if (widget.onUpdateQuantity != null) {
                                  widget.onUpdateQuantity!(product, 0);
                                }
                              } else {
                                _selectedQuantities[product.id] = current - 1;
                                if (widget.onUpdateQuantity != null) {
                                  widget.onUpdateQuantity!(product, current - 1);
                                }
                              }
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.remove, color: Colors.white, size: 16),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '$qtyInBill',
                            style: AppTheme.timesFont(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              final current = _selectedQuantities[product.id] ?? 0;
                              _selectedQuantities[product.id] = current + 1;
                              if (widget.onUpdateQuantity != null) {
                                widget.onUpdateQuantity!(product, current + 1);
                              } else {
                                widget.onAddProduct(product);
                              }
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.add, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductListTile(Product product) {
    final qtyInBill = _selectedQuantities[product.id] ?? 0;
    final catColor = _getCategoryColor(product.category);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: qtyInBill > 0 ? AppColors.primary : AppColors.border,
          width: qtyInBill > 0 ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getCategoryIcon(product.category), color: catColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: AppTheme.timesFont(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: product.isLowStock ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${product.stockQuantity} ${product.unit}',
                        style: AppTheme.timesFont(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: product.isLowStock ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Cat: ${product.category} • Size: ${product.size}${product.color.isNotEmpty ? ' • Color: ${product.color}' : ''}',
                  style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${product.unitPrice.toStringAsFixed(0)}',
                style: AppTheme.timesFont(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              if (product.mrpPrice > product.unitPrice)
                Text(
                  'MRP: ₹${product.mrpPrice.toStringAsFixed(0)}',
                  style: AppTheme.timesFont(fontSize: 10, decoration: TextDecoration.lineThrough, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Add / Qty Controls
          if (qtyInBill == 0)
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedQuantities[product.id] = 1;
                });
                widget.onAddProduct(product);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add'),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        final current = _selectedQuantities[product.id] ?? 1;
                        if (current <= 1) {
                          _selectedQuantities.remove(product.id);
                          if (widget.onUpdateQuantity != null) {
                            widget.onUpdateQuantity!(product, 0);
                          }
                        } else {
                          _selectedQuantities[product.id] = current - 1;
                          if (widget.onUpdateQuantity != null) {
                            widget.onUpdateQuantity!(product, current - 1);
                          }
                        }
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.remove, color: Colors.white, size: 16),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '$qtyInBill',
                      style: AppTheme.timesFont(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        final current = _selectedQuantities[product.id] ?? 0;
                        _selectedQuantities[product.id] = current + 1;
                        if (widget.onUpdateQuantity != null) {
                          widget.onUpdateQuantity!(product, current + 1);
                        } else {
                          widget.onAddProduct(product);
                        }
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.add, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
