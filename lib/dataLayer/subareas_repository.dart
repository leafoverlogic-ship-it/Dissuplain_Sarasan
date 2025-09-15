import 'package:firebase_database/firebase_database.dart';

class SubAreaEntry {
  final String subareaId;
  final String subareaName;
  final String areaId;
  final String regionId;
  const SubAreaEntry({
    required this.subareaId,
    required this.subareaName,
    required this.areaId,
    required this.regionId,
  });
}

class SubAreasRepository {
  SubAreasRepository({FirebaseDatabase? db}) : _db = db ?? FirebaseDatabase.instance;
  final FirebaseDatabase _db;

  Stream<List<SubAreaEntry>> streamSubAreas() =>
      _db.ref('SubAreas').onValue.map((e) => _extract(e.snapshot.value));

  Future<List<SubAreaEntry>> fetchOnce() async {
    final s = await _db.ref('SubAreas').get();
    return _extract(s.value);
  }

  static List<SubAreaEntry> _extract(dynamic raw) {
    final out = <SubAreaEntry>[];

    String? pick(Map m, List<String> keys) {
      for (final k in keys) {
        if (m.containsKey(k) && (m[k]?.toString().trim().isNotEmpty ?? false)) {
          return m[k].toString().trim();
        }
      }
      return null;
    }

    void addFrom(Map v, String fallbackKey) {
      final sid = pick(v, ['subareaID','subareaId','SubAreaID','SubareaID','subareaID']) ?? fallbackKey;
      final sname = pick(v, ['subareaName','SubAreaName','subAreaName','name','Name']) ?? '';
      final aid = pick(v, ['areaID','areaId','AreaID','AreaId']) ?? '';
      final rid = pick(v, ['regionId','RegionId','RegionID','regionID']) ?? '';
      if (sid.isNotEmpty) {
        out.add(SubAreaEntry(subareaId: sid, subareaName: sname, areaId: aid, regionId: rid));
      }
    }

    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) addFrom(v, k.toString());
      });
    } else if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final v = raw[i];
        if (v is Map) addFrom(v, i.toString());
      }
    }

    out.sort((a, b) {
      final n = a.subareaName.toLowerCase().compareTo(b.subareaName.toLowerCase());
      return n != 0 ? n : a.subareaId.compareTo(b.subareaId);
    });
    final seen = <String>{};
    return out.where((e) => seen.add('${e.subareaId}|${e.subareaName}|${e.areaId}|${e.regionId}')).toList();
  }
}
