import 'package:firebase_database/firebase_database.dart';

class AreaEntry {
  final String areaId;
  final String areaName;
  final String regionId;
  const AreaEntry({required this.areaId, required this.areaName, required this.regionId});
}

class AreasRepository {
  AreasRepository({FirebaseDatabase? db}) : _db = db ?? FirebaseDatabase.instance;
  final FirebaseDatabase _db;

  Stream<List<AreaEntry>> streamAreas() =>
      _db.ref('Areas').onValue.map((e) => _extract(e.snapshot.value));

  Future<List<AreaEntry>> fetchOnce() async {
    final s = await _db.ref('Areas').get();
    return _extract(s.value);
  }

  static List<AreaEntry> _extract(dynamic raw) {
    final out = <AreaEntry>[];

    String? pick(Map m, List<String> keys) {
      for (final k in keys) {
        if (m.containsKey(k) && (m[k]?.toString().trim().isNotEmpty ?? false)) {
          return m[k].toString().trim();
        }
      }
      return null;
    }

    void addFrom(Map v, String fallbackKey) {
      final id = pick(v, ['areaID','areaId','AreaID','AreaId','id','Id']) ?? fallbackKey;
      final name = pick(v, ['areaName','AreaName','name','Name']) ?? '';
      final regionId = pick(v, ['regionId','RegionId','RegionID','regionID']) ?? '';
      if (id.isNotEmpty) {
        out.add(AreaEntry(areaId: id, areaName: name, regionId: regionId));
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
      final n = a.areaName.toLowerCase().compareTo(b.areaName.toLowerCase());
      return n != 0 ? n : a.areaId.compareTo(b.areaId);
    });
    final seen = <String>{};
    return out.where((e) => seen.add('${e.areaId}|${e.areaName}|${e.regionId}')).toList();
  }
}
