import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:suta/models.dart';

class HomePage extends StatefulWidget {
  final Person person;

  final void Function(String pinId) onToggleMute;
  final void Function(String pinId) onSync;
  final void Function(String pinId) onDeletePin;
  final void Function(String pinId, String newName) onRenamePin;

  const HomePage({
    super.key,
    required this.person,
    required this.onToggleMute,
    required this.onSync,
    required this.onDeletePin,
    required this.onRenamePin,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ✅ shared now (stored in Person)
  List<MainGroup> get _mains => widget.person.mains;
  Map<String, List<PinItem>> get _itemsByMain => widget.person.itemsByMain;

  String? _editingMainId;
  final Map<String, TextEditingController> _mainControllers = {};

  bool _reorganizeMode = false;

  // ✅ Demo pins per MAIN (still local; safe)
  final Map<String, List<PinItem>> _demoPinsByMain = {};

  // -------------------------------------------------------
  // ✅ Scroll control
  // -------------------------------------------------------
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _pageStackKey = GlobalKey();

  // ✅ extra bottom padding so user can scroll past last main
  double _extraBottomPadding = 0;

  // -------------------------------------------------------
  // ✅ Item popover (LOCAL + CLIPPED to page)
  // -------------------------------------------------------
  final Map<String, LayerLink> _itemLinksById = {};
  final Map<String, GlobalKey> _itemKeysById = {};

  String? _openItemId;
  PinItem? _openPin;

  bool _itemEditMode = false;
  bool _itemDirty = false;

  TextEditingController? _itemTitleCtrl;
  TextEditingController? _itemRangeCtrl;

  final GlobalKey _popoverKey = GlobalKey();

  // -------------------------------------------------------
  // ✅ Delete confirmation popover
  // -------------------------------------------------------
  final Map<String, LayerLink> _deleteLinksByMain = {};
  OverlayEntry? _deleteConfirmEntry;
  String? _deleteConfirmMainId;

  static const double _confirmRadius = 18;

  // -------------------------------------------------------
  // ✅ Layout constants
  // -------------------------------------------------------
  static const double _minEditWidth = 56;
  static const double _maxEditWidth = 210;

  static const TextStyle _titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle _itemTextStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.0,
  );

  static const TextStyle _dialogItemTitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  static const Color _sepColor = Color(0xFFE6E8EF);
  Widget _sepLine() => Container(height: 1, color: _sepColor);

  static const Color _reorgHighlight = Color(0xFFEFF3FF);

  static const List<({String label, IconData icon})> _mainPresets = [
    (label: "School", icon: Icons.school_outlined),
    (label: "Tools", icon: Icons.handyman_outlined),
    (label: "Work", icon: Icons.work_outline),
    (label: "Home", icon: Icons.home_outlined),
    (label: "Car", icon: Icons.directions_car_outlined),
    (label: "Travel", icon: Icons.flight_takeoff_outlined),
  ];

  // -------------------------------------------------------
  // ✅ Styles helper
  // -------------------------------------------------------
  ButtonStyle _noOverlay(ButtonStyle base) {
    return base.copyWith(
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
    );
  }

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

  LayerLink _deleteLinkFor(String mainId) {
    return _deleteLinksByMain.putIfAbsent(mainId, () => LayerLink());
  }

  LayerLink _itemLinkFor(String itemId) {
    return _itemLinksById.putIfAbsent(itemId, () => LayerLink());
  }

  GlobalKey _itemKeyFor(String itemId) {
    return _itemKeysById.putIfAbsent(itemId, () => GlobalKey());
  }

  @override
  void dispose() {
    _hideDeleteConfirm();
    _hideItemPopover(force: true);

    for (final c in _mainControllers.values) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------
  // ✅ Demo pins generator (per main)
  // -------------------------------------------------------
  List<PinItem> _demoPinsForMain(String mainId) {
    return _demoPinsByMain.putIfAbsent(mainId, () {
      return [
        PinItem(
          id: "${mainId}_demo_ipad",
          name: "iPad",
          synced: true,
          inRange: true,
          rangeFeet: 10,
          distanceFeet: 4.0,
        ),
        PinItem(
          id: "${mainId}_demo_keys",
          name: "Keys",
          synced: true,
          inRange: true,
          rangeFeet: 10,
          distanceFeet: 8.0,
        ),
        PinItem(
          id: "${mainId}_demo_lunchbox",
          name: "Lunchbox",
          synced: false,
          inRange: false,
          rangeFeet: 10,
          distanceFeet: 18.0,
        ),
      ];
    });
  }

  // -------------------------------------------------------
  // ✅ Main actions (now mutate shared Person data)
  // -------------------------------------------------------
  void _addMainFromPreset(String name, IconData icon) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _mains.add(MainGroup(id: id, name: name, icon: icon));
      _itemsByMain[id] = [];
    });
  }

  void _onReorderMain(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final m = _mains.removeAt(oldIndex);
      _mains.insert(newIndex, m);
    });
  }

  void _syncMain(MainGroup m) {
    setState(() => m.synced = true);
    widget.onSync(m.id);
  }

  void _toggleMainMute(MainGroup m) {
    setState(() => m.muted = !m.muted);
    widget.onToggleMute(m.id);
  }

  void _toggleRing(MainGroup m) {
    setState(() => m.ringEnabled = !m.ringEnabled);
  }

  void _toggleLight(MainGroup m) {
    setState(() => m.lightEnabled = !m.lightEnabled);
  }

  void _deleteMain(MainGroup m) {
    setState(() {
      _itemsByMain.remove(m.id);
      _mainControllers.remove(m.id)?.dispose();
      _deleteLinksByMain.remove(m.id);
      _demoPinsByMain.remove(m.id);
      if (_editingMainId == m.id) _editingMainId = null;
      _mains.removeWhere((x) => x.id == m.id);
    });
    widget.onDeletePin(m.id);
  }

  // -------------------------------------------------------
  // ✅ Delete confirm popover
  // -------------------------------------------------------
  void _hideDeleteConfirm() {
    _deleteConfirmEntry?.remove();
    _deleteConfirmEntry = null;
    _deleteConfirmMainId = null;
  }

  void _showDeleteConfirm(MainGroup m) {
    if (_deleteConfirmEntry != null && _deleteConfirmMainId == m.id) {
      _hideDeleteConfirm();
      return;
    }

    _hideDeleteConfirm();
    _deleteConfirmMainId = m.id;

    final overlay = Overlay.of(context);
    final link = _deleteLinkFor(m.id);

    _deleteConfirmEntry = OverlayEntry(
      builder: (ctx) {
        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideDeleteConfirm,
                child: const SizedBox.expand(),
              ),
              CompositedTransformFollower(
                link: link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 6),
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
                                  onPressed: _hideDeleteConfirm,
                                  child: const Text("No"),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: _confirmYesStyle,
                                  onPressed: () {
                                    _hideDeleteConfirm();
                                    _deleteMain(m);
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

    overlay.insert(_deleteConfirmEntry!);
  }

  // -------------------------------------------------------
  // ✅ Main title editing
  // -------------------------------------------------------
  TextEditingController _mainControllerFor(MainGroup m) {
    return _mainControllers.putIfAbsent(
      m.id,
      () => TextEditingController(text: m.name),
    );
  }

  void _startEditingMain(MainGroup m) {
    final c = _mainControllerFor(m);
    c.text = m.name;
    setState(() => _editingMainId = m.id);
  }

  void _cancelEditingMain(MainGroup m) {
    final c = _mainControllerFor(m);
    c.text = m.name;
    setState(() => _editingMainId = null);
  }

  void _saveEditingMain(MainGroup m) {
    final c = _mainControllerFor(m);
    final newName = c.text.trim();
    if (newName.isEmpty) return;

    setState(() {
      m.name = newName;
      _editingMainId = null;
    });

    widget.onRenamePin(m.id, newName);
  }

  double _measureTextWidth(BuildContext context, String text) {
    final tp = TextPainter(
      text: TextSpan(text: text.isEmpty ? " " : text, style: _titleStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return tp.width + 18;
  }

  // -------------------------------------------------------
  // ✅ Range / inRange evaluation
  // -------------------------------------------------------
  void _recomputeInRange(PinItem pin) {
    final range = pin.effectiveRangeFeet.toDouble();
    final dist = pin.effectiveDistanceFeet;

    final nextInRange = dist <= range;

    if (nextInRange != pin.inRange) {
      setState(() {
        pin.inRange = nextInRange;
        pin.lastStatusOn = DateTime.now();
      });
    }
  }

  Color _syncColorFor(PinItem pin) {
    final ok = pin.synced && pin.inRange;
    return ok ? const Color(0xFF16A34A) : const Color(0xFFF59E0B);
  }

  String _fmtDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}";
  }

  // -------------------------------------------------------
  // ✅ Item popover logic
  // -------------------------------------------------------
  void _hideItemPopover({required bool force}) {
    if (!force && _itemDirty) return;

    setState(() {
      _openItemId = null;
      _openPin = null;
      _itemEditMode = false;
      _itemDirty = false;
      _extraBottomPadding = 0;
    });

    _itemTitleCtrl?.dispose();
    _itemTitleCtrl = null;

    _itemRangeCtrl?.dispose();
    _itemRangeCtrl = null;
  }

  void _openItemPopover({required PinItem pin}) {
    if (_openItemId == pin.id) {
      _hideItemPopover(force: false);
      return;
    }

    _hideItemPopover(force: true);

    setState(() {
      _openItemId = pin.id;
      _openPin = pin;
      _itemEditMode = false;
      _itemDirty = false;
    });

    _itemTitleCtrl = TextEditingController(text: pin.name);
    _itemRangeCtrl = TextEditingController(
      text: (pin.rangeFeet == null) ? "" : pin.rangeFeet.toString(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExtraPaddingFromPopover();
      _ensurePopoverFullyVisible(pin.id);
    });
  }

  void _updateExtraPaddingFromPopover() {
    if (!mounted) return;
    if (_openItemId == null) return;

    final popCtx = _popoverKey.currentContext;
    final popBox = popCtx?.findRenderObject() as RenderBox?;
    if (popBox == null) return;

    final h = popBox.size.height;
    final next = (h + 24).clamp(0, 600).toDouble();

    if ((next - _extraBottomPadding).abs() > 1) {
      setState(() => _extraBottomPadding = next);
    }
  }

  void _ensurePopoverFullyVisible(String itemId) {
    if (!mounted) return;
    if (_openItemId != itemId) return;

    final stackCtx = _pageStackKey.currentContext;
    final itemCtx = _itemKeyFor(itemId).currentContext;
    final popCtx = _popoverKey.currentContext;

    if (stackCtx == null || itemCtx == null || popCtx == null) return;

    final stackBox = stackCtx.findRenderObject() as RenderBox?;
    final itemBox = itemCtx.findRenderObject() as RenderBox?;
    final popBox = popCtx.findRenderObject() as RenderBox?;
    if (stackBox == null || itemBox == null || popBox == null) return;

    final stackTopLeft = stackBox.localToGlobal(Offset.zero);
    final stackBottom = stackTopLeft.dy + stackBox.size.height;

    final itemTopLeft = itemBox.localToGlobal(Offset.zero);
    final itemBottom = itemTopLeft.dy + itemBox.size.height;

    final popHeight = popBox.size.height;

    const double followerOffset = 6;
    final popBottom = itemBottom + followerOffset + popHeight;

    final overflow = popBottom - stackBottom;

    if (overflow > 0) {
      final target = (_scrollCtrl.offset + overflow + 12).clamp(
        _scrollCtrl.position.minScrollExtent,
        _scrollCtrl.position.maxScrollExtent,
      );

      _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateExtraPaddingFromPopover();
      });
    }
  }

  Widget _buildLocalPopover(PinItem pin) {
    final syncColor = _syncColorFor(pin);
    final syncText = (pin.synced && pin.inRange) ? "Synced" : "Not synced";

    return KeyedSubtree(
      key: _popoverKey,
      child: Material(
        color: Colors.transparent,
        child: Material(
          color: Colors.white,
          elevation: 10,
          shadowColor: Colors.black.withOpacity(0.18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0x11000000)),
          ),
          clipBehavior: Clip.antiAlias,
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              void markDirty() {
                if (!_itemDirty) setLocal(() => _itemDirty = true);
              }

              void toggleEdit() {
                setLocal(() => _itemEditMode = !_itemEditMode);
              }

              void cancel() {
                _itemTitleCtrl?.text = pin.name;
                _itemRangeCtrl?.text =
                    (pin.rangeFeet == null) ? "" : pin.rangeFeet.toString();
                setLocal(() {
                  _itemEditMode = false;
                  _itemDirty = false;
                });
                _hideItemPopover(force: true);
              }

              void save() {
                final newTitle = (_itemTitleCtrl?.text ?? "").trim();
                final rawRange = (_itemRangeCtrl?.text ?? "").trim();

                if (newTitle.isNotEmpty && newTitle != pin.name) {
                  pin.name = newTitle;
                  widget.onRenamePin(pin.id, newTitle);
                }

                if (rawRange.isEmpty) {
                  pin.rangeFeet = null;
                } else {
                  final parsed = int.tryParse(rawRange);
                  if (parsed != null) pin.rangeFeet = parsed;
                }

                _recomputeInRange(pin);

                setLocal(() {
                  _itemEditMode = false;
                  _itemDirty = false;
                });

                setState(() {});
                _hideItemPopover(force: true);
              }

              Widget row({required String label, required Widget value}) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          "$label:",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                      Flexible(child: value),
                    ],
                  ),
                );
              }

              final titleField = TextField(
                controller: _itemTitleCtrl,
                enabled: _itemEditMode,
                onChanged: (_) => markDirty(),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE6E8EF)),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: _dialogItemTitleStyle,
              );

              final rangeField = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _itemRangeCtrl,
                      enabled: _itemEditMode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => markDirty(),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFE6E8EF)),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 13, height: 1.2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text("Feet",
                      style: TextStyle(fontSize: 13, height: 1.2)),
                ],
              );

              return IntrinsicWidth(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            style: _confirmNoStyle,
                            onPressed: toggleEdit,
                            child: Text(_itemEditMode ? "Done" : "Edit Item"),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _itemEditMode
                            ? titleField
                            : Text(pin.name, style: _dialogItemTitleStyle),
                      ),
                      row(
                        label: "Sync Status",
                        value: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync, size: 18, color: syncColor),
                            const SizedBox(width: 6),
                            Text(syncText,
                                style: const TextStyle(
                                    fontSize: 13, height: 1.2)),
                          ],
                        ),
                      ),
                      row(
                        label: "Status date",
                        value: Text(
                          _fmtDateTime(pin.lastStatusOn),
                          style: const TextStyle(fontSize: 13, height: 1.2),
                        ),
                      ),
                      row(label: "Range", value: rangeField),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Spacer(),
                          TextButton(
                            style: _confirmNoStyle,
                            onPressed: cancel,
                            child: const Text("Cancel"),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: _confirmYesStyle,
                            onPressed: save,
                            child: const Text("Save"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  int _totalItemsCount() {
    int total = 0;
    for (final entry in _itemsByMain.entries) {
      total += entry.value.length;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _mains.isEmpty;
    const double menuAlignToLabelDx = 34;
    final hasAnyItems = _totalItemsCount() > 0;

    final list = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_deleteConfirmEntry != null) _hideDeleteConfirm();
        if (_openItemId != null) _hideItemPopover(force: false);
        if (_reorganizeMode) setState(() => _reorganizeMode = false);
      },
      child: ListView(
        controller: _scrollCtrl,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + _extraBottomPadding),
        children: [
          Row(
            children: [
              const Spacer(),
              Theme(
                data: Theme.of(context).copyWith(
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  focusColor: Colors.transparent,
                ),
                child: PopupMenuButton<int>(
                  tooltip: "",
                  offset: const Offset(menuAlignToLabelDx, 30),
                  color: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE6E8EF)),
                  ),
                  onSelected: (i) {
                    final p = _mainPresets[i];
                    _addMainFromPreset(p.label, p.icon);
                  },
                  itemBuilder: (_) => List.generate(_mainPresets.length, (i) {
                    final p = _mainPresets[i];
                    return PopupMenuItem<int>(
                      value: i,
                      height: 28,
                      child: Row(
                        children: [
                          Icon(p.icon, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            p.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  child: const _TopButton(
                    label: "Add Main",
                    icon: Icons.add_circle_outline,
                    disableInkEffects: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TopButton(
                label: "Order",
                icon: Icons.reorder_outlined,
                active: _reorganizeMode,
                onTap: () {
                  _hideDeleteConfirm();
                  _hideItemPopover(force: true);
                  setState(() => _reorganizeMode = !_reorganizeMode);
                },
                disableInkEffects: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _sepLine(),
          const SizedBox(height: 12),
          if (isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: Center(
                child: Text(
                  "No Main yet. Tap “Add Main” to create one.",
                  style: TextStyle(color: Colors.black45),
                ),
              ),
            )
          else if (!_reorganizeMode) ...[
            ..._mains.map((m) {
              final isEditing = _editingMainId == m.id;
              final controller = _mainControllerFor(m);

              final desired = _measureTextWidth(context, controller.text);
              final editWidth = desired.clamp(_minEditWidth, _maxEditWidth);

              final isTravel = m.name.trim().toLowerCase() == "travel";

              // ✅ Real linked items (shared)
              final realLinkedItems = _itemsByMain[m.id] ?? const [];

              // ✅ Display logic (unchanged)
              final List<PinItem> items = hasAnyItems
                  ? realLinkedItems
                  : (isTravel ? <PinItem>[] : _demoPinsForMain(m.id));

              for (final pin in items) {
                _recomputeInRange(pin);
              }

              final actionsEnabled = isTravel ? realLinkedItems.isNotEmpty : true;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Block(
                  titleWidget: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(m.icon, size: 18, color: Colors.black87),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isEditing) ...[
                              Flexible(
                                child: Text(
                                  m.name,
                                  style: _titleStyle,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
                              GestureDetector(
                                onTap: () => _startEditingMain(m),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: Colors.black54,
                                ),
                              ),
                            ] else ...[
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                curve: Curves.easeOut,
                                width: editWidth.toDouble(),
                                child: TextField(
                                  controller: controller,
                                  autofocus: true,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _saveEditingMain(m),
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: "Main name",
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  style: _titleStyle,
                                ),
                              ),
                              const SizedBox(width: 2),
                              GestureDetector(
                                onTap: () => _saveEditingMain(m),
                                child: const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 2),
                              GestureDetector(
                                onTap: () => _cancelEditingMain(m),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SmallAction(
                                label: "Sync",
                                icon: Icons.sync_outlined,
                                onTap: () => _syncMain(m),
                              ),
                              const SizedBox(width: 6),
                              _SmallAction(
                                label: "Mute",
                                icon: m.muted
                                    ? Icons.volume_off_outlined
                                    : Icons.volume_up_outlined,
                                enabled: actionsEnabled,
                                onTap: () => _toggleMainMute(m),
                              ),
                              const SizedBox(width: 6),
                              _SmallAction(
                                label: "Ring",
                                icon: m.ringEnabled
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_off_outlined,
                                enabled: actionsEnabled,
                                onTap: () => _toggleRing(m),
                              ),
                              const SizedBox(width: 6),
                              _SmallAction(
                                label: "Light",
                                enabled: actionsEnabled,
                                iconWidget: m.lightEnabled
                                    ? const Icon(Icons.lightbulb_outline, size: 16)
                                    : const _SlashedIcon(
                                        icon: Icons.lightbulb_outline,
                                        size: 16,
                                      ),
                                onTap: () => _toggleLight(m),
                              ),
                              const SizedBox(width: 6),
                              if (actionsEnabled)
                                CompositedTransformTarget(
                                  link: _deleteLinkFor(m.id),
                                  child: _SmallAction(
                                    label: "Delete",
                                    icon: Icons.delete_outline,
                                    onTap: () => _showDeleteConfirm(m),
                                  ),
                                )
                              else
                                _SmallAction(
                                  label: "Delete",
                                  icon: Icons.delete_outline,
                                  enabled: false,
                                  onTap: () {},
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  contentTopGap: 16,
                  child: items.isEmpty
                      ? const Text(
                          "No items synced.",
                          style: TextStyle(color: Colors.black45),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: items.map((pin) {
                            final syncColor = _syncColorFor(pin);

                            return KeyedSubtree(
                              key: _itemKeyFor(pin.id),
                              child: CompositedTransformTarget(
                                link: _itemLinkFor(pin.id),
                                child: GestureDetector(
                                  onTap: () => _openItemPopover(pin: pin),
                                  child: _ItemPill(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          pin.name,
                                          style: _itemTextStyle,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.sync, size: 16, color: syncColor),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              );
            }),
          ] else ...[
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: _onReorderMain,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  child: child,
                );
              },
              itemCount: _mains.length,
              itemBuilder: (context, index) {
                final m = _mains[index];
                return ReorderableDragStartListener(
                  key: ValueKey(m.id),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _Block(
                      backgroundColor: _reorgHighlight,
                      titleWidget: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(m.icon, size: 18, color: Colors.black87),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              m.name,
                              style: _titleStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      child: const Text(
                        "Drag to reorder",
                        style: TextStyle(color: Colors.black45),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );

    return ClipRect(
      child: Stack(
        key: _pageStackKey,
        children: [
          list,
          if (_openItemId != null && _openPin != null)
            Positioned.fill(
              child: Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _hideItemPopover(force: false),
                    child: const SizedBox.expand(),
                  ),
                  CompositedTransformFollower(
                    link: _itemLinkFor(_openItemId!),
                    showWhenUnlinked: false,
                    targetAnchor: Alignment.bottomLeft,
                    followerAnchor: Alignment.topLeft,
                    offset: const Offset(0, 6),
                    child: _buildLocalPopover(_openPin!),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final bool disableInkEffects;

  const _TopButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.active = false,
    this.disableInkEffects = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEFF3FF) : const Color(0xFFF2F4FA),
        borderRadius: BorderRadius.circular(12),
        border: active ? Border.all(color: const Color(0xFFBFD0FF)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );

    if (onTap == null) return child;

    if (disableInkEffects) {
      return GestureDetector(onTap: onTap, child: child);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: child,
    );
  }
}

class _SmallAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback onTap;
  final bool enabled;

  const _SmallAction({
    required this.label,
    this.icon,
    this.iconWidget,
    required this.onTap,
    this.enabled = true,
  }) : assert(icon != null || iconWidget != null);

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onTapEffective = enabled ? onTap : null;
    final fg = enabled ? Colors.black87 : Colors.black26;

    return InkWell(
      onTap: onTapEffective,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconTheme(
            data: IconThemeData(color: fg),
            child: DefaultTextStyle(
              style: TextStyle(fontSize: 12, color: fg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconWidget != null) iconWidget! else Icon(icon!, size: 16),
                  const SizedBox(width: 4),
                  Text(label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlashedIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _SlashedIcon({
    required this.icon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: size),
          Transform.rotate(
            angle: -0.75,
            child: Container(
              width: size + 4,
              height: 2,
              decoration: BoxDecoration(
                color: IconTheme.of(context).color ?? Colors.black87,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final Widget titleWidget;
  final Widget child;
  final Color? backgroundColor;
  final double contentTopGap;

  const _Block({
    required this.titleWidget,
    required this.child,
    this.backgroundColor,
    this.contentTopGap = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 8),
            color: Color(0x11000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          SizedBox(height: contentTopGap),
          child,
        ],
      ),
    );
  }
}

class _ItemPill extends StatelessWidget {
  final Widget child;

  const _ItemPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EF)),
      ),
      child: child,
    );
  }
}