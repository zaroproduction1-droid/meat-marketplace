import 'dart:convert';
import 'package:cutlink/features/support/presentation/support_center_page.dart';
import 'package:cutlink/shared/theme/cutlink_app_theme.dart';
import 'package:cutlink/shared/theme/cutlink_appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => CutLinkAppearance.instance.setMode(ThemeMode.system));
  for (final dark in [false, true]) {
    for (final width in [375.0, 1440.0]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
          'Support opens a conversation $width scale $scale dark $dark',
          (tester) async {
            tester.view.physicalSize = Size(width, 1000);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await CutLinkAppearance.instance.setMode(
              dark ? ThemeMode.dark : ThemeMode.light,
            );
            late SupabaseClient client;
            await tester.runAsync(() async {
              client = SupabaseClient(
                'https://test.invalid',
                'test',
                httpClient: MockClient((request) async {
                  final path = request.url.path;
                  if (path.endsWith('/businesses')) {
                    return http.Response(
                      jsonEncode({'business_type': 'supplier'}),
                      200,
                      request: request,
                      headers: {'content-type': 'application/json'},
                    );
                  }
                  if (path.endsWith('/support_tickets')) {
                    return http.Response(
                      jsonEncode([
                        {
                          'id': 'ticket1',
                          'ticket_number': 'SUP-00214',
                          'business_id': 'business',
                          'subject': 'Help with an invoice',
                          'business_name': 'A5 Butchers',
                          'requester_name': 'Sam',
                          'category': 'technical',
                          'priority': 'normal',
                          'status': 'open',
                          'created_at': '2026-11-07T10:00:00Z',
                          'updated_at': '2026-11-07T10:00:00Z',
                        },
                      ]),
                      200,
                      request: request,
                      headers: {'content-type': 'application/json'},
                    );
                  }
                  if (path.endsWith('/support_ticket_messages')) {
                    return http.Response(
                      jsonEncode([
                        {
                          'id': 'message1',
                          'ticket_id': 'ticket1',
                          'sender_role': 'admin',
                          'sender_name': 'CutLink Support',
                          'message': 'Thanks, we can help with that.',
                          'created_at': '2026-11-07T10:01:00Z',
                          'support_ticket_attachments': [],
                        },
                      ]),
                      200,
                      request: request,
                      headers: {'content-type': 'application/json'},
                    );
                  }
                  return http.Response(
                    'null',
                    200,
                    request: request,
                    headers: {'content-type': 'application/json'},
                  );
                }),
              );
              await client.from('businesses').select().single();
            });
            await tester.runAsync(() async {
              await tester.pumpWidget(
                AppearanceScope(
                  child: MaterialApp(
                    theme: cutLinkAppTheme(
                      dark ? Brightness.dark : Brightness.light,
                    ),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: SupportCenterPage(
                      businessId: 'business',
                      adminMode: false,
                      client: client,
                      listenForUpdates: false,
                    ),
                  ),
                ),
              );
              await Future<void>.delayed(const Duration(milliseconds: 50));
            });
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.text('Help with an invoice'),
              findsOneWidget,
              reason: tester
                  .widgetList<Text>(find.byType(Text))
                  .map((e) => e.data)
                  .join('; '),
            );
            await tester.runAsync(() async {
              await tester.tap(find.text('Help with an invoice'));
              await Future<void>.delayed(const Duration(milliseconds: 50));
            });
            await tester.pumpAndSettle();
            expect(find.text('Thanks, we can help with that.'), findsOneWidget);
            expect(tester.takeException(), isNull);
            expect(find.byType(TextField), findsWidgets);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.runAsync(client.dispose);
          },
        );
      }
    }
  }
}
