import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../CommonHeader.dart';
import '../CommonFooter.dart';
import 'ClientDetailsPage.dart';
import '../../dataLayer/customers_repository.dart';
import '../../dataLayer/areas_repository.dart';
import '../../dataLayer/subareas_repository.dart';
import '../app_session.dart';

enum _DateFilterType { all, day, month, year, range }

enum _SortType { orderDateDesc, delayDesc }

enum _ApprovalStage { am, gm, ceo }

class _SalesRegisterRow {
  final String orderNo;
  final DateTime? orderDate;
  final String orderConfirmation;
  final String category;
  final String city;
  final String destination;
  final String customerCode;
  final String outletName;
  final String address;
  final String contactPerson;
  final String contactMobile;
  final String gstin;
  final String docName;
  final String docContact;
  final String productCode;
  final String productName;
  final String billingType;
  final String billingPercent;
  final int billedQty;
  final int freeQty;
  final double rate;
  final double totalAmount;
  final double cdAmount;
  final double totalBillingAmount; // after CD for the line
  final double grandTotal; // order-level grand total (column 25)
  final String orderType;
  final String salesPersonName;
  final String amApproverName;
  final String gmApproverName;
  final String ceoApproverName;
  final String deliveryStatus;
  final DateTime? deliveryDate;
  final DateTime? finalApprovalDate;
  final String orderNotes;

  const _SalesRegisterRow({
    required this.orderNo,
    required this.orderDate,
    required this.orderConfirmation,
    required this.category,
    required this.city,
    required this.destination,
    required this.customerCode,
    required this.outletName,
    required this.address,
    required this.contactPerson,
    required this.contactMobile,
    required this.gstin,
    required this.docName,
    required this.docContact,
    required this.productCode,
    required this.productName,
    required this.billingType,
    required this.billingPercent,
    required this.billedQty,
    required this.freeQty,
    required this.rate,
    required this.totalAmount,
    required this.cdAmount,
    required this.totalBillingAmount,
    required this.grandTotal,
    required this.orderType,
    required this.salesPersonName,
    required this.amApproverName,
    required this.gmApproverName,
    required this.ceoApproverName,
    required this.deliveryStatus,
    required this.deliveryDate,
    required this.finalApprovalDate,
    required this.orderNotes,
  });
}

class SalesRegisterPage extends StatefulWidget {
  final String? roleId;
  final String? salesPersonName;
  final bool? allAccess;
  final List<String>? allowedRegionIds;
  final List<String>? allowedAreaIds;
  final List<String>? allowedSubareaIds;
  final VoidCallback? onLogout;

  const SalesRegisterPage({
    Key? key,
    this.roleId,
    this.salesPersonName,
    this.allAccess,
    this.allowedRegionIds,
    this.allowedAreaIds,
    this.allowedSubareaIds,
    this.onLogout,
  }) : super(key: key);

  @override
  State<SalesRegisterPage> createState() => _SalesRegisterPageState();
}

class _SalesRegisterPageState extends State<SalesRegisterPage> {
  final _db = FirebaseDatabase.instance;
  late final CustomersRepository _customersRepo = CustomersRepository(db: _db);
  late final AreasRepository _areasRepo = AreasRepository(db: _db);
  late final SubAreasRepository _subAreasRepo = SubAreasRepository(db: _db);

  StreamSubscription<DatabaseEvent>? _ordersSub;
  dynamic _lastOrdersRaw;
  List<_SalesRegisterRow> _allRows = const [];

  final Map<String, CustomerEntry> _customerByCode = {};
  final Map<String, AreaEntry> _areaById = {};
  final Map<String, SubAreaEntry> _subareaById = {};
  final Map<String, String> _userNameById = {};
  Set<String> _allowedCustomerCodes = {};

  _DateFilterType _filterType = _DateFilterType.all;
  DateTime? _selectedDay;
  DateTime? _selectedMonth;
  DateTime? _selectedYear;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  _SortType _sortType = _SortType.orderDateDesc;
  bool _undeliveredOnly = false;
  int get _currentRole {
    final roleId = (widget.roleId ?? AppSession().roleId ?? '').trim();
    return int.tryParse(roleId) ?? 0;
  }

  String get _currentUserId => (AppSession().salesPersonId ?? '').trim();
  bool get _canAccessSalesRegister {
    return _currentRole == 4 || _currentUserId == 'SS-1132';
  }

  String get _currentUserName {
    final sessionName = (AppSession().salesPersonName ?? '').trim();
    if (sessionName.isNotEmpty) return sessionName;
    final id = _currentUserId;
    return _userNameById[id] ?? id;
  }

  bool _canEditRate(_SalesRegisterRow r) {
    return _canActOnOrder(r);
  }

  String _displayStatus(String raw, double total) {
    final t = raw.trim();
    if (t.isEmpty) return 'New';
    final lower = t.toLowerCase();
    if (lower == 'confirmed') return 'Confirmed';
    if (lower == 'am confirmed') {
      return _gmNeeded(total) ? 'Awaiting GM Approval' : 'Confirmed';
    }
    if (lower == 'gm confirmed') {
      return _ceoNeeded(total) ? 'Awaiting CEO Approval' : 'Confirmed';
    }
    if (lower == 'ceo confirmed') return 'Confirmed';
    if (lower == 'awaiting gm approval') {
      return _gmNeeded(total) ? 'Awaiting GM Approval' : 'Confirmed';
    }
    if (lower == 'awaiting ceo approval') {
      return _ceoNeeded(total) ? 'Awaiting CEO Approval' : 'Confirmed';
    }
    if (lower == 'am cancelled') return 'AM Cancelled';
    if (lower == 'gm cancelled') return 'GM Cancelled';
    if (lower == 'ceo cancelled') return 'CEO Cancelled';
    if (lower == 'cancelled') return 'AM Cancelled';
    if (lower == 'new') return 'New';
    return t;
  }

  bool _canActOnOrder(_SalesRegisterRow r) {
    if (_currentRole < 2) return false;
    final status = _displayStatus(r.orderConfirmation, r.grandTotal);
    if (status == 'New') return _currentRole >= 2;
    if (status == 'Awaiting GM Approval') {
      return _gmNeeded(r.grandTotal) && _currentRole >= 4;
    }
    if (status == 'Awaiting CEO Approval') {
      return _ceoNeeded(r.grandTotal) && _currentRole >= 5;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _listenOrders();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final customers = await _customersRepo.fetchCustomersOnce();
      final areas = await _areasRepo.fetchOnce();
      final subs = await _subAreasRepo.fetchOnce();
      final usersSnap = await _db.ref('Users').get();
      final Map<String, String> userMap = {};
      void addUser(Map m) {
        final id = (m['SalesPersonID'] ?? '').toString().trim();
        final name = (m['SalesPersonName'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          userMap[id] = name.isNotEmpty ? name : id;
        }
      }

      final uVal = usersSnap.value;
      if (uVal is Map) {
        uVal.forEach((_, v) {
          if (v is Map) addUser(v);
        });
      } else if (uVal is List) {
        for (final v in uVal) {
          if (v is Map) addUser(v);
        }
      }
      setState(() {
        _customerByCode
          ..clear()
          ..addEntries(
            customers
                .where((c) => (c.customerCode ?? '').isNotEmpty)
                .map((c) => MapEntry(c.customerCode!.trim(), c)),
          );
        _areaById
          ..clear()
          ..addEntries(areas.map((a) => MapEntry(a.areaId, a)));
        _subareaById
          ..clear()
          ..addEntries(subs.map((s) => MapEntry(s.subareaId, s)));
        _userNameById
          ..clear()
          ..addAll(userMap);
        _allowedCustomerCodes = _computeAllowedCustomers(
          customers,
          widget.roleId ?? AppSession().roleId,
          widget.allowedRegionIds ?? AppSession().allowedRegionIds,
          widget.allowedAreaIds ?? AppSession().allowedAreaIds,
          widget.allowedSubareaIds ?? AppSession().allowedSubareaIds,
        );
        _allRows = _parseOrders(_lastOrdersRaw);
      });
    } catch (_) {
      // swallow lookup errors for now
    }
  }

  void _listenOrders() {
    _ordersSub = _db.ref('Orders').onValue.listen((event) {
      _lastOrdersRaw = event.snapshot.value;
      final parsed = _parseOrders(_lastOrdersRaw);
      setState(() {
        _allRows = parsed;
      });
    });
  }

  Set<String> _computeAllowedCustomers(
    List<CustomerEntry> customers,
    String? roleId,
    List<String>? allowedRegions,
    List<String>? allowedAreas,
    List<String>? allowedSubareas,
  ) {
    final r = (roleId ?? '').trim();
    if (r == '4' || r == '5' || r == '6' || r == '7' || r.isEmpty) {
      // Full access for higher roles or unknown role (fail open to avoid empty list)
      return customers
          .map((c) => c.customerCode ?? '')
          .where((c) => c.isNotEmpty)
          .toSet();
    }

    final Set<String> regionSet =
        allowedRegions?.where((e) => e.isNotEmpty).toSet() ?? {};
    final Set<String> areaSet =
        allowedAreas?.where((e) => e.isNotEmpty).toSet() ?? {};
    final Set<String> subSet =
        allowedSubareas?.where((e) => e.isNotEmpty).toSet() ?? {};

    bool allowed(CustomerEntry c) {
      if (r == '1') {
        return subSet.isEmpty ? true : subSet.contains(c.subareaId);
      }
      if (r == '2') {
        return areaSet.isEmpty ? true : areaSet.contains(c.areaId);
      }
      if (r == '3') {
        return regionSet.isEmpty ? true : regionSet.contains(c.regionId);
      }
      return true;
    }

    return customers
        .where(allowed)
        .map((c) => c.customerCode ?? '')
        .where((c) => c.isNotEmpty)
        .toSet();
  }

  List<_SalesRegisterRow> _parseOrders(dynamic raw) {
    final out = <_SalesRegisterRow>[];
    if (raw is! Map) return out;

    double _d(v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    int _i(v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    bool _isCd(dynamic v) {
      if (v is bool) return v;
      final n = _i(v);
      return n != 0;
    }

    String _fmtBillingPercent(double mrp, double rate) {
      if (mrp <= 0) return '';
      final pct = (1 - (rate / mrp)) * 100;
      return pct.isFinite ? '${pct.toStringAsFixed(2)}%' : '';
    }

    DateTime? _dateFromMs(dynamic v) {
      final ms = _i(v);
      return ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
    }

    String _normDeliveryStatus(String v) {
      final t = v.trim();
      if (t.isEmpty) return 'Undelivered';
      final lower = t.toLowerCase();
      if (lower == 'undelivered') return 'Undelivered';
      if (lower == 'delivered') return 'Delivered';
      return t;
    }

    DateTime? _finalApprovalDate(
      String status,
      double total,
      DateTime? am,
      DateTime? gm,
      DateTime? ceo,
      DateTime? fallback,
    ) {
      final normalized = _displayStatus(status, total);
      if (normalized == 'Confirmed') return ceo ?? gm ?? am ?? fallback;
      return null;
    }

    String _notesFromRaw(dynamic raw) {
      if (raw == null) return '';
      if (raw is String) return raw.trim();
      if (raw is List) {
        return raw
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .join(' | ');
      }
      if (raw is Map) {
        final entries = raw.entries.toList()
          ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
        return entries
            .map((e) => e.value?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .join(' | ');
      }
      return raw.toString();
    }

    raw.forEach((customerCode, ordersValue) {
      if (ordersValue is! Map) return;
      ordersValue.forEach((orderId, orderVal) {
        if (orderVal is! Map) return;

        final orderDate = _i(orderVal['orderDate']);
        final dt = orderDate > 0
            ? DateTime.fromMillisecondsSinceEpoch(orderDate)
            : null;
        final orderConfirmation = (orderVal['orderConfirmation'] ?? '')
            .toString();
        final orderGrandTotal = _d(orderVal['grandTotal']);
        final amApproverId = (orderVal['amApproverID'] ?? '').toString();
        final gmApproverId = (orderVal['gmApproverID'] ?? '').toString();
        final ceoApproverId = (orderVal['ceoApproverID'] ?? '').toString();
        final amApprovalDate = _dateFromMs(orderVal['amApprovalDate']);
        final gmApprovalDate = _dateFromMs(orderVal['gmApprovalDate']);
        final ceoApprovalDate = _dateFromMs(orderVal['ceoApprovalDate']);
        final finalApprovalDate = _finalApprovalDate(
          orderConfirmation,
          orderGrandTotal,
          amApprovalDate,
          gmApprovalDate,
          ceoApprovalDate,
          dt,
        );
        final deliveryStatus = _normDeliveryStatus(
          (orderVal['deliveryStatus'] ?? '').toString(),
        );
        final deliveryDate = _dateFromMs(orderVal['deliveryDate']);
        final orderNotes = _notesFromRaw(orderVal['orderNotes']);
        final salesPersonId = (orderVal['salesPersonID'] ?? '').toString();
        final orderType = (orderVal['orderType'] ?? '').toString();
        final amApproverName = _userNameById[amApproverId] ?? amApproverId;
        final gmApproverName = _userNameById[gmApproverId] ?? gmApproverId;
        final ceoApproverName = _userNameById[ceoApproverId] ?? ceoApproverId;
        final salesPersonName = _userNameById[salesPersonId] ?? salesPersonId;

        final customer =
            _customerByCode[(orderVal['customerCode'] ?? customerCode)
                .toString()];
        final areaName = customer != null
            ? (_areaById[customer.areaId]?.areaName ?? '')
            : '';
        final subName = customer != null
            ? (_subareaById[customer.subareaId]?.subareaName ?? '')
            : '';

        String _firstNonEmpty(List<String?> vals) =>
            vals
                .firstWhere(
                  (v) => v != null && v.trim().isNotEmpty,
                  orElse: () => '',
                )
                ?.trim() ??
            '';

        final outletName = customer == null
            ? ''
            : _firstNonEmpty([
                customer.instituteOrClinicName,
                customer.pharmacyName,
              ]);
        final address = customer == null
            ? ''
            : _firstNonEmpty([
                customer.instituteOrClinicAddress1,
                customer.instituteOrClinicAddress2,
                customer.pharmacyAddress1,
                customer.pharmacyAddress2,
              ]);
        final contactPerson = customer == null
            ? ''
            : _firstNonEmpty([
                customer.pharmacyPersonName,
                customer.salesPersonName,
              ]);
        final contactMobile = customer == null
            ? ''
            : _firstNonEmpty([
                customer.pharmacyMobileNo1,
                customer.pharmacyMobileNo2,
                customer.docMobileNo1,
                customer.docMobileNo2,
              ]);

        void addRow({
          required String productCode,
          required String productName,
          required double productMRP,
          required int billQty,
          required int freeQty,
          required double rate,
          required double totalAmount,
          required String billingType,
          required bool cdApplied,
        }) {
          final cdAmount = cdApplied ? totalAmount * 0.03 : 0.0;
          final totalAfterCd = totalAmount - cdAmount;
          final billingPct = _fmtBillingPercent(productMRP, rate);

          out.add(
            _SalesRegisterRow(
              orderNo: (orderVal['orderID'] ?? orderId).toString(),
              orderDate: dt,
              orderConfirmation: orderConfirmation,
              category: customer?.category ?? '',
              city: areaName,
              destination: subName,
              customerCode: (orderVal['customerCode'] ?? customerCode)
                  .toString(),
              outletName: outletName,
              address: address,
              contactPerson: contactPerson,
              contactMobile: contactMobile,
              gstin: customer?.gstNumber ?? '',
              docName: customer?.docName ?? '',
              docContact: _firstNonEmpty([
                customer?.docMobileNo1,
                customer?.docMobileNo2,
              ]),
              productCode: productCode,
              productName: productName,
              billingType: billingType,
              billingPercent: billingPct,
              billedQty: billQty,
              freeQty: freeQty,
              rate: rate,
              totalAmount: totalAmount,
              cdAmount: double.parse(cdAmount.toStringAsFixed(2)),
              totalBillingAmount: double.parse(totalAfterCd.toStringAsFixed(2)),
              grandTotal: orderGrandTotal > 0 ? orderGrandTotal : totalAfterCd,
              orderType: orderType,
              salesPersonName: salesPersonName,
              amApproverName: amApproverName,
              gmApproverName: gmApproverName,
              ceoApproverName: ceoApproverName,
              deliveryStatus: deliveryStatus,
              deliveryDate: deliveryDate,
              finalApprovalDate: finalApprovalDate,
              orderNotes: orderNotes,
            ),
          );
        }

        final pd = orderVal['productsDetail'];
        if (pd is Map) {
          pd.forEach((code, val) {
            if (val is! Map) return;
            addRow(
              productCode: code.toString(),
              productName: (val['productName'] ?? '').toString(),
              productMRP: _d(val['productMRP']),
              billQty: _i(val['billQuantity']),
              freeQty: _i(val['freeQuantity']),
              rate: _d(val['rate']),
              totalAmount: _d(val['totalAmount']),
              billingType: (val['billingType'] ?? 'NET').toString(),
              cdApplied: _isCd(val['cdApplied'] ?? orderVal['cdApplied'] ?? 0),
            );
          });
        } else {
          addRow(
            productCode: (orderVal['productCode'] ?? '').toString(),
            productName: (orderVal['productName'] ?? '').toString(),
            productMRP: _d(orderVal['productMRP']),
            billQty: _i(orderVal['billQuantity']),
            freeQty: _i(orderVal['freeQuantity']),
            rate: _d(orderVal['rate']),
            totalAmount: _d(orderVal['totalAmount']),
            billingType: (orderVal['billingType'] ?? 'NET').toString(),
            cdApplied: _isCd(orderVal['cdApplied'] ?? 0),
          );
        }
      });
    });

    out.sort((a, b) {
      final ad = a.orderDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.orderDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final cmp = bd.compareTo(ad); // newest first
      if (cmp != 0) return cmp;
      return a.orderNo.compareTo(b.orderNo);
    });
    return out;
  }

  List<_SalesRegisterRow> get _filteredRows {
    final filtered = _allRows.where((r) {
      final dt = r.orderDate;
      if (dt == null) return false;
      if (_allowedCustomerCodes.isNotEmpty &&
          !_allowedCustomerCodes.contains(r.customerCode)) {
        return false;
      }
      if (_undeliveredOnly && r.deliveryStatus != 'Undelivered') {
        return false;
      }
      switch (_filterType) {
        case _DateFilterType.all:
          return true;
        case _DateFilterType.day:
          if (_selectedDay == null) return true;
          return dt.year == _selectedDay!.year &&
              dt.month == _selectedDay!.month &&
              dt.day == _selectedDay!.day;
        case _DateFilterType.month:
          if (_selectedMonth == null) return true;
          return dt.year == _selectedMonth!.year &&
              dt.month == _selectedMonth!.month;
        case _DateFilterType.year:
          if (_selectedYear == null) return true;
          return dt.year == _selectedYear!.year;
        case _DateFilterType.range:
          if (_rangeStart == null || _rangeEnd == null) return true;
          final start = DateTime(
            _rangeStart!.year,
            _rangeStart!.month,
            _rangeStart!.day,
          );
          final end = DateTime(
            _rangeEnd!.year,
            _rangeEnd!.month,
            _rangeEnd!.day,
            23,
            59,
            59,
          );
          return !dt.isBefore(start) && !dt.isAfter(end);
      }
    }).toList();

    int delayDays(_SalesRegisterRow r) {
      if (r.deliveryStatus != 'Undelivered') return -1;
      final finalDate = r.finalApprovalDate;
      if (finalDate == null) return -1;
      final now = DateTime.now();
      return now.difference(finalDate).inDays;
    }

    filtered.sort((a, b) {
      if (_sortType == _SortType.delayDesc) {
        final cmp = delayDays(b).compareTo(delayDays(a));
        if (cmp != 0) return cmp;
      }
      final ad = a.orderDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.orderDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final cmpDate = bd.compareTo(ad);
      if (cmpDate != 0) return cmpDate;
      return a.orderNo.compareTo(b.orderNo);
    });

    return filtered;
  }

  Future<void> _pickDate(
    void Function(DateTime) onPick, {
    DateTime? initial,
  }) async {
    final now = DateTime.now();
    final first = DateTime(now.year - 3);
    final last = DateTime(now.year + 1, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      onPick(picked);
    }
  }

  String _fmtShortDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  Color _deliveryIndicatorColor(_SalesRegisterRow r) {
    if (r.deliveryStatus == 'Delivered') return Colors.green;
    if (r.deliveryStatus == 'Undelivered' && r.finalApprovalDate != null) {
      final days = DateTime.now().difference(r.finalApprovalDate!).inDays;
      return days < 21 ? Colors.amber : Colors.red;
    }
    return Colors.grey;
  }

  Future<void> _showRateEditDialog(_SalesRegisterRow r) async {
    if (!_canEditRate(r)) return;
    final controller = TextEditingController(text: r.rate.toStringAsFixed(2));
    String? error;
    final newRate = await showDialog<double>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update rate'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'New rate',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final txt = controller.text.trim();
                    final val = double.tryParse(txt);
                    if (val == null || val <= 0) {
                      setState(() => error = 'Enter a valid rate');
                      return;
                    }
                    Navigator.of(context).pop(val);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (newRate == null) return;
    await _updateRate(r, newRate);
  }

  Future<void> _updateRate(_SalesRegisterRow r, double newRate) async {
    final orderRef = _db.ref('Orders/${r.customerCode}/${r.orderNo}');
    final snap = await orderRef.get();
    if (!snap.exists || snap.value is! Map) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order not found for update')),
      );
      return;
    }

    final oldRate = r.rate;
    final order = Map<String, dynamic>.from(snap.value as Map);
    double _d(v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    int _i(v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    final rate = double.parse(newRate.toStringAsFixed(2));
    final total = double.parse((rate * r.billedQty).toStringAsFixed(2));
    final updates = <String, Object?>{};

    final pdRaw = order['productsDetail'];
    if (pdRaw is Map) {
      final pd = Map<String, dynamic>.from(pdRaw as Map);
      String? matchKey;
      if (pd.containsKey(r.productCode)) {
        matchKey = r.productCode;
      } else {
        for (final k in pd.keys) {
          if (k.toString() == r.productCode) {
            matchKey = k.toString();
            break;
          }
        }
      }
      if (matchKey == null || pd[matchKey] is! Map) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product not found for update')),
        );
        return;
      }
      final line = Map<String, dynamic>.from(pd[matchKey] as Map);
      line['rate'] = rate;
      line['totalAmount'] = total;
      pd[matchKey] = line;

      double grand = 0.0;
      pd.forEach((_, v) {
        if (v is! Map) return;
        final m = Map<String, dynamic>.from(v as Map);
        final lineTotal = _d(m['totalAmount']);
        final cdApplied = _i(m['cdApplied']) != 0;
        grand += cdApplied ? lineTotal * 0.97 : lineTotal;
      });
      updates['productsDetail'] = pd;
      updates['grandTotal'] = double.parse(grand.toStringAsFixed(2));
    } else {
      final cdApplied = _i(order['cdApplied']) != 0;
      final grandTotal = cdApplied ? total * 0.97 : total;
      updates['rate'] = rate;
      updates['totalAmount'] = total;
      updates['grandTotal'] = double.parse(grandTotal.toStringAsFixed(2));
    }

    await orderRef.update(updates);
    await _appendOrderNote(
      r,
      'Rate updated for ${r.productCode} from ${oldRate.toStringAsFixed(2)} to ${newRate.toStringAsFixed(2)}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rate updated for ${r.productCode}')),
    );
  }

  DataCell _rateCell(_SalesRegisterRow r) {
    final canEdit = _canEditRate(r);
    return DataCell(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(r.rate.toStringAsFixed(2)),
          if (canEdit) ...[
            const SizedBox(width: 6),
            const Icon(Icons.edit, size: 14, color: Colors.blueGrey),
          ],
        ],
      ),
      onTap: canEdit ? () => _showRateEditDialog(r) : null,
    );
  }

  Future<void> _updateDelivery(
    _SalesRegisterRow r,
    String status, {
    DateTime? deliveryDate,
  }) async {
    final normalized = status.toLowerCase() == 'delivered'
        ? 'Delivered'
        : 'Undelivered';
    final effectiveDate = normalized == 'Delivered'
        ? (deliveryDate ?? DateTime.now())
        : null;
    await _db.ref('Orders/${r.customerCode}/${r.orderNo}').update({
      'deliveryStatus': normalized,
      'deliveryDate': effectiveDate?.millisecondsSinceEpoch ?? 0,
    });
  }

  bool _gmNeeded(double total) => total > 10000;
  bool _ceoNeeded(double total) => total >= 20001;

  bool _canActAsAm(_SalesRegisterRow r) {
    final status = _displayStatus(r.orderConfirmation, r.grandTotal);
    return status == 'New' && _currentRole >= 2;
  }

  bool _canActAsGm(_SalesRegisterRow r) {
    final status = _displayStatus(r.orderConfirmation, r.grandTotal);
    return status == 'Awaiting GM Approval' &&
        _gmNeeded(r.grandTotal) &&
        _currentRole >= 4;
  }

  bool _canActAsCeo(_SalesRegisterRow r) {
    final status = _displayStatus(r.orderConfirmation, r.grandTotal);
    return status == 'Awaiting CEO Approval' &&
        _ceoNeeded(r.grandTotal) &&
        _currentRole >= 5;
  }

  bool _canRetractAm(_SalesRegisterRow r) {
    if (_currentRole < 2) return false;
    if (r.amApproverName.isEmpty) return false;
    final status = _displayStatus(r.orderConfirmation, r.grandTotal);
    if (status == 'Awaiting GM Approval') return true;
    if (status == 'Confirmed' && !_gmNeeded(r.grandTotal)) return true;
    return false;
  }

  bool _canRetractGm(_SalesRegisterRow r) {
    if (_currentRole < 4) return false;
    if (r.gmApproverName.isEmpty) return false;
    final status = _displayStatus(r.orderConfirmation, r.grandTotal);
    if (status == 'Awaiting CEO Approval') return true;
    if (status == 'Confirmed' &&
        _gmNeeded(r.grandTotal) &&
        !_ceoNeeded(r.grandTotal)) {
      return true;
    }
    return false;
  }

  bool _canRetractCeo(_SalesRegisterRow r) {
    if (_currentRole < 5) return false;
    if (r.ceoApproverName.isEmpty) return false;
    final status = _displayStatus(r.orderConfirmation, r.grandTotal);
    return status == 'Confirmed' && _ceoNeeded(r.grandTotal);
  }

  String _amStatusText(_SalesRegisterRow r) {
    final status = _displayStatus(r.orderConfirmation, r.grandTotal);
    if (status == 'AM Cancelled') {
      return r.amApproverName.isNotEmpty
          ? '${r.amApproverName} (Cancelled)'
          : 'Cancelled';
    }
    if (r.amApproverName.isNotEmpty) return r.amApproverName;
    return status.contains('Cancelled') ? 'Cancelled' : '';
  }

  String _gmStatusText(_SalesRegisterRow r) {
    if (!_gmNeeded(r.grandTotal)) return 'N/A';
    final status = _displayStatus(r.orderConfirmation, r.grandTotal);
    if (status == 'GM Cancelled') {
      return r.gmApproverName.isNotEmpty
          ? '${r.gmApproverName} (Cancelled)'
          : 'Cancelled';
    }
    if (status == 'New') return '';
    if (status == 'Awaiting GM Approval') {
      return r.gmApproverName.isNotEmpty ? r.gmApproverName : '';
    }
    if (status == 'Awaiting CEO Approval' || status == 'Confirmed') {
      return r.gmApproverName.isNotEmpty ? r.gmApproverName : '';
    }
    return status.contains('Cancelled') ? 'N/A' : r.gmApproverName;
  }

  String _ceoStatusText(_SalesRegisterRow r) {
    if (!_ceoNeeded(r.grandTotal)) return 'N/A';
    final status = _displayStatus(r.orderConfirmation, r.grandTotal);
    if (status == 'CEO Cancelled') {
      return r.ceoApproverName.isNotEmpty
          ? '${r.ceoApproverName} (Cancelled)'
          : 'Cancelled';
    }
    if (status == 'New' || status == 'Awaiting GM Approval') {
      return '';
    }
    if (status == 'Awaiting CEO Approval') {
      return r.ceoApproverName.isNotEmpty ? r.ceoApproverName : '';
    }
    if (status == 'Confirmed') {
      return r.ceoApproverName.isNotEmpty ? r.ceoApproverName : '';
    }
    return status.contains('Cancelled') ? 'N/A' : r.ceoApproverName;
  }

  String _noteStamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _appendOrderNote(_SalesRegisterRow r, String note) async {
    final text = '${_noteStamp(DateTime.now())} - $_currentUserName: $note';
    await _db
        .ref('Orders/${r.customerCode}/${r.orderNo}/orderNotes')
        .push()
        .set(text);
  }

  Future<void> _applyApprovalAction(
    _SalesRegisterRow r,
    _ApprovalStage stage,
    bool approved,
  ) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, Object?>{};
    final total = r.grandTotal;
    String newStatus;
    String note;

    switch (stage) {
      case _ApprovalStage.am:
        if (approved) {
          newStatus = _gmNeeded(total) ? 'Awaiting GM Approval' : 'Confirmed';
          note = 'AM approved order';
        } else {
          newStatus = 'AM Cancelled';
          note = 'AM cancelled order';
        }
        updates['amApproverID'] = _currentUserId;
        updates['amApprovalDate'] = nowMs;
        updates['gmApproverID'] = '';
        updates['gmApprovalDate'] = 0;
        updates['ceoApproverID'] = '';
        updates['ceoApprovalDate'] = 0;
        break;
      case _ApprovalStage.gm:
        if (approved) {
          newStatus = _ceoNeeded(total) ? 'Awaiting CEO Approval' : 'Confirmed';
          note = 'GM approved order';
        } else {
          newStatus = 'GM Cancelled';
          note = 'GM cancelled order';
        }
        updates['gmApproverID'] = _currentUserId;
        updates['gmApprovalDate'] = nowMs;
        updates['ceoApproverID'] = '';
        updates['ceoApprovalDate'] = 0;
        break;
      case _ApprovalStage.ceo:
        if (approved) {
          newStatus = 'Confirmed';
          note = 'CEO approved order';
        } else {
          newStatus = 'CEO Cancelled';
          note = 'CEO cancelled order';
        }
        updates['ceoApproverID'] = _currentUserId;
        updates['ceoApprovalDate'] = nowMs;
        break;
    }

    updates['orderConfirmation'] = newStatus;
    await _db.ref('Orders/${r.customerCode}/${r.orderNo}').update(updates);
    await _appendOrderNote(r, note);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order status updated to $newStatus')),
    );
  }

  Future<void> _applyRetractAction(
    _SalesRegisterRow r,
    _ApprovalStage stage,
  ) async {
    final updates = <String, Object?>{};
    String newStatus;
    String note;

    switch (stage) {
      case _ApprovalStage.am:
        newStatus = 'New';
        note = 'AM retracted approval';
        updates['amApproverID'] = '';
        updates['amApprovalDate'] = 0;
        updates['gmApproverID'] = '';
        updates['gmApprovalDate'] = 0;
        updates['ceoApproverID'] = '';
        updates['ceoApprovalDate'] = 0;
        break;
      case _ApprovalStage.gm:
        newStatus = 'Awaiting GM Approval';
        note = 'GM retracted approval';
        updates['gmApproverID'] = '';
        updates['gmApprovalDate'] = 0;
        updates['ceoApproverID'] = '';
        updates['ceoApprovalDate'] = 0;
        break;
      case _ApprovalStage.ceo:
        newStatus = 'Awaiting CEO Approval';
        note = 'CEO retracted approval';
        updates['ceoApproverID'] = '';
        updates['ceoApprovalDate'] = 0;
        break;
    }

    updates['orderConfirmation'] = newStatus;
    await _db.ref('Orders/${r.customerCode}/${r.orderNo}').update(updates);
    await _appendOrderNote(r, note);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order status updated to $newStatus')),
    );
  }

  Widget _approverCell({
    required String label,
    required bool showActions,
    VoidCallback? onApprove,
    VoidCallback? onCancel,
    bool showRetract = false,
    VoidCallback? onRetract,
  }) {
    final trimmed = label.trim();
    final hideLabel =
        showActions && trimmed.toLowerCase().startsWith('awaiting');
    final display = (trimmed.isEmpty || hideLabel) ? '-' : trimmed;
    final buttonTextStyle = const TextStyle(fontSize: 11);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(display),
        if (showActions) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ElevatedButton(
                onPressed: onApprove,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  textStyle: buttonTextStyle,
                ),
                child: const Text('Approve'),
              ),
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  textStyle: buttonTextStyle,
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
        if (showRetract) ...[
          const SizedBox(height: 4),
          OutlinedButton(
            onPressed: onRetract,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              textStyle: buttonTextStyle,
            ),
            child: const Text('Retract Approval'),
          ),
        ],
      ],
    );
  }

  Widget _amApproverCell(_SalesRegisterRow r) => _approverCell(
    label: _amStatusText(r),
    showActions: _canActAsAm(r),
    onApprove: () => _applyApprovalAction(r, _ApprovalStage.am, true),
    onCancel: () => _applyApprovalAction(r, _ApprovalStage.am, false),
    showRetract: _canRetractAm(r),
    onRetract: () => _applyRetractAction(r, _ApprovalStage.am),
  );

  Widget _gmApproverCell(_SalesRegisterRow r) => _approverCell(
    label: _gmStatusText(r),
    showActions: _canActAsGm(r),
    onApprove: () => _applyApprovalAction(r, _ApprovalStage.gm, true),
    onCancel: () => _applyApprovalAction(r, _ApprovalStage.gm, false),
    showRetract: _canRetractGm(r),
    onRetract: () => _applyRetractAction(r, _ApprovalStage.gm),
  );

  Widget _ceoApproverCell(_SalesRegisterRow r) => _approverCell(
    label: _ceoStatusText(r),
    showActions: _canActAsCeo(r),
    onApprove: () => _applyApprovalAction(r, _ApprovalStage.ceo, true),
    onCancel: () => _applyApprovalAction(r, _ApprovalStage.ceo, false),
    showRetract: _canRetractCeo(r),
    onRetract: () => _applyRetractAction(r, _ApprovalStage.ceo),
  );

  void _openOrder(_SalesRegisterRow r) {
    final customer = _customerByCode[r.customerCode];
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer not found for this order')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ClientDetailsPage(client: customer, initialOrderId: r.orderNo),
      ),
    );
  }

  Widget _deliveryStatusCell(_SalesRegisterRow r) {
    const statuses = ['Undelivered', 'Delivered'];
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _deliveryIndicatorColor(r),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: statuses.contains(r.deliveryStatus)
                ? r.deliveryStatus
                : 'Undelivered',
            items: statuses
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              _updateDelivery(r, v, deliveryDate: r.deliveryDate);
            },
          ),
        ),
      ],
    );
  }

  Widget _deliveryDateCell(_SalesRegisterRow r) {
    final label = _fmtShortDate(r.deliveryDate);
    return TextButton(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: r.deliveryDate ?? DateTime.now(),
          firstDate: DateTime(DateTime.now().year - 3),
          lastDate: DateTime(DateTime.now().year + 2, 12, 31),
        );
        if (picked == null) return;
        await _updateDelivery(r, 'Delivered', deliveryDate: picked);
      },
      child: Text(label.isEmpty ? 'Pick date' : label),
    );
  }

  Widget _dateFilterControls() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    String fmt(DateTime? d) => d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Date Filter:',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              DropdownButton<_DateFilterType>(
                value: _filterType,
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: colorScheme.onSurface),
                items: const [
                  DropdownMenuItem(
                    value: _DateFilterType.all,
                    child: Text('All'),
                  ),
                  DropdownMenuItem(
                    value: _DateFilterType.day,
                    child: Text('Day'),
                  ),
                  DropdownMenuItem(
                    value: _DateFilterType.month,
                    child: Text('Month'),
                  ),
                  DropdownMenuItem(
                    value: _DateFilterType.year,
                    child: Text('Year'),
                  ),
                  DropdownMenuItem(
                    value: _DateFilterType.range,
                    child: Text('Custom Range'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _filterType = v);
                },
              ),
              if (_filterType == _DateFilterType.day)
                OutlinedButton(
                  onPressed: () => _pickDate(
                    (d) => setState(() => _selectedDay = d),
                    initial: _selectedDay,
                  ),
                  child: Text(
                    _selectedDay == null
                        ? 'Pick day'
                        : 'Day: ${fmt(_selectedDay)}',
                  ),
                ),
              if (_filterType == _DateFilterType.month)
                OutlinedButton(
                  onPressed: () => _pickDate(
                    (d) => setState(
                      () => _selectedMonth = DateTime(d.year, d.month, 1),
                    ),
                    initial: _selectedMonth,
                  ),
                  child: Text(
                    _selectedMonth == null
                        ? 'Pick month'
                        : 'Month: ${_selectedMonth!.month.toString().padLeft(2, '0')}-${_selectedMonth!.year}',
                  ),
                ),
              if (_filterType == _DateFilterType.year)
                OutlinedButton(
                  onPressed: () => _pickDate(
                    (d) =>
                        setState(() => _selectedYear = DateTime(d.year, 1, 1)),
                    initial: _selectedYear,
                  ),
                  child: Text(
                    _selectedYear == null
                        ? 'Pick year'
                        : 'Year: ${_selectedYear!.year}',
                  ),
                ),
              if (_filterType == _DateFilterType.range) ...[
                OutlinedButton(
                  onPressed: () => _pickDate(
                    (d) => setState(() => _rangeStart = d),
                    initial: _rangeStart,
                  ),
                  child: Text(
                    _rangeStart == null
                        ? 'Start date'
                        : 'From: ${fmt(_rangeStart)}',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _pickDate(
                    (d) => setState(() => _rangeEnd = d),
                    initial: _rangeEnd,
                  ),
                  child: Text(
                    _rangeEnd == null ? 'End date' : 'To: ${fmt(_rangeEnd)}',
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Text(
                'Sort:',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              DropdownButton<_SortType>(
                value: _sortType,
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: colorScheme.onSurface),
                items: const [
                  DropdownMenuItem(
                    value: _SortType.orderDateDesc,
                    child: Text('Order time (newest)'),
                  ),
                  DropdownMenuItem(
                    value: _SortType.delayDesc,
                    child: Text('Delayed delivery'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _sortType = v);
                },
              ),
              FilterChip(
                label: const Text('Undelivered only'),
                selected: _undeliveredOnly,
                onSelected: (v) => setState(() => _undeliveredOnly = v),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDay = null;
                    _selectedMonth = null;
                    _selectedYear = null;
                    _rangeStart = null;
                    _rangeEnd = null;
                    _filterType = _DateFilterType.all;
                    _sortType = _SortType.orderDateDesc;
                    _undeliveredOnly = false;
                  });
                },
                child: const Text('Clear'),
              ),
              ElevatedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export CSV'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final headers = <String>[
      'Type of Order',
      'Order Status',
      'Order No.',
      'Order Date',
      'Category',
      'Sales Person Name',
      'City',
      'Destination/Sub Area',
      'Customer Code',
      'Pharmacy/Clinic/Hospital Name',
      'Address',
      'Contact Person Name',
      'Contact Person Mobile No.',
      'GSTIN',
      'DOC Name',
      'DOC Contact Number',
      'Product Code',
      'Product Name',
      'Type of Billing',
      'Billing %',
      'Billed QTY',
      'Free QTY',
      'Rate',
      'Total Amount',
      'CD Amount @ 3%',
      'Total Billing Amount',
      'Grand Total (Order)',
      'AM Approver',
      'GM Approver',
      'CEO Approver',
      'Date Confirmed',
      'Delivery Status',
      'Date of Delivery',
    ];

    String fmtDate(DateTime? d) => _fmtShortDate(d);

    final rows = _filteredRows;
    final dataRows = <DataRow>[];
    String? lastOrderNo;
    var useAlt = false;
    for (final r in rows) {
      if (lastOrderNo != null && lastOrderNo != r.orderNo) {
        useAlt = !useAlt;
      }
      lastOrderNo = r.orderNo;
      final displayStatus = _displayStatus(r.orderConfirmation, r.grandTotal);
      dataRows.add(
        DataRow(
          color: useAlt
              ? WidgetStateProperty.all(colorScheme.surfaceContainerHighest)
              : null,
          cells: [
            DataCell(Text(r.orderType)),
            DataCell(Text(displayStatus)),
            DataCell(
              Text(
                r.orderNo,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
              onTap: () => _openOrder(r),
            ),
            DataCell(Text(fmtDate(r.orderDate))),
            DataCell(Text(r.category)),
            DataCell(Text(r.salesPersonName)),
            DataCell(Text(r.city)),
            DataCell(Text(r.destination)),
            DataCell(Text(r.customerCode)),
            DataCell(Text(r.outletName)),
            DataCell(Text(r.address)),
            DataCell(Text(r.contactPerson)),
            DataCell(Text(r.contactMobile)),
            DataCell(Text(r.gstin)),
            DataCell(Text(r.docName)),
            DataCell(Text(r.docContact)),
            DataCell(Text(r.productCode)),
            DataCell(Text(r.productName)),
            DataCell(Text(r.billingType)),
            DataCell(Text(r.billingPercent)),
            DataCell(Text('${r.billedQty}')),
            DataCell(Text('${r.freeQty}')),
            _rateCell(r),
            DataCell(Text(r.totalAmount.toStringAsFixed(2))),
            DataCell(Text(r.cdAmount.toStringAsFixed(2))),
            DataCell(Text(r.totalBillingAmount.toStringAsFixed(2))),
            DataCell(Text(r.grandTotal.toStringAsFixed(2))),
            DataCell(_amApproverCell(r)),
            DataCell(_gmApproverCell(r)),
            DataCell(_ceoApproverCell(r)),
            DataCell(Text(fmtDate(r.finalApprovalDate))),
            DataCell(_deliveryStatusCell(r)),
            DataCell(_deliveryDateCell(r)),
          ],
        ),
      );
    }
    final hCtrl = ScrollController();
    final vCtrl = ScrollController();

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Scrollbar(
            controller: hCtrl,
            thumbVisibility: true,
            notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: hCtrl,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: headers.length * 180.0),
                child: Scrollbar(
                  controller: vCtrl,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: vCtrl,
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        colorScheme.surfaceContainerHighest,
                      ),
                      columns: headers
                          .map(
                            (h) => DataColumn(
                              label: Text(
                                h,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      rows: dataRows,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canAccessSalesRegister) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        bottomNavigationBar: CommonFooter(),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CommonHeader(
                pageTitle: 'Sales Register',
                userName: widget.salesPersonName,
                onLogout: widget.onLogout,
                roleId: widget.roleId,
                salesPersonName: widget.salesPersonName,
                allAccess: widget.allAccess,
                allowedRegionIds: widget.allowedRegionIds,
                allowedAreaIds: widget.allowedAreaIds,
                allowedSubareaIds: widget.allowedSubareaIds,
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'You are not authorized to view the Sales Register.',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: CommonFooter(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CommonHeader(
              pageTitle: 'Sales Register',
              userName: widget.salesPersonName,
              onLogout: widget.onLogout,
              roleId: widget.roleId,
              salesPersonName: widget.salesPersonName,
              allAccess: widget.allAccess,
              allowedRegionIds: widget.allowedRegionIds,
              allowedAreaIds: widget.allowedAreaIds,
              allowedSubareaIds: widget.allowedSubareaIds,
            ),
            _dateFilterControls(),
            _buildTable(),
          ],
        ),
      ),
    );
  }

  // ---------- Export ----------
  Future<void> _exportCsv() async {
    final rows = _filteredRows;
    final headers = <String>[
      'Type of Order',
      'Order Status',
      'Order No.',
      'Order Date',
      'Category',
      'Sales Person Name',
      'City',
      'Destination/Sub Area',
      'Customer Code',
      'Pharmacy/Clinic/Hospital Name',
      'Address',
      'Contact Person Name',
      'Contact Person Mobile No.',
      'GSTIN',
      'DOC Name',
      'DOC Contact Number',
      'Product Code',
      'Product Name',
      'Type of Billing',
      'Billing %',
      'Billed QTY',
      'Free QTY',
      'Rate',
      'Total Amount',
      'CD Amount @ 3%',
      'Total Billing Amount',
      'Grand Total (Order)',
      'AM Approver',
      'GM Approver',
      'CEO Approver',
      'Date Confirmed',
      'Delivery Status',
      'Date of Delivery',
    ];

    String fmtDate(DateTime? d) {
      if (d == null) return '';
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    String esc(String v) => '"${v.replaceAll('"', '""')}"';

    final buffer = StringBuffer();
    buffer.writeln(headers.map(esc).join(','));
    for (final r in rows) {
      final displayStatus = _displayStatus(r.orderConfirmation, r.grandTotal);
      final data = [
        r.orderType,
        displayStatus,
        r.orderNo,
        fmtDate(r.orderDate),
        r.category,
        r.salesPersonName,
        r.city,
        r.destination,
        r.customerCode,
        r.outletName,
        r.address,
        r.contactPerson,
        r.contactMobile,
        r.gstin,
        r.docName,
        r.docContact,
        r.productCode,
        r.productName,
        r.billingType,
        r.billingPercent,
        '${r.billedQty}',
        '${r.freeQty}',
        r.rate.toStringAsFixed(2),
        r.totalAmount.toStringAsFixed(2),
        r.cdAmount.toStringAsFixed(2),
        r.totalBillingAmount.toStringAsFixed(2),
        r.grandTotal.toStringAsFixed(2),
        _amStatusText(r),
        _gmStatusText(r),
        _ceoStatusText(r),
        fmtDate(r.finalApprovalDate),
        r.deliveryStatus,
        fmtDate(r.deliveryDate),
      ];
      buffer.writeln(data.map(esc).join(','));
    }

    final csv = buffer.toString();
    final fileName =
        'sales_register_${DateTime.now().millisecondsSinceEpoch}.csv';

    try {
      if (kIsWeb) {
        final blob = html.Blob([csv], 'text/csv;charset=utf-8');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..download = fileName
          ..style.display = 'none';
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(url);
        return;
      }

      String targetDir;
      if (Platform.isAndroid) {
        targetDir = '/storage/emulated/0/Download';
      } else if (Platform.isWindows) {
        final home = Platform.environment['USERPROFILE'] ?? '';
        targetDir = home.isNotEmpty
            ? '$home\\Downloads'
            : Directory.systemTemp.path;
      } else {
        final home = Platform.environment['HOME'] ?? '';
        targetDir = home.isNotEmpty
            ? '$home/Downloads'
            : Directory.systemTemp.path;
      }
      final dir = Directory(targetDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csv, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}
