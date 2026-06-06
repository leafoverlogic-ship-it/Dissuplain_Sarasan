import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dissuplain_app_web_mobile/dataLayer/orders_repository.dart';

class OrderSectionExistingOrder extends StatefulWidget {
  final OrdersRepository ordersRepo;
  final String customerCode;
  final Map<String, String>? userNameById; // optional map for approver names
  final String? initialOrderId;
  const OrderSectionExistingOrder({
    super.key,
    required this.ordersRepo,
    required this.customerCode,
    this.userNameById,
    this.initialOrderId,
  });

  @override
  State<OrderSectionExistingOrder> createState() =>
      _OrderSectionExistingOrderState();
}

class _OrderSectionExistingOrderState extends State<OrderSectionExistingOrder> {
  final _statusFilters = const [
    'All',
    'New',
    'Confirmed',
    'Awaiting GM Approval',
    'Awaiting CEO Approval',
    'AM Cancelled',
    'GM Cancelled',
    'CEO Cancelled',
  ];
  final ScrollController _hCtrl = ScrollController();

  String _filter = 'All';
  List<OrderEntry> _orders = [];
  List<DistributorRow> _distributors = [];
  final Map<String, GlobalKey> _orderKeys = {};
  bool _didJump = false;

  bool _gmNeeded(double total) => total > 10000;
  bool _ceoNeeded(double total) => total >= 20001;

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

  @override
  void initState() {
    super.initState();
    widget.ordersRepo
        .streamForCustomer(widget.customerCode)
        .listen((v) => setState(() => _orders = v));
    widget.ordersRepo.streamDistributors().listen(
          (v) => setState(() => _distributors = v),
        );
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _orders.where((o) {
      if (_filter == 'All') return true;
      final total = widget.ordersRepo.grandTotalFromEntryMP(o);
      return _displayStatus(o.orderConfirmation, total) == _filter;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            DropdownButton<String>(
              value: _filter,
              items: _statusFilters
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _filter = v ?? 'All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const double targetWidth = 1200;
            final double contentWidth =
                constraints.maxWidth > targetWidth ? constraints.maxWidth : targetWidth;

            return Scrollbar(
              controller: _hCtrl,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 8,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _hCtrl,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: contentWidth,
                  child: _buildOrdersDisplayMP(filtered),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _scheduleJump() {
    if (_didJump) return;
    final targetId = widget.initialOrderId;
    if (targetId == null || targetId.isEmpty) return;
    final key = _orderKeys[targetId];
    if (key == null) return;
    _didJump = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = key?.currentContext;
      if (current == null) {
        _didJump = false;
        return;
      }
      Scrollable.ensureVisible(
        current,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _updateDeliveryStatus(
    String orderId,
    String status,
  ) async {
    final normalized = status.toLowerCase() == 'delivered' ? 'Delivered' : 'Undelivered';
    final deliveryDate = normalized == 'Delivered'
        ? DateTime.now().millisecondsSinceEpoch
        : 0;
    await FirebaseDatabase.instance
        .ref('Orders/${widget.customerCode}/$orderId')
        .update({'deliveryStatus': normalized, 'deliveryDate': deliveryDate});
  }

  Widget _buildOrdersDisplayMP(List<OrderEntry> src) {
    String _fmtDate(int ms) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d-$m-${dt.year}';
    }
    String _fmtDeliveryDate(int ms) {
      if (ms <= 0) return '';
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d-$m-${dt.year}';
    }

    String _distName(String id) => _distributors
        .firstWhere(
          (d) => d.distributorID == id,
          orElse: () => DistributorRow(distributorID: '', firmName: 'ƒ?"'),
        )
        .firmName;

    Text _head(String t) => Text(
          t,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
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
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text(
                    'Billing Type',
                    style: TextStyle(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.left,
                  ),
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
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text(
                    l.billingType,
                    textAlign: TextAlign.left,
                  ),
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

    final children = <Widget>[];
    for (final h in src) {
      final total = widget.ordersRepo.grandTotalFromEntryMP(h);
      final key = _orderKeys.putIfAbsent(h.orderID, () => GlobalKey());
      children.add(
        Container(
          key: key,
          margin: const EdgeInsets.only(bottom: 16),
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
                    Expanded(flex: 14, child: _head('Order Status')),
                    Expanded(flex: 14, child: _head('Order Type')),
                    Expanded(flex: 22, child: _head('Distributor')),
                    Expanded(flex: 14, child: _head('Order Date')),
                    Expanded(flex: 12, child: _head('Delivery Status')),
                    Expanded(flex: 12, child: _head('Delivery Date')),
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
                  Expanded(
                    flex: 14,
                    child: Text(_displayStatus(h.orderConfirmation, total)),
                  ),
                  Expanded(flex: 14, child: Text(h.orderType)),
                  Expanded(
                    flex: 22,
                    child: Text(_distName(h.distributorID)),
                  ),
                  Expanded(flex: 14, child: Text(_fmtDate(h.orderDate))),
                  Expanded(
                    flex: 12,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (h.deliveryStatus == 'Delivered')
                            ? 'Delivered'
                            : 'Undelivered',
                        items: const [
                          DropdownMenuItem(
                            value: 'Undelivered',
                            child: Text('Undelivered'),
                          ),
                          DropdownMenuItem(
                            value: 'Delivered',
                            child: Text('Delivered'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          _updateDeliveryStatus(h.orderID, v);
                        },
                      ),
                    ),
                  ),
                  Expanded(flex: 12, child: Text(_fmtDeliveryDate(h.deliveryDate))),
                  Expanded(
                    flex: 10,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        total.toStringAsFixed(2),
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
      );
    }

    _scheduleJump();

    return Column(
      children: [
        ...children,
      ],
    );
  }
}
