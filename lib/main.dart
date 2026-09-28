import 'features/landing/presentation/cutlink_landing_content.dart';
import 'shared/navigation/page_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/authentication/presentation/sign_in_page.dart';
import 'features/authentication/presentation/registration_type_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabasePublishableKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    throw Exception('SUPABASE_URL is missing from the .env file.');
  }

  if (supabasePublishableKey == null || supabasePublishableKey.isEmpty) {
    throw Exception('SUPABASE_PUBLISHABLE_KEY is missing from the .env file.');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const CutLinkApp());
}

class CutLinkApp extends StatelessWidget {
  const CutLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CutLink',
      navigatorObservers: [PageLocation.instance],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F7F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7A1F1F),
          brightness: Brightness.light,
        ),
        fontFamily: 'Arial',
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          width: 440,
          backgroundColor: const Color(0xFF111C27),
          elevation: 10,
          showCloseIcon: true,
          closeIconColor: Colors.white70,
          actionTextColor: const Color(0xFFFFD7D7),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  static const Color darkRed = Color(0xFF741C1C);
  static const Color darkText = Color(0xFF1D1D1D);
  static const Color softBackground = Color(0xFFF7F7F5);

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  void initState() {
    super.initState();
    if (Supabase.instance.client.auth.currentSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SignInPage(restoreSession: true),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => CutLinkLandingContent(
    onSignIn: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SignInPage())),
    onRegister: (role) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegistrationTypePage(initialBusinessType: role),
      ),
    ),
  );
}
