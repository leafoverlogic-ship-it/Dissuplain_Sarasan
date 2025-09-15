import 'package:firebase_database/firebase_database.dart';

String _s(dynamic v) => v?.toString().trim() ?? '';

/// One row from /Users
class UserEntry {
  final String salesPersonId;      // SalesPersonID / salesPersonID
  final String salesPersonName;    // SalesPersonName / salesPersonName
  final String emailAddress;       // EmailAddress / email
  final String phoneNumber;        // PhoneNumber / phone
  final String salesPersonRoleId;  // SalesPersonRoleID / salesPersonRoleId / RoleID
  final String reportingPersonId;  // ReportingPersonID / reportingPersonID / managerID
  final String loginPwd;           // loginPwd / LoginPwd / password

  const UserEntry({
    required this.salesPersonId,
    required this.salesPersonName,
    required this.emailAddress,
    required this.phoneNumber,
    required this.salesPersonRoleId,
    required this.reportingPersonId,
    required this.loginPwd,
  });
}

class UsersRepository {
  UsersRepository({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference get _ref => _db.ref('Users');

  Stream<List<UserEntry>> streamUsers() =>
      _ref.onValue.map((e) => _extract(e.snapshot.value));

  Future<List<UserEntry>> fetchOnce() async {
    final s = await _ref.get();
    return _extract(s.value);
  }

  static List<UserEntry> _extract(dynamic raw) {
    final out = <UserEntry>[];

    void addFrom(Map<dynamic, dynamic> m) {
      // Handle multiple key casings/aliases defensively
      final spId   = _s(m['SalesPersonID'] ?? m['salesPersonID'] ?? m['salesPersonId'] ?? m['UserID'] ?? m['userId']);
      final spName = _s(m['SalesPersonName'] ?? m['salesPersonName'] ?? m['name']);
      final email  = _s(m['EmailAddress'] ?? m['email'] ?? m['Email']);
      final phone  = _s(m['PhoneNumber'] ?? m['phone'] ?? m['Mobile'] ?? m['mobile']);
      final roleId = _s(m['SalesPersonRoleID'] ?? m['salesPersonRoleId'] ?? m['RoleID'] ?? m['roleId']);
      final mgrId  = _s(m['ReportingPersonID'] ?? m['reportingPersonID'] ?? m['reportingPersonId'] ?? m['ManagerID'] ?? m['managerId']);
      final pwd    = _s(m['loginPwd'] ?? m['LoginPwd'] ?? m['password'] ?? m['Password']);

      // Minimal guard: must have an ID
      if (spId.isEmpty) return;

      out.add(UserEntry(
        salesPersonId: spId,
        salesPersonName: spName,
        emailAddress: email,
        phoneNumber: phone,
        salesPersonRoleId: roleId,
        reportingPersonId: mgrId,
        loginPwd: pwd,
      ));
    }

    if (raw is Map) {
      raw.forEach((_, v) {
        if (v is Map) addFrom(v);
      });
    } else if (raw is List) {
      for (final v in raw) {
        if (v is Map) addFrom(v);
      }
    }

    return out;
  }
}
