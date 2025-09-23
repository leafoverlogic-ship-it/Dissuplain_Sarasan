import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/UserNamePwd.dart';
import 'screens/TestExportPage.dart';
import 'screens/Admin.dart';
import 'screens/ExportViaClients.dart';
import 'screens/DataMigrationScreen.dart';

void main() async{
  
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options:DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:'Dissuplain',
      initialRoute: '/',
      routes: {
        '/': (context) => UserNamePwdPage(),
        //'/': (context) => TestExportPage(),
        //'/': (context) => ExportViaClients(),
        //'/': (context) => Admin(),
        //'/': (context) => InsertData(),
      },
    );
  }
}
