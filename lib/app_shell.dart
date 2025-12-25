import 'package:flutter/material.dart';
import 'app_globals.dart';
import 'models.dart';
import 'widgets/app_footer.dart';
import 'widgets/app_header.dart';

import 'pages/home_page.dart';
import 'pages/status_page.dart';
import 'pages/notifications_page.dart';
import 'pages/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  int tabIndex = 0;
  bool notificationsEnabled = true;

  // Temporary local data
  final List<Person> people = [
    Person(
      id: "p1",
      name: "Fatou",
      pins: [
        PinItem(id: "pin1", name: "iPad", synced: true, inRange: true), // green
        PinItem(id: "pin2", name: "Keys", synced: true, inRange: false), // red
      ],
    ),
    Person(
      id: "p2",
      name: "Awa",
      pins: [
        PinItem(id: "pin3", name: "Lunchbox", synced: false, inRange: true), // orange
      ],
    ),
  ];

  // ✅ Notifications state
  final List<AppNotification> _notifications = [];
  int get _unreadCount => _notifications.where((n) => n.unread).length;

  int selectedPersonIndex = 0;
  Person get currentPerson => people[selectedPersonIndex];

  late final PageController _peopleController;

  // ✅ Virtual paging so direction never flips on wrap
  late int _basePage;

  // ✅ Panel animation
  bool _panelVisible = false;
  late final AnimationController _panelCtrl;

  @override
  void initState() {
    super.initState();

    for (final p in people) {
      p.name = _capitalizeFirst(p.name);
    }

    final len = people.isEmpty ? 1 : people.length;
    _basePage = len * 1000;
    final initialVirtual = _basePage + selectedPersonIndex;

    _peopleController = PageController(initialPage: initialVirtual);

    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _peopleController.dispose();
    _panelCtrl.dispose();
    super.dispose();
  }

  // =======================================================
  // NOTIFICATIONS (demo + helpers)
  // =======================================================

  void _emitNotification({
    required Person person,
    required PinItem pin,
    required NotificationEventName event,
    required NotificationActionName action,
  }) {
    final n = AppNotification(
      id: "n${DateTime.now().microsecondsSinceEpoch}",
      personId: person.id,
      personName: person.name,
      pinId: pin.id,
      pinName: pin.name,
      occurredAt: DateTime.now(),
      event: event,
      action: action,
      unread: true,
    );

    setState(() {
      _notifications.insert(0, n);
    });

    // ✅ no BuildContext warning (uses global key)
    if (notificationsEnabled) {
      final msg = "${person.name} • ${pin.name} • ${notificationEventLabel(event)}";
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  void _deleteNotification(String id) {
    setState(() => _notifications.removeWhere((n) => n.id == id));
  }

  void _setNotificationUnread(String id, bool unread) {
    setState(() {
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx >= 0) _notifications[idx].unread = unread;
    });
  }

  // ✅ Add demo notification (so you can test quickly)
  void _addDemoNotification() {
    if (people.isEmpty) return;

    final p = people[selectedPersonIndex];
    final PinItem pin = p.pins.isNotEmpty
        ? p.pins.first
        : PinItem(id: "temp", name: "Item", synced: true, inRange: true);

    final i = _notifications.length % 3;

    late final NotificationEventName event;
    late final NotificationActionName action;

    if (i == 0) {
      event = NotificationEventName.leftBehind;
      action = NotificationActionName.manuStop;
    } else if (i == 1) {
      event = NotificationEventName.desync;
      action = NotificationActionName.autoStop;
    } else {
      event = NotificationEventName.notFound;
      action = NotificationActionName.none;
    }

    _emitNotification(person: p, pin: pin, event: event, action: action);
  }

  // =======================================================
  // PERSON PAGEVIEW HELPERS
  // =======================================================

  int _currentVirtualPage() {
    if (!_peopleController.hasClients) return _peopleController.initialPage;
    final p = _peopleController.page;
    if (p == null) return _peopleController.initialPage;
    return p.round();
  }

  // ✅ Always animate FORWARD only (left -> right)
  void _goToPerson(int targetRealIndex) {
    if (people.isEmpty) return;
    if (targetRealIndex < 0 || targetRealIndex >= people.length) return;
    if (!_peopleController.hasClients) {
      setState(() => selectedPersonIndex = targetRealIndex);
      return;
    }

    final len = people.length;
    final currentReal = selectedPersonIndex;

    final forwardSteps = (targetRealIndex - currentReal + len) % len;
    if (forwardSteps == 0) return;

    final currentV = _currentVirtualPage();
    final destV = currentV + forwardSteps;

    _peopleController.animateToPage(
      destV,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _nextPerson() {
    if (people.isEmpty) return;
    if (!_peopleController.hasClients) return;

    final v = _currentVirtualPage();
    _peopleController.animateToPage(
      v + 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _prevPerson() {
    if (people.isEmpty) return;
    if (!_peopleController.hasClients) return;

    final v = _currentVirtualPage();
    _peopleController.animateToPage(
      v - 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  // ✅ Opening panel always redirects to Home (tab 0) but keeps sheet open
  void _openPeoplePanel() {
    if (_panelVisible) return;

    if (tabIndex != 0) {
      setState(() => tabIndex = 0);
    }

    setState(() => _panelVisible = true);
    _panelCtrl.forward(from: 0);
  }

  Future<void> _closePeoplePanel() async {
    if (!_panelVisible) return;
    await _panelCtrl.reverse();
    if (mounted) setState(() => _panelVisible = false);
  }

  void _addPerson(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final normalized = _capitalizeFirst(trimmed);

    setState(() {
      final newId = "p${people.length + 1}";
      people.add(Person(id: newId, name: normalized, pins: []));
    });

    final len = people.length;
    _basePage = len * 1000;

    _goToPerson(people.length - 1);
  }

  Future<void> _setTab(int i) async {
    if (_panelVisible) {
      await _closePeoplePanel();
    }
    if (!mounted) return;
    setState(() => tabIndex = i);
  }

  // =======================================================
  // STATUS PAGE "REFRESH" DEMO -> emits notifications
  // =======================================================

  void _onRefreshPinFromStatus(String pinId) {
    Person? foundPerson;
    PinItem? foundPin;

    for (final p in people) {
      for (final pin in p.pins) {
        if (pin.id == pinId) {
          foundPerson = p;
          foundPin = pin;
          break;
        }
      }
      if (foundPin != null) break;
    }

    // ✅ make non-null locals so no nullable access errors
    final person = foundPerson;
    final pin = foundPin;
    if (person == null || pin == null) return;

    // Demo refresh
    setState(() {
      pin.lastStatusOn = DateTime.now();
      pin.inRange = !pin.inRange;
    });

    // Emit events (demo)
    if (!pin.synced) {
      _emitNotification(
        person: person,
        pin: pin,
        event: NotificationEventName.desync,
        action: NotificationActionName.none,
      );
    } else if (!pin.inRange) {
      _emitNotification(
        person: person,
        pin: pin,
        event: NotificationEventName.leftBehind,
        action: NotificationActionName.autoStop,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      PageView.builder(
        controller: _peopleController,
        itemCount: people.isEmpty ? 0 : 2000000,
        onPageChanged: (virtualIndex) {
          if (people.isEmpty) return;
          final real = virtualIndex % people.length;
          setState(() => selectedPersonIndex = real);
        },
        itemBuilder: (context, virtualIndex) {
          if (people.isEmpty) return const SizedBox.shrink();

          final person = people[virtualIndex % people.length];

          return HomePage(
            person: person,
            onRenamePin: (pinId, newName) {
              setState(() {
                final pin = person.pins.firstWhere((p) => p.id == pinId);
                pin.name = newName;
              });
            },
            onToggleMute: (pinId) {
              setState(() {
                final pin = person.pins.firstWhere((p) => p.id == pinId);
                pin.muted = !pin.muted;
              });
            },
            onSync: (pinId) {
              setState(() {
                final pin = person.pins.firstWhere((p) => p.id == pinId);
                pin.synced = true;
              });
            },
            onDeletePin: (pinId) {
              final pin = person.pins.firstWhere((p) => p.id == pinId);

              setState(() {
                person.pins.removeWhere((p) => p.id == pinId);
              });

              _emitNotification(
                person: person,
                pin: pin,
                event: NotificationEventName.notFound,
                action: NotificationActionName.none,
              );
            },
          );
        },
      ),
      StatusPage(
        people: people,
        onRefreshPin: _onRefreshPinFromStatus,
      ),

      // ✅ Updated notifications page with demo button + actions
      NotificationsPage(
        notifications: _notifications,
        onAddDemoNotification: _addDemoNotification,
        onDelete: _deleteNotification,
        onSetUnread: _setNotificationUnread,
      ),

      const SettingsPage(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              AppHeader(
                people: people,
                selectedPersonIndex: selectedPersonIndex,
                notificationsEnabled: notificationsEnabled,
                onToggleNotifications: () =>
                    setState(() => notificationsEnabled = !notificationsEnabled),
                onOpenProfile: () => _setTab(3),

                // ✅ Only Home supports switching
                onNextPerson: tabIndex == 0 ? _nextPerson : null,
                onPrevPerson: tabIndex == 0 ? _prevPerson : null,
                onTapPerson: _openPeoplePanel,
              ),
              Expanded(
                child: IndexedStack(
                  index: tabIndex,
                  children: pages,
                ),
              ),
            ],
          ),
          if (_panelVisible)
            _PeopleSidePanel(
              controller: _panelCtrl,
              people: people,
              selectedPersonIndex: selectedPersonIndex,
              onSelectPerson: (i) async {
                setState(() => tabIndex = 0);
                _goToPerson(i);
                await _closePeoplePanel();
              },
              onAddPerson: (name) async {
                _addPerson(name);
                await _closePeoplePanel();
              },
              onLogout: () async {
                await _closePeoplePanel();
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text("Log out (next step)")),
                );
              },
              onClose: _closePeoplePanel,
            ),
        ],
      ),
      bottomNavigationBar: AppFooter(
        index: tabIndex,
        onTap: (i) => _setTab(i),
        unreadNotifications: _unreadCount,
      ),
    );
  }
}

/// Swipe right->left on panel to close
class _SwipeToClose extends StatelessWidget {
  final double width;
  final Future<void> Function() onClose;
  final Widget child;

  const _SwipeToClose({
    required this.width,
    required this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    double drag = 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) {
        drag += (-d.delta.dx);
      },
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        final shouldClose = drag > width * 0.20 || v < -700;
        if (shouldClose) onClose();
      },
      child: child,
    );
  }
}

class _PeopleSidePanel extends StatefulWidget {
  final AnimationController controller;

  final List<Person> people;
  final int selectedPersonIndex;

  final Future<void> Function(int index) onSelectPerson;
  final Future<void> Function(String name) onAddPerson;
  final Future<void> Function() onLogout;
  final Future<void> Function() onClose;

  const _PeopleSidePanel({
    required this.controller,
    required this.people,
    required this.selectedPersonIndex,
    required this.onSelectPerson,
    required this.onAddPerson,
    required this.onLogout,
    required this.onClose,
  });

  @override
  State<_PeopleSidePanel> createState() => _PeopleSidePanelState();
}

class _PeopleSidePanelState extends State<_PeopleSidePanel> {
  bool _showAddPopup = false;
  final TextEditingController _nameCtrl = TextEditingController();

  final GlobalKey _addTitleKey = GlobalKey();
  final GlobalKey _popupKey = GlobalKey();

  double? _popupTop;
  double? _popupLeft;

  static const double _gapBelowAnchor = 10;
  static const double _gapAboveAnchor = 10;
  static const double _panelPaddingTop = 8;
  static const double _panelPaddingBottom = 12;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _openAddPopup() {
    setState(() {
      _nameCtrl.clear();
      _showAddPopup = true;
      _popupTop = null;
      _popupLeft = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final titleCtx = _addTitleKey.currentContext;
      final panelBox = context.findRenderObject() as RenderBox?;
      if (titleCtx == null || panelBox == null) return;

      final titleBox = titleCtx.findRenderObject() as RenderBox?;
      if (titleBox == null || !titleBox.hasSize) return;

      final titleGlobal = titleBox.localToGlobal(Offset.zero);
      final panelGlobal = panelBox.localToGlobal(Offset.zero);

      final anchorLeft = (titleGlobal.dx - panelGlobal.dx);
      final anchorTop = (titleGlobal.dy - panelGlobal.dy);
      final anchorHeight = titleBox.size.height;

      setState(() {
        _popupLeft = anchorLeft;
        _popupTop = anchorTop + anchorHeight + _gapBelowAnchor;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_showAddPopup) return;

        final pBox = context.findRenderObject() as RenderBox?;
        final popupCtx = _popupKey.currentContext;
        if (pBox == null || popupCtx == null) return;

        final popupBox = popupCtx.findRenderObject() as RenderBox?;
        if (popupBox == null || !popupBox.hasSize) return;

        final panelHeight = pBox.size.height;
        final popupHeight = popupBox.size.height;

        final belowTop = anchorTop + anchorHeight + _gapBelowAnchor;
        final belowBottom = belowTop + popupHeight;

        final aboveTop = anchorTop - _gapAboveAnchor - popupHeight;

        double chosenTop =
            belowBottom <= (panelHeight - _panelPaddingBottom) ? belowTop : aboveTop;

        final maxTop = panelHeight - _panelPaddingBottom - popupHeight;
        chosenTop = (maxTop >= _panelPaddingTop)
            ? chosenTop.clamp(_panelPaddingTop, maxTop)
            : _panelPaddingTop;

        setState(() => _popupTop = chosenTop);
      });
    });
  }

  void _closeAddPopup() {
    setState(() {
      _showAddPopup = false;
      _popupTop = null;
      _popupLeft = null;
    });
  }

  Future<void> _submitAdd() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final normalized = _capitalizeFirst(name);
    await widget.onAddPerson(normalized);

    _closeAddPopup();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final panelWidth = size.width * 0.66;

    final slide = CurvedAnimation(parent: widget.controller, curve: Curves.easeOut);
    final fade = CurvedAnimation(parent: widget.controller, curve: Curves.easeOut);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final dx = (-panelWidth) + (panelWidth * slide.value);

        return Stack(
          children: [
            Positioned.fill(
              left: panelWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: Container(
                  color: Colors.black.withOpacity(0.12 * fade.value),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: _SwipeToClose(
                  width: panelWidth,
                  onClose: widget.onClose,
                  child: Container(
                    width: panelWidth,
                    height: size.height,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 24,
                          offset: Offset(10, 0),
                          color: Color(0x14000000),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  "SUTA",
                                  style: TextStyle(fontSize: 22),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                                  children: [
                                    for (int i = 0; i < widget.people.length; i++) ...[
                                      _PersonRow(
                                        person: widget.people[i],
                                        selected: i == widget.selectedPersonIndex,
                                        onTap: () => widget.onSelectPerson(i),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                                      leading: const Icon(Icons.person_add_alt_1_outlined),
                                      title: Text("Add person", key: _addTitleKey),
                                      onTap: _openAddPopup,
                                    ),
                                    const SizedBox(height: 4),
                                    const Divider(height: 1, thickness: 1, color: Color(0xFFE6E8EF)),
                                    const SizedBox(height: 4),
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                                      leading: const Icon(Icons.logout),
                                      title: const Text("Log out"),
                                      onTap: widget.onLogout,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_showAddPopup) ...[
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: _closeAddPopup,
                                child: Container(color: Colors.black.withOpacity(0.15)),
                              ),
                            ),
                            if (_popupTop != null && _popupLeft != null)
                              Positioned(
                                left: _popupLeft!,
                                right: 14,
                                top: _popupTop!,
                                child: Material(
                                  key: _popupKey,
                                  color: Colors.white,
                                  elevation: 12,
                                  borderRadius: BorderRadius.circular(18),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextField(
                                          controller: _nameCtrl,
                                          autofocus: true,
                                          textInputAction: TextInputAction.done,
                                          onSubmitted: (_) => _submitAdd(),
                                          decoration: const InputDecoration(hintText: "Person name"),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: _closeAddPopup,
                                              child: const Text("Cancel"),
                                            ),
                                            const SizedBox(width: 8),
                                            FilledButton(
                                              onPressed: _submitAdd,
                                              child: const Text("Add"),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PersonRow extends StatelessWidget {
  final Person person;
  final bool selected;
  final VoidCallback onTap;

  const _PersonRow({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFDCEBFF) : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // ✅ ensure center
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: _colorFor(person.id),
                child: Text(
                  _initials(person.name),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 30, // ✅ same as avatar diameter (15 * 2)
                  child: Align(
                    alignment: Alignment.centerLeft, // ✅ vertical center + left align
                    child: Text(
                      _capitalizeFirst(person.name),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helpers
String _capitalizeFirst(String s) {
  final trimmed = s.trim();
  if (trimmed.isEmpty) return trimmed;

  return trimmed
      .split(RegExp(r'\s+'))
      .map((word) {
        final w = word.toLowerCase();
        return w[0].toUpperCase() + w.substring(1);
      })
      .join(' ');
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return "?";
  final first = parts.first;
  final last = parts.length > 1 ? parts.last : "";
  final a = first.isNotEmpty ? first[0].toUpperCase() : "?";
  final b = last.isNotEmpty ? last[0].toUpperCase() : "";
  return (a + b).isEmpty ? "?" : (a + b);
}

Color _colorFor(String key) {
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