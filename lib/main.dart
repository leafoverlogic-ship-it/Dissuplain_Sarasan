import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_session.dart';
import 'app_theme.dart';
import 'screens/UserNamePwd.dart';
import 'screens/Clients_Summary.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppSession();
    session.loadFromStorage();

    final Widget home;
    if (session.isLoggedIn) {
      home = Builder(
        builder: (context) => ClientsSummaryPage(
          roleId: session.roleId ?? '5',
          salesPersonName: session.salesPersonName ?? '',
          allAccess: session.allAccess ?? false,
          allowedRegionIds: session.allowedRegionIds ?? const [],
          allowedAreaIds: session.allowedAreaIds ?? const [],
          allowedSubareaIds: session.allowedSubareaIds ?? const [],
          onLogout: () {
            session.clear();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const UserNamePwdPage()),
              (route) => false,
            );
          },
        ),
      );
    } else {
      home = const UserNamePwdPage();
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeController,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Dissuplain',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          home: home,
        );
      },
    );
  }
}
