import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerAccountService {
  static Future<Map<String, dynamic>> save({
    required String supplierBusinessId,
    Map<String, dynamic>? account,
    required Map<String, dynamic> values,
  }) async {
    final result = await Supabase.instance.client.rpc(
      'save_supplier_customer_account_profile',
      params: {
        'p_supplier_business_id': supplierBusinessId,
        'p_account_id': account?['id'],
        'p_values': values,
        'p_expected_updated_at': account?['updated_at'],
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }
}
