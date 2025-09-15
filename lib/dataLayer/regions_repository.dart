import 'package:firebase_database/firebase_database.dart';

/// DTO for a region row.
class RegionEntry {
  final String regionId;
  final String regionName;
  const RegionEntry({required this.regionId, required this.regionName});
}

/// Repository for reading Regions from Firebase Realtime Database.
class RegionsRepository {
  RegionsRepository({FirebaseDatabase? db}) : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  /// Live stream of RegionEntry rows from /Regions.
  /// - Tolerates Map/List node shapes
  /// - Accepts common key variants: regionId/RegionId/id/Id and regionName/RegionName/name/Name
  /// - Falls back to the child key for regionId if field missing
  Stream<List<RegionEntry>> streamRegions() {
    final ref = _db.ref('Regions');
    return ref.onValue.map((event) {
      final raw = event.snapshot.value;
      final rows = _extractEntries(raw);
      // Sort by name, then id for stable display
      rows.sort((a, b) {
        final n = a.regionName.toLowerCase().compareTo(b.regionName.toLowerCase());
        return n != 0 ? n : a.regionId.toLowerCase().compareTo(b.regionId.toLowerCase());
      });
      return rows;
    });
  }

  /// One-shot fetch (optional)
  Future<List<RegionEntry>> fetchRegionsOnce() async {
    final snap = await _db.ref('Regions').get();
    final rows = _extractEntries(snap.value);
    rows.sort((a, b) {
      final n = a.regionName.toLowerCase().compareTo(b.regionName.toLowerCase());
      return n != 0 ? n : a.regionId.toLowerCase().compareTo(b.regionId.toLowerCase());
    });
    return rows;
  }

  // ---- Parsing helpers ----

  static List<RegionEntry> _extractEntries(dynamic raw) {
    final List<RegionEntry> out = [];

    String? _pickName(dynamic v) {
      if (v is Map) {
        for (final k in const ['regionName', 'RegionName', 'regionname', 'name', 'Name']) {
          if (v.containsKey(k)) {
            final s = v[k]?.toString().trim();
            if (s != null && s.isNotEmpty) return s;
          }
        }
      } else if (v is String) {
        final s = v.trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    }

    String? _pickId(dynamic v) {
      if (v is Map) {
        for (final k in const ['regionId', 'RegionId', 'regionID', 'RegionID', 'id', 'Id', 'ID']) {
          if (v.containsKey(k)) {
            final s = v[k]?.toString().trim();
            if (s != null && s.isNotEmpty) return s;
          }
        }
      } else if (v is String) {
        // Sometimes the value itself might be the ID
        final s = v.trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    }

    if (raw is Map) {
      // Example: { "1": {regionId:"1", regionName:"Varanasi"}, "2": {...} }
      raw.forEach((childKey, value) {
        final name = _pickName(value) ?? '';
        final id   = _pickId(value) ?? childKey.toString();
        if (name.isNotEmpty || id.isNotEmpty) {
          out.add(RegionEntry(regionId: id, regionName: name));
        }
      });
    } else if (raw is List) {
      // Example: [null, {regionId:"1", regionName:"Varanasi"}, ...]
      for (var i = 0; i < raw.length; i++) {
        final v = raw[i];
        final name = _pickName(v) ?? '';
        final id   = _pickId(v) ?? i.toString();
        if (name.isNotEmpty || id.isNotEmpty) {
          out.add(RegionEntry(regionId: id, regionName: name));
        }
      }
    } else if (raw != null) {
      // Primitive at /Regions – treat as a single row
      final s = raw.toString().trim();
      if (s.isNotEmpty) {
        out.add(RegionEntry(regionId: s, regionName: s));
      }
    }

    // Optional: dedupe by (regionId, regionName) pair
    final seen = <String>{};
    return out.where((e) {
      final key = '${e.regionId}::${e.regionName}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }
}
