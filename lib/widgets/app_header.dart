import 'package:flutter/material.dart';
import 'package:suta/models.dart';

class AppHeader extends StatelessWidget {
  final List<Person> people;
  final int selectedPersonIndex;

  final bool notificationsEnabled;
  final VoidCallback onToggleNotifications;
  final VoidCallback onOpenProfile;

  final VoidCallback? onNextPerson;
  final VoidCallback? onPrevPerson;
  final VoidCallback? onTapPerson;

  const AppHeader({
    super.key,
    required this.people,
    required this.selectedPersonIndex,
    required this.notificationsEnabled,
    required this.onToggleNotifications,
    required this.onOpenProfile,
    this.onNextPerson,
    this.onPrevPerson,
    this.onTapPerson,
  });

  @override
  Widget build(BuildContext context) {
    final canSwitch =
        people.length > 1 && onNextPerson != null && onPrevPerson != null;

    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: canSwitch
                          ? (details) {
                              final v = details.primaryVelocity ?? 0;
                              if (v > 0) onPrevPerson!.call();
                              if (v < 0) onNextPerson!.call();
                            }
                          : null,
                      onTap: onTapPerson,
                      child: _PersonSwitcherPill(
                        people: people,
                        selectedIndex: selectedPersonIndex,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: notificationsEnabled
                      ? "Notifications on"
                      : "Notifications off",
                  onPressed: onToggleNotifications,
                  icon: Icon(
                    notificationsEnabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: onOpenProfile,
                  borderRadius: BorderRadius.circular(999),
                  child: const CircleAvatar(
                    radius: 18,
                    child: Icon(Icons.person),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE6E8EF),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonSwitcherPill extends StatelessWidget {
  final List<Person> people;
  final int selectedIndex;

  const _PersonSwitcherPill({
    required this.people,
    required this.selectedIndex,
  });

  double _measureTextWidth(BuildContext context, String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return tp.size.width;
  }

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();

    const double pillHeight = 40;
    const double pillPadV = 6;
    const double pillPadH = 10;

    const double chipPadH = 10;
    const double gap = 8;

    const double greyAvatar = 34;
    const double avatarOnlySlotW = 40;
    const double overlap = 18;

    const double selectedAvatar = greyAvatar;

    const nameStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    );

    final selectedPerson = people[selectedIndex];
    final nameW = _measureTextWidth(context, selectedPerson.name, nameStyle) + 8;

    final selectedChipWidth = (chipPadH * 2) + selectedAvatar + gap + nameW;

    final totalWidth = selectedChipWidth +
        (people.length - 1) * avatarOnlySlotW -
        (people.length - 1) * overlap;

    final indices = List<int>.generate(people.length, (i) => i);
    indices.sort((a, b) {
      if (a == selectedIndex) return 1;
      if (b == selectedIndex) return -1;
      return a.compareTo(b);
    });

    final List<Widget> stackChildren = [];
    double left = 0;

    for (final i in indices) {
      final bool isSelected = i == selectedIndex;
      final double w = isSelected ? selectedChipWidth : avatarOnlySlotW;

      stackChildren.add(
        Positioned(
          left: left,
          top: 0,
          bottom: 0,
          child: SizedBox(
            width: w,
            child: isSelected
                ? _SelectedPersonChip(
                    person: people[i],
                    avatarSize: selectedAvatar,
                    paddingH: chipPadH,
                    gap: gap,
                    nameStyle: nameStyle,
                  )
                : _AvatarOnlyGrey(person: people[i], avatarSize: greyAvatar),
          ),
        ),
      );

      left = left + (w - overlap);
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: pillPadH, vertical: pillPadV),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 6),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: SizedBox(
        width: totalWidth,
        height: pillHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: stackChildren,
        ),
      ),
    );
  }
}

class _AvatarOnlyGrey extends StatelessWidget {
  final Person person;
  final double avatarSize;

  const _AvatarOnlyGrey({
    required this.person,
    required this.avatarSize,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.35,
      child: Align(
        alignment: Alignment.centerLeft,
        child: _MiniAvatar(person: person, size: avatarSize),
      ),
    );
  }
}

class _SelectedPersonChip extends StatelessWidget {
  final Person person;
  final double avatarSize;
  final double paddingH;
  final double gap;
  final TextStyle nameStyle;

  const _SelectedPersonChip({
    required this.person,
    required this.avatarSize,
    required this.paddingH,
    required this.gap,
    required this.nameStyle,
  });

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE6E8EF);

    return Container(
      // ✅ remove vertical padding: this was what made centering feel off
      padding: EdgeInsets.symmetric(horizontal: paddingH),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: SizedBox(
        // ✅ lock the chip content height to avatar size so everything centers perfectly
        height: avatarSize,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _MiniAvatar(person: person, size: avatarSize),
            SizedBox(width: gap),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  person.name,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: nameStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final Person person;
  final double size;

  const _MiniAvatar({required this.person, required this.size});

  @override
  Widget build(BuildContext context) {
    final bg = _colorFor(person.id);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(person.name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size <= 30 ? 12 : 13,
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return "?";
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
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