import 'package:flutter/material.dart';
import '../../features/landing/presentation/public_page_palette.dart';

/// Public account pages share a visual frame; their forms own all account logic.
class PublicAuthFrame extends StatelessWidget {
  const PublicAuthFrame({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.step,
  });
  final String title;
  final String description;
  final Widget child;
  final int? step;

  @override
  Widget build(BuildContext context) {
    const ink = PublicPagePalette.background;
    const red = Color(0xFF933744);
    final theme = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: red,
        brightness: Brightness.light,
        surface: PublicPagePalette.surface,
      ),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: PublicPagePalette.border),
    );
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.link_rounded,
          size: 42,
          color: PublicPagePalette.accent,
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            color: PublicPagePalette.text,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          description,
          style: const TextStyle(
            color: PublicPagePalette.muted,
            fontSize: 16,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final label in const [
              'Wholesale trade',
              'Suppliers & butchers',
            ])
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: PublicPagePalette.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: PublicPagePalette.muted,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        if (step != null) ...[
          const SizedBox(height: 30),
          for (final item in const [
            (1, 'Business type'),
            (2, 'Login details'),
            (3, 'Business details'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: step == item.$1
                        ? red
                        : PublicPagePalette.border,
                    child: Text(
                      '${item.$1}',
                      style: TextStyle(
                        color: step == item.$1
                            ? Colors.white
                            : PublicPagePalette.text,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: TextStyle(
                        color: step == item.$1
                            ? PublicPagePalette.text
                            : PublicPagePalette.muted,
                        fontWeight: step == item.$1
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: PublicPagePalette.background,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: red, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          helperMaxLines: 3,
          errorMaxLines: 3,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: PublicPagePalette.accent,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: ink,
        appBar: AppBar(
          backgroundColor: ink,
          foregroundColor: PublicPagePalette.text,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'CutLink',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: PublicPagePalette.border),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 20 : 40,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final form = Container(
                      padding: EdgeInsets.all(c.maxWidth < 600 ? 20 : 32),
                      decoration: BoxDecoration(
                        color: PublicPagePalette.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: PublicPagePalette.border),
                      ),
                      child: child,
                    );
                    if (c.maxWidth < 900) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [intro, const SizedBox(height: 28), form],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: intro,
                          ),
                        ),
                        const SizedBox(width: 48),
                        Expanded(flex: 6, child: form),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
