import 'package:firebase_database/firebase_database.dart';

class ActivityLogEntry {
  final String id; // push key
  final String customerCode; // index field
  final String type; // "Phone Call" | "In Person Meeting"
  final String message;
  final DateTime dateTime; // when the activity happened
  final DateTime?
  createdAt; // when the log was created (server timestamp if available)
  final double? locationLat;
  final double? locationLng;
  final DateTime? locationCapturedAt;

  ActivityLogEntry({
    required this.id,
    required this.customerCode,
    required this.type,
    required this.message,
    required this.dateTime,
    this.createdAt,
    this.locationLat,
    this.locationLng,
    this.locationCapturedAt,
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
      locationLat: double.tryParse((m['locationLat'] ?? '').toString()),
      locationLng: double.tryParse((m['locationLng'] ?? '').toString()),
      locationCapturedAt: _ts(m['locationCapturedAt']),
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
    double? locationLat,
    double? locationLng,
    DateTime? locationCapturedAt,
  }) async {
    final key = _ref.push().key!;
    await _ref.child(key).set({
      'customerCode': customerCode,
      'type': type,
      'message': message,
      'dateTimeMillis': dateTime.millisecondsSinceEpoch,
      if (userId != null && userId.isNotEmpty) 'userId': userId,
      if (response != null && response.isNotEmpty) 'Response': response,
      if (locationLat != null) 'locationLat': locationLat,
      if (locationLng != null) 'locationLng': locationLng,
      if (locationCapturedAt != null)
        'locationCapturedAt': locationCapturedAt.millisecondsSinceEpoch,
      'createdAt': ServerValue.timestamp,
    });

    // Check if this is the first "New Call" activity for this customer and set Date_of_1st_Call
    if (type.trim().toLowerCase() == 'new call') {
      // Query to find if there are other "New Call" logs for this customer
      final query = _ref.orderByChild('customerCode').equalTo(customerCode);
      final snap = await query.get();
      
      int newCallCount = 0;
      if (snap.value is Map) {
        (snap.value as Map).forEach((_, value) {
          if (value is Map) {
            final logType = (value['type'] ?? '').toString().trim().toLowerCase();
            if (logType == 'new call') {
              newCallCount++;
            }
          }
        });
      } else if (snap.value is List) {
        final list = snap.value as List;
        for (final value in list) {
          if (value is Map) {
            final logType = (value['type'] ?? '').toString().trim().toLowerCase();
            if (logType == 'new call') {
              newCallCount++;
            }
          }
        }
      }

      // If this is the first "New Call", set Date_of_1st_Call in Clients
      if (newCallCount == 1) {
        try {
          final clientsQuery = await _db
              .ref('Clients')
              .orderByChild('customerCode')
              .equalTo(customerCode)
              .get();

          String? clientKey;
          for (final child in clientsQuery.children) {
            if (child.key != null && child.key!.isNotEmpty) {
              clientKey = child.key!;
              break;
            }
          }

          if (clientKey != null) {
            await _db.ref('Clients/$clientKey').update({
              'Date_of_1st_Call': dateTime.millisecondsSinceEpoch,
            });
          }
        } catch (e) {
          // Log error but don't fail the addLog operation
          print('Error setting Date_of_1st_Call: $e');
        }
      }
    }
  }
}
