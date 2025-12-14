// lib/CommonHeader.dart
import 'package:flutter/material.dart';
import 'package:dissuplain_app_web_mobile/screens/Phone_Entry.dart';

import 'screens/Clients_Summary.dart';
import './screens/Dashboard.dart';
import './screens/Attendance.dart';
import './screens/Admin.dart';
import 'screens/DataMigrationScreen.dart';
import 'screens/TerritoryManagerPage.dart';
import 'screens/UserNamePwd.dart'; // <-- added fallback login
import 'screens/SalesRegisterPage.dart';
import 'app_session.dart';

class CommonHeader extends StatelessWidget implements PreferredSizeWidget {
  final String pageTitle;

  /// New: shows "Welcome <name>" if provided
  final String? userName;

  /// Logout callback (optional). If null, we fallback to UserNamePwdPage.
  final VoidCallback? onLogout;

  /// Context needed to keep access restrictions when navigating via header
  final String? roleId;
  final String? salesPersonName;
  final bool? allAccess;
  final List<String>? allowedRegionIds;
  final List<String>? allowedAreaIds;
  final List<String>? allowedSubareaIds;

  const CommonHeader({
    super.key,
    required this.pageTitle,
    this.userName,
    this.onLogout,
    this.roleId,
    this.salesPersonName,
    this.allAccess,
    this.allowedRegionIds,
    this.allowedAreaIds,
    this.allowedSubareaIds,
  });

  void _logout(BuildContext context) {
    if (onLogout != null) {
      onLogout!();
      return;
    }
    // Fallback: go to username/password login and clear stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const UserNamePwdPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset(
                  'assets/images/Sarasan_Logo.png',
                  width: 57,
                  height: 57,
                ),
                Column(
                  children: [
                    Text(
                      pageTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (userName != null && userName!.isNotEmpty)
                      Text(
                        'Welcome $userName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Logout'),
                    ),
                    const SizedBox(width: 8),
                    Image.asset(
                      'assets/images/Dissuplain_Image.png',
                      width: 57,
                      height: 57,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 5,
            child: Container(color: const Color.fromARGB(255, 209, 209, 209)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Prefer props if provided, else fallback to AppSession
                    final sess = AppSession();

                    final rId = roleId ?? sess.roleId;
                    final sName =
                        salesPersonName ?? (sess.salesPersonName ?? '');
                    final aAcc = allAccess ?? (sess.allAccess ?? false);
                    final rIds =
                        allowedRegionIds ?? (sess.allowedRegionIds ?? const []);
                    final aIds =
                        allowedAreaIds ?? (sess.allowedAreaIds ?? const []);
                    final sIds =
                        allowedSubareaIds ??
                        (sess.allowedSubareaIds ?? const []);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClientsSummaryPage(
                          roleId:
                              rId ??
                              '5', // fallback safest role if truly missing
                          salesPersonName: sName,
                          allAccess: aAcc,
                          allowedRegionIds: rIds,
                          allowedAreaIds: aIds,
                          allowedSubareaIds: sIds,
                        ),
                      ),
                    );
                  },
                  style: menuButtonStyle,
                  child: const Text("Clients"),
                ),
                /*ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => Dashboard()));
                  },
                  style: menuButtonStyle,
                  child: const Text("Dashboard"),
                ),
                const SizedBox(width: 8),
                
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => Phone_Entry()));
                  },
                  style: menuButtonStyle,
                  child: const Text("Orders"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                  },
                  style: menuButtonStyle,
                  child: const Text("Attendance"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => InsertData()));
                  },
                  style: menuButtonStyle,
                  child: const Text("Admin"),
                ),*/
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final sess = AppSession();
                    final rId = roleId ?? sess.roleId;
                    final sName =
                        salesPersonName ?? (sess.salesPersonName ?? '');
                    final aAcc = allAccess ?? (sess.allAccess ?? false);
                    final rIds =
                        allowedRegionIds ?? (sess.allowedRegionIds ?? const []);
                    final aIds =
                        allowedAreaIds ?? (sess.allowedAreaIds ?? const []);
                    final sIds =
                        allowedSubareaIds ??
                        (sess.allowedSubareaIds ?? const []);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SalesRegisterPage(
                          roleId: rId,
                          salesPersonName: sName,
                          allAccess: aAcc,
                          allowedRegionIds: rIds,
                          allowedAreaIds: aIds,
                          allowedSubareaIds: sIds,
                          onLogout: onLogout,
                        ),
                      ),
                    );
                  },
                  style: menuButtonStyle,
                  child: const Text("Sales Register"),
                ),
                const SizedBox(width: 8),
                if ((roleId is int ? roleId : int.tryParse('$roleId')) == 4)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Admin()),
                      );
                    },
                    style: menuButtonStyle,
                    child: const Text("Admin"),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 5,
            child: Container(color: const Color.fromARGB(255, 209, 209, 209)),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

final ButtonStyle menuButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: Colors.black,
  elevation: 1,
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
);
