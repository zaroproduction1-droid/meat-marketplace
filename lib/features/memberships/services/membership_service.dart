import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class MembershipService {
  static Map<String, dynamic> map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static Future<Map<String, dynamic>> publicPricing() async => map(
    await Supabase.instance.client
        .rpc('cutlink_public_pricing')
        .timeout(const Duration(seconds: 15)),
  );
  static Future<Map<String, dynamic>> mine(String businessId) async => map(
    await Supabase.instance.client
        .rpc('my_cutlink_membership', params: {'p_business_id': businessId})
        .timeout(const Duration(seconds: 15)),
  );
  static Future<Map<String, dynamic>> admin({
    String search = '',
    int offset = 0,
  }) async => map(
    await Supabase.instance.client
        .rpc(
          'platform_membership_admin_query',
          params: {'p_search': search, 'p_offset': offset},
        )
        .timeout(const Duration(seconds: 15)),
  );
  static String stage(dynamic stage) => switch (stage) {
    'free_founding' => 'Free founding period',
    'founding_half_price' => 'Founding 50% period',
    'not_started' => 'Not started',
    'standard' => 'Standard membership',
    _ => 'Awaiting membership review',
  };
  static String money(dynamic amount) =>
      '\$${(num.tryParse('$amount') ?? 0).toStringAsFixed(2)}';
}
