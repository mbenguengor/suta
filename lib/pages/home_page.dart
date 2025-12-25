import 'package:flutter/material.dart';
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
  String? _editingPinId;
  final Map<String, TextEditingController> _controllers = {};

  // Keeps the title layout stable and lets the field grow until this limit.
  static const double _minEditWidth = 56;
  static const double _maxEditWidth = 210;

  static const TextStyle _titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(PinItem pin) {
    return _controllers.putIfAbsent(
      pin.id,
      () => TextEditingController(text: pin.name),
    );
  }

  void _startEditing(PinItem pin) {
    final c = _controllerFor(pin);
    c.text = pin.name;
    setState(() => _editingPinId = pin.id);
  }

  void _cancelEditing(PinItem pin) {
    final c = _controllerFor(pin);
    c.text = pin.name;
    setState(() => _editingPinId = null);
  }

  void _saveEditing(PinItem pin) {
    final c = _controllerFor(pin);
    final newName = c.text.trim();
    if (newName.isEmpty) return;
    widget.onRenamePin(pin.id, newName);
    setState(() => _editingPinId = null);
  }

  double _measureTextWidth(BuildContext context, String text) {
    final tp = TextPainter(
      text: TextSpan(text: text.isEmpty ? " " : text, style: _titleStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();

    // Add a tiny padding so caret doesn't feel cramped.
    return tp.width + 18;
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _Block(
          title: "Main",
          child: const Text(
            "Main device summary goes here (connection, battery, last alert).",
          ),
        ),
        const SizedBox(height: 12),

        ...person.pins.map((pin) {
          final isEditing = _editingPinId == pin.id;
          final controller = _controllerFor(pin);

          // Width grows as user types, then clamps.
          final desired = _measureTextWidth(context, controller.text);
          final editWidth = desired.clamp(_minEditWidth, _maxEditWidth);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Block(
              titleWidget: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!isEditing) ...[
                    Flexible(
                      child: Text(
                        pin.name,
                        style: _titleStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2), // ✅ really close
                    GestureDetector(
                      onTap: () => _startEditing(pin),
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
                        onSubmitted: (_) => _saveEditing(pin),
                        onChanged: (_) => setState(() {}), // update width live
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: "Item name",
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: _titleStyle,
                      ),
                    ),
                    const SizedBox(width: 2), // ✅ super close to the field
                    GestureDetector(
                      onTap: () => _saveEditing(pin),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 2), // ✅ super close
                    GestureDetector(
                      onTap: () => _cancelEditing(pin),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ],
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Action(
                    label: pin.muted ? "Unmute" : "Mute",
                    icon: pin.muted
                        ? Icons.volume_up_outlined
                        : Icons.volume_off_outlined,
                    onTap: () => widget.onToggleMute(pin.id),
                  ),
                  _Action(
                    label: "Sync",
                    icon: Icons.sync_outlined,
                    onTap: () => widget.onSync(pin.id),
                  ),
                  _Action(
                    label: "Delete",
                    icon: Icons.delete_outline,
                    onTap: () => widget.onDeletePin(pin.id),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget child;

  const _Block({
    this.title,
    this.titleWidget,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final header = titleWidget ??
        Text(
          title ?? "",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
          header,
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        // ✅ tighter padding so actions in the left drawer are closer together
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}