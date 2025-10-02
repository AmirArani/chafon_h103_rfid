import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'device_scan_screen.dart';
import 'l10n/app_localizations.dart';
import 'models/tag.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TagAdapter());
  await Hive.openBox<Tag>('tagsBox');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          // seedColor: const Color(0xff1F493D),
          seedColor: Colors.green.shade900,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final base = Theme.of(context);
        final textTheme = GoogleFonts.vazirmatnTextTheme(base.textTheme);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Theme(
            data: base.copyWith(textTheme: textTheme),
            child: child!,
          ),
        );
      },
      home: const DeviceScanScreen(),
    );
  }
}
