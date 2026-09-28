import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AdminRow = Map<String, dynamic>;

class PlatformAdminService {
  static Future<dynamic> query(
    String view, {
    String? businessId,
    String? id,
    String? filter,
    String? accessReason,
    String search = '',
    int offset = 0,
  }) => Supabase.instance.client.rpc(
    'platform_admin_query',
    params: {
      'p_view': view,
      'p_business_id': businessId,
      'p_id': id,
      'p_filter': filter,
      'p_access_reason': accessReason,
      'p_search': search,
      'p_offset': offset,
    },
  );
  static Future<AdminRow> action(String action, AdminRow data) async => map(
    await Supabase.instance.client.rpc(
      'platform_admin_action',
      params: {'p_action': action, 'p_data': data},
    ),
  );
  static AdminRow map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static List<AdminRow> rows(dynamic value) =>
      value is List ? value.map(map).toList() : <AdminRow>[];
  static double amount(dynamic value) => double.tryParse('$value') ?? 0;
  static String money(dynamic value) => '\$${amount(value).toStringAsFixed(2)}';
  static String date(dynamic value) {
    final d = DateTime.tryParse('$value');
    return d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String iso(DateTime date) => date.toIso8601String().substring(0, 10);
  static String name(AdminRow b) =>
      '${b['trading_name'] ?? b['billing_name'] ?? b['legal_name'] ?? 'Business'}';
  static String error(Object e) =>
      e is PostgrestException ? e.message : e.toString();
  static String requestKey() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
