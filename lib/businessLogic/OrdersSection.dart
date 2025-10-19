import 'package:flutter/material.dart';
import '../../dataLayer/orders_repository.dart';

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

class _DisplayLine {
  final String code, name;
  final double mrp, rate, total;
  final int qty, free;

  _DisplayLine({
    required this.code,
    required this.name,
    required this.mrp,
    required this.qty,
    required this.free,
    required this.rate,
    required this.total,
  });
}

class _OrdersSectionState extends State<OrdersSection> {
  final _orderTypes = const ['1st Order', 'Repeat Order'];
  final _billingTypes = const ['With Scheme', 'NET'];
  final _statusFilters = const ['All', 'New', 'Confirmed', 'Cancelled'];
  String _resolvedCatCode = ''; // e.g. "S"

  // === MULTI-PRODUCT: state ===
  final List<_MpRow> mp_rows = [];
  final Map<String, ProductCategoryRow> mp_pcByProduct =
      {}; // productCode -> mapping row
  final List<TextEditingController> mp_qtyCtrls = [];

  double get mp_grandTotal => mp_rows.fold<double>(0.0, (a, r) => a + r.total);

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
  String _filter = 'All';

  List<ProductRow> _products = [];
  List<DistributorRow> _distributors = [];
  List<OrderEntry> _orders = [];
  List<ProductCategoryRow> _pcRows = [];

  @override
  void initState() {
    super.initState();
    widget.ordersRepo.streamProducts().listen(
      (v) => setState(() => _products = v),
    );
    widget.ordersRepo.streamDistributors().listen(
      (v) => setState(() => _distributors = v),
    );
    widget.ordersRepo
        .streamForCustomer(widget.customerCode)
        .listen((v) => setState(() => _orders = v));
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

    // === RATE ===
    if (_billingType == 'With Scheme') {
      r.rate = r.mrp * (1 - r.discountScheme);
    } else if (_billingType == 'NET') {
      r.rate = r.mrp * (1 - r.discountNET);
    } else {
      r.rate = r.mrp;
    }

    // === FREE QTY ===
    r.free = (_billingType == 'With Scheme')
        ? (r.qty ~/ 10) * r.freePer10Scheme
        : 0;

    r.total = double.parse((r.qty * r.rate).toStringAsFixed(2));
    final newTotal = double.parse((r.qty * r.rate).toStringAsFixed(2));

    r
      ..rate = r.rate
      ..free = r.free
      ..total = newTotal;
  }

  void mp_recomputeAll() {
    for (var i = 0; i < mp_rows.length; i++) {
      mp_recomputeRow(i);
    }
    setState(() {});
  }

  Future<void> _saveMPOrder() async {
    // Basic validations (same style as your single-product save)
    if ((_orderType ?? '').isEmpty ||
        (_billingType ?? '').isEmpty ||
        (_distributorId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select Order Type, Billing Type and Distributor',
          ),
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
      productsDetail[r.code] = {
        'productName': r.name,
        'productMRP': r.mrp,
        'rate': double.parse(r.rate.toStringAsFixed(2)),
        'totalAmount': double.parse(r.total.toStringAsFixed(2)),
        'billQuantity': r.qty,
        'freeQuantity': r.free,
      };
      grand += r.total;
    }

    final grandTotal = double.parse(grand.toStringAsFixed(2));

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
      billingType: _billingType!,
      distributorID: _distributorId!,
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
    final filtered = _orders
        .where((o) => _filter == 'All' ? true : o.orderConfirmation == _filter)
        .toList();
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

                c(Text(r.free.toString()), wFree, right: true),
                c(Text(r.rate.toStringAsFixed(2)), wRate, right: true),
                c(Text(r.total.toStringAsFixed(2)), wTot, right: true),
              ],
            ),
          ),
        );
      }

      rows.add(const Divider(height: 1));

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

    Widget _buildOrdersDisplayMP(List<OrderEntry> src) {
      String _fmtDate(int ms) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        final d = dt.day.toString().padLeft(2, '0');
        final m = dt.month.toString().padLeft(2, '0');
        return '$d-$m-${dt.year}';
      }

      String _distName(String id) => _distributors
          .firstWhere(
            (d) => d.distributorID == id,
            orElse: () => DistributorRow(distributorID: '', firmName: '—'),
          )
          .firmName;

      Text _head(String t) => Text(
        t,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      );

      Widget _miniHeader() => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Row(
          children: const [
            Expanded(
              flex: 15,
              child: Text(
                'Product Code',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 35,
              child: Text(
                'Product Name',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 10,
              child: Text(
                'MRP',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 12,
              child: Text(
                'Billing Quantity',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 12,
              child: Text(
                'Free Quantity',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 10,
              child: Text(
                'Rate',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 16,
              child: Text(
                'Product Total',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

      Widget _miniRow(OrderDisplayLine l) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(flex: 15, child: Text(l.productCode)),
            Expanded(flex: 35, child: Text(l.productName)),
            Expanded(
              flex: 10,
              child: Text(
                l.productMRP.toStringAsFixed(2),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 12,
              child: Text(
                l.billQuantity.toString(),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 12,
              child: Text(
                l.freeQuantity.toString(),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 10,
              child: Text(
                l.rate.toStringAsFixed(2),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 16,
              child: Text(
                l.totalAmount.toStringAsFixed(2),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );

      return Column(
        children: [
          for (final h in src)
            Container(
              margin: const EdgeInsets.only(bottom: 16), // ← gap between orders
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // --- header labels ---
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(flex: 16, child: _head('Order ID')),
                        Expanded(flex: 14, child: _head('Confirmation')),
                        Expanded(flex: 14, child: _head('Order Type')),
                        Expanded(flex: 14, child: _head('Billing Type')),
                        Expanded(flex: 22, child: _head('Distributor')),
                        Expanded(flex: 14, child: _head('Order Date')),
                        Expanded(flex: 10, child: _head('Grand Total')),
                      ],
                    ),
                  ),
                  // --- header values ---
                  Row(
                    children: [
                      Expanded(
                        flex: 16,
                        child: Text(
                          h.orderID,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(flex: 14, child: Text(h.orderConfirmation)),
                      Expanded(flex: 14, child: Text(h.orderType)),
                      Expanded(flex: 14, child: Text(h.billingType)),
                      Expanded(
                        flex: 22,
                        child: Text(_distName(h.distributorID)),
                      ),
                      Expanded(flex: 14, child: Text(_fmtDate(h.orderDate))),
                      Expanded(
                        flex: 10,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            widget.ordersRepo
                                .grandTotalFromEntryMP(h)
                                .toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  const Divider(height: 1),

                  // --- products mini table ---
                  _miniHeader(),
                  const Divider(height: 1),
                  ...widget.ordersRepo.linesFromEntryMP(h).map(_miniRow),
                ],
              ),
            ),
        ],
      );
    }

    const double wCode = 150;
    const double wName = 260;
    const double wMrp = 100;
    const double wQty = 120;
    const double wFree = 120;
    const double wRate = 100;
    const double wTot = 140;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text(
          'Orders',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Billing Type',
                        ),
                        value: _billingType,
                        items: _billingTypes
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() => _billingType = v);
                          _recompute();
                          mp_recomputeAll();
                        },
                        isDense: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // One data row (reuses your existing state/logic)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Row(
                    children: [
                      // Product Code (dropdown)
                      dCell(
                        SizedBox(
                          width: wCode - 10,
                          child: DropdownButtonFormField<String>(
                            isDense: true,
                            value: _productCode,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            items: _products
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p.productCode,
                                    child: Text(
                                      '${p.productCode} (${p.productName})',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() => _productCode = v);
                              _recompute();
                            },
                          ),
                        ),
                        wCode,
                      ),

                      // Product Name (readonly)
                      dCell(
                        Text(
                          _productName ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                        wName,
                      ),

                      // MRP (readonly)
                      dCell(
                        Text((_mrp == 0 ? '' : _mrp.toStringAsFixed(2))),
                        wMrp,
                        right: true,
                      ),

                      // Billing Quantity (editable)
                      dCell(
                        SizedBox(
                          width: wQty - 10,
                          child: TextFormField(
                            controller: _qtyCtl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: '0',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) => _recompute(),
                          ),
                        ),
                        wQty,
                        right: true,
                      ),

                      // Free Qty (readonly)
                      dCell(Text((_freeQty).toString()), wFree, right: true),

                      // Rate (readonly)
                      dCell(Text(_rate.toStringAsFixed(2)), wRate, right: true),

                      // Product Total (readonly)
                      dCell(Text(_total.toStringAsFixed(2)), wTot, right: true),
                    ],
                  ),
                ),

                const Divider(height: 1),
                const SizedBox(height: 8),

                // Grand Total (same as product total for single-product order)
                Row(
                  children: [
                    const Spacer(),
                    Text(
                      'Grand Total',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: wTot,
                      child: Text(
                        _total.toStringAsFixed(2),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

                _buildMultiProductTable(),
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
                Row(
                  children: [
                    const Text(
                      'Existing Orders',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    // DropdownButton<String>(
                    //   value: _filter,
                    //   items: _statusFilters
                    //       .map(
                    //         (e) => DropdownMenuItem(value: e, child: Text(e)),
                    //       )
                    //       .toList(),
                    //   onChanged: (v) => setState(() => _filter = v ?? 'All'),
                    // ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildOrdersDisplayMP(filtered),
              ],
            ),
          ),
        ],
      ),
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
    this.qty = 0,
    this.free = 0,
    this.rate = 0.0,
    this.total = 0.0,
  });
}

class _InlineStatusEditor extends StatefulWidget {
  final Future<void> Function(String) onSave;
  const _InlineStatusEditor({required this.onSave, Key? key}) : super(key: key);
  @override
  State<_InlineStatusEditor> createState() => _InlineStatusEditorState();
}

class _InlineStatusEditorState extends State<_InlineStatusEditor> {
  String? _v = 'Confirmed';
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DropdownButton<String>(
          value: _v,
          items: const [
            DropdownMenuItem(value: 'Confirmed', child: Text('Confirmed')),
            DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
          ],
          onChanged: (v) => setState(() => _v = v),
        ),
        IconButton(
          icon: const Icon(Icons.check, size: 18),
          onPressed: _v == null
              ? null
              : () async {
                  await widget.onSave(_v!);
                },
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => setState(() => _v = 'Confirmed'),
        ),
      ],
    );
  }
}
