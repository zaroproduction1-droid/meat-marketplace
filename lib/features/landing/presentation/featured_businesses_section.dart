import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/presentation/registration_type_page.dart';
import 'public_page_palette.dart';

class FeaturedBusinessesSection extends StatefulWidget {
  const FeaturedBusinessesSection({super.key, this.onRegister});
  final ValueChanged<BusinessType>? onRegister;
  @override
  State<FeaturedBusinessesSection> createState() =>
      _FeaturedBusinessesSectionState();
}

class _FeaturedBusinessesSectionState extends State<FeaturedBusinessesSection> {
  late Future<Map<String, dynamic>> _data;
  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(
    await Supabase.instance.client.rpc('cutlink_public_businesses') as Map,
  );
  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _data,
    builder: (context, snapshot) {
      final data = snapshot.data;
      final rows = (data?['featured'] as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      return Column(
        children: [
          const Text(
            'THE CUTLINK COMMUNITY',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PublicPagePalette.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'The CutLink community.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PublicPagePalette.text,
              fontSize: MediaQuery.sizeOf(context).width < 600 ? 29 : 37,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 32),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: PublicPagePalette.accent),
            )
          else if (snapshot.hasError)
            Column(
              children: [
                const Text(
                  'The community is temporarily unavailable.',
                  style: TextStyle(color: PublicPagePalette.muted),
                ),
                TextButton(
                  onPressed: () => setState(() => _data = _load()),
                  style: TextButton.styleFrom(
                    foregroundColor: PublicPagePalette.accent,
                  ),
                  child: const Text('Try again'),
                ),
              ],
            )
          else ...[
            _role(true, data, rows),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Divider(color: PublicPagePalette.border),
            ),
            _role(false, data, rows),
          ],
        ],
      );
    },
  );
  Widget _role(
    bool supplier,
    Map<String, dynamic>? data,
    List<Map<String, dynamic>> all,
  ) {
    final role = supplier ? 'supplier' : 'butcher';
    final count = data?['${role}_total'];
    final featured = all
        .where((row) => row['business_type'] == role)
        .take(5)
        .toList();
    return Column(
      children: [
        Text(
          supplier ? 'Featured suppliers' : 'Featured butchers',
          style: const TextStyle(
            color: PublicPagePalette.text,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        if (featured.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Community businesses will appear here when selected.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PublicPagePalette.muted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 1000
                  ? 5
                  : box.maxWidth >= 650
                  ? 3
                  : box.maxWidth >= 350
                  ? 2
                  : 1;
              final width = ((box.maxWidth - 16 * (columns - 1)) / columns)
                  .clamp(0.0, 230.0);
              return SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final row in featured)
                      Container(
                        width: width,
                        height: 190,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 22,
                        ),
                        decoration: BoxDecoration(
                          color: PublicPagePalette.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: PublicPagePalette.border),
                        ),
                        child: Column(
                          children: [
                            BusinessDisplayLogo(
                              path: row['logo_path'] as String?,
                              size: 82,
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: Center(
                                child: Text(
                                  row['name'] as String? ?? '',
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: PublicPagePalette.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        if (count != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              '$count registered ${supplier ? 'suppliers' : 'butchers'} in total',
              style: const TextStyle(
                color: PublicPagePalette.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (widget.onRegister != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton.icon(
              onPressed: () => widget.onRegister!(
                supplier ? BusinessType.supplier : BusinessType.butcher,
              ),
              style: TextButton.styleFrom(
                foregroundColor: PublicPagePalette.accent,
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(
                supplier ? 'Join as a supplier' : 'Join as a butcher',
              ),
            ),
          ),
      ],
    );
  }
}

class BusinessDisplayLogo extends StatelessWidget {
  const BusinessDisplayLogo({super.key, this.path, this.size = 64});
  final String? path;
  final double size;
  @override
  Widget build(BuildContext context) {
    final value = path?.trim() ?? '';
    final url = value.startsWith('https://')
        ? value
        : value.isEmpty
        ? ''
        : Supabase.instance.client.storage
              .from('business-branding')
              .getPublicUrl(value);
    final fallback = Icon(
      Icons.storefront_outlined,
      size: size * .55,
      color: const Color(0xFF697681),
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stack) => fallback,
            ),
    );
  }
}
