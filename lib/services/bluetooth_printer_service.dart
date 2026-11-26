import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice.dart';
import '../models/shop_profile.dart';
import 'pdf_service.dart';

/// Permission status enum compatible across platforms
enum BluetoothPermissionStatus { granted, denied, permanentlyDenied, notRequired }

/// Connection type for universal billing printing
enum PrinterConnectionType {
  auto,      // Auto-detect: use Windows default or connected thermal printer
  system,    // Specific installed Windows / OS spooler printer (e.g. Canon A4, HP, POS-80 driver)
  bluetooth, // Bluetooth Classic SPP thermal printer
  serial,    // COM serial port / USB virtual COM port
}

/// Universal printer configuration stored per device/shop
class UniversalPrinterConfig {
  final PrinterConnectionType type;
  final String name;
  final String? address;
  final bool isThermal;

  const UniversalPrinterConfig({
    required this.type,
    required this.name,
    this.address,
    this.isThermal = false,
  });

  bool get isAuto => type == PrinterConnectionType.auto;
  bool get isSystem => type == PrinterConnectionType.system;
  bool get isBluetooth => type == PrinterConnectionType.bluetooth;
  bool get isSerial => type == PrinterConnectionType.serial;

  String get typeLabel {
    switch (type) {
      case PrinterConnectionType.system:
        return isThermal ? 'Thermal Spooler Driver' : 'Document Printer (Spooler)';
      case PrinterConnectionType.bluetooth:
        return 'Bluetooth Thermal (SPP)';
      case PrinterConnectionType.serial:
        return 'Serial / USB COM Port';
      case PrinterConnectionType.auto:
        return 'Windows System Default';
    }
  }

  UniversalPrinterConfig copyWith({
    PrinterConnectionType? type,
    String? name,
    String? address,
    bool? isThermal,
  }) {
    return UniversalPrinterConfig(
      type: type ?? this.type,
      name: name ?? this.name,
      address: address ?? this.address,
      isThermal: isThermal ?? this.isThermal,
    );
  }
}

/// Universal printer device representation
class BluetoothPrinterDevice {
  final String name;
  final String address;
  final int? rssi;
  final bool isBluetooth;
  final bool isUsb;
  final bool isIncoming;
  final String? detail;

  const BluetoothPrinterDevice({
    required this.name,
    required this.address,
    this.rssi,
    this.isBluetooth = false,
    this.isUsb = false,
    this.isIncoming = false,
    this.detail,
  });

  String get displayName => name.trim().isNotEmpty ? name.trim() : 'Printer ($address)';
}

/// Service managing universal commercial printing:
/// Windows system default & installed drivers (Canon, HP, Epson, Brother, TVS, etc.),
/// Bluetooth Classic SPP thermal printing (58mm & 80mm),
/// raw Windows COM serial / USB ports, and ESC/POS thermal streaming.
class BluetoothPrinterService {
  static const String _kSavedThermalPrinterKey = 'saved_thermal_printer_name';
  static const String _kSavedThermalAddressKey = 'saved_thermal_printer_address';
  static const String _kSavedThermalComPortKey = 'saved_thermal_com_port';
  static const String _kSavedThermalTypeKey = 'saved_thermal_printer_type'; // 'bluetooth', 'com', 'spooler'

  static const String _kSelectedPrinterTypeKey = 'selected_printer_type';
  static const String _kSelectedPrinterNameKey = 'selected_printer_name';
  static const String _kSelectedPrinterAddressKey = 'selected_printer_address';
  static const String _kSelectedPrinterIsThermalKey = 'selected_printer_is_thermal';

  // Standard Bluetooth Serial Port Profile (SPP) UUID
  static const String sppUuid = '00001101-0000-1000-8000-00805F9B34FB';

  // Active state
  static String? _connectedAddress;
  static String? _connectedName;
  static String? _activeComPort;
  static bool _isConnected = false;

  /// Notifier for live UI status updates
  static final ValueNotifier<String> connectionStatusNotifier =
      ValueNotifier<String>('Disconnected');

  static bool get isConnected => _isConnected || _activeComPort != null;
  static String? get connectedDeviceName => _connectedName;
  static String? get connectedDeviceAddress => _connectedAddress;
  static String? get activeComPort => _activeComPort;

  // ──────────────────────────────────────────────────────────────────────────
  // Permissions & Hardware Status
  // ──────────────────────────────────────────────────────────────────────────

  /// Check Bluetooth permissions
  static Future<BluetoothPermissionStatus> checkPermissions() async {
    if (kIsWeb || Platform.isWindows) {
      return BluetoothPermissionStatus.granted;
    }
    try {
      final isGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      return isGranted ? BluetoothPermissionStatus.granted : BluetoothPermissionStatus.denied;
    } catch (e) {
      debugPrint('Error checking Bluetooth permissions: $e');
      return BluetoothPermissionStatus.denied;
    }
  }

  /// Request Bluetooth permissions (Android 12+ scan/connect, or Android <=11 location)
  static Future<BluetoothPermissionStatus> requestPermissions() async {
    if (kIsWeb || Platform.isWindows) {
      return BluetoothPermissionStatus.granted;
    }
    try {
      final isGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      return isGranted ? BluetoothPermissionStatus.granted : BluetoothPermissionStatus.denied;
    } catch (e) {
      debugPrint('Error requesting Bluetooth permissions: $e');
      return BluetoothPermissionStatus.denied;
    }
  }

  /// Open app settings if permissions were permanently denied
  static Future<bool> openAppSettings() async {
    return false;
  }

  /// Whether Bluetooth hardware is supported
  static Future<bool> isBluetoothSupported() async {
    if (kIsWeb) return false;
    if (Platform.isWindows) return true;
    return true;
  }

  /// Whether Bluetooth adapter is turned on
  static Future<bool> isBluetoothEnabled() async {
    if (kIsWeb) return false;
    if (Platform.isWindows) return true;
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  /// Request the OS to enable Bluetooth (Android)
  static Future<bool> enableBluetooth() async {
    return await isBluetoothEnabled();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Device Discovery & Listing
  // ──────────────────────────────────────────────────────────────────────────

  /// List all paired/bonded Bluetooth Classic devices (Android & Windows)
  static Future<List<BluetoothPrinterDevice>> getPairedBluetoothDevices() async {
    if (kIsWeb) return [];
    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        final List<BluetoothInfo> items = await PrintBluetoothThermal.pairedBluetooths;
        return items
            .map((b) => BluetoothPrinterDevice(name: b.name, address: b.macAdress, isBluetooth: true))
            .toList();
      } else if (Platform.isWindows) {
        final List<BluetoothPrinterDevice> devices = [];

        // 1. Query rich Windows PnP hardware for Bluetooth & USB COM ports
        try {
          const hwScript = r'''
$ErrorActionPreference = 'SilentlyContinue'
$btDevices = @{}
$btPnp = Get-PnpDevice -Class Bluetooth | Where-Object { $_.InstanceId -like '*DEV_*' }
foreach ($b in $btPnp) {
    if ($b.InstanceId -match 'DEV_([0-9A-Fa-f]{12})') {
        $mac = $matches[1].ToUpper()
        $btDevices[$mac] = $b.FriendlyName
    }
}

$results = @()
$pnpEntities = Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match '\(COM\d+\)' }
foreach ($dev in $pnpEntities) {
    if ($dev.Name -match '\((COM\d+)\)') {
        $port = $matches[1].ToUpper()
        $rawName = $dev.Name
        $pnpId = $dev.PNPDeviceID
        $isBt = ($pnpId -like '*BTHENUM*')
        $isUsb = ($pnpId -like '*USB*')
        $btName = $null
        $isIncoming = $false

        if ($isBt) {
            if ($pnpId -like '*000000000000*') {
                $isIncoming = $true
            } else {
                foreach ($mac in $btDevices.Keys) {
                    if ($pnpId.ToUpper().Contains($mac)) {
                        $btName = $btDevices[$mac]
                        break
                    }
                }
            }
        }

        $results += [PSCustomObject]@{
            Port = $port
            RawName = $rawName
            BluetoothDevice = $btName
            IsBluetooth = $isBt
            IsIncoming = $isIncoming
            IsUsb = $isUsb
        }
    }
}
$results | ConvertTo-Json -Compress
''';
          final res = await Process.run('powershell', [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            hwScript,
          ]).timeout(const Duration(seconds: 4), onTimeout: () => ProcessResult(0, 1, '[]', 'Timed out'));

          final out = (res.stdout as String).trim();
          if (out.isNotEmpty && (out.startsWith('[') || out.startsWith('{'))) {
            final decoded = jsonDecode(out);
            final list = decoded is List ? decoded : [decoded];
            for (final item in list) {
              if (item is Map) {
                final port = (item['Port'] ?? '').toString();
                final btName = item['BluetoothDevice']?.toString();
                final rawName = (item['RawName'] ?? '').toString();
                final isBt = item['IsBluetooth'] == true;
                final isUsb = item['IsUsb'] == true;
                final isInc = item['IsIncoming'] == true;

                if (port.isEmpty) continue;

                String dispName;
                if (isBt && btName != null && btName.isNotEmpty) {
                  dispName = '$btName ($port)';
                } else if (isBt && isInc) {
                  dispName = 'Bluetooth Incoming Port ($port)';
                } else if (isUsb && rawName.isNotEmpty) {
                  dispName = rawName;
                } else {
                  dispName = 'Serial Port ($port)';
                }

                devices.add(BluetoothPrinterDevice(
                  name: dispName,
                  address: port,
                  isBluetooth: isBt,
                  isUsb: isUsb,
                  isIncoming: isInc,
                  detail: rawName,
                ));
              }
            }
          }
        } catch (e) {
          debugPrint('Error running rich hardware discovery: $e');
        }

        // 2. Fallback: If no COM ports discovered via PnP, query registry serial ports
        if (devices.isEmpty) {
          final comPorts = await getWindowsComPorts();
          for (final port in comPorts) {
            devices.add(BluetoothPrinterDevice(
              name: 'Serial Thermal Port ($port)',
              address: port,
              isBluetooth: true,
            ));
          }
        }

        // 3. Add installed likely thermal spooler printers
        final printers = await getAvailablePrinters();
        for (final p in printers) {
          if (isLikelyThermalPrinter(p) || p.name.contains('Generic')) {
            devices.add(BluetoothPrinterDevice(
              name: '${p.name} (Windows Spooler)',
              address: p.name,
              detail: 'Windows Spooler Driver',
            ));
          }
        }
        return devices;
      }
    } catch (e) {
      debugPrint('Error getting paired Bluetooth devices: $e');
    }
    return [];
  }

  /// Scan for nearby Bluetooth Classic devices
  static Future<List<BluetoothPrinterDevice>> scanBluetoothDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return await getPairedBluetoothDevices();
  }

  /// Query detected Windows COM ports (e.g. standard serial over Bluetooth links)
  static Future<List<String>> getWindowsComPorts() async {
    if (kIsWeb || !Platform.isWindows) return [];
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        r"(Get-ItemProperty -Path 'HKLM:\HARDWARE\DEVICEMAP\SERIALCOMM' -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object { $_.Value }"
      ]).timeout(const Duration(seconds: 3), onTimeout: () => ProcessResult(0, 1, '', 'Timed out'));
      if (result.exitCode == 0) {
        final lines = (result.stdout as String)
            .split(RegExp(r'[\r\n]+'))
            .map((s) => s.trim().toUpperCase())
            .where((s) => s.isNotEmpty && s.startsWith('COM'))
            .toSet()
            .toList();
        lines.sort();
        return lines;
      }
    } catch (e) {
      debugPrint('Error getting Windows COM ports: $e');
    }
    return [];
  }

  /// Clears any stuck jobs in the Windows print queue (e.g. error jobs on serial/USB ports)
  static Future<bool> clearWindowsSpoolerQueue([String? printerName]) async {
    if (kIsWeb || !Platform.isWindows) return false;
    try {
      final filter = (printerName != null && printerName.isNotEmpty)
          ? "-PrinterName '${printerName.replaceAll("'", "''")}'"
          : '';
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        "Get-PrintJob $filter -ErrorAction SilentlyContinue | Remove-PrintJob -ErrorAction SilentlyContinue",
      ]).timeout(const Duration(seconds: 4), onTimeout: () => ProcessResult(0, 1, '', 'Timed out'));
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Error clearing Windows spooler queue: $e');
      return false;
    }
  }

  /// Checks if any Windows spooler printers have stuck error jobs
  static Future<int> getWindowsStuckJobCount() async {
    if (kIsWeb || !Platform.isWindows) return 0;
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        r"(Get-PrintJob -ErrorAction SilentlyContinue | Where-Object { $_.JobStatus -match 'Error|Retained' }).Count",
      ]).timeout(const Duration(seconds: 3), onTimeout: () => ProcessResult(0, 1, '0', 'Timed out'));
      final text = (result.stdout as String).trim();
      return int.tryParse(text) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// List all detected system spooler printers (Canon A4, POS-58 USB, Generic, etc.)
  static Future<List<Printer>> getAvailablePrinters() async {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (!isDesktop) {
      return [];
    }
    try {
      return await Printing.listPrinters();
    } catch (e) {
      debugPrint('Error listing spooler printers: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Saved Configuration (Preferences)
  // ──────────────────────────────────────────────────────────────────────────

  /// Retrieve universal printer configuration with legacy fallback
  static Future<UniversalPrinterConfig> getSavedPrinterConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final typeStr = prefs.getString(_kSelectedPrinterTypeKey);
      final name = prefs.getString(_kSelectedPrinterNameKey);
      final address = prefs.getString(_kSelectedPrinterAddressKey);
      final isThermal = prefs.getBool(_kSelectedPrinterIsThermalKey) ?? false;

      if (typeStr != null && name != null && name.isNotEmpty) {
        PrinterConnectionType type;
        switch (typeStr) {
          case 'system':
            type = PrinterConnectionType.system;
            break;
          case 'bluetooth':
            type = PrinterConnectionType.bluetooth;
            break;
          case 'serial':
            type = PrinterConnectionType.serial;
            break;
          default:
            type = PrinterConnectionType.auto;
        }
        return UniversalPrinterConfig(
          type: type,
          name: name,
          address: address,
          isThermal: isThermal,
        );
      }

      // Legacy fallback: check _kSavedThermalPrinterKey
      final legacyName = prefs.getString(_kSavedThermalPrinterKey);
      final legacyAddr = prefs.getString(_kSavedThermalAddressKey);
      final legacyCom = prefs.getString(_kSavedThermalComPortKey);
      final legacyType = prefs.getString(_kSavedThermalTypeKey);

      if (legacyName != null && legacyName.isNotEmpty) {
        if (legacyType == 'com' || (legacyCom != null && legacyCom.isNotEmpty)) {
          return UniversalPrinterConfig(
            type: PrinterConnectionType.serial,
            name: legacyName,
            address: legacyCom,
            isThermal: true,
          );
        } else if (legacyType == 'bluetooth' || (legacyAddr != null && legacyAddr.contains(':'))) {
          return UniversalPrinterConfig(
            type: PrinterConnectionType.bluetooth,
            name: legacyName,
            address: legacyAddr,
            isThermal: true,
          );
        } else {
          return UniversalPrinterConfig(
            type: PrinterConnectionType.system,
            name: legacyName,
            address: legacyAddr,
            isThermal: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting saved printer config: $e');
    }

    return const UniversalPrinterConfig(
      type: PrinterConnectionType.auto,
      name: 'Windows System Default',
      isThermal: false,
    );
  }

  /// Persistently save universal printer configuration
  static Future<void> savePrinterConfig(UniversalPrinterConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSelectedPrinterTypeKey, config.type.name);
      await prefs.setString(_kSelectedPrinterNameKey, config.name);
      if (config.address != null) {
        await prefs.setString(_kSelectedPrinterAddressKey, config.address!);
      } else {
        await prefs.remove(_kSelectedPrinterAddressKey);
      }
      await prefs.setBool(_kSelectedPrinterIsThermalKey, config.isThermal);

      // Mirror to legacy keys for seamless backwards compatibility
      await prefs.setString(_kSavedThermalPrinterKey, config.name);
      if (config.address != null) {
        await prefs.setString(_kSavedThermalAddressKey, config.address!);
      }
      if (config.type == PrinterConnectionType.serial) {
        await prefs.setString(_kSavedThermalComPortKey, config.address ?? config.name);
        await prefs.setString(_kSavedThermalTypeKey, 'com');
      } else if (config.type == PrinterConnectionType.bluetooth) {
        await prefs.setString(_kSavedThermalTypeKey, 'bluetooth');
      } else if (config.type == PrinterConnectionType.system) {
        await prefs.setString(_kSavedThermalTypeKey, 'spooler');
      }
    } catch (e) {
      debugPrint('Error saving printer config: $e');
    }
  }

  /// 1-click selection of an installed Windows/OS Spooler printer (Canon A4, POS-80, Generic, etc.)
  static Future<void> selectSystemPrinter(Printer printer, {bool? isThermal}) async {
    final thermal = isThermal ?? isLikelyThermalPrinter(printer);
    final config = UniversalPrinterConfig(
      type: PrinterConnectionType.system,
      name: printer.name,
      address: printer.url.isNotEmpty ? printer.url : printer.name,
      isThermal: thermal,
    );
    await savePrinterConfig(config);
    _connectedName = printer.name;
    _connectedAddress = printer.url.isNotEmpty ? printer.url : printer.name;
    _isConnected = true;
    _activeComPort = null;
    connectionStatusNotifier.value = 'Configured: ${printer.name}';
  }

  /// Reset billing printer setting to system default
  static Future<void> resetToSystemDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSelectedPrinterTypeKey);
      await prefs.remove(_kSelectedPrinterNameKey);
      await prefs.remove(_kSelectedPrinterAddressKey);
      await prefs.remove(_kSelectedPrinterIsThermalKey);
      await prefs.remove(_kSavedThermalPrinterKey);
      await prefs.remove(_kSavedThermalAddressKey);
      await prefs.remove(_kSavedThermalComPortKey);
      await prefs.remove(_kSavedThermalTypeKey);
      await disconnect();
      connectionStatusNotifier.value = 'Windows System Default';
    } catch (_) {}
  }

  static Future<String?> getSavedThermalPrinterName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kSelectedPrinterNameKey) ?? prefs.getString(_kSavedThermalPrinterKey);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getSavedThermalPrinterAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kSelectedPrinterAddressKey) ?? prefs.getString(_kSavedThermalAddressKey);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getSavedThermalComPort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kSavedThermalComPortKey);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getSavedThermalPrinterType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kSelectedPrinterTypeKey) ?? prefs.getString(_kSavedThermalTypeKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveThermalPrinterSettings({
    required String name,
    String? address,
    String? comPort,
    String type = 'bluetooth',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSavedThermalPrinterKey, name);
      if (address != null) {
        await prefs.setString(_kSavedThermalAddressKey, address);
      }
      if (comPort != null) {
        await prefs.setString(_kSavedThermalComPortKey, comPort);
      }
      await prefs.setString(_kSavedThermalTypeKey, type);
    } catch (_) {}
  }

  static Future<void> saveThermalPrinterName(String printerName) async {
    await saveThermalPrinterSettings(name: printerName);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Connection Management
  // ──────────────────────────────────────────────────────────────────────────

  /// Connect to a Bluetooth Classic thermal printer using SPP
  static Future<bool> connectBluetooth({
    required String address,
    String? name,
  }) async {
    try {
      await disconnect();

      connectionStatusNotifier.value = 'Connecting to ${name ?? address}...';
      debugPrint('Connecting to Bluetooth device: $address ($name)');

      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        final success = await PrintBluetoothThermal.connect(macPrinterAddress: address)
            .timeout(const Duration(seconds: 12), onTimeout: () => false);

        if (success) {
          _isConnected = true;
          _connectedAddress = address;
          _connectedName = name ?? address;
          _activeComPort = null;
          connectionStatusNotifier.value = 'Connected to ${_connectedName!}';

          await savePrinterConfig(UniversalPrinterConfig(
            type: PrinterConnectionType.bluetooth,
            name: _connectedName!,
            address: address,
            isThermal: true,
          ));
          return true;
        } else {
          _isConnected = false;
          connectionStatusNotifier.value = 'Connection failed';
          throw Exception('Could not connect to $address. Ensure printer is turned on and paired in Bluetooth settings.');
        }
      } else if (Platform.isWindows) {
        if (address.toUpperCase().startsWith('COM')) {
          return await selectWindowsComPort(address, displayName: name);
        } else {
          _connectedName = name ?? address;
          _connectedAddress = address;
          _isConnected = true;
          connectionStatusNotifier.value = 'Connected to ${_connectedName!}';
          await savePrinterConfig(UniversalPrinterConfig(
            type: PrinterConnectionType.system,
            name: _connectedName!,
            address: address,
            isThermal: true,
          ));
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Failed to connect to Bluetooth device $address: $e');
      connectionStatusNotifier.value = 'Connection failed: $e';
      _isConnected = false;
      _connectedAddress = null;
      _connectedName = null;
      rethrow;
    }
  }

  /// Select and activate a Windows COM port for serial thermal printing
  static Future<bool> selectWindowsComPort(String comPort, {String? displayName}) async {
    try {
      await disconnect();
      _activeComPort = comPort.toUpperCase().trim();
      _connectedName = displayName ?? '$_activeComPort (Bluetooth/USB Serial)';
      _connectedAddress = _activeComPort;
      _isConnected = true;
      connectionStatusNotifier.value = 'Connected via $_activeComPort';

      await savePrinterConfig(UniversalPrinterConfig(
        type: PrinterConnectionType.serial,
        name: _connectedName!,
        address: _activeComPort,
        isThermal: true,
      ));
      return true;
    } catch (e) {
      debugPrint('Failed to select COM port: $e');
      return false;
    }
  }

  /// Disconnect active connection
  static Future<void> disconnect() async {
    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        await PrintBluetoothThermal.disconnect;
      }
    } catch (_) {
    } finally {
      _isConnected = false;
      _connectedAddress = null;
      _connectedName = null;
      _activeComPort = null;
      connectionStatusNotifier.value = 'Disconnected';
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Direct Raw Byte Transmission
  // ──────────────────────────────────────────────────────────────────────────

  /// Send raw ESC/POS bytes to the active printer connection
  static Future<bool> sendRawBytes(List<int> bytes) async {
    // 1. Android Bluetooth Thermal (MT580P via SPP)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      try {
        final isConn = await PrintBluetoothThermal.connectionStatus;
        if (isConn) {
          final written = await PrintBluetoothThermal.writeBytes(bytes);
          if (written) {
            debugPrint('Successfully printed ${bytes.length} bytes via PrintBluetoothThermal');
            return true;
          }
        }

        // Auto-reconnect to saved printer address if connection dropped
        final savedAddress = await getSavedThermalPrinterAddress();
        final savedName = await getSavedThermalPrinterName();
        if (savedAddress != null && savedAddress.isNotEmpty) {
          debugPrint('Attempting auto-reconnect to saved printer: $savedAddress ($savedName)');
          final connected = await connectBluetooth(address: savedAddress, name: savedName);
          if (connected) {
            final written = await PrintBluetoothThermal.writeBytes(bytes);
            if (written) {
              debugPrint('Successfully printed ${bytes.length} bytes after auto-reconnect.');
              return true;
            }
          }
        }
      } catch (e) {
        debugPrint('Error sending raw bytes to Bluetooth printer: $e');
        connectionStatusNotifier.value = 'Write failed: $e';
        return false;
      }
    }

    // 2. Windows: Print to active COM port or Windows System Default / Spooler Printer
    if (!kIsWeb && Platform.isWindows) {
      return await _printRawBytesWindows(bytes);
    }

    return false;
  }

  static String? _cachedPrinterHelperPath;

  /// Ensures native Windows printer helper executable is available
  static Future<String?> _ensurePrinterHelperExe() async {
    if (kIsWeb || !Platform.isWindows) return null;
    if (_cachedPrinterHelperPath != null && File(_cachedPrinterHelperPath!).existsSync()) {
      return _cachedPrinterHelperPath;
    }

    try {
      // 1. Check windows/win_printer_helper.exe
      final localExe = File('${Directory.current.path}\\windows\\win_printer_helper.exe');
      if (await localExe.exists()) {
        _cachedPrinterHelperPath = localExe.path;
        return _cachedPrinterHelperPath;
      }

      // 2. Check next to resolved executable (for release / debug build)
      final exeDir = File(Platform.resolvedExecutable).parent;
      final bundledExe = File('${exeDir.path}\\win_printer_helper.exe');
      if (await bundledExe.exists()) {
        _cachedPrinterHelperPath = bundledExe.path;
        return _cachedPrinterHelperPath;
      }

      // 3. Check system temp
      final tempExe = File('${Directory.systemTemp.path}\\win_printer_helper.exe');
      if (await tempExe.exists()) {
        _cachedPrinterHelperPath = tempExe.path;
        return _cachedPrinterHelperPath;
      }

      // 4. If source exists in windows/win_printer_helper.cs, compile to temp with csc.exe
      final sourceFile = File('${Directory.current.path}\\windows\\win_printer_helper.cs');
      final cscExe = File(r'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe');
      if (await sourceFile.exists() && await cscExe.exists()) {
        final res = await Process.run(cscExe.path, [
          '/nologo',
          '/optimize',
          '/target:exe',
          '/out:${tempExe.path}',
          sourceFile.path,
        ]).timeout(const Duration(seconds: 5), onTimeout: () => ProcessResult(0, 1, '', 'Timed out'));
        if (res.exitCode == 0 && await tempExe.exists()) {
          _cachedPrinterHelperPath = tempExe.path;
          return _cachedPrinterHelperPath;
        }
      }
    } catch (e) {
      debugPrint('Note: Could not initialize native printer helper: $e');
    }
    return null;
  }

  /// Handles Windows raw thermal printing via Win32 spooler RAW datatype or direct serial port
  static Future<bool> _printRawBytesWindows(List<int> bytes) async {
    try {
      final savedConfig = await getSavedPrinterConfig();

      // 1. If savedConfig specifies a serial COM port (e.g. COM5 for MPT-III or COM3 for USB)
      if (savedConfig.isSerial && savedConfig.address != null && savedConfig.address!.isNotEmpty) {
        final port = savedConfig.address!;
        debugPrint('Sending ${bytes.length} raw bytes to configured COM port: $port');
        final success = await _writeToWindowsComPort(port, bytes);
        if (success) return true;
      }

      // 2. If active in-memory COM port is selected
      if (_activeComPort != null) {
        debugPrint('Sending ${bytes.length} raw bytes to active COM port: $_activeComPort');
        final success = await _writeToWindowsComPort(_activeComPort!, bytes);
        if (success) return true;
      }

      // 3. If configured as a specific system spooler printer
      if (savedConfig.isSystem && savedConfig.name.isNotEmpty) {
        debugPrint('Sending ${bytes.length} raw bytes to configured spooler printer: ${savedConfig.name}');
        final success = await _sendToWindowsPrinterRaw(savedConfig.name, bytes);
        if (success) return true;
      }

      // 4. Check legacy saved COM port in preferences
      final savedCom = await getSavedThermalComPort();
      if (savedCom != null && savedCom.isNotEmpty) {
        final success = await _writeToWindowsComPort(savedCom, bytes);
        if (success) return true;
      }

      // 5. Check legacy saved printer name
      final savedName = await getSavedThermalPrinterName();
      if (savedName != null && savedName.isNotEmpty) {
        final success = await _sendToWindowsPrinterRaw(savedName, bytes);
        if (success) return true;
      }

      // 6. Find target printer in Windows Spooler
      final printers = await Printing.listPrinters();
      Printer? targetSpooler;

      // Check default printer if thermal or Generic
      try {
        final def = printers.firstWhere((p) => p.isDefault);
        if (isLikelyThermalPrinter(def) || def.name.contains('Generic')) {
          targetSpooler = def;
        }
      } catch (_) {}

      // Check any installed likely thermal printer
      if (targetSpooler == null) {
        try {
          targetSpooler = printers.firstWhere((p) => !PdfService.isVirtualPrinter(p.name) && (isLikelyThermalPrinter(p) || p.name.contains('Generic')));
        } catch (_) {}
      }

      if (targetSpooler != null) {
        debugPrint('Sending ${bytes.length} raw bytes to Windows printer: ${targetSpooler.name}');
        final success = await _sendToWindowsPrinterRaw(targetSpooler.name, bytes);
        if (success) return true;
      }

      // 7. Check paired Bluetooth printer devices with outgoing COM ports
      final devices = await getPairedBluetoothDevices();
      for (final dev in devices) {
        if (!dev.isIncoming && dev.address.toUpperCase().startsWith('COM')) {
          debugPrint('Trying discovered printer port: ${dev.displayName} (${dev.address})');
          final success = await _writeToWindowsComPort(dev.address, bytes);
          if (success) {
            _activeComPort = dev.address;
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('Windows raw print dispatch error: $e');
    }
    return false;
  }

  /// Public entry point to send raw ESC/POS bytes directly to a specific named Windows spooler printer
  static Future<bool> sendRawBytesToNamedPrinter(String printerName, List<int> bytes) async {
    if (kIsWeb || !Platform.isWindows) return false;
    return await _sendToWindowsPrinterRaw(printerName, bytes);
  }

  /// Sends raw byte stream to a named Windows printer using Win32 WinSpool RAW API
  static Future<bool> _sendToWindowsPrinterRaw(String printerName, List<int> bytes) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}\\thermal_${DateTime.now().millisecondsSinceEpoch}.bin');
      await tempFile.writeAsBytes(bytes);

      try {
        // 1. Native helper execution (runs in ~20ms)
        final helperExe = await _ensurePrinterHelperExe();
        if (helperExe != null) {
          final res = await Process.run(helperExe, ['spool', printerName, tempFile.path])
              .timeout(const Duration(seconds: 5), onTimeout: () => ProcessResult(0, 98, '', 'Timed out'));
          final out = '${res.stdout} ${res.stderr}';
          if (res.exitCode == 0 && out.contains('SUCCESS')) {
            debugPrint('Successfully printed ${bytes.length} bytes to $printerName via native helper.');
            return true;
          } else {
            debugPrint('Native helper spool output: $out');
          }
        }

        // 2. PowerShell WinSpool RAW fallback
        final escapedPrinter = printerName.replaceAll("'", "''");
        final escapedPath = tempFile.path.replaceAll("'", "''");
        final psScript = '''
\$code = @'
using System;
using System.IO;
using System.Runtime.InteropServices;
public class RawPrinterHelperFallback {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public class DOCINFOA {
        [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
        [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
        [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
    }
    [DllImport("winspool.Drv", EntryPoint = "OpenPrinterA", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern bool OpenPrinter(string szPrinter, out IntPtr hPrinter, IntPtr pd);
    [DllImport("winspool.Drv", EntryPoint = "ClosePrinter", SetLastError = true)]
    public static extern bool ClosePrinter(IntPtr hPrinter);
    [DllImport("winspool.Drv", EntryPoint = "StartDocPrinterA", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, int level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);
    [DllImport("winspool.Drv", EntryPoint = "EndDocPrinter", SetLastError = true)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);
    [DllImport("winspool.Drv", EntryPoint = "StartPagePrinter", SetLastError = true)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);
    [DllImport("winspool.Drv", EntryPoint = "EndPagePrinter", SetLastError = true)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);
    [DllImport("winspool.Drv", EntryPoint = "WritePrinter", SetLastError = true)]
    public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, int dwCount, out int dwWritten);

    public static bool SendFile(string szPrinterName, string szFileName) {
        byte[] bytes = File.ReadAllBytes(szFileName);
        IntPtr pUnmanagedBytes = Marshal.AllocCoTaskMem(bytes.Length);
        Marshal.Copy(bytes, 0, pUnmanagedBytes, bytes.Length);
        IntPtr hPrinter;
        if (!OpenPrinter(szPrinterName, out hPrinter, IntPtr.Zero)) {
            Marshal.FreeCoTaskMem(pUnmanagedBytes);
            return false;
        }
        DOCINFOA di = new DOCINFOA();
        di.pDocName = "Thermal Receipt";
        di.pDataType = "RAW";
        bool success = false;
        if (StartDocPrinter(hPrinter, 1, di)) {
            if (StartPagePrinter(hPrinter)) {
                int dwWritten = 0;
                success = WritePrinter(hPrinter, pUnmanagedBytes, bytes.Length, out dwWritten);
                EndPagePrinter(hPrinter);
            }
            EndDocPrinter(hPrinter);
        }
        ClosePrinter(hPrinter);
        Marshal.FreeCoTaskMem(pUnmanagedBytes);
        return success;
    }
}
'@
Add-Type -TypeDefinition \$code -ErrorAction SilentlyContinue
[RawPrinterHelperFallback]::SendFile('$escapedPrinter', '$escapedPath')
''';
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          psScript,
        ]).timeout(const Duration(seconds: 6), onTimeout: () => ProcessResult(0, 98, '', 'Timed out'));

        final output = (result.stdout as String).trim();
        return output.contains('True');
      } finally {
        try {
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error writing raw bytes to Windows printer $printerName: $e');
      return false;
    }
  }

  /// Writes raw byte stream directly to a Windows COM port
  static Future<bool> _writeToWindowsComPort(String comPort, List<int> bytes) async {
    try {
      final cleanPort = comPort.replaceAll(':', '').replaceAll(r'\\.\', '').trim().toUpperCase();
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}\\com_print_${DateTime.now().millisecondsSinceEpoch}.bin');
      await tempFile.writeAsBytes(bytes);

      try {
        // 1. Fast Native Helper execution (runs in ~10-20ms)
        final helperExe = await _ensurePrinterHelperExe();
        if (helperExe != null) {
          final res = await Process.run(helperExe, ['serial', cleanPort, tempFile.path, '9600'])
              .timeout(const Duration(seconds: 4), onTimeout: () => ProcessResult(0, 98, '', 'Timed out'));
          final out = '${res.stdout} ${res.stderr}';
          if (res.exitCode == 0 && out.contains('SUCCESS')) {
            debugPrint('Successfully printed ${bytes.length} bytes to $cleanPort via native helper.');
            return true;
          } else {
            debugPrint('Native helper serial output: $out');
          }
        }

        // 2. PowerShell serial port write with DTR/RTS and strict 4s timeout
        final escapedPath = tempFile.path.replaceAll("'", "''");
        final psScript = '''
\$ErrorActionPreference = 'Stop'
\$port = [System.IO.Ports.SerialPort]::new('$cleanPort', 9600, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
\$port.DtrEnable = \$true
\$port.RtsEnable = \$true
\$port.WriteTimeout = 3000
\$port.ReadTimeout = 2000
try {
  \$port.Open()
  \$b = [System.IO.File]::ReadAllBytes('$escapedPath')
  \$port.Write(\$b, 0, \$b.Length)
  Start-Sleep -Milliseconds 250
  \$port.Close()
  Write-Output "SUCCESS"
} catch {
  Write-Output ("ERROR: " + \$_.Exception.Message)
} finally {
  if (\$port.IsOpen) { try { \$port.Close() } catch {} }
}
''';
        final psResult = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          psScript,
        ]).timeout(const Duration(seconds: 5), onTimeout: () => ProcessResult(0, 98, '', 'Timed out'));

        final output = (psResult.stdout as String).trim();
        if (output.contains('SUCCESS')) {
          debugPrint('Successfully wrote ${bytes.length} bytes to $cleanPort via PowerShell');
          return true;
        } else {
          debugPrint('PowerShell serial write failed to $cleanPort: $output ${psResult.stderr}');
        }
      } finally {
        try {
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error writing to COM port $comPort: $e');
    }
    return false;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ESC/POS Command Generation (Matching Kotlin Project ESCPOSCommands.kt)
  // ──────────────────────────────────────────────────────────────────────────

  /// Generate ESC/POS byte sequence for an invoice receipt
  static List<int> generateInvoiceEscPos({
    required Invoice invoice,
    required ShopProfile shopProfile,
    BillPaperSize paperSize = BillPaperSize.mm58,
  }) {
    // 58mm: 29 usable table columns / 32 total columns (MT580P)
    // 80mm: 48 usable table columns
    final cols = paperSize == BillPaperSize.mm58 ? 29 : 48;
    final builder = EscPosBuilder();

    // 1. Initialize Printer
    builder.reset();

    // 2. Store Header (Centered, Bold, Large, Char spacing matching Kotlin)
    builder.alignCenter().setBold(true).setLargeSize().setCharSpacing(2);

    final storeName = shopProfile.shopName.isNotEmpty ? shopProfile.shopName.toUpperCase() : 'STORE';
    final wrappedName = _wrapText(storeName, paperSize == BillPaperSize.mm58 ? 24 : 36);
    for (final line in wrappedName) {
      builder.textLine(line);
    }

    builder.setBold(false).setNormalSize().resetCharSpacing();

    if (shopProfile.address.trim().isNotEmpty) {
      builder.textLine(shopProfile.address.trim());
    }
    if (shopProfile.mobile.trim().isNotEmpty) {
      builder.textLine('Ph: ${shopProfile.mobile.trim()}');
    }
    if (shopProfile.gstin.trim().isNotEmpty) {
      builder.textLine('GSTIN: ${shopProfile.gstin.trim()}');
    }

    builder.divider(cols, '=');

    // 3. Document Meta
    builder.alignLeft();
    builder.setBold(true);
    builder.textLine('Invoice: #${invoice.invoiceNumber}');
    builder.setBold(false);

    final dateStr = DateFormat('dd-MM-yyyy HH:mm').format(invoice.issueDate);
    builder.textLine('Date: $dateStr');

    if (invoice.customerName.trim().isNotEmpty) {
      builder.textLine('Customer: ${invoice.customerName.trim()}');
    }
    if (invoice.customerPhone.trim().isNotEmpty) {
      builder.textLine('Phone: ${invoice.customerPhone.trim()}');
    }

    builder.divider(cols, '-');

    // 4. Line Items Table Header (Item, Qty, Amt matching Kotlin layout)
    builder.setBold(true);
    builder.fourColumnRow('Item', 'Qty', 'Rate', 'Amt', cols);
    builder.setBold(false);
    builder.divider(cols, '-');

    // 5. Line Items
    for (final item in invoice.items) {
      final qtyStr = item.quantity % 1 == 0
          ? item.quantity.toInt().toString()
          : item.quantity.toStringAsFixed(2);
      builder.fourColumnRow(
        item.description,
        qtyStr,
        item.unitPrice.toStringAsFixed(0),
        'Rs.${item.totalPrice.toStringAsFixed(2)}',
        cols,
      );
      if (item.discount > 0) {
        builder.textLine('  (Disc: -Rs.${item.discount.toStringAsFixed(2)})');
      }
    }

    builder.divider(cols, '-');

    // 6. Totals & Tax Breakdown (Aligned right with Rs. formatting)
    builder.alignRight();
    builder.twoColumnRow('Subtotal:', 'Rs. ${invoice.subtotal.toStringAsFixed(2)}', cols);

    if (invoice.taxAmount > 0) {
      builder.twoColumnRow('GST Amount:', 'Rs. ${invoice.taxAmount.toStringAsFixed(2)}', cols);
    }
    if (invoice.discountAmount > 0) {
      final discLabel = invoice.discountPercent > 0
          ? 'Discount (${invoice.discountPercent.toStringAsFixed(invoice.discountPercent % 1 == 0 ? 0 : 1)}%):'
          : 'Discount:';
      builder.twoColumnRow(discLabel, '-Rs. ${invoice.discountAmount.toStringAsFixed(2)}', cols);
    }

    builder.divider(cols, '=');
    builder.setBold(true);
    builder.twoColumnRow('TOTAL:', 'Rs. ${invoice.totalAmount.toStringAsFixed(2)}', cols);
    builder.setBold(false);

    // 7. Bank Details if available
    if (shopProfile.bankName.trim().isNotEmpty || shopProfile.accountNumber.trim().isNotEmpty) {
      builder.alignLeft();
      builder.divider(cols, '-');
      if (shopProfile.bankName.trim().isNotEmpty) {
        builder.textLine('Bank: ${shopProfile.bankName.trim()}');
      }
      if (shopProfile.accountNumber.trim().isNotEmpty) {
        builder.textLine('A/C: ${shopProfile.accountNumber.trim()} | IFSC: ${shopProfile.ifscCode.trim()}');
      }
    }

    // 8. Footer & Tear-bar Feeds (matching Kotlin ESCPOSCommands)
    builder.feed(1);
    builder.alignCenter();
    builder.textNormal();
    builder.textLine('Thank You! Visit Again');
    if (shopProfile.shopName.isNotEmpty) {
      builder.textLine(shopProfile.shopName);
    }
    builder.feed(4); // Feeds past manual tear bar on MT580P
    builder.cutPartial();

    return builder.bytes;
  }

  /// Generate ESC/POS byte sequence for an independent test receipt
  static List<int> generateTestReceiptEscPos({
    required ShopProfile shopProfile,
    BillPaperSize paperSize = BillPaperSize.mm58,
  }) {
    final cols = paperSize == BillPaperSize.mm58 ? 29 : 48;
    final builder = EscPosBuilder();

    builder.reset();
    builder.alignCenter().setBold(true).setLargeSize().setCharSpacing(2);
    final storeName = shopProfile.shopName.isNotEmpty ? shopProfile.shopName.toUpperCase() : 'STORE';
    builder.textLine(storeName);
    builder.setBold(false).setNormalSize().resetCharSpacing();

    builder.textLine('*** THERMAL PRINTER TEST ***');
    final modelName = _connectedName ?? (paperSize == BillPaperSize.mm58 ? 'POS-58 Thermal' : 'POS-80 Thermal');
    builder.textLine('Model: $modelName');
    builder.divider(cols, '=');

    builder.alignLeft();
    builder.twoColumnRow('STATUS:', 'READY & CONNECTED', cols);
    builder.twoColumnRow('PAPER WIDTH:', '${cols + 3} cols / ${paperSize.label}', cols);

    final now = DateTime.now();
    final timeStr = DateFormat('dd-MM-yyyy HH:mm:ss').format(now);
    builder.twoColumnRow('DATE/TIME:', timeStr, cols);

    if (_connectedName != null) {
      builder.twoColumnRow('DEVICE:', _connectedName!, cols);
    }
    if (_connectedAddress != null) {
      builder.twoColumnRow('ADDRESS:', _connectedAddress!, cols);
    }

    builder.divider(cols, '-');
    builder.setBold(true);
    builder.fourColumnRow('Item', 'Qty', 'Rate', 'Amt', cols);
    builder.setBold(false);
    builder.divider(cols, '-');
    builder.fourColumnRow('Sample Item A', '2', '50', 'Rs.100.00', cols);
    builder.fourColumnRow('Sample Item B', '1', '250', 'Rs.250.00', cols);
    builder.divider(cols, '=');
    builder.setBold(true);
    builder.twoColumnRow('TOTAL:', 'Rs. 350.00', cols);
    builder.setBold(false);

    builder.divider(cols, '-');
    builder.alignCenter();
    builder.textLine('ESC/POS COMMUNICATION PASSED');
    builder.textLine('Thank You! Visit Again');
    builder.feed(4);
    builder.cutPartial();

    return builder.bytes;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // High-Level Print Dispatchers
  // ──────────────────────────────────────────────────────────────────────────

  /// Print test receipt directly via ESC/POS to the thermal printer
  static Future<bool> printTestReceiptEscPos({
    required ShopProfile shopProfile,
    BillPaperSize paperSize = BillPaperSize.mm58,
  }) async {
    try {
      final bytes = generateTestReceiptEscPos(
        shopProfile: shopProfile,
        paperSize: paperSize,
      );
      final success = await sendRawBytes(bytes);
      if (success) {
        return true;
      }
      throw Exception('Printer communication failed. Please check that printer is turned on and paired.');
    } catch (e) {
      debugPrint('Test receipt print error: $e');
      rethrow;
    }
  }

  /// Direct print invoice to Bluetooth thermal printer or Windows default printer
  static Future<bool> directPrint({
    required Invoice invoice,
    required ShopProfile shopProfile,
    required BillPaperSize paperSize,
    Printer? targetPrinter,
  }) async {
    try {
      final savedConfig = await getSavedPrinterConfig();

      // If document is A4 / A5 / 127mm size, ALWAYS use Spooler / PDF printing because ESC/POS raw bytes will ruin document printers
      if (paperSize == BillPaperSize.a4 || paperSize == BillPaperSize.a5 || paperSize == BillPaperSize.mm127) {
        final printed = await PdfService.printPdf(
          invoice: invoice,
          shopProfile: shopProfile,
          paperSize: paperSize,
          targetPrinter: targetPrinter,
        );
        return printed != null;
      }

      // If user specifically configured a system document printer (e.g. Canon A4) that is not thermal, use PDF layout
      if (savedConfig.isSystem && !savedConfig.isThermal) {
        final printed = await PdfService.printPdf(
          invoice: invoice,
          shopProfile: shopProfile,
          paperSize: paperSize,
          targetPrinter: targetPrinter,
        );
        return printed != null;
      }

      // 1. If paper size is 58mm or 80mm thermal, send raw ESC/POS commands
      if (paperSize == BillPaperSize.mm58 || paperSize == BillPaperSize.mm80) {
        final escPosBytes = generateInvoiceEscPos(
          invoice: invoice,
          shopProfile: shopProfile,
          paperSize: paperSize,
        );

        final rawSuccess = await sendRawBytes(escPosBytes);
        if (rawSuccess) {
          debugPrint('Successfully printed thermal receipt via ESC/POS stream.');
          return true;
        }
      }

      // 2. Standard document / Canon A4 or System Spooler printing fallback
      debugPrint('ESC/POS direct stream did not complete; attempting Windows Spooler PDF fallback...');
      final printed = await PdfService.printPdf(
        invoice: invoice,
        shopProfile: shopProfile,
        paperSize: paperSize,
        targetPrinter: targetPrinter,
      );
      return printed != null;
    } catch (e) {
      debugPrint('Direct print error: $e');
      try {
        final printed = await PdfService.printPdf(
          invoice: invoice,
          shopProfile: shopProfile,
          paperSize: paperSize,
          targetPrinter: targetPrinter,
        );
        return printed != null;
      } catch (_) {}
      rethrow;
    }
  }

  /// Print a test page / receipt (preserves existing signature)
  static Future<bool> printTestReceipt({
    required ShopProfile shopProfile,
    Printer? printer,
    BillPaperSize paperSize = BillPaperSize.mm80,
  }) async {
    try {
      final success = await printTestReceiptEscPos(
        shopProfile: shopProfile,
        paperSize: paperSize,
      );
      if (success) return true;
    } catch (_) {}

    // Spooler fallback
    try {
      final theme = await PdfService.getDocumentTheme();
      final pdf = pw.Document(theme: theme);
      final pageFormat = paperSize == BillPaperSize.mm58
          ? PdfService.roll58
          : PdfService.roll80;

      final now = DateTime.now();
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context ctx) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(2 * PdfPageFormat.mm),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    shopProfile.shopName.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('*** THERMAL TEST ***', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(thickness: 0.5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('STATUS:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('READY', style: pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('FORMAT:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(paperSize.label, style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('DATE:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(now), style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Divider(thickness: 0.5),
                  pw.Text('ESC/POS Thermal Test Completed', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            );
          },
        ),
      );

      final bytes = await pdf.save();
      return await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Thermal_Test_Print',
        format: pageFormat,
      );
    } catch (e) {
      debugPrint('Test receipt print error: $e');
      rethrow;
    }
  }

  /// Checks if a printer is likely a thermal or bluetooth POS printer (e.g. MT580P, POS-58)
  static bool isLikelyThermalPrinter(Printer printer) {
    final name = printer.name.toLowerCase();
    final url = printer.url.toLowerCase();
    return name.contains('pos') ||
        name.contains('thermal') ||
        name.contains('mt580') ||
        name.contains('mt58') ||
        name.contains('580') ||
        name.contains('58mm') ||
        name.contains('80mm') ||
        name.contains('pos-58') ||
        name.contains('pos58') ||
        name.contains('receipt') ||
        name.contains('rpp') ||
        name.contains('bluetooth') ||
        name.contains('inner') ||
        url.contains('bluetooth') ||
        url.contains('rfcomm') ||
        url.contains('com') ||
        url.contains('usb');
  }

  static List<String> _wrapText(String text, int maxWidth) {
    if (text.length <= maxWidth) return [text];
    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      final testLine = currentLine.isEmpty ? word : '$currentLine $word';
      if (testLine.length <= maxWidth) {
        currentLine = testLine;
      } else {
        if (currentLine.isNotEmpty) lines.add(currentLine);
        currentLine = word;
      }
    }
    if (currentLine.isNotEmpty) lines.add(currentLine);
    return lines.isEmpty ? [text.substring(0, maxWidth)] : lines;
  }
}

/// Helper class to assemble standard ESC/POS byte sequences matching Kotlin ESCPOSCommands.kt
class EscPosBuilder {
  final List<int> _bytes = [];

  List<int> get bytes => List.unmodifiable(_bytes);

  EscPosBuilder reset() {
    _bytes.addAll([0x1B, 0x40]); // ESC @ (Initialize)
    return this;
  }

  EscPosBuilder alignLeft() {
    _bytes.addAll([0x1B, 0x61, 0x00]); // ESC a 0
    return this;
  }

  EscPosBuilder alignCenter() {
    _bytes.addAll([0x1B, 0x61, 0x01]); // ESC a 1
    return this;
  }

  EscPosBuilder alignRight() {
    _bytes.addAll([0x1B, 0x61, 0x02]); // ESC a 2
    return this;
  }

  EscPosBuilder setBold(bool enable) {
    _bytes.addAll([0x1B, 0x45, enable ? 0x01 : 0x00]); // ESC E n
    return this;
  }

  EscPosBuilder setNormalSize() {
    _bytes.addAll([0x1B, 0x21, 0x00]); // ESC ! 0x00
    return this;
  }

  EscPosBuilder setDoubleHeight() {
    _bytes.addAll([0x1B, 0x21, 0x10]); // ESC ! 0x10
    return this;
  }

  EscPosBuilder setDoubleWidth() {
    _bytes.addAll([0x1B, 0x21, 0x20]); // ESC ! 0x20
    return this;
  }

  EscPosBuilder setLargeSize() {
    _bytes.addAll([0x1B, 0x21, 0x11]); // ESC ! 0x11 (Large)
    return this;
  }

  EscPosBuilder textNormal() {
    _bytes.addAll([0x1B, 0x21, 0x00]);
    return this;
  }

  EscPosBuilder setCharSpacing([int n = 2]) {
    _bytes.addAll([0x1B, 0x20, n]); // ESC SP n
    return this;
  }

  EscPosBuilder resetCharSpacing() {
    _bytes.addAll([0x1B, 0x20, 0x00]);
    return this;
  }

  EscPosBuilder feed([int lines = 1]) {
    _bytes.addAll([0x1B, 0x64, lines]); // ESC d n
    return this;
  }

  EscPosBuilder textLine(String text) {
    final sanitized = _sanitizeText(text);
    _bytes.addAll(utf8.encode(sanitized));
    _bytes.add(0x0A);
    return this;
  }

  EscPosBuilder text(String text) {
    final sanitized = _sanitizeText(text);
    _bytes.addAll(utf8.encode(sanitized));
    return this;
  }

  EscPosBuilder divider([int cols = 29, String char = '-']) {
    final line = char * cols;
    textLine(line);
    return this;
  }

  EscPosBuilder twoColumnRow(String left, String right, int cols) {
    final sLeft = _sanitizeText(left);
    final sRight = _sanitizeText(right);
    final availableSpaces = cols - (sLeft.length + sRight.length);
    if (availableSpaces >= 1) {
      textLine('$sLeft${' ' * availableSpaces}$sRight');
    } else {
      textLine(sLeft);
      final pad = cols > sRight.length ? ' ' * (cols - sRight.length) : '';
      textLine('$pad$sRight');
    }
    return this;
  }

  EscPosBuilder fourColumnRow(String item, String qty, String rate, String total, int cols) {
    final sItem = _sanitizeText(item);
    final sQty = _sanitizeText(qty);
    final sRate = _sanitizeText(rate);
    final sTotal = _sanitizeText(total);

    if (cols <= 32) {
      // 58mm layout (29 chars): Item (13), Qty (3), Rate (5), Total (8)
      // Matches Fly-Bill String.format("%-14s %-5s %8s")
      const itemW = 13;
      const qtyW = 3;
      const rateW = 5;
      const totalW = 8;

      final truncatedItem = sItem.length > itemW ? sItem.substring(0, itemW) : sItem;
      final line = truncatedItem.padRight(itemW) +
          sQty.padLeft(qtyW) +
          sRate.padLeft(rateW) +
          sTotal.padLeft(totalW);
      textLine(line);
    } else {
      // 80mm layout (48 chars)
      const itemW = 22;
      const qtyW = 6;
      const rateW = 8;
      const totalW = 12;

      final truncatedItem = sItem.length > itemW ? sItem.substring(0, itemW) : sItem;
      final line = truncatedItem.padRight(itemW) +
          sQty.padLeft(qtyW) +
          sRate.padLeft(rateW) +
          sTotal.padLeft(totalW);
      textLine(line);
    }
    return this;
  }

  EscPosBuilder cutPartial() {
    _bytes.addAll([0x1D, 0x56, 0x01]); // GS V 1 (Partial cut matching Kotlin)
    return this;
  }

  String _sanitizeText(String input) {
    return input
        .replaceAll('₹', 'Rs.')
        .replaceAll('•', '*')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'");
  }
}
