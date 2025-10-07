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

class _OrdersSectionState extends State<OrdersSection> {
  final _orderTypes = const ['1st Order', 'Repeat Order'];
  final _billingTypes = const ['With Scheme', 'NET'];
  final _statusFilters = const ['All', 'New', 'Confirmed', 'Cancelled'];
  String _resolvedCatCode = ''; // e.g. "S"

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
  }

  Future<void> _save() async {
    final qty = int.tryParse(_qtyCtl.text.trim()) ?? 0;

    if (_orderType == null ||
        _billingType == null ||
        _productCode == null ||
        _productCode!.isEmpty ||
        qty <= 0 ||
        _distributorId == null ||
        _distributorId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fill Order Type, Billing, Product, Quantity, Distributor',
          ),
        ),
      );
      return;
    }
    // Enforce multiples of 10 only on submission when "With Scheme"
    if (_billingType == 'With Scheme' && (qty % 10 != 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'For "With Scheme", billing quantity must be a multiple of 10.',
          ),
        ),
      );
      return;
    }
    await widget.ordersRepo.addOrder(
      customerCode: widget.customerCode,
      orderType: _orderType!,
      billingType: _billingType!,
      productCode: _productCode!,
      productName: _productName,
      productMRP: _mrp,
      billQuantity: qty,
      freeQuantity: _freeQty,
      rate: _rate,
      totalAmount: _total,
      distributorID: _distributorId!,
    );
    setState(() {
      _orderType = null;
      _billingType = null;
      _productCode = null;
      _productName = '';
      _mrp = 0;
      _qtyCtl.text = '0';
      _freeQty = 0;
      _rate = 0;
      _total = 0;
      _distributorId = null;
    });
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
                        },
                        isDense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Product Code',
                        ),
                        value: _productCode,
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
                        isDense: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                        ),
                        controller: TextEditingController(text: _productName),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Product MRP',
                        ),
                        controller: TextEditingController(
                          text: _mrp == 0 ? '' : _mrp.toStringAsFixed(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Billing Quantity',
                        ),
                        controller: _qtyCtl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _recompute(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Free Quantity',
                        ),
                        controller: TextEditingController(
                          text: _freeQty.toString(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Rate'),
                        controller: TextEditingController(
                          text: _rate.toStringAsFixed(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Total Amount',
                        ),
                        controller: TextEditingController(
                          text: 'Rs. ${_total.toStringAsFixed(2)}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _save,
                    child: const Text('Save Order'),
                  ),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Text(
                      'Existing Orders',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    DropdownButton<String>(
                      value: _filter,
                      items: _statusFilters
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _filter = v ?? 'All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Order ID')),
                          DataColumn(label: Text('Order Date')),
                          DataColumn(label: Text('Order Type')),
                          DataColumn(label: Text('Billing Type')),
                          DataColumn(label: Text('Product Code')),
                          DataColumn(label: Text('Product Name')),
                          DataColumn(label: Text('MRP')),
                          DataColumn(label: Text('Qty')),
                          DataColumn(label: Text('Free')),
                          DataColumn(label: Text('Rate')),
                          DataColumn(label: Text('Total')),
                          DataColumn(label: Text('Distributor')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: filtered.map((o) {
                          final dt = DateTime.fromMillisecondsSinceEpoch(
                            o.orderDate,
                          );
                          final ds =
                              '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} '
                              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          final canEdit = o.orderConfirmation == 'New';
                          final dist = _distributors
                              .firstWhere(
                                (d) => d.distributorID == o.distributorID,
                                orElse: () => DistributorRow(
                                  distributorID: '',
                                  firmName: '',
                                ),
                              )
                              .firmName;
                          return DataRow(
                            cells: [
                              DataCell(Text(o.orderID)),
                              DataCell(Text(ds)),
                              DataCell(Text(o.orderType)),
                              DataCell(Text(o.billingType)),
                              DataCell(Text(o.productCode)),
                              DataCell(Text(o.productName)),
                              DataCell(Text(o.productMRP.toStringAsFixed(2))),
                              DataCell(Text(o.billQuantity.toString())),
                              DataCell(Text(o.freeQuantity.toString())),
                              DataCell(Text(o.rate.toStringAsFixed(2))),
                              DataCell(Text(o.totalAmount.toStringAsFixed(2))),
                              DataCell(Text(dist)),
                              DataCell(Text(o.orderConfirmation)),
                              DataCell(
                                canEdit
                                    ? _InlineStatusEditor(
                                        onSave: (val) async {
                                          await widget.ordersRepo
                                              .updateConfirmation(
                                                widget.customerCode,
                                                o.orderID,
                                                val,
                                              );
                                        },
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
