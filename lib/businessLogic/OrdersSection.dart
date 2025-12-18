import 'package:flutter/material.dart';
import 'package:dissuplain_app_web_mobile/dataLayer/orders_repository.dart';
import 'package:dissuplain_app_web_mobile/app_session.dart';

class OrdersSection extends StatefulWidget {
  final OrdersRepository ordersRepo;
  final String customerCode;
  final String customerCategory;
  const OrdersSection({
    super.key,
    required this.ordersRepo,
    required this.customerCode,
    required this.customerCategory,
  });

  @override
  State<OrdersSection> createState() => _OrdersSectionState();
}

class _OrdersSectionState extends State<OrdersSection> {
  final _orderTypes = const ['1st Order', 'Repeat Order'];
  final Map<String, bool> _mpBillingTypeWithScheme = {};
  String _mpBillingTypeString(bool v) => v ? 'With Scheme' : 'NET';
  String _resolvedCatCode = ''; // e.g. "S"

  // === MULTI-PRODUCT: state ===
  final List<_MpRow> mp_rows = [];
  final Map<String, ProductCategoryRow> mp_pcByProduct =
      {}; // productCode -> mapping row
  final List<TextEditingController> mp_qtyCtrls = [];
  final ScrollController _newOrderHCtrl = ScrollController();

  //double get mp_grandTotal => mp_rows.fold<double>(0.0, (a, r) => a + r.total);

  double get mp_grandTotal {
    double sum = 0.0;
    for (final r in mp_rows) {
      final qty = r.qty < 0 ? 0 : r.qty;
      final base =
          r.total; // keep row rate/total untouched for display and storage
      final useScheme = _mpBillingTypeWithScheme[r.code] ?? false;
      final bulkMoq = useScheme ? r.schemeBulkMOQ : r.netBulkMOQ;
      final belowBulk = bulkMoq > 0 ? qty < bulkMoq : false;

      if (_cd && belowBulk) {
        sum += base * 0.97; // 3% extra off only in grand total
      } else {
        sum += base;
      }
    }
    return double.parse(sum.toStringAsFixed(2));
  }

  bool _cd =
      false; // Additional 3% off below bulk MOQ, applies only in grand total

  String? _orderType;
  String? _billingType;
  String? _productCode;
  String _productName = '';
  double _mrp = 0.0;
  final _qtyCtl = TextEditingController(text: '0');
  int _freeQty = 0;
  double _rate = 0.0;
  double _total = 0.0;
  String? _distributorId;

  List<ProductRow> _products = [];
  List<DistributorRow> _distributors = [];
  List<ProductCategoryRow> _pcRows = [];
  final String _salesPersonId = AppSession().salesPersonId ?? '';

  Widget _mpBuildBillingTypeSwitch(int i) {
    if (i < 0 || i >= mp_rows.length) return const SizedBox.shrink();
    final r = mp_rows[i];
    final code = r.code;
    final current =
        _mpBillingTypeWithScheme[code] ?? false; // default NET (off)

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch.adaptive(
          value: current,
          onChanged: (v) {
            setState(() {
              _mpBillingTypeWithScheme[code] = v;
              mp_recomputeRow(i); // recompute only this row
            });
          },
          activeColor: Colors.green,
          activeTrackColor: Colors.green.withOpacity(0.5),
          inactiveThumbColor: Colors.grey,
          inactiveTrackColor: Colors.grey.withOpacity(0.4),
        ),
        const SizedBox(width: 8),
        Text(_mpBillingTypeString(current)),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    widget.ordersRepo.streamProducts().listen(
      (v) => setState(() => _products = v),
    );
    widget.ordersRepo.streamDistributors().listen(
      (v) => setState(() => _distributors = v),
    );
    widget.ordersRepo.streamProductCategories().listen((v) {
      if (!mounted) return;
      setState(() => _pcRows = v);
    });
    widget.ordersRepo.getCategoryCodeByName(widget.customerCategory).then((
      code,
    ) {
      if (!mounted) return;
      setState(() {
        _resolvedCatCode = code; // "S" / "C" / "P"
      });
      _recompute(); // refresh rate with proper discount
    });
  }

  @override
  void dispose() {
    _qtyCtl.dispose();
    _newOrderHCtrl.dispose();
    super.dispose();
  }

  void _recompute() {
    final p = _products.firstWhere(
      (e) => e.productCode == _productCode,
      orElse: () =>
          ProductRow(productCode: '', productName: '', mrp: 0, freePer10: 0),
    );

    final pc = _pcFor(_productCode, _resolvedCatCode);

    _productName = p.productName;
    _mrp = p.mrp;

    final raw = _qtyCtl.text.trim();
    final typedQty = int.tryParse(raw) ?? 0;
    final qty = typedQty < 0 ? 0 : typedQty;

    _freeQty = (_billingType == 'With Scheme')
        ? (qty ~/ 10) * pc.freePer10Scheme
        : 0;

    if (_billingType == 'With Scheme') {
      _rate = _mrp * (1 - pc.discountScheme); // e.g. 350 * (1 - 0.3825)
    } else if (_billingType == 'NET') {
      _rate = _mrp * (1 - pc.discountNET); // e.g. 350 * (1 - 0.44)
    } else {
      _rate = _mrp;
    }
    _total = qty * _rate;

    setState(() {});

    mp_populateFromData();
  }

  void mp_recomputeRow(int i) {
    if (i < 0 || i >= mp_rows.length) return;
    final r = mp_rows[i];

    final bool useScheme = _mpBillingTypeWithScheme[r.code] ?? false;
    final int qty = r.qty < 0 ? 0 : r.qty;

    if (useScheme) {
      final bool hitBulk = r.schemeBulkMOQ > 0 && qty >= r.schemeBulkMOQ;
      final double disc = hitBulk ? r.discountSchemeBulk : r.discountScheme;
      r.rate = r.mrp * (1 - disc);

      // Free qty for scheme: bulk freeQty if MOQ hit, else per-10 scheme free
      if (hitBulk && r.freeQtyBulkScheme > 0) {
        r.free = r.freeQtyBulkScheme;
      } else {
        r.free = (qty ~/ 10) * r.freePer10Scheme;
      }
    } else {
      final bool hitBulk = r.netBulkMOQ > 0 && qty >= r.netBulkMOQ;
      final double disc = hitBulk ? r.discountNETBulk : r.discountNET;
      r.rate = r.mrp * (1 - disc);
      r.free = 0; // NET has no free qty
    }

    r.total = double.parse((qty * r.rate).toStringAsFixed(2));
  }

  void mp_recomputeAll() {
    for (var i = 0; i < mp_rows.length; i++) {
      mp_recomputeRow(i);
    }
    setState(() {});
  }

  Future<void> _saveMPOrder() async {
    // Basic validations (same style as your single-product save)
    if ((_orderType ?? '').isEmpty || (_distributorId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Order Type and Distributor'),
        ),
      );
      return;
    }

    // Collect only rows with qty > 0
    final nonZero = mp_rows.where((r) => r.qty > 0).toList();
    if (nonZero.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter at least one Billing Quantity > 0'),
        ),
      );
      return;
    }

    // Build productsDetail map and compute grandTotal
    final Map<String, Map<String, dynamic>> productsDetail = {};
    double grand = 0.0;

    for (final r in nonZero) {
      final bool billingSwitchState =
          _mpBillingTypeWithScheme[r.code] ?? false; // false => NET
      final String billingType = _mpBillingTypeString(billingSwitchState);
      final belowBulk = billingSwitchState
          ? (r.schemeBulkMOQ > 0 && r.qty < r.schemeBulkMOQ)
          : (r.netBulkMOQ > 0 && r.qty < r.netBulkMOQ);
      final bool cdApplied = _cd && belowBulk;
      productsDetail[r.code] = {
        'productName': r.name,
        'productMRP': r.mrp,
        'rate': double.parse(r.rate.toStringAsFixed(2)),
        'totalAmount': double.parse(r.total.toStringAsFixed(2)),
        'billQuantity': r.qty,
        'freeQuantity': r.free,
        'billingType': billingType,
        'cdApplied': cdApplied ? 1 : 0,
      };
      grand += r.total;
    }

    final grandTotal = mp_grandTotal;
    //double.parse(grand.toStringAsFixed(2));

    if (grandTotal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter quantity for at least one product'),
        ),
      );
      return;
    }

    await widget.ordersRepo.addMPOrder(
      customerCode: widget.customerCode,
      orderType: _orderType!,
      distributorID: _distributorId!,
      salesPersonID: _salesPersonId,
      grandTotal: grandTotal,
      productsDetail: productsDetail,
    );

    // Reset qty fields and recompute
    for (var i = 0; i < mp_rows.length; i++) {
      mp_rows[i]
        ..qty = 0
        ..free = 0
        ..total = 0.0; // rate stays based on billing type and discounts
      if (i < mp_qtyCtrls.length) {
        mp_qtyCtrls[i].text = '0';
      }
    }
    mp_recomputeAll();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Multi-product order saved')));
  }

  void mp_populateFromData() {
    if (_products.isEmpty || _pcRows.isEmpty || (_resolvedCatCode.isEmpty)) {
      // don’t build until we have the essentials
      return;
    }

    // Build map productCode -> productCategoryRow for this customer's category
    mp_pcByProduct.clear();
    for (final r in _pcRows) {
      if ((r.categoryCode.trim().toLowerCase() ==
          _resolvedCatCode.trim().toLowerCase())) {
        mp_pcByProduct[r.productCode] = r;
      }
    }

    // Filter products by above mapping (customer's category)
    final allowedCodes = mp_pcByProduct.keys.toSet();
    final scoped =
        _products.where((p) => allowedCodes.contains(p.productCode)).toList()
          ..sort((a, b) => a.productName.compareTo(b.productName));

    // Build rows (qty=0 by default). Rate computed off billing type & mrp.
    mp_rows..clear();
    mp_qtyCtrls.clear();

    for (final p in scoped) {
      final pc = mp_pcByProduct[p.productCode] ?? ProductCategoryRow.empty();

      mp_rows.add(
        _MpRow(
          code: p.productCode,
          name: p.productName,
          mrp: p.mrp,
          discountNET: pc.discountNET,
          discountScheme: pc.discountScheme,
          freePer10Scheme: pc.freePer10Scheme,
          netBulkMOQ: pc.netBulkMOQ,
          schemeBulkMOQ: pc.schemeBulkMOQ,
          discountNETBulk: pc.discountNETBulk,
          discountSchemeBulk: pc.discountSchemeBulk,
          freeQtyBulkScheme: pc.freeQtyBulkScheme,
        ),
      );
      mp_qtyCtrls.add(TextEditingController(text: '0'));
    }
    mp_recomputeAll();
    setState(() {});
  }

  ProductCategoryRow _pcFor(String? productCode, String catCodeRaw) {
    if (productCode == null || productCode.isEmpty) {
      return ProductCategoryRow.empty();
    }

    // normalize for matching
    final prodCode = productCode.trim().toUpperCase();
    final catCode = _resolvedCatCode.trim().toUpperCase();

    // exact match: productCode + categoryCode
    final exact = _pcRows.where(
      (r) =>
          r.productCode.trim().toUpperCase() == prodCode &&
          r.categoryCode.trim().toUpperCase() == catCode,
    );
    if (exact.isNotEmpty) return exact.first;

    // fallback: match by product only (useful if rows are not filled per-category yet)
    final byProdOnly = _pcRows.where(
      (r) => r.productCode.trim().toUpperCase() == prodCode,
    );
    if (byProdOnly.isNotEmpty) return byProdOnly.first;

    // fallback: match by category only (if discounts are category-wide)
    final byCatOnly = _pcRows.where(
      (r) => r.categoryCode.trim().toUpperCase() == catCode,
    );
    if (byCatOnly.isNotEmpty) return byCatOnly.first;

    return ProductCategoryRow.empty();
  }

  @override
  Widget build(BuildContext context) {
    Widget dCell(Widget child, double w, {bool right = false}) => SizedBox(
      width: w,
      child: Align(
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
    Widget _buildMultiProductTable() {
      Widget h(String t, double w, {bool right = false}) => SizedBox(
        width: w,
        child: Text(
          t,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
      Widget c(Widget child, double w, {bool right = false}) => SizedBox(
        width: w,
        child: Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
        ),
      );

      const double wCode = 150;
      const double wName = 260;
      const double wMrp = 100;
      const double wQty = 120;
      const double wFree = 120;
      const double wRate = 100;
      const double wTot = 140;
      const double wBill = 160;

      final rows = <Widget>[
        // header
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              h('Product Code', wCode),
              h('Product Name', wName),
              h('MRP', wMrp, right: true),
              h('Billing\nQuantity', wQty, right: true),
              Padding(
                padding: const EdgeInsets.only(left: 12.0), // <-- adds gap
                child: h('Billing Type', wBill),
              ),
              h('Free\nQuantity', wFree, right: true),
              h('Rate', wRate, right: true),
              h('Product Total', wTot, right: true),
            ],
          ),
        ),
        const Divider(height: 1),
      ];

      for (var i = 0; i < mp_rows.length; i++) {
        final r = mp_rows[i];
        final qtyCtl = mp_qtyCtrls[i];

        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                c(Text(r.code), wCode),
                c(Text(r.name), wName),
                c(Text(r.mrp.toStringAsFixed(2)), wMrp, right: true),

                // Qty editor -> recompute this row & grand total
                c(
                  SizedBox(
                    width: wQty - 10,
                    child: TextFormField(
                      controller: qtyCtl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '0',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (txt) {
                        final v = int.tryParse(txt.trim()) ?? 0;
                        r.qty = v < 0 ? 0 : v;
                        mp_recomputeRow(i);
                        setState(() {}); // reflect this row & grand total
                      },
                    ),
                  ),
                  wQty,
                  right: true,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: c(_mpBuildBillingTypeSwitch(i), wBill),
                ),
                c(Text(r.free.toString()), wFree, right: true),
                c(Text(r.rate.toStringAsFixed(2)), wRate, right: true),
                c(Text(r.total.toStringAsFixed(2)), wTot, right: true),
              ],
            ),
          ),
        );
      }

      rows.add(const Divider(height: 1));

      rows.add(
        Row(
          children: [
            const Spacer(),
            const Text('CD'),
            Switch.adaptive(
              value: _cd,
              onChanged: (v) => setState(() => _cd = v),
              activeColor: Colors.green,
              activeTrackColor: Colors.green.withOpacity(0.5),
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.grey.withOpacity(0.4),
            ),
          ],
        ),
      );
      rows.add(const SizedBox(height: 8));

      // grand total line

      rows.add(const SizedBox(height: 8));
      rows.add(
        Row(
          children: [
            const Spacer(),
            Text('Grand Total', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 24),
            SizedBox(
              width: 140,
              child: Text(
                mp_grandTotal.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      return Column(children: rows);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'New Order',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),

        // Row: Order Type | Billing Type (unchanged)
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Order Type',
                ),
                value: _orderType,
                items: _orderTypes
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text(e)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _orderType = v),
                isDense: true,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Distributor (unchanged)
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Distributor'),
          value: _distributorId,
          items: _distributors
              .map(
                (d) => DropdownMenuItem(
                  value: d.distributorID,
                  child: Text(d.firmName),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _distributorId = v),
          isDense: true,
        ),

        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (context, constraints) {
            const double targetWidth = 1200;
            final double contentWidth =
                constraints.maxWidth > targetWidth ? constraints.maxWidth : targetWidth;
            return Scrollbar(
              controller: _newOrderHCtrl,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 8,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _newOrderHCtrl,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: contentWidth,
                  child: _buildMultiProductTable(),
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: _saveMPOrder,
            child: const Text('Save Multi-Product Order'),
          ),
        ),
      ],
    );
  }
}

// === MULTI-PRODUCT: row model ===
class _MpRow {
  final String code;
  final String name;
  final double mrp;
  final double discountNET;
  final double discountScheme;
  final int freePer10Scheme;
  final int netBulkMOQ;
  final int schemeBulkMOQ;
  final double discountNETBulk;
  final double discountSchemeBulk;
  final int freeQtyBulkScheme;
  int qty;
  int free;
  double rate;
  double total;

  _MpRow({
    required this.code,
    required this.name,
    required this.mrp,
    required this.discountNET,
    required this.discountScheme,
    required this.freePer10Scheme,
    required this.netBulkMOQ,
    required this.schemeBulkMOQ,
    required this.discountNETBulk,
    required this.discountSchemeBulk,
    required this.freeQtyBulkScheme,
    this.qty = 0,
    this.free = 0,
    this.rate = 0.0,
    this.total = 0.0,
  });
}
