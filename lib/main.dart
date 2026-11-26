import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'providers/billing_provider.dart';
import 'widgets/responsive_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseService.verifyConnectivity();
  } catch (e) {
    debugPrint('Firebase init note: $e');
  }
  runApp(const BillingApp());
}

class BillingApp extends StatelessWidget {
  const BillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BillingProvider(),
      child: Consumer<BillingProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: 'FlyBill - Billing & Invoicing',
            debugShowCheckedModeBanner: false,
            theme: provider.themeData,
            home: const ResponsiveLayout(),
          );
        },
      ),
    );
  }
}
