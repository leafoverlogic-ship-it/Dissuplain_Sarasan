
import 'package:flutter/foundation.dart';

class AppSession {
  static final AppSession _instance = AppSession._internal();
  factory AppSession() => _instance;
  AppSession._internal();

  // Context
  String? roleId;
  String? salesPersonName;
  String? salesPersonId;
  bool? allAccess;
  List<String>? allowedRegionIds;
  List<String>? allowedAreaIds;
  List<String>? allowedSubareaIds;

  void clear() {
    roleId = null;
    salesPersonName = null;
    salesPersonId = null;
    allAccess = null;
    allowedRegionIds = null;
    allowedAreaIds = null;
    allowedSubareaIds = null;
  }

  void setContext({
    required String roleId,
    required String salesPersonName,
    String? salesPersonId,     
    required bool allAccess,
    required List<String> allowedRegionIds,
    required List<String> allowedAreaIds,
    required List<String> allowedSubareaIds,
  }) {
    this.roleId = roleId;
    this.salesPersonName = salesPersonName;
    this.salesPersonId = salesPersonId;
    this.allAccess = allAccess;
    this.allowedRegionIds = List<String>.from(allowedRegionIds);
    this.allowedAreaIds = List<String>.from(allowedAreaIds);
    this.allowedSubareaIds = List<String>.from(allowedSubareaIds);
  }
}
