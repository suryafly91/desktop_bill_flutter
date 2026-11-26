import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/billing_provider.dart';
import '../theme/app_theme.dart';
import '../models/default_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegisterMode = false;
  bool _isLoading = false;
  String? _errorMessage;

  final _loginEmailOrMobileController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final UserRole _selectedRole = UserRole.admin;

  // Register Controllers
  final _regFormKey = GlobalKey<FormState>();
  final _regEmailOrMobileController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regShopNameController = TextEditingController();
  final _regOwnerNameController = TextEditingController();
  final _regAddressController = TextEditingController();
  final _regMobileController = TextEditingController();
  final _regGstinController = TextEditingController();
  final _regBankNameController = TextEditingController();
  final _regAccountNumberController = TextEditingController();
  final _regIfscCodeController = TextEditingController();
  String _regLogoPreset = 'store';

  final List<Map<String, dynamic>> _logoPresets = [
    {'id': 'store', 'label': 'General Store', 'icon': Icons.storefront_rounded},
    {'id': 'pos', 'label': 'POS & Hardware', 'icon': Icons.point_of_sale_rounded},
    {'id': 'tech', 'label': 'Tech & Electronics', 'icon': Icons.devices_other_rounded},
    {'id': 'apparel', 'label': 'Apparel & Fashion', 'icon': Icons.checkroom_rounded},
    {'id': 'mart', 'label': 'Grocery & Mart', 'icon': Icons.shopping_basket_rounded},
    {'id': 'pharma', 'label': 'Pharmacy & Care', 'icon': Icons.medical_services_rounded},
  ];

  @override
  void dispose() {
    _loginEmailOrMobileController.dispose();
    _loginPasswordController.dispose();

    _regEmailOrMobileController.dispose();
    _regPasswordController.dispose();
    _regShopNameController.dispose();
    _regOwnerNameController.dispose();
    _regAddressController.dispose();
    _regMobileController.dispose();
    _regGstinController.dispose();
    _regBankNameController.dispose();
    _regAccountNumberController.dispose();
    _regIfscCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final input = _loginEmailOrMobileController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both Email/Mobile and Password to log in.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final provider = Provider.of<BillingProvider>(context, listen: false);
    final result = await provider.loginWithCredentials(
      emailOrMobile: input,
      password: password,
      requestedRole: _selectedRole,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (!result.success) {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Invalid login credentials.';
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_regFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final provider = Provider.of<BillingProvider>(context, listen: false);
    final result = await provider.registerCompany(
      emailOrMobile: _regEmailOrMobileController.text.trim(),
      password: _regPasswordController.text.trim(),
      shopName: _regShopNameController.text.trim(),
      ownerName: _regOwnerNameController.text.trim(),
      address: _regAddressController.text.trim(),
      mobile: _regMobileController.text.trim(),
      logoPreset: _regLogoPreset,
      gstin: _regGstinController.text.trim(),
      bankName: _regBankNameController.text.trim(),
      accountNumber: _regAccountNumberController.text.trim(),
      ifscCode: _regIfscCodeController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (!result.success) {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Registration failed. Please check form inputs.';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Company "${_regShopNameController.text.trim()}" registered successfully!',
            style: AppTheme.timesFont(),
          ),
          backgroundColor: AppColors.paid,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _isRegisterMode ? 880 : 820),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Logo Banner Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: AppColors.sidebar,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(kDefaultFlyTowardsLogoBase64),
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FLY-TOWARDS DIGITAL INNOVATION',
                              style: AppTheme.timesFont(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isRegisterMode
                                  ? 'Register New Company Account'
                                  : 'Sign in to access your Company Billing Portal',
                              style: AppTheme.timesFont(
                                fontSize: 13,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Mode Switcher (Login vs Register)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _isRegisterMode = false;
                              _errorMessage = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isRegisterMode ? AppColors.primaryButton : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.login_rounded,
                                  size: 18,
                                  color: !_isRegisterMode ? Colors.white : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Company Login',
                                  style: AppTheme.timesFont(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: !_isRegisterMode ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _isRegisterMode = true;
                              _errorMessage = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isRegisterMode ? AppColors.primaryButton : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.business_rounded,
                                  size: 18,
                                  color: _isRegisterMode ? Colors.white : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Register New Company',
                                  style: AppTheme.timesFont(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: _isRegisterMode ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Error Feedback Banner
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTheme.timesFont(
                              color: const Color(0xFF991B1B),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // BODY CONTENT: LOGIN VS REGISTER FORM
                if (!_isRegisterMode)
                  _buildLoginForm(context)
                else
                  _buildRegisterForm(context),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Created @ FlyTowards',
                    style: AppTheme.timesFont(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Authentication',
            style: AppTheme.timesFont(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your registered Email or Mobile number and Password to identify your company.',
            style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Input Fields
          TextFormField(
            controller: _loginEmailOrMobileController,
            decoration: const InputDecoration(
              labelText: 'Email or Mobile Number *',
              prefixIcon: Icon(Icons.person_outline_rounded),
              hintText: 'Enter Email or Mobile Number',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password *',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleLogin,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded, size: 20),
              label: Text(
                _isLoading
                    ? 'Authenticating & Loading Company Data...'
                    : 'Sign In & Load Company Dashboard',
                style: AppTheme.timesFont(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _regFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Register New Company Profile',
              style: AppTheme.timesFont(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A unique company ID will be created in Firestore. All billing and inventory data will be securely isolated under your company.',
              style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // Step 1: Account Info
            Text(
              '1. Admin Credentials',
              style: AppTheme.timesFont(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryButton),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _regEmailOrMobileController,
                    decoration: const InputDecoration(
                      labelText: 'Email or Mobile Number *',
                      prefixIcon: Icon(Icons.contact_mail_outlined),
                      hintText: 'Enter Email or Mobile Number',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Email or Mobile is required' : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _regPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Create Password *',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Password is required';
                      if (v.trim().length < 6) return 'Minimum 6 characters required';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Step 2: Company Details
            Text(
              '2. Company Details',
              style: AppTheme.timesFont(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryButton),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _regShopNameController,
                    decoration: const InputDecoration(
                      labelText: 'Shop / Company Name *',
                      prefixIcon: Icon(Icons.storefront_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Shop name is required' : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _regMobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact Mobile Number *',
                      prefixIcon: Icon(Icons.phone_android_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Mobile number is required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _regAddressController,
              decoration: const InputDecoration(
                labelText: 'Company Address *',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Address is required' : null,
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _regGstinController,
                    decoration: const InputDecoration(
                      labelText: 'GSTIN Number (Optional)',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                      hintText: 'Enter GSTIN Number',
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _regOwnerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Owner / Manager Name (Optional)',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Bank Information (Optional / Not Required)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _regBankNameController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name (Optional)',
                      prefixIcon: Icon(Icons.account_balance_rounded),
                      hintText: 'Enter Bank Name',
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _regIfscCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'IFSC Code (Optional)',
                      prefixIcon: Icon(Icons.pin_outlined),
                      hintText: 'Enter IFSC Code',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _regAccountNumberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Bank Account Number (Optional)',
                prefixIcon: Icon(Icons.numbers_rounded),
                hintText: 'Enter Bank Account Number',
              ),
            ),
            const SizedBox(height: 20),

            // Logo Preset Selection
            Text(
              'Select Company Logo Preset',
              style: AppTheme.timesFont(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _logoPresets.map((opt) {
                final isSelected = _regLogoPreset == opt['id'];
                return InkWell(
                  onTap: () => setState(() => _regLogoPreset = opt['id'] as String),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryButton.withValues(alpha: 0.1) : AppColors.tableHeader,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? AppColors.primaryButton : AppColors.border, width: isSelected ? 2 : 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(opt['icon'] as IconData, size: 18, color: isSelected ? AppColors.primaryButton : AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          opt['label'] as String,
                          style: AppTheme.timesFont(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.primaryButton : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Register Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleRegister,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _isLoading ? 'Generating Company ID & Registering...' : 'Complete Registration & Open Dashboard',
                  style: AppTheme.timesFont(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryButton,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
