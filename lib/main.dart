import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'state/app_state.dart';
import 'screen/login_screen.dart';
import 'screen/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AppState s) => s.user);
    final isDarkMode = context.select((AppState s) => s.isDarkMode);

    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFBFC4CC),
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8A92A6),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Budget Management',
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        appBarTheme: const AppBarTheme(
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.black,
        ),
        scaffoldBackgroundColor: lightScheme.background,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: lightScheme.surface,
          selectedItemColor: lightScheme.primary,
          unselectedItemColor: lightScheme.onSurfaceVariant,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightScheme.primary,
            foregroundColor: lightScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: darkScheme.copyWith(
          surface: const Color(0xFF1E1E1F), 
          background: const Color(0xFF121212),
        ),
        appBarTheme: AppBarTheme(
          surfaceTintColor: Colors.transparent,
          foregroundColor: darkScheme.onBackground,
          backgroundColor: const Color(0xFF1E1E1F),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color(0xFF1E1E1F),
          selectedItemColor: darkScheme.primary,
          unselectedItemColor: darkScheme.onSurfaceVariant,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkScheme.primary,
            foregroundColor: darkScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: user == null ? const LoginScreen() : const MainScreen(),
    );
  }
}
