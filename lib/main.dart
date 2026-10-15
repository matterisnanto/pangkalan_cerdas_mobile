import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/transaction_queue_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/pelanggan_screen.dart';
import 'ui/screens/webview_screen.dart';
import 'ui/widgets/glass_components.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FASE 3: Initialize Firebase Firestore with offline persistence
  try {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // FR-8.1: Initialize local notifications
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Notification init error: $e');
  }

  final themeProvider = ThemeProvider();
  await themeProvider.load();
  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider,
      child: const PangkalanCerdasApp(),
    ),
  );
}

class PangkalanCerdasApp extends StatelessWidget {
  const PangkalanCerdasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TransactionQueueProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, theme, __) => MaterialApp(
          title: 'Pangkalan Cerdas LPG 3Kg',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.themeMode,
          home: const MainNavigationScreen(),
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      auth.onTokenExpired = _showTokenExpiredDialog;
    });
  }

  void _showTokenExpiredDialog() {
    if (!mounted) return;
    _onSelectTab(2);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sesi Login Berakhir'),
        content: const Text('Silakan Login Ulang untuk Melanjutkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Login Ulang'),
          ),
        ],
      ),
    );
  }

  void _onSelectTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) {
      // Home queue refreshes from its Firebase-backed data source.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(onOpenWebView: () => _onSelectTab(2)),
          const PelangganScreen(),
          WebViewScreen(onBackToDashboard: () => _onSelectTab(0)),
        ],
      ),
      bottomNavigationBar: GlassBottomNavBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onSelectTab,
      ),
    );
  }
}
