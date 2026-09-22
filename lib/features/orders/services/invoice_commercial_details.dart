Map<String, dynamic> invoiceCommercialDetails(Map<String, dynamic> invoice) {
  final raw = invoice['commercial_details_snapshot'];
  return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
}

String commercialText(dynamic value) => value?.toString().trim() ?? '';

String commercialDate(dynamic value) {
  final text = commercialText(value);
  final date = DateTime.tryParse(text);
  return date == null
      ? text
      : '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

Map<String, String> invoiceCommercialReferences(Map<String, dynamic> invoice) {
  final details = invoiceCommercialDetails(invoice);
  final rawOrder = invoice['orders'];
  final order = rawOrder is Map ? rawOrder : const <String, dynamic>{};
  final fields = <String, String>{
    'Account No.': commercialText(details['account_number']),
    'Order No.': commercialText(
      details['order_number'] ?? order['order_number'],
    ),
    'Customer PO No.': commercialText(invoice['customer_reference_snapshot']),
    'Salesperson': commercialText(details['salesperson_name']),
    'Sales phone': commercialText(details['salesperson_phone']),
    'Delivery / pickup date': commercialDate(details['delivery_date']),
    'Run No.': commercialText(details['run_number']),
  };
  fields.removeWhere((key, value) => value.isEmpty);
  return fields;
}

Map<String, String> invoiceCommercialNotices(Map<String, dynamic> invoice) {
  final details = invoiceCommercialDetails(invoice);
  final hours = num.tryParse('${details['issue_reporting_hours']}');
  final fields = <String, String>{
    'Delivery instructions': commercialText(details['delivery_instructions']),
    'Accreditations': commercialText(details['accreditations']),
    'Retail labelling': commercialText(details['labelling_notice']),
    'Issue reporting': hours != null && hours > 0
        ? 'Please report delivery or product issues within $hours hours of receipt.'
        : '',
    'Supplier terms': commercialText(details['terms']),
  };
  fields.removeWhere((key, value) => value.isEmpty);
  return fields;
}

String invoiceSupplySummary(List<Map<String, dynamic>> items) {
  double cartons = 0;
  double kg = 0;
  var hasWeight = false;
  double number(dynamic value) => num.tryParse('$value')?.toDouble() ?? 0;
  for (final item in items) {
    final unit = commercialText(
      item['supplied_quantity_unit'] ?? item['ordered_quantity_unit'],
    );
    final quantity = number(
      item['supplied_quantity'] ?? item['ordered_quantity'],
    );
    if (unit == 'carton') {
      cartons += quantity;
    }
    final weightUnit = commercialText(item['actual_weight_unit']);
    if (item['actual_weight'] != null &&
        (weightUnit.isEmpty ||
            weightUnit == 'kg' ||
            weightUnit == 'kilogram')) {
      kg += number(item['actual_weight']);
      hasWeight = true;
    } else if (unit == 'kilogram' || unit == 'kg') {
      kg += quantity;
      hasWeight = true;
    }
  }
  return [
    if (cartons > 0)
      'Cartons: ${cartons == cartons.roundToDouble() ? cartons.toInt() : cartons}',
    if (hasWeight) 'Recorded weight: ${kg.toStringAsFixed(2)} kg',
  ].join('  |  ');
}
