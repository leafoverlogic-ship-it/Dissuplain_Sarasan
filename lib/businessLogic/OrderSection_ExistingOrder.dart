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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _orders.where((o) {
      if (_filter == 'All') return true;
      final total = widget.ordersRepo.grandTotalFromEntryMP(o);
      return _displayStatus(o.orderConfirmation, total) == _filter;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                filtered.isEmpty ? 'No orders found' : '${filtered.length} order${filtered.length != 1 ? 's' : ''}',
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.8 : 0.9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: DropdownButton<String>(
                  value: _filter,
                  underline: const SizedBox(),
                  items: _statusFilters
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _filter = v ?? 'All'),
                ),
              ),
            ],
          ),
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

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('confirmed')) return const Color(0xFF10B981);
    if (lower.contains('gm')) return const Color(0xFFF59E0B);
    if (lower.contains('ceo')) return const Color(0xFFEF4444);
    if (lower.contains('cancelled')) return const Color(0xFF6B7280);
    if (lower.contains('new')) return const Color(0xFF3B82F6);
    return const Color(0xFF8B5CF6);
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.7)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 12),
      ),
    );
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
              ?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
        );

    Widget _miniHeader() => Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 15,
                child: Text(
                  'Code',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700) ??
                      const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 35,
                child: Text(
                  'Product',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700) ??
                      const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  'MRP',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700) ??
                      const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  'Qty',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700) ??
                      const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 12,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text(
                    'Type',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700) ??
                        const TextStyle(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  'Free',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700) ??
                      const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  'Rate',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700) ??
                      const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 16,
                child: Text(
                  'Total',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700) ??
                      const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );

    Widget _miniRow(OrderDisplayLine l) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest.withOpacity(0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 15,
                child: Text(
                  l.productCode,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 35,
                child: Text(
                  l.productName,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  l.productMRP.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  l.billQuantity.toString(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 12,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text(
                    l.billingType,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  l.freeQuantity.toString(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  l.rate.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                flex: 16,
                child: Text(
                  l.totalAmount.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
        );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final children = <Widget>[];
    for (final h in src) {
      final total = widget.ordersRepo.grandTotalFromEntryMP(h);
      final key = _orderKeys.putIfAbsent(h.orderID, () => GlobalKey());
      final status = _displayStatus(h.orderConfirmation, total);
      children.add(
        Container(
          key: key,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(isDark ? 0.72 : 0.88),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.8)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // --- header labels ---
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(flex: 16, child: _head('Order ID')),
                    Expanded(flex: 14, child: _head('Status')),
                    Expanded(flex: 14, child: _head('Type')),
                    Expanded(flex: 22, child: _head('Distributor')),
                    Expanded(flex: 14, child: _head('Order Date')),
                    Expanded(flex: 12, child: _head('Delivery')),
                    Expanded(flex: 12, child: _head('Del. Date')),
                    Expanded(flex: 10, child: _head('Total')),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              const SizedBox(height: 8),
              // --- header values ---
              Row(
                children: [
                  Expanded(
                    flex: 16,
                    child: Text(
                      h.orderID,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 14,
                    child: _statusBadge(status),
                  ),
                  Expanded(flex: 14, child: Text(h.orderType, style: const TextStyle(fontSize: 13))),
                  Expanded(
                    flex: 22,
                    child: Text(_distName(h.distributorID), style: const TextStyle(fontSize: 13)),
                  ),
                  Expanded(flex: 14, child: Text(_fmtDate(h.orderDate), style: const TextStyle(fontSize: 13))),
                  Expanded(
                    flex: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (h.deliveryStatus == 'Delivered')
                            ? const Color(0xFF10B981).withOpacity(0.15)
                            : const Color(0xFFEF4444).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (h.deliveryStatus == 'Delivered')
                              ? const Color(0xFF10B981).withOpacity(0.5)
                              : const Color(0xFFEF4444).withOpacity(0.5),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: (h.deliveryStatus == 'Delivered')
                              ? 'Delivered'
                              : 'Undelivered',
                          isDense: true,
                          style: TextStyle(
                            color: (h.deliveryStatus == 'Delivered')
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
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
                  ),
                  Expanded(flex: 12, child: Text(_fmtDeliveryDate(h.deliveryDate), style: const TextStyle(fontSize: 13))),
                  Expanded(
                    flex: 10,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        total.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    _miniHeader(),
                    const SizedBox(height: 8),
                    ...widget.ordersRepo.linesFromEntryMP(h).map(_miniRow),
                  ],
                ),
              ),
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
