import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/color_picker_widget.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BillingProvider>(context);
    final theme = provider.previewTheme;

    final presetThemes = [
      {
        'name': 'Classic Royal Blue',
        'theme': const CustomTheme(),
        'color': const Color(0xFF0818A8),
      },
      {
        'name': 'Emerald Eco Mart',
        'theme': const CustomTheme(
          primaryColor: Color(0xFF059669),
          secondaryColor: Color(0xFFA7F3D0),
          backgroundColor: Color(0xFFF0FDF4),
          buttonColor: Color(0xFF059669),
          textColor: Color(0xFF064E3B),
          invoiceHeaderColor: Color(0xFFFFFFFF),
        ),
        'color': const Color(0xFF059669),
      },
      {
        'name': 'Deep Purple Luxe',
        'theme': const CustomTheme(
          primaryColor: Color(0xFF7C3AED),
          secondaryColor: Color(0xFFDDD6FE),
          backgroundColor: Color(0xFFF5F3FF),
          buttonColor: Color(0xFF7C3AED),
          textColor: Color(0xFF4C1D95),
          invoiceHeaderColor: Color(0xFFFFFFFF),
        ),
        'color': const Color(0xFF7C3AED),
      },
      {
        'name': 'Warm Amber Retail',
        'theme': const CustomTheme(
          primaryColor: Color(0xFFD97706),
          secondaryColor: Color(0xFFFDE68A),
          backgroundColor: Color(0xFFFFFBEB),
          buttonColor: Color(0xFFD97706),
          textColor: Color(0xFF78350F),
          invoiceHeaderColor: Color(0xFFFFFFFF),
        ),
        'color': const Color(0xFFD97706),
      },
      {
        'name': 'Crimson Boutique',
        'theme': const CustomTheme(
          primaryColor: Color(0xFFDC2626),
          secondaryColor: Color(0xFFFECACA),
          backgroundColor: Color(0xFFFEF2F2),
          buttonColor: Color(0xFFDC2626),
          textColor: Color(0xFF7F1D1D),
          invoiceHeaderColor: Color(0xFFFFFFFF),
        ),
        'color': const Color(0xFFDC2626),
      },
      {
        'name': 'Midnight Dark Mode',
        'theme': const CustomTheme(
          primaryColor: Color(0xFF1E293B),
          secondaryColor: Color(0xFF475569),
          backgroundColor: Color(0xFF0F172A),
          buttonColor: Color(0xFF2563EB),
          textColor: Color(0xFFF8FAFC),
          invoiceHeaderColor: Color(0xFF1E293B),
        ),
        'color': const Color(0xFF0F172A),
      },
    ];

    void openColorPicker(String key, String title, Color currentColor) {
      showDialog(
        context: context,
        builder: (context) => ColorPickerDialog(
          initialColor: currentColor,
          title: title,
          onColorSelected: (selectedColor) {
            provider.updatePreviewColor(key, selectedColor);
          },
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.secondaryColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.palette_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theme & Appearance Settings',
                            style: AppTheme.timesFont(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Customize your billing desktop application colors with interactive live preview and persistent theme saving.',
                            style: AppTheme.timesFont(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // LIVE PREVIEW CARD
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye_rounded, size: 20, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Live Interface Preview',
                          style: AppTheme.timesFont(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            provider.isThemeModified ? 'Previewing Changes' : 'Saved Theme',
                            style: AppTheme.timesFont(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Mock Application UI Canvas
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: theme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          // Mock Sidebar
                          Container(
                            width: 140,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(11),
                                bottomLeft: Radius.circular(11),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: theme.secondaryColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(Icons.storefront_rounded, size: 14, color: theme.primaryColor),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'FlyBill',
                                        style: AppTheme.timesFont(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _buildMockNavItem('Dashboard', Icons.dashboard_rounded, true, theme),
                                _buildMockNavItem('Invoices', Icons.receipt_long_rounded, false, theme),
                                _buildMockNavItem('Products', Icons.inventory_2_rounded, false, theme),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: theme.secondaryColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Admin Role',
                                    style: AppTheme.timesFont(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Mock Main Content Area
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Business Dashboard',
                                        style: AppTheme.timesFont(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: theme.textColor,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: theme.buttonColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '+ New Bill',
                                          style: AppTheme.timesFont(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: theme.invoiceHeaderColor,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.border),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Today Sales', style: AppTheme.timesFont(fontSize: 9, color: theme.textColor.withValues(alpha: 0.7))),
                                              const SizedBox(height: 2),
                                              Text('₹24,500', style: AppTheme.timesFont(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textColor)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: theme.invoiceHeaderColor,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.border),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Total Invoices', style: AppTheme.timesFont(fontSize: 9, color: theme.textColor.withValues(alpha: 0.7))),
                                              const SizedBox(height: 2),
                                              Text('148 Bills', style: AppTheme.timesFont(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textColor)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // COLOR CUSTOMIZATION GRID (The 6 Required Color Selectors)
              Text(
                'Manual Color Controls:',
                style: AppTheme.timesFont(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Click any color tile to open the manual color picker, adjust RGB/Hex, or select preset swatches.',
                style: AppTheme.timesFont(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildColorTile(
                    title: '1. Primary Color',
                    subtitle: 'Sidebar, Branding & Accent',
                    color: theme.primaryColor,
                    onTap: () => openColorPicker('primary', 'Pick Primary Color', theme.primaryColor),
                  ),
                  _buildColorTile(
                    title: '2. Secondary Color',
                    subtitle: 'Highlights & Badges',
                    color: theme.secondaryColor,
                    onTap: () => openColorPicker('secondary', 'Pick Secondary Color', theme.secondaryColor),
                  ),
                  _buildColorTile(
                    title: '3. Background Color',
                    subtitle: 'Screen Canvas & Dashboard',
                    color: theme.backgroundColor,
                    onTap: () => openColorPicker('background', 'Pick Background Color', theme.backgroundColor),
                  ),
                  _buildColorTile(
                    title: '4. Button Color',
                    subtitle: 'Primary Buttons & CTAs',
                    color: theme.buttonColor,
                    onTap: () => openColorPicker('button', 'Pick Button Color', theme.buttonColor),
                  ),
                  _buildColorTile(
                    title: '5. Text Color',
                    subtitle: 'Body & Typography',
                    color: theme.textColor,
                    onTap: () => openColorPicker('text', 'Pick Text Color', theme.textColor),
                  ),
                  _buildColorTile(
                    title: '6. Invoice/Header Color',
                    subtitle: 'Cards, Header & Table',
                    color: theme.invoiceHeaderColor,
                    onTap: () => openColorPicker('invoiceHeader', 'Pick Invoice/Header Color', theme.invoiceHeaderColor),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // PRESET THEMES PALETTES
              Text(
                'Quick Preset Theme Palettes:',
                style: AppTheme.timesFont(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: presetThemes.map((p) {
                  final presetTheme = p['theme'] as CustomTheme;
                  return InkWell(
                    onTap: () => provider.applyPresetTheme(presetTheme),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: p['color'] as Color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            p['name'] as String,
                            style: AppTheme.timesFont(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // ACTION BUTTONS ROW
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await provider.saveTheme();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Custom theme saved & applied globally across application!',
                                style: AppTheme.timesFont(),
                              ),
                              backgroundColor: AppColors.paid,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_rounded, size: 20),
                      label: const Text('Save Theme'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.buttonColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await provider.resetTheme();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Theme reset to default Royal Blue palette.',
                                style: AppTheme.timesFont(),
                              ),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 20),
                      label: const Text('Reset to Default'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.dueOverdue,
                        side: const BorderSide(color: AppColors.dueOverdue),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockNavItem(String title, IconData icon, bool active, CustomTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? theme.secondaryColor.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: active ? theme.secondaryColor : Colors.white70),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: AppTheme.timesFont(
                  color: active ? Colors.white : Colors.white70,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorTile({
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final hexString = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withValues(alpha: 0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTheme.timesFont(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$subtitle ($hexString)',
                    style: AppTheme.timesFont(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.colorize_rounded, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
