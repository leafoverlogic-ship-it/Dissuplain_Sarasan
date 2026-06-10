import 'package:firebase_database/firebase_database.dart';

class ActivityLogEntry {
  final String id; // push key
  final String customerCode; // index field
  final String type; // "Phone Call" | "In Person Meeting"
  final String message;
  final DateTime dateTime; // when the activity happened
  final DateTime?
  createdAt; // when the log was created (server timestamp if available)

  ActivityLogEntry({
    required this.id,
    required this.customerCode,
    required this.type,
    required this.message,
    required this.dateTime,
    this.createdAt,
  });

  factory ActivityLogEntry.fromMap(String id, Map<dynamic, dynamic> m) {
    DateTime? _ts(dynamic v) {
      if (v == null) return null;
      final n = int.tryParse(v.toString());
      if (n == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(n);
    }

    return ActivityLogEntry(
      id: id,
      customerCode: (m['customerCode'] ?? '').toString().trim(),
      type: (m['type'] ?? '').toString().trim(),
      message: (m['message'] ?? '').toString().trim(),
      dateTime: _ts(m['dateTimeMillis']) ?? DateTime.now(),
      createdAt: _ts(m['createdAt']),
    );
  }
}

class ActivityLogsRepository {
  ActivityLogsRepository({FirebaseDatabase? db})
    : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference get _ref => _db.ref('ActivityLogs');

  /// Live stream of logs for a customer, ordered by dateTimeMillis ascending.
  Stream<List<ActivityLogEntry>> streamForCustomer(String customerCode) {
    final q = _ref.orderByChild('customerCode').equalTo(customerCode);
    return q.onValue.map((event) {
      final snap = event.snapshot;
      final List<ActivityLogEntry> out = [];
      if (snap.value is Map) {
        (snap.value as Map).forEach((key, value) {
          if (value is Map) {
            out.add(ActivityLogEntry.fromMap(key.toString(), value));
          }
        });
      } else if (snap.value is List) {
        final list = snap.value as List;
        for (var i = 0; i < list.length; i++) {
          final value = list[i];
          if (value is Map) {
            out.add(ActivityLogEntry.fromMap(i.toString(), value));
          }
        }
      }
      out.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return out;
    });
  }

  /// Add a new log.
  Future<void> addLog({
    required String customerCode,
    required String type,
    required String message,
    required DateTime dateTime,
    String? userId,
    String? response,
  }) async {
    final key = _ref.push().key!;
    await _ref.child(key).set({
      'customerCode': customerCode,
      'type': type,
      'message': message,
      'dateTimeMillis': dateTime.millisecondsSinceEpoch,
      if (userId != null && userId.isNotEmpty) 'userId': userId,
       if (response != null && response.isNotEmpty) 'Response': response,
      'createdAt': ServerValue.timestamp,
    });
  }
}
