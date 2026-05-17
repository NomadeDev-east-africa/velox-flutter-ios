import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nomade_client/models/order.dart';
import 'package:nomade_client/providers/all_providers.dart';
import 'order_completed_screen.dart';
import 'track_delivery_screen.dart';

// ── Kinetic Monolith palette ──────────────────────────────────────────────────
const _bg         = Color(0xFF0E0E0E);
const _surfaceLow = Color(0xFF131313);
const _surface    = Color(0xFF1A1919);
const _surfaceHigh= Color(0xFF20201F);
const _primary    = Color(0xFF9FFF88);
const _onPrimary  = Color(0xFF026400);
const _onSurface  = Color(0xFFFFFFFF);
const _onVariant  = Color(0xFFADAAAA);
const _outline    = Color(0xFF484847);
const _error      = Color(0xFFFF7351);

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String? orderId;
  const OrderTrackingScreen({super.key, this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  bool   _attachTriggered = false;
  Order? _completedOrder;

  // ── Timer d'annulation (2 minutes) ───────────────────────────────────────
  Timer? _cancelTimer;
  int    _cancelSecondsLeft  = 120;
  bool   _cancelTimerStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.orderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryAttachOrder());
    }
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  void _startCancelTimer() {
    if (_cancelTimerStarted) return;
    _cancelTimerStarted = true;
    _cancelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _cancelSecondsLeft--;
        if (_cancelSecondsLeft <= 0) timer.cancel();
      });
    });
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _tryAttachOrder() {
    if (_attachTriggered || !mounted) return;
    final currentState = ref.read(activeOrderProvider);
    if (currentState.order == null &&
        !currentState.isLoading &&
        widget.orderId != null) {
      _attachTriggered = true;
      debugPrint('📎 [OrderTracking] Auto-attach orderId: ${widget.orderId}');
      ref.read(activeOrderProvider.notifier).attachOrder(widget.orderId!);
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  int _getCurrentStepIndex(String status) {
    switch (status) {
      case Order.statusPending:
      case Order.statusConfirmed:
      case Order.statusAccepted:   return 0;
      case Order.statusPreparing:  return 1;
      case Order.statusReady:      return 2;
      case Order.statusDelivering: return 3;
      case Order.statusCompleted:  return 4;
      default:                     return 0;
    }
  }

  String _sessionId(String orderId) =>
      '#${orderId.substring(0, 8).toUpperCase()}';

  Future<void> _showExitDialog() async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Quitter le suivi ?',
            style: TextStyle(color: _onSurface, fontWeight: FontWeight.bold)),
        content: const Text(
          'Votre commande continue d\'être préparée. '
          'Vous pouvez revenir suivre sa progression.',
          style: TextStyle(color: _onVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Rester', style: TextStyle(color: _primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter', style: TextStyle(color: _onVariant)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) navigator.popUntil((r) => r.isFirst);
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(activeOrderProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(orderState.order),
        body: _buildBody(orderState),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Order? order) {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: _primary),
        onPressed: () {},
      ),
      title: Image.asset('assets/images/logo_velox.webp', height: 36, fit: BoxFit.contain),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _surfaceHigh,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _outline.withValues(alpha: 0.3)),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close, color: _onVariant, size: 18),
            onPressed: _showExitDialog,
          ),
        ),
      ],
    );
  }

  // ── BODY ROUTING ─────────────────────────────────────────────────────────

  Widget _buildBody(ActiveOrderState orderState) {
    if (orderState.order != null &&
        orderState.order!.status == Order.statusCompleted) {
      _completedOrder = orderState.order;
    }

    // Loading
    if (orderState.isLoading ||
        (widget.orderId != null &&
            orderState.order == null &&
            !orderState.isTerminated &&
            _completedOrder == null)) {
      return _buildLoadingView();
    }

    // Erreur
    if (orderState.error != null &&
        orderState.order == null &&
        _completedOrder == null) {
      return _buildErrorView(orderState.error!);
    }

    // Commande terminée (en cache) → bouton confirmer
    if (orderState.order == null && _completedOrder != null) {
      return _buildMainContent(_completedOrder!, isCompletedCache: true);
    }

    // État terminal réel
    if (orderState.order == null && _attachTriggered) {
      return _buildTerminalView();
    }

    if (orderState.order == null) {
      return _buildLoadingView();
    }

    return _buildMainContent(orderState.order!, isWatching: orderState.isWatching);
  }

  // ── MAIN CONTENT ─────────────────────────────────────────────────────────

  Widget _buildMainContent(
    Order order, {
    bool isWatching = false,
    bool isCompletedCache = false,
  }) {
    // Démarrer le timer d'annulation dès que la commande est annulable
    if (order.canBeCancelled && !_cancelTimerStarted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startCancelTimer();
      });
    }

    final isDelivering = order.status == Order.statusDelivering;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageHeader(order, isDelivering: isDelivering),
                _buildMapPlaceholder(order, isDelivering: isDelivering, isWatching: isWatching),
                _buildStepper(order),
                _buildProviderOrDetails(order, isDelivering: isDelivering),
                if (!isDelivering) _buildManifest(order),
                if (isDelivering) _buildDetailsCard(order),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        // CTA Buttons
        _buildBottomActions(order, isCompletedCache: isCompletedCache),
      ],
    );
  }

  // ── PAGE HEADER ──────────────────────────────────────────────────────────

  Widget _buildPageHeader(Order order, {required bool isDelivering}) {
    if (!isDelivering) {
      // Design 1 : CURRENT OPERATION + big title + SESSION ID
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left green accent bar + title block
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: const BoxDecoration(color: _primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CURRENT OPERATION',
                          style: TextStyle(
                            color: _onVariant,
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SUIVI DE\nCOMMANDE',
                          style: TextStyle(
                            color: _onSurface,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'SESSION ID',
                      style: TextStyle(
                        color: _onVariant,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _sessionId(order.id),
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Design 2 : Big title + two-column info
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SUIVI DE COMMANDE',
            style: TextStyle(
              color: _onSurface,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoCol('IDENTIFICATION', _sessionId(order.id))),
              Expanded(child: _buildInfoCol('ETABLISSEMENT', order.restaurantName)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _onVariant,
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 2, color: _primary),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── MAP PLACEHOLDER ───────────────────────────────────────────────────────

  Widget _buildMapPlaceholder(
    Order order, {
    required bool isDelivering,
    required bool isWatching,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      height: isDelivering ? 200 : 140,
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _outline.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle grid pattern
          CustomPaint(painter: _GridPainter()),
          // Center icon
          Center(
            child: Icon(
              isDelivering ? Icons.delivery_dining : Icons.map_outlined,
              color: _primary.withValues(alpha: 0.15),
              size: 64,
            ),
          ),
          // Status chip top-right
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _surfaceHigh,
                border: Border.all(color: _primary.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: _primary, shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isDelivering ? 'LIVE TELEMETRY ACTIVE' : 'SIGNAL: OPTIMAL',
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEPPER ───────────────────────────────────────────────────────────────

  Widget _buildStepper(Order order) {
    final steps = [
      _StepData(
        label: 'Confirmée',
        subLabel: 'Order validated by system',
        subLabelDelivering: 'Order received by system',
      ),
      _StepData(
        label: 'Préparation',
        subLabel: 'Chef is assembling your order',
        subLabelDelivering: 'Chef is currently processing the order',
      ),
      _StepData(
        label: 'Prête',
        subLabel: 'Awaiting pick-up',
        subLabelDelivering: 'Packaging completed. Awaiting pick-up',
      ),
      _StepData(
        label: 'En livraison',
        subLabel: 'En route vers vous',
        subLabelDelivering: 'Driver is on the way to your location',
      ),
      _StepData(
        label: 'Livrée',
        subLabel: '',
        subLabelDelivering: '',
      ),
    ];

    final currentIndex  = _getCurrentStepIndex(order.status);
    final isDelivering  = order.status == Order.statusDelivering;
    const deliveringIdx = 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceLow,
          border: Border.all(color: _outline.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PROCESS STATUS',
              style: TextStyle(
                color: _onVariant,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...steps.asMap().entries.map((entry) {
              final i         = entry.key;
              final step      = entry.value;
              final isDone    = i < currentIndex;
              final isCurrent = i == currentIndex;
              final isLast    = i == steps.length - 1;

              final showVoirLivreur = i == deliveringIdx &&
                  order.status == Order.statusDelivering &&
                  order.deliveryDriverId != null;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column: checkbox + vertical line
                  Column(
                    children: [
                      _buildStepIcon(isDone: isDone, isCurrent: isCurrent),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 36,
                          color: isDone ? _primary : _outline.withValues(alpha: 0.3),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Right column: label + sublabel + voir livreur
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  step.label.toUpperCase(),
                                  style: TextStyle(
                                    color: isCurrent
                                        ? _primary
                                        : isDone
                                            ? _onSurface
                                            : _outline,
                                    fontSize: 13,
                                    fontWeight: isCurrent || isDone
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (showVoirLivreur)
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TrackDeliveryScreen(
                                        orderId:          order.id,
                                        livreurId:        order.deliveryDriverId!,
                                        livreurName:      order.deliveryDriverName,
                                        deliveryLocation: order.deliveryLocation,
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: _onSurface.withValues(alpha: 0.5)),
                                    ),
                                    child: const Text(
                                      'VOIR LIVREUR',
                                      style: TextStyle(
                                        color: _onSurface,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if ((isCurrent || isDone) &&
                              (isDelivering ? step.subLabelDelivering : step.subLabel).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                isDelivering ? step.subLabelDelivering : step.subLabel,
                                style: TextStyle(
                                  color: _onVariant.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIcon({required bool isDone, required bool isCurrent}) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isDone
            ? _primary
            : isCurrent
                ? Colors.transparent
                : Colors.transparent,
        border: Border.all(
          color: isDone || isCurrent ? _primary : _outline,
          width: 1.5,
        ),
      ),
      child: isDone
          ? const Icon(Icons.check, color: _onPrimary, size: 14)
          : isCurrent
              ? Container(
                  margin: const EdgeInsets.all(4),
                  color: _primary,
                )
              : null,
    );
  }

  // ── PROVIDER (design 1 — non-delivering) ─────────────────────────────────

  Widget _buildProviderOrDetails(Order order, {required bool isDelivering}) {
    if (isDelivering) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surfaceLow,
          border: Border.all(color: _outline.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.restaurant, color: _onVariant, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROVIDER',
                  style: TextStyle(
                    color: _onVariant,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.restaurantName.toUpperCase(),
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── MANIFEST (design 1 — non-delivering) ─────────────────────────────────

  Widget _buildManifest(Order order) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MANIFEST CONTENT',
            style: TextStyle(
              color: _onVariant,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${item.quantity}x  ${item.name.toUpperCase()}',
                      style: const TextStyle(color: _onSurface, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      '${item.totalPrice} FDJ',
                      style: const TextStyle(color: _onSurface, fontSize: 13),
                    ),
                  ],
                ),
              )),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Text('LIVRAISON',
                    style: TextStyle(color: _onVariant, fontSize: 13)),
                const Spacer(),
                Text('${order.deliveryFee} FDJ',
                    style: const TextStyle(color: _onVariant, fontSize: 13)),
              ],
            ),
          ),
          Divider(color: _outline.withValues(alpha: 0.3), height: 20),
          Row(
            children: [
              const Text(
                'TOTAL PAYLOAD',
                style: TextStyle(
                  color: _onVariant,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${order.total} FDJ',
                style: const TextStyle(
                  color: _primary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'AUTHORIZED COMMAND ONLY · REF ${_sessionId(order.id)}',
              style: TextStyle(
                color: _onVariant.withValues(alpha: 0.4),
                fontSize: 9,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── DETAILS CARD (design 2 — delivering) ─────────────────────────────────

  Widget _buildDetailsCard(Order order) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceLow,
          border: Border.all(color: _outline.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DÉTAILS DE LA COMMANDE',
              style: TextStyle(
                color: _onVariant,
                fontSize: 10,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text('${item.quantity}x ${item.name.toLowerCase()}',
                          style: const TextStyle(color: _onSurface, fontSize: 13)),
                      const Spacer(),
                      Text('${item.totalPrice}  FDJ',
                          style: const TextStyle(color: _onSurface, fontSize: 13)),
                    ],
                  ),
                )),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Text('Livraison',
                      style: TextStyle(color: _onVariant, fontSize: 13)),
                  const Spacer(),
                  Text('${order.deliveryFee}  FDJ',
                      style: const TextStyle(color: _onVariant, fontSize: 13)),
                ],
              ),
            ),
            Divider(color: _outline.withValues(alpha: 0.3), height: 20),
            Row(
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    color: _onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  '${order.total} FDJ',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── BOTTOM ACTIONS ────────────────────────────────────────────────────────

  Widget _buildBottomActions(Order order, {bool isCompletedCache = false}) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Confirmer livraison
          if (order.status == Order.statusCompleted || isCompletedCache)
            GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderCompletedScreen(
                      order: isCompletedCache ? _completedOrder! : order),
                ),
              ),
              child: Container(
                width: double.infinity,
                height: 54,
                color: _primary,
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: _onPrimary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'CONFIRMER LA LIVRAISON',
                      style: TextStyle(
                        color: _onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Annuler la commande (fenêtre de 2 minutes)
          if (order.canBeCancelled && _cancelSecondsLeft > 0) ...[
            if (order.status == Order.statusCompleted || isCompletedCache)
              const SizedBox(height: 10),
            // Countdown bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              color: _surfaceLow,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, color: _onVariant, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Annulation possible encore ',
                    style: TextStyle(
                      color: _onVariant.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatCountdown(_cancelSecondsLeft),
                    style: const TextStyle(
                      color: _error,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _confirmCancel(),
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  color: _error.withValues(alpha: 0.05),
                  border: Border.all(color: _error.withValues(alpha: 0.6)),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'ANNULER LA COMMANDE',
                  style: TextStyle(
                    color: _error,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Annuler la commande ?',
            style: TextStyle(color: _onSurface, fontWeight: FontWeight.bold)),
        content: const Text('Cette action est irréversible.',
            style: TextStyle(color: _onVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non', style: TextStyle(color: _primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, annuler', style: TextStyle(color: _error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref.read(activeOrderProvider.notifier).cancelOrder();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Commande annulée avec succès')),
        );
        Navigator.of(context).popUntil((r) => r.isFirst);
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  // ── STATES ────────────────────────────────────────────────────────────────

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _primary, strokeWidth: 2),
          SizedBox(height: 16),
          Text('Chargement de votre commande...',
              style: TextStyle(color: _onVariant, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTerminalView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            color: _primary.withValues(alpha: 0.1),
            child: const Icon(Icons.check, color: _primary, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'COMMANDE TERMINÉE',
            style: TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: _error),
            const SizedBox(height: 16),
            Text('Erreur: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _onVariant)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                color: _primary,
                child: const Text(
                  'RETOUR À L\'ACCUEIL',
                  style: TextStyle(
                    color: _onPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data class pour les étapes ────────────────────────────────────────────────

class _StepData {
  final String label;
  final String subLabel;
  final String subLabelDelivering;
  const _StepData({
    required this.label,
    required this.subLabel,
    required this.subLabelDelivering,
  });
}

// ── Painter grille map ────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9FFF88).withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
