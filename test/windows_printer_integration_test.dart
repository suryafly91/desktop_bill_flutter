import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/services/bluetooth_printer_service.dart';

void main() {
  test('Windows printer device discovery and spooler check', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final devices = await BluetoothPrinterService.getPairedBluetoothDevices();
    expect(devices, isNotNull);
    print('Found ${devices.length} devices:');
    for (final d in devices) {
      print('  - Device: ${d.displayName} (${d.address}), isBluetooth: ${d.isBluetooth}, isUsb: ${d.isUsb}');
    }

    final stuck = await BluetoothPrinterService.getWindowsStuckJobCount();
    print('Stuck jobs in spooler: $stuck');
    expect(stuck, greaterThanOrEqualTo(0));
  });
}
