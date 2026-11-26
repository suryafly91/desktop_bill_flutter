import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/shop_profile.dart';
import '../providers/billing_provider.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';

class PrinterDiagnosticScreen extends StatefulWidget {
  const PrinterDiagnosticScreen({super.key});

  @override
  State<PrinterDiagnosticScreen> createState() => _PrinterDiagnosticScreenState();
}

class _PrinterDiagnosticScreenState extends State<PrinterDiagnosticScreen> {
  bool _isLoading = false;
  bool _isScanning = false;
  bool _isPrintingTest = false;

  bool _isBluetoothEnabled = false;
  BluetoothPermissionStatus _permissionStatus = BluetoothPermissionStatus.notRequired;
  int _stuckJobCount = 0;

  List<BluetoothPrinterDevice> _pairedDevices = [];
  List<BluetoothPrinterDevice> _discoveredDevices = [];
  List<String> _windowsComPorts = [];
  List<Printer> _spoolerPrinters = [];

  UniversalPrinterConfig _savedConfig = const UniversalPrinterConfig(
    type: PrinterConnectionType.auto,
    name: 'Windows System Default',
  );

  BillPaperSize _testPaperSize = BillPaperSize.mm58;
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initDiagnostics();
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  void _addLog(String message, {bool isError = false}) {
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
    final entry = '[$timeStr] ${isError ? "ERROR: " : ""}$message';
    setState(() {
      _logs.add(entry);
    });
    debugPrint(entry);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _initDiagnostics() async {
    setState(() => _isLoading = true);
    _addLog('Initializing printer hardware & configuration...');

    try {
      // 1. Check Permissions
      _permissionStatus = await BluetoothPrinterService.checkPermissions();
      _addLog('Permissions status: ${_permissionStatus.name}');

      // 2. Check Adapter Enabled
      _isBluetoothEnabled = await BluetoothPrinterService.isBluetoothEnabled();
      _addLog('Bluetooth adapter enabled: $_isBluetoothEnabled');

      // 3. Load Saved Settings
      _savedConfig = await BluetoothPrinterService.getSavedPrinterConfig();
      _addLog('Saved billing printer: ${_savedConfig.name} (${_savedConfig.typeLabel})');

      // 4. Fetch Paired Devices
      await _refreshPairedDevices(silent: true);

      // 5. Windows specific ports & spooler
      if (!kIsWeb && Platform.isWindows) {
        await _refreshWindowsPorts(silent: true);
        await _refreshSpoolerPrinters(silent: true);
        _stuckJobCount = await BluetoothPrinterService.getWindowsStuckJobCount();
        if (_stuckJobCount > 0) {
          _addLog('Warning: $_stuckJobCount stuck print job(s) found in Windows spooler.', isError: true);
        }
      }
    } catch (e) {
      _addLog('Initialization failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearSpoolerQueue() async {
    _addLog('Clearing stuck print jobs from Windows print spooler...');
    setState(() => _isLoading = true);
    try {
      final success = await BluetoothPrinterService.clearWindowsSpoolerQueue();
      _stuckJobCount = await BluetoothPrinterService.getWindowsStuckJobCount();
      if (success || _stuckJobCount == 0) {
        _addLog('Print queue cleared successfully. Ports unblocked.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Windows print queue cleared successfully!', style: AppTheme.timesFont()),
              backgroundColor: AppColors.paid,
            ),
          );
        }
      } else {
        _addLog('Could not clear all print jobs.', isError: true);
      }
      await _refreshSpoolerPrinters(silent: true);
    } catch (e) {
      _addLog('Failed to clear queue: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshPairedDevices({bool silent = false}) async {
    try {
      if (!silent) _addLog('Querying paired Bluetooth Classic devices...');
      final devices = await BluetoothPrinterService.getPairedBluetoothDevices();
      setState(() {
        _pairedDevices = devices;
      });
      _addLog('Found ${devices.length} paired Bluetooth device(s).');
    } catch (e) {
      _addLog('Failed to query paired devices: $e', isError: true);
    }
  }

  Future<void> _requestPermissions() async {
    _addLog('Requesting Bluetooth permissions from user...');
    try {
      final status = await BluetoothPrinterService.requestPermissions();
      setState(() {
        _permissionStatus = status;
      });
      _addLog('Permission request result: ${status.name}');
      if (status == BluetoothPermissionStatus.permanentlyDenied) {
        _addLog('Permissions permanently denied. Opening App Settings...');
        await BluetoothPrinterService.openAppSettings();
      }
      _refreshPairedDevices();
    } catch (e) {
      _addLog('Error requesting permissions: $e', isError: true);
    }
  }

  Future<void> _enableBluetooth() async {
    _addLog('Requesting system to enable Bluetooth...');
    try {
      final enabled = await BluetoothPrinterService.enableBluetooth();
      setState(() {
        _isBluetoothEnabled = enabled;
      });
      _addLog('Bluetooth enabled response: $enabled');
      _refreshPairedDevices();
    } catch (e) {
      _addLog('Error enabling Bluetooth: $e', isError: true);
    }
  }

  Future<void> _startDiscoveryScan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _discoveredDevices = [];
    });
    _addLog('Starting 10-second Bluetooth Classic discovery scan...');

    try {
      final results = await BluetoothPrinterService.scanBluetoothDevices(
        timeout: const Duration(seconds: 10),
      );
      setState(() {
        _discoveredDevices = results;
      });
      _addLog('Scan completed. Discovered ${results.length} device(s).');
    } catch (e) {
      _addLog('Discovery scan failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _refreshWindowsPorts({bool silent = false}) async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      if (!silent) _addLog('Scanning active Windows COM serial ports...');
      final ports = await BluetoothPrinterService.getWindowsComPorts();
      setState(() {
        _windowsComPorts = ports;
      });
      _addLog('Found ${ports.length} Windows COM port(s): ${ports.join(", ")}');
    } catch (e) {
      _addLog('Failed to get Windows COM ports: $e', isError: true);
    }
  }

  Future<void> _refreshSpoolerPrinters({bool silent = false}) async {
    try {
      if (!silent) _addLog('Scanning Windows spooler printers...');
      final printers = await BluetoothPrinterService.getAvailablePrinters();
      setState(() {
        _spoolerPrinters = printers;
      });
      _addLog('Found ${printers.length} spooler printer(s): ${printers.map((p) => p.name).join(", ")}');
    } catch (e) {
      _addLog('Failed to get spooler printers: $e', isError: true);
    }
  }

  Future<void> _connectToBluetoothDevice(BluetoothPrinterDevice device) async {
    _addLog('Attempting connection to ${device.displayName} (${device.address})...');
    setState(() => _isLoading = true);
    try {
      final success = await BluetoothPrinterService.connectBluetooth(
        address: device.address,
        name: device.displayName,
      );
      if (success) {
        _addLog('Successfully connected to ${device.displayName}!');
        final cfg = await BluetoothPrinterService.getSavedPrinterConfig();
        setState(() {
          _savedConfig = cfg;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${device.displayName}', style: AppTheme.timesFont()),
              backgroundColor: AppColors.paid,
            ),
          );
        }
      }
    } catch (e) {
      _addLog('Connection failed: $e', isError: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e', style: AppTheme.timesFont()),
            backgroundColor: AppColors.dueOverdue,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectComPort(String comPort) async {
    _addLog('Selecting Windows Serial port: $comPort...');
    setState(() => _isLoading = true);
    try {
      final success = await BluetoothPrinterService.selectWindowsComPort(comPort);
      if (success) {
        _addLog('Port $comPort activated for direct ESC/POS thermal printing.');
        final cfg = await BluetoothPrinterService.getSavedPrinterConfig();
        setState(() {
          _savedConfig = cfg;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Activated $comPort for thermal billing', style: AppTheme.timesFont()),
              backgroundColor: AppColors.paid,
            ),
          );
        }
      }
    } catch (e) {
      _addLog('Error activating COM port: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectSpoolerPrinter(Printer printer) async {
    _addLog('Setting "${printer.name}" as active billing printer...');
    setState(() => _isLoading = true);
    try {
      await BluetoothPrinterService.selectSystemPrinter(printer);
      final cfg = await BluetoothPrinterService.getSavedPrinterConfig();
      setState(() {
        _savedConfig = cfg;
      });
      _addLog('Active billing printer configured: ${printer.name} (${cfg.typeLabel})');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Configured "${printer.name}" for billing', style: AppTheme.timesFont()),
            backgroundColor: AppColors.paid,
          ),
        );
      }
    } catch (e) {
      _addLog('Failed to set printer: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetToSystemDefault() async {
    _addLog('Resetting billing printer to Windows System Default...');
    setState(() => _isLoading = true);
    try {
      await BluetoothPrinterService.resetToSystemDefault();
      final cfg = await BluetoothPrinterService.getSavedPrinterConfig();
      setState(() {
        _savedConfig = cfg;
      });
      _addLog('Reset complete: App will use the Windows default printer automatically.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset to Windows default printer', style: AppTheme.timesFont()),
            backgroundColor: AppColors.paid,
          ),
        );
      }
    } catch (e) {
      _addLog('Reset failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnect() async {
    _addLog('Disconnecting active printer connection...');
    await BluetoothPrinterService.disconnect();
    _addLog('Disconnected.');
    setState(() {});
  }

  Future<void> _runTestPrint(BillingProvider provider) async {
    if (_isPrintingTest) return;
    setState(() => _isPrintingTest = true);
    _addLog('Initiating independent test print (${_testPaperSize.label})...');

    try {
      // 1. A4 or A5 Document Format (Canon / HP / Epson Spooler)
      if (_testPaperSize == BillPaperSize.a4 || _testPaperSize == BillPaperSize.a5) {
        final success = await BluetoothPrinterService.printTestReceipt(
          shopProfile: provider.shopProfile,
          paperSize: _testPaperSize,
        );
        if (success) {
          _addLog('A4 test document dispatched successfully via Windows Spooler.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('A4 Test document printed successfully!', style: AppTheme.timesFont(color: Colors.white)),
                backgroundColor: AppColors.paid,
              ),
            );
          }
          return;
        }
      }

      // 2. Thermal Format (58mm or 80mm ESC/POS) with Spooler fallback
      bool success = false;
      try {
        success = await BluetoothPrinterService.printTestReceiptEscPos(
          shopProfile: provider.shopProfile,
          paperSize: _testPaperSize,
        );
      } catch (e) {
        _addLog('Raw ESC/POS communication: $e. Trying Spooler PDF fallback...');
      }

      if (!success) {
        success = await BluetoothPrinterService.printTestReceipt(
          shopProfile: provider.shopProfile,
          paperSize: _testPaperSize,
        );
      }

      if (success) {
        _addLog('Test receipt printed successfully!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Test receipt printed successfully!', style: AppTheme.timesFont(color: Colors.white)),
                ],
              ),
              backgroundColor: AppColors.paid,
            ),
          );
        }
      }
    } catch (e) {
      _addLog('Test print failed: $e', isError: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test print error: $e', style: AppTheme.timesFont()),
            backgroundColor: AppColors.dueOverdue,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrintingTest = false);
    }
  }

  Future<void> _testPrintSpecificSpoolerPrinter(Printer printer, BillingProvider provider) async {
    _addLog('Sending test page to "${printer.name}"...');
    setState(() => _isPrintingTest = true);
    try {
      final isThermal = BluetoothPrinterService.isLikelyThermalPrinter(printer) || printer.name.contains('Generic');
      if (isThermal) {
        final bytes = BluetoothPrinterService.generateTestReceiptEscPos(
          shopProfile: provider.shopProfile,
          paperSize: _testPaperSize == BillPaperSize.a4 ? BillPaperSize.mm80 : _testPaperSize,
        );
        final success = await BluetoothPrinterService.sendRawBytesToNamedPrinter(printer.name, bytes);
        if (success) {
          _addLog('Test receipt sent to ${printer.name} via RAW ESC/POS.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Test receipt printed to ${printer.name}', style: AppTheme.timesFont()),
                backgroundColor: AppColors.paid,
              ),
            );
          }
          return;
        } else {
          _addLog('Raw ESC/POS not accepted by ${printer.name}. Falling back to standard Spooler print...');
        }
      }

      final success = await BluetoothPrinterService.printTestReceipt(
        shopProfile: provider.shopProfile,
        printer: printer,
        paperSize: _testPaperSize,
      );
      if (success) {
        _addLog('Test page printed to "${printer.name}" via Spooler.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Test page printed to ${printer.name}', style: AppTheme.timesFont()),
              backgroundColor: AppColors.paid,
            ),
          );
        }
      }
    } catch (e) {
      _addLog('Test print to "${printer.name}" failed: $e', isError: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e', style: AppTheme.timesFont()),
            backgroundColor: AppColors.dueOverdue,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrintingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BillingProvider>(context);
    final isDesktop = !kIsWeb && Platform.isWindows;

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.print_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Printer Settings & Hardware Configuration',
                        style: AppTheme.timesFont(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Universal Commercial Billing: Bluetooth Thermal (58mm/80mm), USB Thermal, Windows Spooler & A4 Printers (Canon, HP, Epson)',
                        style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _initDiagnostics,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh All'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top Status Cards Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 800;
                return Column(
                  children: [
                    if (!isNarrow)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildConnectionStatusCard()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildBluetoothHardwareCard()),
                        ],
                      )
                    else ...[
                      _buildConnectionStatusCard(),
                      const SizedBox(height: 16),
                      _buildBluetoothHardwareCard(),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Windows Spooler Printers (Canon A4, HP, POS-80, Generic, etc.)
            if (isDesktop) ...[
              _buildSpoolerPrintersCard(provider),
              const SizedBox(height: 20),
            ],

            // Bluetooth & Serial Thermal Hardware
            _buildBluetoothAndSerialCard(),
            const SizedBox(height: 20),

            // Independent Test Print Section
            _buildIndependentTestPrintCard(provider),
            const SizedBox(height: 20),

            // Setup & Troubleshooting Guide
            _buildHardwareGuideCard(),
            const SizedBox(height: 20),

            // Diagnostic Log Console
            _buildLogConsoleCard(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    final isConnected = BluetoothPrinterService.isConnected;
    final connName = BluetoothPrinterService.connectedDeviceName ?? _savedConfig.name;
    final connAddr = BluetoothPrinterService.connectedDeviceAddress ?? (_savedConfig.address ?? 'Default Spooler');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _savedConfig.isAuto ? AppColors.primary.withValues(alpha: 0.5) : AppColors.paid,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: _savedConfig.isAuto ? AppColors.primary : AppColors.paid,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Billing Printer',
                    style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (_savedConfig.isAuto ? AppColors.primary : AppColors.paid).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _savedConfig.isAuto ? 'AUTO (WINDOWS DEFAULT)' : 'CUSTOM SELECTED',
                  style: AppTheme.timesFont(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _savedConfig.isAuto ? AppColors.primary : AppColors.paid,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            connName,
            style: AppTheme.timesFont(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 3),
          Text(
            'Type: ${_savedConfig.typeLabel}',
            style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
          ),
          Text(
            'Target: $connAddr',
            style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_savedConfig.isAuto)
                OutlinedButton.icon(
                  onPressed: _resetToSystemDefault,
                  icon: const Icon(Icons.settings_backup_restore_rounded, size: 15),
                  label: const Text('Reset to Windows Default'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  ),
                ),
              if (isConnected && (_savedConfig.isBluetooth || _savedConfig.isSerial))
                ElevatedButton.icon(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.close, size: 15),
                  label: const Text('Disconnect'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.dueOverdue),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothHardwareCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bluetooth_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Bluetooth Adapter & Permissions',
                style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Radio Adapter:', style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary)),
              Row(
                children: [
                  Icon(
                    _isBluetoothEnabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: _isBluetoothEnabled ? AppColors.paid : AppColors.dueOverdue,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isBluetoothEnabled ? 'Enabled & Ready' : 'Disabled / Off',
                    style: AppTheme.timesFont(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _isBluetoothEnabled ? AppColors.paid : AppColors.dueOverdue,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Permissions:', style: AppTheme.timesFont(fontSize: 13, color: AppColors.textSecondary)),
              Text(
                _permissionStatus.name.toUpperCase(),
                style: AppTheme.timesFont(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _permissionStatus == BluetoothPermissionStatus.granted ||
                          _permissionStatus == BluetoothPermissionStatus.notRequired
                      ? AppColors.paid
                      : AppColors.dueOverdue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_isBluetoothEnabled && !kIsWeb && Platform.isAndroid)
                ElevatedButton.icon(
                  onPressed: _enableBluetooth,
                  icon: const Icon(Icons.bluetooth_connected_rounded, size: 15),
                  label: const Text('Turn Bluetooth On'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              if (_permissionStatus == BluetoothPermissionStatus.denied ||
                  _permissionStatus == BluetoothPermissionStatus.permanentlyDenied)
                ElevatedButton.icon(
                  onPressed: _requestPermissions,
                  icon: const Icon(Icons.security_rounded, size: 15),
                  label: const Text('Grant Permissions'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpoolerPrintersCard(BillingProvider provider) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.desktop_windows_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Installed Windows System Printers (${_spoolerPrinters.length})',
                    style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _refreshSpoolerPrinters(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Compatible with Canon A4, HP, Epson, Brother, TVS, USB POS thermal printers, and Generic / Text Only drivers.',
            style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          if (_stuckJobCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Windows spooler has $_stuckJobCount stuck print job(s) locking the printer port.',
                      style: AppTheme.timesFont(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _clearSpoolerQueue,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                    label: const Text('Clear Queue'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
                  ),
                ],
              ),
            ),
          ],
          if (_spoolerPrinters.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('No installed Windows printers detected.', style: AppTheme.timesFont(color: AppColors.textSecondary)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _spoolerPrinters.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final printer = _spoolerPrinters[index];
                final isDefault = printer.isDefault;
                final isSelected = _savedConfig.isSystem && _savedConfig.name == printer.name;
                final isVirtual = PdfService.isVirtualPrinter(printer.name);
                final isThermal = BluetoothPrinterService.isLikelyThermalPrinter(printer);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? AppColors.paid.withValues(alpha: 0.15)
                        : (isVirtual ? Colors.grey.shade100 : AppColors.primary.withValues(alpha: 0.1)),
                    child: Icon(
                      isThermal ? Icons.receipt_long_rounded : Icons.print_rounded,
                      color: isSelected ? AppColors.paid : (isVirtual ? Colors.grey : AppColors.primary),
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          printer.name,
                          style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text('DEFAULT', style: AppTheme.timesFont(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                            ],
                          ),
                        ),
                      ],
                      if (isThermal) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('THERMAL POS', style: AppTheme.timesFont(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                        ),
                      ],
                      if (isVirtual) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('VIRTUAL', style: AppTheme.timesFont(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    isThermal
                        ? 'Raw ESC/POS or WinSpool Direct Streaming'
                        : (isVirtual ? 'Virtual Software Printer' : 'Standard Spooler Document Printing (Canon/A4/A5)'),
                    style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: _isPrintingTest ? null : () => _testPrintSpecificSpoolerPrinter(printer, provider),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        child: const Text('Test Print', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.paid.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check, size: 14, color: AppColors.paid),
                              const SizedBox(width: 4),
                              Text('Active', style: AppTheme.timesFont(color: AppColors.paid, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: _isLoading ? null : () => _selectSpoolerPrinter(printer),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: const Text('Use for Billing', style: TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBluetoothAndSerialCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.devices_other_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Bluetooth Classic & USB Serial Hardware',
                    style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isScanning ? null : _startDiscoveryScan,
                icon: _isScanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.search_rounded, size: 16),
                label: Text(_isScanning ? 'Scanning...' : 'Scan Nearby'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Connect directly to 58mm or 80mm thermal receipt printers over Bluetooth SPP or Windows virtual serial COM ports.',
            style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // COM Ports
          if (!kIsWeb && Platform.isWindows) ...[
            Text('Windows Serial / Virtual COM Ports:', style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (_windowsComPorts.isEmpty)
              Text('No COM ports detected.', style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _windowsComPorts.map((port) {
                  final isSelected = BluetoothPrinterService.activeComPort == port ||
                      (_savedConfig.isSerial && _savedConfig.address == port);
                  return ActionChip(
                    avatar: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.usb_rounded,
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                    backgroundColor: isSelected ? AppColors.paid : Colors.grey.shade100,
                    label: Text(
                      '$port ${isSelected ? "(Active)" : ""}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _selectComPort(port),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),
          ],

          // Paired Bluetooth Devices
          Text('Paired Bluetooth Thermal Printers (${_pairedDevices.length}):', style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_pairedDevices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No paired Bluetooth printers detected. Pair your printer in Windows or Android Settings, then tap "Refresh All".',
                style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pairedDevices.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final device = _pairedDevices[index];
                final isCurrent = BluetoothPrinterService.connectedDeviceAddress == device.address ||
                    (_savedConfig.isBluetooth && _savedConfig.address == device.address) ||
                    (_savedConfig.isSerial && _savedConfig.address == device.address);

                IconData iconData = Icons.bluetooth_connected_rounded;
                if (device.isUsb) {
                  iconData = Icons.usb_rounded;
                } else if (device.name.contains('Spooler')) {
                  iconData = Icons.receipt_long_rounded;
                }

                String subtitle = device.address.startsWith('COM') ? 'Serial Port: ${device.address}' : 'MAC: ${device.address}';
                if (device.detail != null && device.detail!.isNotEmpty && device.detail != device.name) {
                  subtitle = '${device.detail} • $subtitle';
                }

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isCurrent ? AppColors.paid.withValues(alpha: 0.15) : Colors.grey.shade100,
                    child: Icon(iconData, color: isCurrent ? AppColors.paid : AppColors.primary, size: 20),
                  ),
                  title: Text(device.displayName, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(subtitle, style: AppTheme.timesFont(fontSize: 11, color: AppColors.textSecondary)),
                  trailing: isCurrent
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.paid.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Active', style: AppTheme.timesFont(color: AppColors.paid, fontWeight: FontWeight.bold, fontSize: 12)),
                        )
                      : ElevatedButton(
                          onPressed: _isLoading ? null : () => _connectToBluetoothDevice(device),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                          child: const Text('Connect & Use', style: TextStyle(fontSize: 11)),
                        ),
                );
              },
            ),

          if (_discoveredDevices.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),
            Text('Discovered Nearby Devices (${_discoveredDevices.length}):', style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _discoveredDevices.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final device = _discoveredDevices[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.radar_rounded, size: 18)),
                  title: Text(device.displayName, style: AppTheme.timesFont(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('MAC: ${device.address}', style: AppTheme.timesFont(fontSize: 11)),
                  trailing: ElevatedButton(
                    onPressed: () => _connectToBluetoothDevice(device),
                    child: const Text('Pair & Connect', style: TextStyle(fontSize: 11)),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIndependentTestPrintCard(BillingProvider provider) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Independent Hardware Test Print',
                style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Safe Hardware Test',
                  style: AppTheme.timesFont(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Test your configured billing printer immediately without saving an invoice. Dispatches clean ESC/POS commands to thermal printers or standard Spooler layouts to Canon/HP/Epson A4 printers.',
            style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
  spacing: 8,
  runSpacing: 8,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    Text(
      'Target Paper Width:',
      style: AppTheme.timesFont(
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    ),
    ChoiceChip(
      label: const Text('58mm Thermal (Receipt)'),
      selected: _testPaperSize == BillPaperSize.mm58,
      onSelected: (val) {
        if (val) {
          setState(() => _testPaperSize = BillPaperSize.mm58);
        }
      },
    ),
    ChoiceChip(
      label: const Text('80mm Thermal (Receipt)'),
      selected: _testPaperSize == BillPaperSize.mm80,
      onSelected: (val) {
        if (val) {
          setState(() => _testPaperSize = BillPaperSize.mm80);
        }
      },
    ),
    ChoiceChip(
      label: const Text('A4 Document (Canon/HP)'),
      selected: _testPaperSize == BillPaperSize.a4,
      onSelected: (val) {
        if (val) {
          setState(() => _testPaperSize = BillPaperSize.a4);
        }
      },
    ),
  ],
),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isPrintingTest ? null : () => _runTestPrint(provider),
            icon: _isPrintingTest
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.print_rounded, size: 18),
            label: Text(
              _isPrintingTest ? 'Dispatching Test Print...' : 'Print Test Receipt / Document Now',
              style: AppTheme.timesFont(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.paid,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareGuideCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Printer Setup & Troubleshooting Guide for Customers',
                style: AppTheme.timesFont(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGuideItem(
            '1. Canon, HP, Epson, Brother A4 Printers',
            'Connect the printer via USB cable or local Wi-Fi. Ensure the official Windows driver is installed from the manufacturer. Select the printer from "Installed Windows System Printers" above, or set it as default in Windows Settings.',
          ),
          _buildGuideItem(
            '2. USB Thermal Receipt Printers (POS-58, POS-80, TVS, Xprinter)',
            'Plug in the USB cable and turn on power. Install the POS printer driver (or use the Windows "Generic / Text Only" driver). Once installed, it appears under "Installed Windows System Printers". Tap "Use for Billing" to select it.',
          ),
          _buildGuideItem(
            '3. Bluetooth Thermal Printers on Windows (MT580P, etc.)',
            'Turn on the printer. Open Windows Settings → Bluetooth & devices → Add device. Enter pairing PIN 0000 or 1234. Windows will create a virtual COM port (e.g. COM5 or COM6). In this screen, select that COM port under "Windows Serial / Virtual COM Ports".',
          ),
          _buildGuideItem(
            '4. Android Bluetooth Thermal Printing',
            'Enable Bluetooth and Location on your mobile/tablet. Pair the printer in Android Bluetooth Settings (PIN 0000 or 1234). Open this screen, grant permissions if prompted, and tap "Connect & Use" next to your printer.',
          ),
          _buildGuideItem(
            '5. Troubleshooting Common Issues',
            '• Blank paper feeding: Verify the paper roll is inserted in the correct direction (thermal coating facing print head).\n• Garbage characters: Occurs if ESC/POS binary data is sent to an A4 document printer. Selecting the correct paper width (A4 vs 58mm/80mm) automatically prevents this.\n• Device Busy: Close any other software (like another POS app) using the printer or COM port, then re-connect.',
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.timesFont(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 3),
          Text(content, style: AppTheme.timesFont(fontSize: 12, color: AppColors.textSecondary, height: 1.35)),
        ],
      ),
    );
  }

  Widget _buildLogConsoleCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.terminal_rounded, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Real-Time Hardware Diagnostic & Error Console',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => setState(() => _logs.clear()),
                icon: const Icon(Icons.delete_outline, size: 14, color: Colors.white70),
                label: const Text('Clear', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 160,
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF13131F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'No events yet. Actions, scan results, and error messages appear here.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    itemCount: _logs.length,
                    itemBuilder: (ctx, i) {
                      final log = _logs[i];
                      final isErr = log.contains('ERROR:');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: isErr ? Colors.redAccent : Colors.lightGreenAccent,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
