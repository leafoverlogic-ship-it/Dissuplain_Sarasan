
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'dart:html' as html;

class AppSession {
  static final AppSession _instance = AppSession._internal();
  factory AppSession() => _instance;
  AppSession._internal();

  static const String _sessionKey = 'dissuplain_app_session';

  // Context
  String? roleId;
  String? salesPersonName;
  String? salesPersonId;
  bool? allAccess;
  bool? deviceLocationEnabled;
  List<String>? allowedRegionIds;
  List<String>? allowedAreaIds;
  List<String>? allowedSubareaIds;

  bool get isLoggedIn =>
      (roleId ?? '').trim().isNotEmpty ||
      (salesPersonName ?? '').trim().isNotEmpty ||
      (salesPersonId ?? '').trim().isNotEmpty;

  void saveToStorage() {
    if (!kIsWeb) return;

    final payload = <String, dynamic>{
      'roleId': roleId ?? '',
      'salesPersonName': salesPersonName ?? '',
      'salesPersonId': salesPersonId ?? '',
      'allAccess': allAccess ?? false,
      'deviceLocationEnabled': deviceLocationEnabled ?? false,
      'allowedRegionIds': allowedRegionIds ?? const <String>[],
      'allowedAreaIds': allowedAreaIds ?? const <String>[],
      'allowedSubareaIds': allowedSubareaIds ?? const <String>[],
    };

    html.window.sessionStorage[_sessionKey] = jsonEncode(payload);
  }

  void loadFromStorage() {
    if (!kIsWeb) return;

    final raw = html.window.sessionStorage[_sessionKey];
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      roleId = (payload['roleId'] ?? '').toString();
      salesPersonName = (payload['salesPersonName'] ?? '').toString();
      salesPersonId = (payload['salesPersonId'] ?? '').toString();
      allAccess = payload['allAccess'] == true;
      deviceLocationEnabled = payload['deviceLocationEnabled'] == true;
      allowedRegionIds = List<String>.from(payload['allowedRegionIds'] ?? const <String>[]);
      allowedAreaIds = List<String>.from(payload['allowedAreaIds'] ?? const <String>[]);
      allowedSubareaIds = List<String>.from(payload['allowedSubareaIds'] ?? const <String>[]);
    } catch (_) {
      clear();
    }
  }

  void clear() {
    roleId = null;
    salesPersonName = null;
    salesPersonId = null;
    allAccess = null;
    deviceLocationEnabled = null;
    allowedRegionIds = null;
    allowedAreaIds = null;
    allowedSubareaIds = null;

    if (kIsWeb) {
      html.window.sessionStorage.remove(_sessionKey);
    }
  }

  void setContext({
    required String roleId,
    required String salesPersonName,
    String? salesPersonId,     
    required bool allAccess,
    bool deviceLocationEnabled = false,
    required List<String> allowedRegionIds,
    required List<String> allowedAreaIds,
    required List<String> allowedSubareaIds,
  }) {
    this.roleId = roleId;
    this.salesPersonName = salesPersonName;
    this.salesPersonId = salesPersonId;
    this.allAccess = allAccess;
    this.deviceLocationEnabled = deviceLocationEnabled;
    this.allowedRegionIds = List<String>.from(allowedRegionIds);
    this.allowedAreaIds = List<String>.from(allowedAreaIds);
    this.allowedSubareaIds = List<String>.from(allowedSubareaIds);

    saveToStorage();
  }

  void setDeviceLocationEnabled(bool enabled) {
    deviceLocationEnabled = enabled;
    saveToStorage();
  }
}
