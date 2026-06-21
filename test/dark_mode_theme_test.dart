import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dissuplain_app_web_mobile/app_theme.dart';
import 'package:dissuplain_app_web_mobile/CommonFooter.dart';

void main() {
  testWidgets('CommonFooter uses the active theme colors in dark mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: const Center(child: Text('content')),
          bottomNavigationBar: CommonFooter(),
        ),
      ),
    );

    final bottomBar = tester.widget<BottomAppBar>(find.byType(BottomAppBar));
    final context = tester.element(find.byType(CommonFooter));

    expect(Theme.of(context).brightness, Brightness.dark);
    expect(bottomBar.color, Theme.of(context).colorScheme.surface);
  });
}
