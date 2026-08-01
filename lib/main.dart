import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabasePublishableKey =
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    throw Exception('SUPABASE_URL is missing from the .env file.');
  }

  if (supabasePublishableKey == null ||
      supabasePublishableKey.isEmpty) {
    throw Exception(
      'SUPABASE_PUBLISHABLE_KEY is missing from the .env file.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabasePublishableKey,
  );

  runApp(const MeatMarketplaceApp());
}

class MeatMarketplaceApp extends StatelessWidget {
  const MeatMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NSW Meat Marketplace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B1E1E),
        ),
        useMaterial3: true,
      ),
      home: const ConnectionTestPage(),
    );
  }
}

class ConnectionTestPage extends StatelessWidget {
  const ConnectionTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final projectUrl = Supabase.instance.client.rest.url;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NSW Meat Marketplace'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 72,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Supabase connected successfully',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your Flutter application has loaded the '
                      'Supabase project configuration.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Project: $projectUrl',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}