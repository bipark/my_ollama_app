import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'views/drawer.dart';
import 'views/desktop_view.dart';
import 'provider/main_provider.dart';
import 'utils/platform_utils.dart';

//--------------------------------------------------------------------------//
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MainProvider()),
    ],
    child: EasyLocalization(
        supportedLocales: [
          Locale('en', 'US'),
          Locale('ko', 'KR'),
          Locale('ja', 'JP')
        ],
        path: 'assets/translations',
        fallbackLocale: Locale('en', 'US'),
        child: MyOllama()),
  ));
}

//--------------------------------------------------------------------------//
class MyOllama extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      localizationsDelegates: context.localizationDelegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
      home: InitializationWrapper(),
    );
  }
}

//--------------------------------------------------------------------------//
class InitializationWrapper extends StatefulWidget {
  @override
  _InitializationWrapperState createState() => _InitializationWrapperState();
}

//--------------------------------------------------------------------------//
class _InitializationWrapperState extends State<InitializationWrapper> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      setLocale(context);
      _initializeApp();
    });
  }

  Future<void> setLocale(BuildContext context) async {
    String currentLocale = Intl.getCurrentLocale();
    List<String> parts = currentLocale.split('_');

    switch (parts[0]) {
      case 'ko':
        context.setLocale(const Locale('ko', 'KR'));
        break;
      case 'ja':
        context.setLocale(const Locale('ja', 'JP'));
        break;
      default:
        context.setLocale(const Locale('en', 'US'));
        break;
    }
  }

  Future<void> _initializeApp() async {
    final provider = Provider.of<MainProvider>(context, listen: false);
    await provider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MainProvider>(
      builder: (context, provider, _) {
        if (!provider.isInitialized) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Initializing...').tr(),
                ],
              ),
            ),
          );
        }

        return isDesktopOrTablet()
            ? DesktopView()
            : MyDrawer();
      },
    );
  }
}
