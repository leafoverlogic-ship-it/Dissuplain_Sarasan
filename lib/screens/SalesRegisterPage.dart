import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../CommonHeader.dart';
import '../CommonFooter.dart';
import '../../dataLayer/customers_repository.dart';
import '../../dataLayer/areas_repository.dart';
import '../../dataLayer/subareas_repository.dart';
import '../app_session.dart';

enum _DateFilterType { all, day, month, year, range }

class _SalesRegisterRow {
  final String orderNo;
  final DateTime? orderDate;
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

  const _SalesRegisterRow({
    required this.orderNo,
    required this.orderDate,
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
          ..addEntries(customers.where((c) => (c.customerCode ?? '').isNotEmpty).map(
                (c) => MapEntry(c.customerCode!.trim(), c),
              ));
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

    final Set<String> regionSet = allowedRegions?.where((e) => e.isNotEmpty).toSet() ?? {};
    final Set<String> areaSet = allowedAreas?.where((e) => e.isNotEmpty).toSet() ?? {};
    final Set<String> subSet = allowedSubareas?.where((e) => e.isNotEmpty).toSet() ?? {};

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

    double _d(v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
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

    raw.forEach((customerCode, ordersValue) {
      if (ordersValue is! Map) return;
      ordersValue.forEach((orderId, orderVal) {
        if (orderVal is! Map) return;

        final status = (orderVal['orderConfirmation'] ?? '').toString().toLowerCase();
        if (status == 'cancelled') return; // skip cancelled orders in register

        final orderDate = _i(orderVal['orderDate']);
        final dt = orderDate > 0 ? DateTime.fromMillisecondsSinceEpoch(orderDate) : null;
        final orderGrandTotal = _d(orderVal['grandTotal']);
        final amApproverId = (orderVal['amApproverID'] ?? '').toString();
        final salesPersonId = (orderVal['salesPersonID'] ?? '').toString();
        final orderType = (orderVal['orderType'] ?? '').toString();
        final amApproverName = _userNameById[amApproverId] ?? amApproverId;
        final salesPersonName = _userNameById[salesPersonId] ?? salesPersonId;

        final customer = _customerByCode[(orderVal['customerCode'] ?? customerCode).toString()];
        final areaName = customer != null ? (_areaById[customer.areaId]?.areaName ?? '') : '';
        final subName = customer != null ? (_subareaById[customer.subareaId]?.subareaName ?? '') : '';

        String _firstNonEmpty(List<String?> vals) =>
            vals.firstWhere((v) => v != null && v.trim().isNotEmpty, orElse: () => '')?.trim() ?? '';

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
              category: customer?.category ?? '',
              city: areaName,
              destination: subName,
              customerCode: (orderVal['customerCode'] ?? customerCode).toString(),
              outletName: outletName,
              address: address,
              contactPerson: contactPerson,
              contactMobile: contactMobile,
              gstin: customer?.gstNumber ?? '',
              docName: customer?.docName ?? '',
              docContact: _firstNonEmpty([customer?.docMobileNo1, customer?.docMobileNo2]),
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
    return _allRows.where((r) {
      final dt = r.orderDate;
      if (dt == null) return false;
      if (_allowedCustomerCodes.isNotEmpty && !_allowedCustomerCodes.contains(r.customerCode)) {
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
          return dt.year == _selectedMonth!.year && dt.month == _selectedMonth!.month;
        case _DateFilterType.year:
          if (_selectedYear == null) return true;
          return dt.year == _selectedYear!.year;
        case _DateFilterType.range:
          if (_rangeStart == null || _rangeEnd == null) return true;
          final start = DateTime(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day);
          final end = DateTime(_rangeEnd!.year, _rangeEnd!.month, _rangeEnd!.day, 23, 59, 59);
          return !dt.isBefore(start) && !dt.isAfter(end);
      }
    }).toList();
  }

  Future<void> _pickDate(void Function(DateTime) onPick, {DateTime? initial}) async {
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

  Widget _dateFilterControls() {
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
              const Text('Date Filter:'),
              DropdownButton<_DateFilterType>(
                value: _filterType,
                items: const [
                  DropdownMenuItem(value: _DateFilterType.all, child: Text('All')),
                  DropdownMenuItem(value: _DateFilterType.day, child: Text('Day')),
                  DropdownMenuItem(value: _DateFilterType.month, child: Text('Month')),
                  DropdownMenuItem(value: _DateFilterType.year, child: Text('Year')),
                  DropdownMenuItem(value: _DateFilterType.range, child: Text('Custom Range')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _filterType = v);
                },
              ),
              if (_filterType == _DateFilterType.day)
                OutlinedButton(
                  onPressed: () => _pickDate((d) => setState(() => _selectedDay = d), initial: _selectedDay),
                  child: Text(_selectedDay == null ? 'Pick day' : 'Day: ${fmt(_selectedDay)}'),
                ),
              if (_filterType == _DateFilterType.month)
                OutlinedButton(
                  onPressed: () => _pickDate(
                    (d) => setState(() => _selectedMonth = DateTime(d.year, d.month, 1)),
                    initial: _selectedMonth,
                  ),
                  child: Text(_selectedMonth == null
                      ? 'Pick month'
                      : 'Month: ${_selectedMonth!.month.toString().padLeft(2, '0')}-${_selectedMonth!.year}'),
                ),
              if (_filterType == _DateFilterType.year)
                OutlinedButton(
                  onPressed: () => _pickDate(
                    (d) => setState(() => _selectedYear = DateTime(d.year, 1, 1)),
                    initial: _selectedYear,
                  ),
                  child: Text(_selectedYear == null ? 'Pick year' : 'Year: ${_selectedYear!.year}'),
                ),
              if (_filterType == _DateFilterType.range) ...[
                OutlinedButton(
                  onPressed: () => _pickDate((d) => setState(() => _rangeStart = d), initial: _rangeStart),
                  child: Text(_rangeStart == null ? 'Start date' : 'From: ${fmt(_rangeStart)}'),
                ),
                OutlinedButton(
                  onPressed: () => _pickDate((d) => setState(() => _rangeEnd = d), initial: _rangeEnd),
                  child: Text(_rangeEnd == null ? 'End date' : 'To: ${fmt(_rangeEnd)}'),
                ),
              ],
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDay = null;
                    _selectedMonth = null;
                    _selectedYear = null;
                    _rangeStart = null;
                    _rangeEnd = null;
                    _filterType = _DateFilterType.all;
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
    final headers = <String>[
      'Type of Order',
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
      'AM Approver Name',
    ];

    String fmtDate(DateTime? d) {
      if (d == null) return '';
      return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
    }

    final rows = _filteredRows;
    final hCtrl = ScrollController();
    final vCtrl = ScrollController();

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
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
                      headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                      columns: headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontSize: 12)))).toList(),
                      rows: rows
                          .map(
                            (r) => DataRow(
                              cells: [
                                DataCell(Text(r.orderType)),
                                DataCell(Text(r.orderNo)),
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
                                DataCell(Text(r.rate.toStringAsFixed(2))),
                                DataCell(Text(r.totalAmount.toStringAsFixed(2))),
                                DataCell(Text(r.cdAmount.toStringAsFixed(2))),
                                DataCell(Text(r.totalBillingAmount.toStringAsFixed(2))),
                                DataCell(Text(r.grandTotal.toStringAsFixed(2))),
                                DataCell(Text(r.amApproverName)),
                              ],
                            ),
                          )
                          .toList(),
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
    return Scaffold(
      backgroundColor: Colors.white,
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
      'AM Approver Name',
    ];

    String fmtDate(DateTime? d) {
      if (d == null) return '';
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    String esc(String v) => '"${v.replaceAll('"', '""')}"';

    final buffer = StringBuffer();
    buffer.writeln(headers.map(esc).join(','));
    for (final r in rows) {
      final data = [
        r.orderType,
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
        r.amApproverName,
      ];
      buffer.writeln(data.map(esc).join(','));
    }

    final csv = buffer.toString();
    final fileName = 'sales_register_${DateTime.now().millisecondsSinceEpoch}.csv';

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
        targetDir = home.isNotEmpty ? '$home\\Downloads' : Directory.systemTemp.path;
      } else {
        final home = Platform.environment['HOME'] ?? '';
        targetDir = home.isNotEmpty ? '$home/Downloads' : Directory.systemTemp.path;
      }
      final dir = Directory(targetDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csv, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}
