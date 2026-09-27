import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'page_location_storage.dart';

class PageLocation extends NavigatorObserver {
  static final instance = PageLocation();
  final Map<Route<dynamic>, Map<String, dynamic>> _routes = {};
  Map<String, dynamic> _workspace = {'page': 'dashboard'};
  static String get _key =>
      'cutlink.page.${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}';
  static Map<String, dynamic>? saved() {
    try {
      final raw = readLocation(_key);
      return raw == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static void clear() {
    clearLocation(_key);
    instance._routes.clear();
  }

  static void workspace(Map<String, dynamic> location) {
    instance._routes.clear();
    instance._workspace = location;
    writeLocation(_key, jsonEncode(location));
  }

  static void track(BuildContext context, Map<String, dynamic> location) {
    final route = ModalRoute.of(context);
    if (route == null) {
      return;
    }
    instance._routes[route] = location;
    if (route.isCurrent) {
      writeLocation(
        _key,
        jsonEncode({...location, 'workspace': instance._workspace}),
      );
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    if (previousRoute is PopupRoute) {
      return;
    }
    final previous = _routes[previousRoute];
    writeLocation(
      _key,
      jsonEncode(
        previous == null ? _workspace : {...previous, 'workspace': _workspace},
      ),
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
  }
}
