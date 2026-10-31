import 'shared/theme/workspace_message_theme.dart';
import 'shared/theme/cutlink_appearance.dart';

import 'dart:convert';

import 'features/landing/presentation/cutlink_landing_content.dart';
import 'shared/navigation/page_location.dart';
import 'shared/widgets/ios_workspace.dart';

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

  // Frontend assets are public. Never initialise this client with a privileged key.
  if (supabasePublishableKey.startsWith('sb_secret_')) {
    throw StateError('Use a Supabase publishable key in the frontend.');
  }
  if (!supabasePublishableKey.startsWith('sb_publishable_')) {
    try {
      final segments = supabasePublishableKey.split('.');
      final claims =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
              )
              as Map;
      if (claims['role'] != 'anon') {
        throw const FormatException('Privileged key');
      }
    } catch (_) {
      throw StateError(
        'Use a Supabase publishable key or legacy anon key in the frontend.',
      );
    }
  }
  final endpoint = Uri.tryParse(supabaseUrl);
  if (endpoint == null || endpoint.scheme != 'https' || endpoint.host.isEmpty) {
    throw StateError('SUPABASE_URL must be an HTTPS project endpoint.');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  await CutLinkAppearance.instance.load();
  runApp(const CutLinkApp());
}

class CutLinkApp extends StatelessWidget {
  const CutLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CutLinkAppearance.instance,
      builder: (context, _) => MaterialApp(
        themeMode: CutLinkAppearance.instance.mode,
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          fontFamily: 'Arial',
          snackBarTheme: workspaceMessageTheme(Brightness.dark),
          scaffoldBackgroundColor: const Color(0xFF111113),
          colorScheme:
              ColorScheme.fromSeed(
                seedColor: const Color(0xFF850E25),
                brightness: Brightness.dark,
              ).copyWith(
                primary: const Color(0xFFFF8EA3),
                onPrimary: const Color(0xFF430014),
                surface: const Color(0xFF1C1C1E),
                onSurface: const Color(0xFFF2F2F7),
              ),
          appBarTheme: const AppBarThemeData(
            backgroundColor: Color(0xFF111113),
            foregroundColor: Color(0xFFF2F2F7),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFF252528),
          ),
        ),
        title: 'CutLink',
        navigatorObservers: [PageLocation.instance],
        debugShowCheckedModeBanner: false,
        builder: (context, child) => AppearanceScope(
          child: useIosWorkspace(context)
              ? Theme(
                  data: IosWorkspaceStyle.theme(Theme.of(context)),
                  child: child!,
                )
              : child!,
        ),
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF7F7F5),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7A1F1F),
            brightness: Brightness.light,
          ),
          fontFamily: 'Arial',
          snackBarTheme: workspaceMessageTheme(Brightness.light),
        ),
        home: const LandingPage(),
      ),
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
  Widget build(BuildContext context) {
    if (useIosWorkspace(context)) {
      return IosWelcomePage(
        onSignIn: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SignInPage())),
        onRegister: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RegistrationTypePage()),
        ),
      );
    }
    return CutLinkLandingContent(
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
}
