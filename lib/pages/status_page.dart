import 'package:flutter/material.dart';
import 'package:suta/models.dart';

enum SortBy { person, status }
enum ItemStatus { inRange, outOfRange, notSynced }

enum _TableOrderBy { person, item, status, statusAt }

class StatusPage extends StatefulWidget {
  final List<Person> people;

  /// Optional: if you later want AppShell to refresh a pin status.
  /// For now this will just update lastStatusOn + toggle inRange for demo.
  final void Function(String pinId)? onRefreshPin;

  const StatusPage({
    super.key,
    required this.people,
    this.onRefreshPin,
  });

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  SortBy _sortBy = SortBy.person;

  final GlobalKey _sortArrowKey = GlobalKey();
  static const double _sortValueWidth = 52;

  final ScrollController _scrollCtrl = ScrollController();

  // ✅ table sorting (when Sort by: Status)
  _TableOrderBy _tableOrderBy = _TableOrderBy.status;
  bool _tableAsc = true; // toggles each time user clicks the same column

  // ✅ prevent stacking multiple popovers
  bool _popoverOpen = false;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ---------------- Status helpers ----------------

  ItemStatus _statusFor(PinItem pin) {
    // Requires your PinItem to have:
    // bool inRange;
    // DateTime lastStatusOn;
    if (!pin.synced) return ItemStatus.notSynced;
    if (pin.inRange) return ItemStatus.inRange;
    return ItemStatus.outOfRange;
  }

  Color _dotColor(ItemStatus s) {
    switch (s) {
      case ItemStatus.inRange:
        return Colors.green;
      case ItemStatus.outOfRange:
        return Colors.red;
      case ItemStatus.notSynced:
        return Colors.orange;
    }
  }

  // ✅ red first, then orange, then green
  int _statusRankRedFirst(ItemStatus s) {
    switch (s) {
      case ItemStatus.outOfRange:
        return 0;
      case ItemStatus.notSynced:
        return 1;
      case ItemStatus.inRange:
        return 2;
    }
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}";
  }

  // ---------------- Anchored item popover (under tapped item) ----------------

  Future<void> _showItemPopover({
    required GlobalKey anchorKey,
    required PinItem pin,
    required ItemStatus status,
  }) async {
    if (_popoverOpen) return;
    _popoverOpen = true;

    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: "dismiss",
        barrierColor: Colors.black.withOpacity(0.08),
        transitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (ctx, a1, a2) {
          void close() => Navigator.of(ctx).pop();

          return GestureDetector(
            onTap: close,
            child: Material(
              type: MaterialType.transparency,
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final mq = MediaQuery.of(ctx);
                  final screenW = mq.size.width;
                  final screenH = mq.size.height;
                  final safePad = mq.padding;
                  final viewInsets = mq.viewInsets;

                  final double effectiveH = screenH - viewInsets.bottom;
                  const double margin = 12;
                  const double gap = 8;

                  final overlayBox =
                      Overlay.of(ctx).context.findRenderObject() as RenderBox;

                  final anchorCtx = anchorKey.currentContext;
                  if (anchorCtx == null) return const SizedBox.shrink();

                  final anchorBox = anchorCtx.findRenderObject() as RenderBox;
                  final anchorTopLeft =
                      anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
                  final anchorBottomLeft = anchorBox.localToGlobal(
                    Offset(0, anchorBox.size.height),
                    ancestor: overlayBox,
                  );

                  // ✅ constrain, but allow shrink-to-fit inside (IntrinsicWidth)
                  final double maxPopoverW =
                      (240.0).clamp(160.0, screenW - (margin * 2)).toDouble();

                  double left = anchorBottomLeft.dx;
                  if (left + maxPopoverW > screenW - margin) {
                    left = (screenW - maxPopoverW - margin).clamp(margin, screenW);
                  }
                  if (left < margin) left = margin;

                  final double topBelow = anchorBottomLeft.dy + gap;
                  final double availableBelow = (effectiveH - margin) - topBelow;
                  final double availableAbove = (anchorTopLeft.dy - margin) - gap;

                  final bool placeAbove =
                      availableBelow < 140 && availableAbove > availableBelow;

                  final double maxHeight =
                      (placeAbove ? availableAbove : availableBelow)
                          .clamp(120.0, effectiveH - (margin * 2))
                          .toDouble();

                  double top = placeAbove
                      ? (anchorTopLeft.dy - gap - maxHeight)
                      : topBelow;

                  top = top.clamp(margin + safePad.top, effectiveH - margin);

                  final statusColor = _dotColor(status);

                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: viewInsets.bottom),
                    child: Stack(
                      children: [
                        Positioned(
                          left: left,
                          top: top,
                          child: GestureDetector(
                            onTap: () {}, // prevent close when tapping inside
                            child: Material(
                              color: Colors.white,
                              elevation: 12,
                              borderRadius: BorderRadius.circular(14),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: maxPopoverW,
                                  maxHeight: maxHeight,
                                ),
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.zero,
                                  child: IntrinsicWidth(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pin.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          // ✅ Status row: keep dot close
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                "Status:",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: statusColor,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 8),

                                          // ✅ Status at row: keep value close to label
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                "Status at:",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _formatDateTime(pin.lastStatusOn),
                                                style: const TextStyle(fontSize: 13),
                                                softWrap: false,
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
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
        transitionBuilder: (ctx, anim, sec, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );
    } finally {
      _popoverOpen = false;
    }
  }

  // ---------------- Sorting ----------------

  List<_RowModel> _rowsAll() {
    final rows = <_RowModel>[];
    for (final p in widget.people) {
      for (final pin in p.pins) {
        rows.add(_RowModel(person: p, pin: pin, status: _statusFor(pin)));
      }
    }

    if (_sortBy == SortBy.person) {
      rows.sort((a, b) {
        final pn =
            a.person.name.toLowerCase().compareTo(b.person.name.toLowerCase());
        if (pn != 0) return pn;
        return a.pin.name.toLowerCase().compareTo(b.pin.name.toLowerCase());
      });
      return rows;
    }

    rows.sort((a, b) {
      int cmp;

      switch (_tableOrderBy) {
        case _TableOrderBy.person:
          cmp = a.person.name.toLowerCase().compareTo(b.person.name.toLowerCase());
          if (cmp != 0) break;
          cmp = a.pin.name.toLowerCase().compareTo(b.pin.name.toLowerCase());
          break;

        case _TableOrderBy.item:
          cmp = a.pin.name.toLowerCase().compareTo(b.pin.name.toLowerCase());
          if (cmp != 0) break;
          cmp = a.person.name.toLowerCase().compareTo(b.person.name.toLowerCase());
          break;

        case _TableOrderBy.status:
          cmp = _statusRankRedFirst(a.status).compareTo(_statusRankRedFirst(b.status));
          if (cmp != 0) break;
          cmp = a.person.name.toLowerCase().compareTo(b.person.name.toLowerCase());
          if (cmp != 0) break;
          cmp = a.pin.name.toLowerCase().compareTo(b.pin.name.toLowerCase());
          break;

        case _TableOrderBy.statusAt:
          cmp = b.pin.lastStatusOn.compareTo(a.pin.lastStatusOn); // most recent first
          if (cmp != 0) break;
          cmp = a.person.name.toLowerCase().compareTo(b.person.name.toLowerCase());
          if (cmp != 0) break;
          cmp = a.pin.name.toLowerCase().compareTo(b.pin.name.toLowerCase());
          break;
      }

      return _tableAsc ? cmp : -cmp;
    });

    return rows;
  }

  String _sortLabel(SortBy s) => s == SortBy.person ? "Person" : "Status";

  Future<void> _openSortMenu() async {
    final ctx = _sortArrowKey.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight =
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);

    final rect = RelativeRect.fromRect(
      Rect.fromPoints(Offset(topLeft.dx, bottomRight.dy), bottomRight),
      Offset.zero & overlay.size,
    );

    final res = await showMenu<SortBy>(
      context: context,
      position: rect,
      elevation: 8,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      constraints: const BoxConstraints(
        minWidth: 72,
        maxWidth: 72,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      items: const [
        PopupMenuItem(
          value: SortBy.person,
          height: 26, // ✅ tighter
          child: Center(
            child: Text(
              "Person",
              style: TextStyle(fontWeight: FontWeight.normal), // ✅ NOT bold
            ),
          ),
        ),
        PopupMenuItem(
          value: SortBy.status,
          height: 26, // ✅ tighter
          child: Center(
            child: Text(
              "Status",
              style: TextStyle(fontWeight: FontWeight.normal), // ✅ NOT bold
            ),
          ),
        ),
      ],
    );

    if (res == null) return;

    setState(() {
      _sortBy = res;

      if (_sortBy == SortBy.status) {
        _tableOrderBy = _TableOrderBy.status;
        _tableAsc = true;
      }
    });
  }

  void _toggleOrder(_TableOrderBy by) {
    setState(() {
      if (_tableOrderBy == by) {
        _tableAsc = !_tableAsc;
      } else {
        _tableOrderBy = by;
        _tableAsc = true;
      }
    });
  }

  void _refreshRow(PinItem pin) {
    if (widget.onRefreshPin != null) {
      widget.onRefreshPin!(pin.id);
      setState(() {});
      return;
    }

    setState(() {
      pin.lastStatusOn = DateTime.now();
      pin.inRange = !pin.inRange;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rowsAll();

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: Scrollbar(
        controller: _scrollCtrl,
        thumbVisibility: true,
        child: ListView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Row(
              children: [
                const Expanded(child: _LegendRow()),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Sort by:", style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: _sortValueWidth,
                      child: Center(child: Text(_sortLabel(_sortBy))),
                    ),
                    InkWell(
                      key: _sortArrowKey,
                      onTap: _openSortMenu,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.keyboard_arrow_down, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_sortBy == SortBy.person)
              _PersonBlocksView(
                people: widget.people,
                statusFor: _statusFor,
                dotColor: _dotColor,
                onTapPin: (pin, key) {
                  final st = _statusFor(pin);
                  _showItemPopover(anchorKey: key, pin: pin, status: st);
                },
              )
            else
              _TableCard(
                rows: rows,
                dotColor: _dotColor,
                formatDateTime: _formatDateTime,
                onHeaderTap: _toggleOrder,
                onRefresh: _refreshRow,
              ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// MODELS
// =======================================================

class _RowModel {
  final Person person;
  final PinItem pin;
  final ItemStatus status;
  _RowModel({required this.person, required this.pin, required this.status});
}

// =======================================================
// LEGEND
// =======================================================

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  Widget _dot(Color c) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          _dot(Colors.green),
          const SizedBox(width: 6),
          const Text("In-range", style: style),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _dot(Colors.red),
          const SizedBox(width: 6),
          const Text("Out-range", style: style),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _dot(Colors.orange),
          const SizedBox(width: 6),
          const Text("Not-synced", style: style),
        ]),
      ],
    );
  }
}

// =======================================================
// PERSON BLOCKS
// =======================================================

class _PersonBlocksView extends StatelessWidget {
  final List<Person> people;
  final ItemStatus Function(PinItem) statusFor;
  final Color Function(ItemStatus) dotColor;

  /// Returns (pin, anchorKey)
  final void Function(PinItem pin, GlobalKey key) onTapPin;

  const _PersonBlocksView({
    required this.people,
    required this.statusFor,
    required this.dotColor,
    required this.onTapPin,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...people]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in sorted) ...[
          _Block(
            title: p.name,
            titleBold: false,
            child: p.pins.isEmpty
                ? const Text("No items linked yet.", style: TextStyle(color: Color(0xFF9CA3AF)))
                : Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final pin in p.pins)
                        _ItemPillDotAfter(
                          name: pin.name,
                          dotColor: dotColor(statusFor(pin)),
                          onTap: (key) => onTapPin(pin, key),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ItemPillDotAfter extends StatefulWidget {
  final String name;
  final Color dotColor;

  /// gives you the internal anchorKey so you can open a popover right under this pill
  final void Function(GlobalKey anchorKey) onTap;

  const _ItemPillDotAfter({
    required this.name,
    required this.dotColor,
    required this.onTap,
  });

  @override
  State<_ItemPillDotAfter> createState() => _ItemPillDotAfterState();
}

class _ItemPillDotAfterState extends State<_ItemPillDotAfter> {
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: _anchorKey,
      onTap: () => widget.onTap(_anchorKey),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.name, overflow: TextOverflow.ellipsis),
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: widget.dotColor, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// TABLE (STATUS SORT) - with Refresh + toggle sorting
// =======================================================

class _TableCard extends StatelessWidget {
  final List<_RowModel> rows;
  final Color Function(ItemStatus) dotColor;
  final String Function(DateTime) formatDateTime;

  final void Function(_TableOrderBy by) onHeaderTap;
  final void Function(PinItem pin) onRefresh;

  const _TableCard({
    required this.rows,
    required this.dotColor,
    required this.formatDateTime,
    required this.onHeaderTap,
    required this.onRefresh,
  });

  static const _divider = Color(0xFFE6E8EF);

  Widget _headerCellButton(String text, _TableOrderBy by) {
    return InkWell(
      onTap: () => onHeaderTap(by),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _headerCellPlain(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _cell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Center(child: child),
    );
  }

  Widget _dot(ItemStatus s) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: dotColor(s), shape: BoxShape.circle),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _Block(
        title: "",
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text("No results.", style: TextStyle(color: Color(0xFF9CA3AF))),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Color(0x11000000)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.15), // Person
            1: FlexColumnWidth(1.15), // Item
            2: FlexColumnWidth(0.75), // Status
            3: FlexColumnWidth(1.55), // Status at
            4: FlexColumnWidth(0.75), // Refresh
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: const TableBorder(horizontalInside: BorderSide(color: _divider)),
          children: [
            TableRow(
              children: [
                _headerCellButton("Person", _TableOrderBy.person),
                _headerCellButton("Item", _TableOrderBy.item),
                _headerCellButton("Status", _TableOrderBy.status),
                _headerCellButton("Status at", _TableOrderBy.statusAt),
                _headerCellPlain("Refresh"),
              ],
            ),
            for (final r in rows)
              TableRow(
                children: [
                  _cell(Text(r.person.name, textAlign: TextAlign.center, softWrap: true)),
                  _cell(Text(r.pin.name, textAlign: TextAlign.center, softWrap: true)),
                  _cell(_dot(r.status)),
                  _cell(Text(formatDateTime(r.pin.lastStatusOn),
                      textAlign: TextAlign.center, softWrap: true)),
                  _cell(
                    InkWell(
                      onTap: () => onRefresh(r.pin),
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.refresh, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// BLOCK
// =======================================================

class _Block extends StatelessWidget {
  final String title;
  final bool titleBold;
  final Widget child;

  const _Block({
    required this.title,
    required this.child,
    this.titleBold = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Color(0x11000000)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.trim().isNotEmpty)
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: titleBold ? FontWeight.w800 : FontWeight.normal,
              ),
            ),
          if (title.trim().isNotEmpty) const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}