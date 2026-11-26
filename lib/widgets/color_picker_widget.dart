import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String title;
  final ValueChanged<Color> onColorSelected;

  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.title,
    required this.onColorSelected,
  });

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;
  late TextEditingController _hexController;

  // Preset Color Swatches Palette
  final List<Color> _swatches = const [
    Color(0xFF0818A8), // Royal Blue
    Color(0xFF2563EB), // Primary Blue
    Color(0xFF0284C7), // Sky Blue
    Color(0xFF0D9488), // Teal
    Color(0xFF16A34A), // Emerald Green
    Color(0xFF059669), // Forest Green
    Color(0xFFD97706), // Amber
    Color(0xFFEA580C), // Orange
    Color(0xFFDC2626), // Crimson Red
    Color(0xFFE11D48), // Rose
    Color(0xFF9333EA), // Purple
    Color(0xFF4F46E5), // Indigo
    Color(0xFF475569), // Slate
    Color(0xFF1E293B), // Dark Charcoal
    Color(0xFFF8FAFC), // Off-White
    Color(0xFFFFFFFF), // Pure White
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _hexController = TextEditingController(text: _colorToHex(_selectedColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  void _onHexSubmitted(String val) {
    String hex = val.replaceAll('#', '').trim();
    if (hex.length == 6) {
      final intValue = int.tryParse('FF$hex', radix: 16);
      if (intValue != null) {
        setState(() {
          _selectedColor = Color(intValue);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _selectedColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTheme.timesFont(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Swatches Grid Title
              Text(
                'Select Preset Color Swatch:',
                style: AppTheme.timesFont(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),

              // Swatches Grid
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _swatches.map((color) {
                  final isSelected = color.toARGB32() == _selectedColor.toARGB32();
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                        _hexController.text = _colorToHex(color);
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.black.withValues(alpha: 0.15),
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Divider(color: AppColors.border),
              const SizedBox(height: 14),

              // RGB Sliders for Manual Fine-tuning
              Text(
                'Manual RGB Fine-Tuning:',
                style: AppTheme.timesFont(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              _buildColorSlider('R', _selectedColor.r, (val) {
                setState(() {
                  _selectedColor = Color.from(
                    alpha: _selectedColor.a,
                    red: val,
                    green: _selectedColor.g,
                    blue: _selectedColor.b,
                  );
                  _hexController.text = _colorToHex(_selectedColor);
                });
              }, Colors.red),

              _buildColorSlider('G', _selectedColor.g, (val) {
                setState(() {
                  _selectedColor = Color.from(
                    alpha: _selectedColor.a,
                    red: _selectedColor.r,
                    green: val,
                    blue: _selectedColor.b,
                  );
                  _hexController.text = _colorToHex(_selectedColor);
                });
              }, Colors.green),

              _buildColorSlider('B', _selectedColor.b, (val) {
                setState(() {
                  _selectedColor = Color.from(
                    alpha: _selectedColor.a,
                    red: _selectedColor.r,
                    green: _selectedColor.g,
                    blue: val,
                  );
                  _hexController.text = _colorToHex(_selectedColor);
                });
              }, Colors.blue),

              const SizedBox(height: 14),

              // Hex Input & Color Comparison
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      onChanged: _onHexSubmitted,
                      decoration: const InputDecoration(
                        labelText: 'Hex Code',
                        prefixText: '',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.tableHeader,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Text('Old', style: AppTheme.timesFont(fontSize: 10, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: widget.initialColor,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.black12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Column(
                          children: [
                            Text('New', style: AppTheme.timesFont(fontSize: 10, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _selectedColor,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.black12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onColorSelected(_selectedColor);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Select Color'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorSlider(String label, double value, ValueChanged<double> onChanged, Color activeColor) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            label,
            style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold, color: activeColor),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              activeColor: activeColor,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '${(value * 255).round()}',
            textAlign: TextAlign.right,
            style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
