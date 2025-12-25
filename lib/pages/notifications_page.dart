import 'package:flutter/material.dart';
import '../models.dart';

class NotificationsPage extends StatefulWidget {
  final List<AppNotification> notifications;

  /// optional demo button
  final VoidCallback? onAddDemoNotification;

  final void Function(String id) onDelete;
  final void Function(String id, bool unread) onSetUnread;

  const NotificationsPage({
    super.key,
    required this.notifications,
    required this.onDelete,
    required this.onSetUnread,
    this.onAddDemoNotification,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // ✅ inline expanded row id (details tied to row)
  String? _expandedId;

  // ✅ anchor link for the "Delete all" confirmation under the Delete button
  final LayerLink _deleteAllLink = LayerLink();
  OverlayEntry? _deleteAllConfirmEntry;

  String _fmtDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}";
  }

  // -------------------------------------------------------
  // ✅ Tight buttons like before + remove ripple/overlay
  // -------------------------------------------------------
  ButtonStyle _noOverlay(ButtonStyle base) {
    return base.copyWith(
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
    );
  }

  // ✅ bigger pills (more comfortable) while staying compact
  static const TextStyle _btnTextStyle = TextStyle(fontSize: 13, height: 1.15);

  ButtonStyle get _tightFilled => _noOverlay(
        FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.center,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          textStyle: _btnTextStyle,
        ),
      );

  ButtonStyle get _tightText => _noOverlay(
        TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.center,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          textStyle: _btnTextStyle,
        ),
      );

  ButtonStyle get _tightTonal => _noOverlay(
        FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.center,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          textStyle: _btnTextStyle,
        ),
      );

  // ✅ Add demo same, a touch wider horizontally
  ButtonStyle get _tightTonalForAddDemo => _noOverlay(
        FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.center,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          textStyle: _btnTextStyle,
        ),
      );

  // -------------------------------------------------------
  // ✅ Smaller buttons INSIDE each notification (expanded area)
  // -------------------------------------------------------
  static const TextStyle _rowBtnTextStyle =
      TextStyle(fontSize: 13, height: 1.0);

  ButtonStyle get _rowTightFilled => _noOverlay(
        FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.center,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
          textStyle: _rowBtnTextStyle,
        ),
      );

  ButtonStyle get _rowTightText => _noOverlay(
        TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.center,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
          textStyle: _rowBtnTextStyle,
        ),
      );

  // -------------------------------------------------------
  // ✅ Rounded confirmation popover under Delete button (anchored)
  // -------------------------------------------------------
  static const double _confirmRadius = 18;

  ButtonStyle get _confirmNoStyle => _noOverlay(
        TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          textStyle: const TextStyle(fontSize: 13, height: 1.0),
        ),
      );

  ButtonStyle get _confirmYesStyle => _noOverlay(
        FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          textStyle: const TextStyle(fontSize: 13, height: 1.0),
        ),
      );

  void _hideDeleteAllConfirm() {
    _deleteAllConfirmEntry?.remove();
    _deleteAllConfirmEntry = null;
  }

  void _showDeleteAllConfirm() {
    if (widget.notifications.isEmpty) return;

    // toggle behavior
    if (_deleteAllConfirmEntry != null) {
      _hideDeleteAllConfirm();
      return;
    }

    final overlay = Overlay.of(context);

    _deleteAllConfirmEntry = OverlayEntry(
      builder: (ctx) {
        return Positioned.fill(
          child: Stack(
            children: [
              // tap-outside to close
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideDeleteAllConfirm,
                child: const SizedBox.expand(),
              ),

              // ✅ anchored to Delete button:
              // targetAnchor = bottomRight of Delete
              // followerAnchor = topRight of dialog
              // => dialog right edge aligns with Delete right edge
              CompositedTransformFollower(
                link: _deleteAllLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 6), // small gap under the button
                child: Material(
                  color: Colors.transparent,
                  child: Material(
                    color: Colors.white,
                    elevation: 10,
                    shadowColor: Colors.black.withOpacity(0.18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_confirmRadius),
                      side: const BorderSide(color: Color(0x11000000)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IntrinsicWidth(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Confirm deletion?",
                              style: TextStyle(fontSize: 13, height: 1.2),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  style: _confirmNoStyle,
                                  onPressed: _hideDeleteAllConfirm,
                                  child: const Text("No"),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: _confirmYesStyle,
                                  onPressed: () {
                                    _hideDeleteAllConfirm();
                                    _deleteAll();
                                  },
                                  child: const Text("Yes"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(_deleteAllConfirmEntry!);
  }

  void _deleteAll() {
    final ids = widget.notifications.map((n) => n.id).toList(growable: false);
    for (final id in ids) {
      widget.onDelete(id);
    }
    setState(() => _expandedId = null);
  }

  void _markAllUnread(bool unread) {
    final ids = widget.notifications.map((n) => n.id).toList(growable: false);
    for (final id in ids) {
      widget.onSetUnread(id, unread);
    }
  }

  void _toggleExpanded(String id) {
    setState(() {
      _expandedId = (_expandedId == id) ? null : id;
    });
  }

  @override
  void dispose() {
    _hideDeleteAllConfirm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.notifications]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final unread = all.where((n) => n.unread).toList(growable: false);
    final read = all.where((n) => !n.unread).toList(growable: false);
    final ordered = [...unread, ...read];

    const headerHeight = 52.0;

    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            height: headerHeight,
            child: SizedBox(
              height: headerHeight,
              child: Container(
                color: const Color(0xFFF6F7FB),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Row(
                  children: [
                    if (widget.onAddDemoNotification != null)
                      FilledButton.tonal(
                        style: _tightTonalForAddDemo,
                        onPressed: widget.onAddDemoNotification,
                        child: const Text("Add demo"),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    FilledButton.tonal(
                      style: _tightTonal,
                      onPressed: widget.notifications.isEmpty
                          ? null
                          : () => _markAllUnread(false),
                      child: const Text("Mark read"),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      style: _tightTonal,
                      onPressed: widget.notifications.isEmpty
                          ? null
                          : () => _markAllUnread(true),
                      child: const Text("Mark unread"),
                    ),
                    const SizedBox(width: 8),

                    // ✅ anchor target for the confirmation dialog
                    CompositedTransformTarget(
                      link: _deleteAllLink,
                      child: FilledButton.tonal(
                        style: _tightTonal,
                        onPressed:
                            widget.notifications.isEmpty ? null : _showDeleteAllConfirm,
                        child: const Text("Delete"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            height: 8,
            child: SizedBox(
              height: 8,
              child: Container(
                color: const Color(0xFFF6F7FB),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.topCenter,
                child: const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE6E8EF),
                ),
              ),
            ),
          ),
        ),
        if (ordered.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                "No notifications to display yet.",
                style: TextStyle(color: Color(0xFF9CA3AF)),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final n = ordered[i];
                final expanded = _expandedId == n.id;

                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _NotificationTile(
                    notification: n,
                    dateText: _fmtDateTime(n.occurredAt),
                    eventText: notificationEventLabel(n.event),
                    actionText: notificationActionLabel(n.action),
                    expanded: expanded,
                    onTap: () => _toggleExpanded(n.id),
                    onDelete: () {
                      widget.onDelete(n.id);
                      if (_expandedId == n.id) {
                        setState(() => _expandedId = null);
                      }
                    },
                    onToggleRead: () {
                      widget.onSetUnread(n.id, !n.unread);
                    },
                    tightTextStyle: _rowTightText,
                    tightFilledStyle: _rowTightFilled,
                    fmtDateTime: _fmtDateTime,
                  ),
                );
              },
              childCount: ordered.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;

  final String dateText;
  final String eventText;
  final String actionText;

  final bool expanded;
  final VoidCallback onTap;

  final VoidCallback onDelete;
  final VoidCallback onToggleRead;

  final ButtonStyle tightTextStyle;
  final ButtonStyle tightFilledStyle;
  final String Function(DateTime) fmtDateTime;

  const _NotificationTile({
    required this.notification,
    required this.dateText,
    required this.eventText,
    required this.actionText,
    required this.expanded,
    required this.onTap,
    required this.onDelete,
    required this.onToggleRead,
    required this.tightTextStyle,
    required this.tightFilledStyle,
    required this.fmtDateTime,
  });

  Color _personColor(String key) {
    final hash = key.codeUnits.fold<int>(0, (a, b) => a + b);
    final colors = <Color>[
      const Color(0xFF2E6BE6),
      const Color(0xFF16A34A),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEF4444),
      const Color(0xFF06B6D4),
    ];
    return colors[hash % colors.length];
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "?";
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final personColor = _personColor(notification.personId);

    final bg = notification.unread
        ? personColor.withOpacity(0.18)
        : const Color(0xFFE5E7EB);

    final border = notification.unread
        ? personColor.withOpacity(0.35)
        : const Color(0xFFD1D5DB);

    Text cell(
      String text, {
      TextAlign align = TextAlign.left,
      FontWeight weight = FontWeight.normal,
    }) {
      return Text(
        text,
        softWrap: true,
        maxLines: null,
        overflow: TextOverflow.visible,
        textAlign: align,
        style: TextStyle(fontSize: 13, fontWeight: weight, height: 1.2),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border, width: 1),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 18,
                  offset: Offset(0, 8),
                  color: Color(0x11000000),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 18,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: personColor,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _initials(notification.personName),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: cell(
                                notification.personName,
                                weight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 20,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: cell(notification.pinName),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 18,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: cell(eventText),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 18,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: cell(actionText),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 26,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: cell(dateText, align: TextAlign.right),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 160),
                  firstCurve: Curves.easeOut,
                  secondCurve: Curves.easeOut,
                  crossFadeState: expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x22000000)),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoLine(label: "Item", value: notification.pinName),
                          _InfoLine(label: "Event", value: eventText),
                          _InfoLine(label: "Action", value: actionText),
                          _InfoLine(
                            label: "Date/Time",
                            value: fmtDateTime(notification.occurredAt),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FilledButton(
                                style: tightFilledStyle,
                                onPressed: onToggleRead,
                                child: Text(
                                  notification.unread
                                      ? "Mark read"
                                      : "Mark unread",
                                ),
                              ),
                              const SizedBox(width: 10),
                              TextButton(
                                style: tightTextStyle,
                                onPressed: onDelete,
                                child: const Text("Delete"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _StickyHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}