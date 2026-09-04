import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/evaluation/add_evaluation_screen.dart';
import 'models/evaluation.dart';
import 'core/auth/local_auth_service.dart';
import 'core/security/secure_storage_service.dart';
import 'services/study_history_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── UI de sistema: modo edge-to-edge real ───────────────────────
  // Sin esto, la barra de navegación por gestos de Android queda con
  // el scrim claro por defecto del sistema, que se ve como una franja
  // blanca sobre el fondo oscuro de la app. La hacemos transparente y
  // forzamos iconos claros (la app es oscura de punta a punta).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  ));

  // ── Firebase ───────────────────────────────────────────────────
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── Hive ───────────────────────────────────────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(EvaluationAdapter());

  await Hive.openBox('legal_consent');
  await Hive.openBox<Evaluation>('evaluations');
  await Hive.openBox('settings');

  // ── Secretos (API key) ──────────────────────────────────────────
  // Nunca hardcodear claves en el código fuente: se leen de
  // --dart-define en build y se persisten en Keystore/Keychain.
  await SecureStorageService.initDefaultApiKey();

  // ── Auth ───────────────────────────────────────────────────────
  await LocalAuthService.seedAdminIfNeeded();
  await LocalAuthService.migrateUsersFromHiveToFirestore();

  // ── Localización ───────────────────────────────────────────────
  await initializeDateFormatting('es', null);
  await StudyHistoryService.init();

  runApp(const ProviderScope(child: EstudIArApp()));
}

class EstudIArApp extends StatelessWidget {
  const EstudIArApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EstudIAr',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      locale: const Locale('es'),
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D0520),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0D0520),
          indicatorColor: const Color(0x33A855F7),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {'/add': (_) => const AddEvaluationScreen()},
    );
  }
}