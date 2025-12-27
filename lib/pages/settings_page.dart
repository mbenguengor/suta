import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:suta/models.dart';

class SettingsPage extends StatefulWidget {
  final UserProfile profile;

  /// ✅ People list + SAVE callback (AppShell applies to header + left sheet)
  final List<Person> people;
  final void Function(List<Person> updatedPeople) onSavePeople;

  const SettingsPage({
    super.key,
    required this.profile,
    required this.people,
    required this.onSavePeople,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Store a "real" password for demo validation (DON'T do this in production like this)
  String _password = "123456";

  // ✅ Inline name editing (no dialog) + save/cancel icons
  bool _isEditingName = false;
  late final TextEditingController _nameController;
  final FocusNode _nameFocus = FocusNode();
  String _nameDraftBeforeEdit = "";
  bool _nameEmptyError = false;

  // ✅ Profile picture / avatar state (stored in widget.profile)
  final ImagePicker _picker = ImagePicker();

  // ✅ Keys to anchor popovers under the crayons / avatar
  final GlobalKey _avatarEditKey = GlobalKey();
  final GlobalKey _emailEditKey = GlobalKey();
  final GlobalKey _passwordEditKey = GlobalKey();

  // ✅ Keys (kept)
  final GlobalKey _helpArrowKey = GlobalKey();
  final GlobalKey _infoArrowKey = GlobalKey();
  final GlobalKey _inviteArrowKey = GlobalKey();

  // ✅ prevent multiple popovers at once (overlap)
  bool _popoverOpen = false;

  // ✅ INLINE panels state (part of page)
  bool _infoInlineOpen = false;
  bool _helpInlineOpen = false;

  // ---- layout tuning ----
  static const double _avatarRadius = 18; // small like footer
  static const double _nameStartIndent = (_avatarRadius * 2) + 12; // avatar diameter + gap
  static const double _tileDividerIndent = 40.0;
  static const Color _dividerColor = Color(0xFFE6E8EF);

  // ---- shared popover form style (email + password SAME) ----
  static const TextStyle _popoverTextStyle = TextStyle(fontSize: 14);
  static const double _fieldGap = 10;

  // ---- app info (edit if needed) ----
  static const String _appName = "SUTA";
  static const String _appVersion = "0.0.1";
  static const String _appReleaseDate = "2025-12-25";

  // ✅ Invite message (placeholder link for now)
  static const String _inviteMessage =
      "Check out SUTA app. It will allows you to never left something behind again https://example.com/download";

  // ✅ Avatars list (reused for profile + people)
  static const List<IconData> _availableAvatars = [
    Icons.face_retouching_natural_outlined,
    Icons.sentiment_satisfied_alt_outlined,
    Icons.sentiment_very_satisfied_outlined,
    Icons.sentiment_neutral_outlined,
    Icons.sentiment_dissatisfied_outlined,
    Icons.pets_outlined,
    Icons.star_outline,
    Icons.favorite_border,
    Icons.sports_soccer_outlined,
    Icons.flight_outlined,
    Icons.music_note_outlined,
    Icons.local_cafe_outlined,
  ];

  InputDecoration _popoverDeco(String hint, {Widget? suffix}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: _popoverTextStyle.copyWith(color: const Color(0xFF9CA3AF)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE6E8EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
      ),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minHeight: 36, minWidth: 36),
    );
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  // -------------------------
  // ✅ Shared: side sheet that starts exactly UNDER header divider
  // -------------------------
  Future<void> _openRightSheetFromHeaderStop({
    required String title,
    required Widget body,
    double widthFactor = 0.66,
  }) async {
    final mq = MediaQuery.of(context);

    const double headerHeight = 72.0;
    const double dividerThickness = 1.0;
    final double topOffset = mq.padding.top + headerHeight + dividerThickness;

    await showGeneralDialog(
      context: context,
      barrierLabel: "sheet",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.10),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, a1, a2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, sec, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);

        return Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            heightFactor: 1,
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.only(top: topOffset),
                child: Material(
                  color: Colors.white,
                  elevation: 16,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 14, 12, 10),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: "Back",
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE6E8EF)),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ).buildSlide(curved);
      },
    );
  }

  // -------------------------
  // ✅ NEW: Manage person sheet (3/4) with draft + Save/Cancel
  // -------------------------
  Future<void> _openManagePersonSheet() async {
    final mq = MediaQuery.of(context);

    const double headerHeight = 72.0;
    const double dividerThickness = 1.0;
    final double topOffset = mq.padding.top + headerHeight + dividerThickness;

    // draft starts from current people, but no changes applied until Save
    List<Person> draft = widget.people.map(_clonePersonDeep).toList(growable: true);

    // dirty flag controls outside-tap close + Save/Cancel enabled
    bool dirty = false;

    void setDirty(bool v) {
      // inside dialog only
      dirty = v;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: "manage-person",
      barrierDismissible: false, // ✅ we handle outside tap ourselves (only when not dirty)
      barrierColor: Colors.black.withOpacity(0.10),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, a1, a2) {
        void closeDiscard() => Navigator.of(ctx).pop(); // discard changes

        return StatefulBuilder(
          builder: (ctx, setStateDlg) {
            void markDirty() {
              if (!dirty) setStateDlg(() => dirty = true);
            }

            void cancel() {
              // discard
              closeDiscard();
            }

            void save() {
              // apply
              widget.onSavePeople(draft);
              Navigator.of(ctx).pop();
            }

            return Stack(
              children: [
                // ✅ click outside: close ONLY if no modifications yet
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (!dirty) closeDiscard();
                    },
                    child: const SizedBox.expand(),
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.75, // ✅ 3/4 sheet
                    heightFactor: 1,
                    child: Material(
                      color: Colors.transparent,
                      child: Padding(
                        padding: EdgeInsets.only(top: topOffset),
                        child: Material(
                          color: Colors.white,
                          elevation: 16,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 14, 12, 10),
                                child: Row(
                                  children: [
                                    IconButton(
                                      tooltip: "Back",
                                      // ✅ always discards changes (spec)
                                      onPressed: closeDiscard,
                                      icon: const Icon(Icons.arrow_back),
                                    ),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        "Manage person",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, thickness: 1, color: Color(0xFFE6E8EF)),

                              Expanded(
                                child: _ManagePeopleSheetBody(
                                  draftPeople: draft,
                                  availableAvatars: _availableAvatars,
                                  onChanged: () => markDirty(),
                                  onDraftChanged: (next) {
                                    setStateDlg(() {
                                      draft = next;
                                      setDirty(true);
                                      dirty = true;
                                    });
                                  },
                                ),
                              ),

                              // ✅ bottom-right buttons
                              Container(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: dirty ? cancel : null,
                                      child: const Text("Cancel"),
                                    ),
                                    const SizedBox(width: 10),
                                    FilledButton(
                                      onPressed: dirty ? save : null,
                                      child: const Text("Save"),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ).buildSlide(CurvedAnimation(parent: a1, curve: Curves.easeOut)),
              ],
            );
          },
        );
      },
    );
  }

  // -------------------------
  // Avatar picker UI + logic (writes to widget.profile)
  // -------------------------
  Future<void> _pickFromCamera() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      widget.profile.setAvatarFile(File(picked.path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open camera.")),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      widget.profile.setAvatarFile(File(picked.path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open gallery.")),
      );
    }
  }

  Future<void> _showAvatarPopover() async {
    await _showAnchoredPopover<void>(
      anchorKey: _avatarEditKey,
      builder: (close, popConstraints) {
        return AnimatedBuilder(
          animation: widget.profile,
          builder: (context, _) {
            final hasAvatar =
                widget.profile.avatarFile != null || widget.profile.avatarIcon != null;

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AvatarAction(
                    icon: Icons.photo_camera_outlined,
                    label: "Take a picture",
                    onTap: () async {
                      close();
                      await _pickFromCamera();
                    },
                  ),
                  const SizedBox(height: 6),
                  _AvatarAction(
                    icon: Icons.photo_library_outlined,
                    label: "Choose a picture",
                    onTap: () async {
                      close();
                      await _pickFromGallery();
                    },
                  ),
                  const SizedBox(height: 6),
                  _AvatarAction(
                    icon: Icons.person_outline,
                    label: "Choose an avatar",
                    onTap: () async {
                      close();
                      await Future.delayed(const Duration(milliseconds: 10));
                      if (!mounted) return;
                      await _showAvatarGridPopover();
                    },
                  ),
                  if (hasAvatar) ...[
                    const Divider(height: 18),
                    _AvatarAction(
                      icon: Icons.delete_outline,
                      label: "Remove profile picture",
                      danger: true,
                      onTap: () {
                        widget.profile.clearAvatar();
                        close();
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAvatarGridPopover() async {
    await _showAnchoredPopover<void>(
      anchorKey: _avatarEditKey,
      builder: (close, popConstraints) {
        final maxH = popConstraints.maxHeight;
        final gridMaxH = (maxH - 18).clamp(140.0, maxH);

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Choose an avatar",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: gridMaxH),
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: _availableAvatars.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemBuilder: (ctx, i) {
                    final icon = _availableAvatars[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        widget.profile.setAvatarIcon(icon);
                        close();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(child: Icon(icon, size: 26)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: close, child: const Text("Cancel")),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ Inline name edit logic (reads/writes widget.profile.fullName)
  void _startEditName() {
    setState(() {
      _nameDraftBeforeEdit = widget.profile.fullName;
      _nameController.text = widget.profile.fullName;
      _isEditingName = true;
      _nameEmptyError = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameFocus.requestFocus();
      _nameController.selection = TextSelection.fromPosition(
        TextPosition(offset: _nameController.text.length),
      );
    });
  }

  bool get _canSaveName => _nameController.text.trim().isNotEmpty;

  void _saveName() {
    final v = _nameController.text.trim();
    if (v.isEmpty) {
      setState(() => _nameEmptyError = true);
      return;
    }

    widget.profile.setFullName(_capitalizeFirst(v));

    setState(() {
      _isEditingName = false;
      _nameEmptyError = false;
    });

    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _cancelNameEdit() {
    setState(() {
      _nameController.text = _nameDraftBeforeEdit;
      _isEditingName = false;
      _nameEmptyError = false;
    });

    FocusManager.instance.primaryFocus?.unfocus();
  }

  double _measureTextWidth({
    required String text,
    required TextStyle style,
    required double maxWidth,
    double minWidth = 60,
    double extraPadding = 14,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? " " : text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final w = (painter.width + extraPadding).clamp(minWidth, maxWidth);
    return w.toDouble();
  }

  // ✅ Responsive anchored popover shown under a widget (avatar/email/password)
  Future<T?> _showAnchoredPopover<T>({
    required GlobalKey anchorKey,
    double? desiredWidth,
    bool alignRightToAnchor = false,
    required Widget Function(VoidCallback close, BoxConstraints popConstraints) builder,
  }) async {
    if (_popoverOpen) return null;
    _popoverOpen = true;

    try {
      return await showGeneralDialog<T>(
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
                  final viewInsets = mq.viewInsets;
                  final safePad = mq.padding;

                  final double effectiveH = screenH - viewInsets.bottom;

                  final overlayBox = Overlay.of(ctx).context.findRenderObject() as RenderBox;

                  final anchorCtx = anchorKey.currentContext;
                  if (anchorCtx == null) return const SizedBox.shrink();

                  final anchorBox = anchorCtx.findRenderObject() as RenderBox;

                  final anchorTopLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
                  final anchorBottomLeft = anchorBox.localToGlobal(
                    Offset(0, anchorBox.size.height),
                    ancestor: overlayBox,
                  );
                  final anchorBottomRight = anchorBox.localToGlobal(
                    Offset(anchorBox.size.width, anchorBox.size.height),
                    ancestor: overlayBox,
                  );

                  const double margin = 12;
                  const double gap = 8;

                  final double target = desiredWidth ?? 260.0;
                  final double popoverWidth =
                      (target).clamp(160.0, screenW - (margin * 2)).toDouble();

                  double left =
                      alignRightToAnchor ? (anchorBottomRight.dx - popoverWidth) : anchorBottomLeft.dx;

                  if (left + popoverWidth > screenW - margin) {
                    left = (screenW - popoverWidth - margin).clamp(margin, screenW);
                  }
                  if (left < margin) left = margin;

                  final double topBelow = anchorBottomLeft.dy + gap;
                  final double availableBelow = (effectiveH - margin) - topBelow;
                  final double availableAbove = (anchorTopLeft.dy - margin) - gap;

                  final bool placeAbove = availableBelow < 140 && availableAbove > availableBelow;

                  final double maxHeight = (placeAbove ? availableAbove : availableBelow)
                      .clamp(90.0, effectiveH - (margin * 2))
                      .toDouble();

                  final popConstraints = BoxConstraints(
                    maxWidth: popoverWidth,
                    maxHeight: maxHeight,
                  );

                  double top = placeAbove ? (anchorTopLeft.dy - gap - maxHeight) : topBelow;
                  top = top.clamp(margin + safePad.top, effectiveH - margin);

                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: viewInsets.bottom),
                    child: Stack(
                      children: [
                        Positioned(
                          left: left,
                          top: top,
                          width: popoverWidth,
                          child: GestureDetector(
                            onTap: () {},
                            child: Material(
                              color: Colors.white,
                              elevation: 12,
                              borderRadius: BorderRadius.circular(16),
                              child: ConstrainedBox(
                                constraints: popConstraints,
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.zero,
                                  child: builder(close, popConstraints),
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

  // -------- Email popover (writes to widget.profile.email) --------
  Future<void> _showChangeEmailDialog() async {
    await _showAnchoredPopover<void>(
      anchorKey: _emailEditKey,
      builder: (close, constraints) {
        return _EmailPopover(
          popoverTextStyle: _popoverTextStyle,
          fieldGap: _fieldGap,
          popoverDeco: _popoverDeco,
          onSave: (newEmail) => widget.profile.setEmail(newEmail),
          close: close,
        );
      },
    );
  }

  // -------- Password popover (local demo password) --------
  Future<void> _showChangePasswordDialog() async {
    await _showAnchoredPopover<void>(
      anchorKey: _passwordEditKey,
      builder: (close, constraints) {
        return _PasswordPopover(
          popoverTextStyle: _popoverTextStyle,
          fieldGap: _fieldGap,
          popoverDeco: _popoverDeco,
          currentPassword: _password,
          onSave: (newPass) => setState(() => _password = newPass),
          close: close,
        );
      },
    );
  }

  void _openPrivacyKidsSheet() {
    _openRightSheetFromHeaderStop(
      title: "Privacy notice for kids",
      body: const _PrivacyKidsScrollable(),
      widthFactor: 0.66,
    );
  }

  void _openPrivacyAdultsSheet() {
    _openRightSheetFromHeaderStop(
      title: "Privacy notice for adults",
      body: const _PrivacyAdultsScrollable(),
      widthFactor: 0.66,
    );
  }

  void _toggleHelpInline() => setState(() => _helpInlineOpen = !_helpInlineOpen);

  Widget _helpInlinePanel() {
    const base = TextStyle(fontSize: 16, height: 1.25, color: Color(0xFF111827));
    const email = TextStyle(fontSize: 16, height: 1.25, color: Color(0xFF2563EB));

    return Padding(
      padding: const EdgeInsets.fromLTRB(_tileDividerIndent, 8, 12, 10),
      child: RichText(
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        text: const TextSpan(
          style: base,
          children: [
            TextSpan(text: "You can request support or leave feedback by sending an email to: "),
            TextSpan(text: "support@suta.com", style: email),
          ],
        ),
      ),
    );
  }

  void _toggleInfoInline() => setState(() => _infoInlineOpen = !_infoInlineOpen);

  Widget _infoInlinePanel() {
    const String osValue = "Android";

    const titleStyle = TextStyle(fontSize: 13.5, height: 1.2, color: Color(0xFF6B7280));
    const infoStyle = TextStyle(fontSize: 13.5, height: 1.2, color: Color(0xFF111827));

    Widget row(String title, String info) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 92, child: Text(title, style: infoStyle)),
              Expanded(child: Text(info, style: titleStyle)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(_tileDividerIndent, 8, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row("App Name", _appName),
          row("Version", _appVersion),
          row("Release date", _appReleaseDate),
          row("OS", osValue),
        ],
      ),
    );
  }

  Future<void> _openInviteSheet() async {
    await _openRightSheetFromHeaderStop(
      title: "Select contact you want to send a invivation to:",
      widthFactor: 0.75,
      body: _InviteContactsSheet(messageBody: _inviteMessage),
    );
  }

  @override
  Widget build(BuildContext context) {
    const nameStyle = TextStyle(fontSize: 18);

    return AnimatedBuilder(
      animation: widget.profile,
      builder: (context, _) {
        Widget avatarChild() {
          if (widget.profile.avatarFile != null) return const SizedBox.shrink();
          if (widget.profile.avatarIcon != null) return Icon(widget.profile.avatarIcon, size: 18);
          return const Icon(Icons.person, size: 18);
        }

        ImageProvider? avatarBgImage() {
          if (widget.profile.avatarFile != null) return FileImage(widget.profile.avatarFile!);
          return null;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            _Card(
              child: Column(
                children: [
                  Row(
                    children: [
                      InkWell(
                        key: _avatarEditKey,
                        onTap: _showAvatarPopover,
                        borderRadius: BorderRadius.circular(999),
                        child: CircleAvatar(
                          radius: _avatarRadius,
                          backgroundImage: avatarBgImage(),
                          child: avatarChild(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            const double iconAreaEdit = (4 + 18 + 4) * 2 + 4;
                            const double iconAreaView = (4 + 16 + 4);
                            final double reserved = _isEditingName ? iconAreaEdit : iconAreaView;
                            final double maxFieldWidth =
                                (c.maxWidth - reserved).clamp(80.0, c.maxWidth);

                            return AnimatedBuilder(
                              animation: _nameController,
                              builder: (context, _) {
                                final String current =
                                    _isEditingName ? _nameController.text : _capitalizeFirst(widget.profile.fullName);

                                final double fieldWidth = _measureTextWidth(
                                  text: current,
                                  style: nameStyle,
                                  maxWidth: maxFieldWidth,
                                  minWidth: 70,
                                  extraPadding: 6,
                                );

                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: fieldWidth,
                                      child: _isEditingName
                                          ? TextField(
                                              controller: _nameController,
                                              focusNode: _nameFocus,
                                              autofocus: true,
                                              textCapitalization: TextCapitalization.words,
                                              style: nameStyle,
                                              maxLines: 1,
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              onChanged: (_) => setState(() {
                                                _nameEmptyError = !_canSaveName;
                                              }),
                                              onSubmitted: (_) => _saveName(),
                                            )
                                          : Text(
                                              current,
                                              style: nameStyle,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (!_isEditingName)
                                      InkWell(
                                        onTap: _startEditName,
                                        borderRadius: BorderRadius.circular(10),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.edit_outlined, size: 16),
                                        ),
                                      )
                                    else ...[
                                      InkWell(
                                        onTap: _canSaveName ? _saveName : null,
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.check,
                                            size: 18,
                                            color: _canSaveName ? null : const Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: _cancelNameEdit,
                                        borderRadius: BorderRadius.circular(10),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.close, size: 18),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_isEditingName && _nameEmptyError) ...[
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: (_avatarRadius * 2) + 12),
                        child: Text(
                          "Name cannot be blank.",
                          style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: _dividerColor),
                  const SizedBox(height: 8),
                  _KeyValueEditRowTight(
                    leftIndent: _nameStartIndent,
                    label: "Email",
                    value: widget.profile.email,
                    valueGrey: true,
                    onEdit: _showChangeEmailDialog,
                    editKey: _emailEditKey,
                  ),
                  const SizedBox(height: 6),
                  _KeyValueEditRowTight(
                    leftIndent: _nameStartIndent,
                    label: "Password",
                    value: "••••••••••",
                    valueGrey: true,
                    onEdit: _showChangePasswordDialog,
                    editKey: _passwordEditKey,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ✅ NEW compact block exactly like Invite a friend measurements
            _Card(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  _SimpleTile(
                    icon: Icons.manage_accounts_outlined,
                    title: "Manage person",
                    compact: true,
                    onTap: _openManagePersonSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _Card(
              child: Column(
                children: [
                  _SimpleTile(
                    icon: Icons.wallpaper_outlined,
                    title: "Background",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Background settings (next step)")),
                      );
                    },
                  ),
                  const Divider(height: 1, thickness: 1, color: _dividerColor, indent: _tileDividerIndent),
                  _SimpleTile(
                    icon: Icons.color_lens_outlined,
                    title: "Theme color",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Theme color (next step)")),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _Card(
              child: Column(
                children: [
                  _SimpleTile(
                    icon: Icons.shield_outlined,
                    title: "Privacy notice for kids",
                    onTap: _openPrivacyKidsSheet,
                  ),
                  const Divider(height: 1, thickness: 1, color: _dividerColor, indent: _tileDividerIndent),
                  _SimpleTile(
                    icon: Icons.shield_outlined,
                    title: "Privacy notice for adults",
                    onTap: _openPrivacyAdultsSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _Card(
              child: Column(
                children: [
                  _SimpleTile(
                    icon: Icons.help_outline,
                    title: "Help & feedback",
                    onTap: _toggleHelpInline,
                    arrowKey: _helpArrowKey,
                    trailingOverride: AnimatedRotation(
                      turns: _helpInlineOpen ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      child: const Icon(Icons.keyboard_arrow_right, size: 16),
                    ),
                  ),
                  if (_helpInlineOpen) ...[
                    const Divider(height: 1, thickness: 1, color: _dividerColor, indent: _tileDividerIndent),
                    _helpInlinePanel(),
                  ],
                  const Divider(height: 1, thickness: 1, color: _dividerColor, indent: _tileDividerIndent),
                  _SimpleTile(
                    icon: Icons.info_outline,
                    title: "Infos & licenses",
                    onTap: _toggleInfoInline,
                    arrowKey: _infoArrowKey,
                    trailingOverride: AnimatedRotation(
                      turns: _infoInlineOpen ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      child: const Icon(Icons.keyboard_arrow_right, size: 16),
                    ),
                  ),
                  if (_infoInlineOpen) ...[
                    const Divider(height: 1, thickness: 1, color: _dividerColor, indent: _tileDividerIndent),
                    _infoInlinePanel(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            _Card(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  _SimpleTile(
                    icon: Icons.share_outlined,
                    title: "Invite a friend",
                    compact: true,
                    onTap: _openInviteSheet,
                    arrowKey: _inviteArrowKey,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

extension _SlideExt on Widget {
  Widget buildSlide(Animation<double> anim) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(anim),
      child: this,
    );
  }
}

// =======================================================
// ✅ MANAGE PEOPLE SHEET BODY
// =======================================================

class _ManagePeopleSheetBody extends StatefulWidget {
  final List<Person> draftPeople;
  final List<IconData> availableAvatars;

  /// Called whenever ANY change happens (for dirty flag)
  final VoidCallback onChanged;

  /// Called when list structure changes (delete) so parent can keep reference
  final void Function(List<Person> next) onDraftChanged;

  const _ManagePeopleSheetBody({
    required this.draftPeople,
    required this.availableAvatars,
    required this.onChanged,
    required this.onDraftChanged,
  });

  @override
  State<_ManagePeopleSheetBody> createState() => _ManagePeopleSheetBodyState();
}

class _ManagePeopleSheetBodyState extends State<_ManagePeopleSheetBody> {
  final ImagePicker _picker = ImagePicker();

  String? _editingId;
  final Map<String, TextEditingController> _nameCtrls = {};
  final Map<String, FocusNode> _focus = {};

  // delete confirm overlay (only one at a time)
  OverlayEntry? _confirmEntry;
  LayerLink? _activeConfirmLink;

  // per-row delete anchors
  final Map<String, LayerLink> _deleteLinks = {};

  // prevent multiple avatar popovers at once
  bool _popoverOpen = false;

  @override
  void dispose() {
    _hideConfirm();
    for (final c in _nameCtrls.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(Person p) {
    return _nameCtrls.putIfAbsent(p.id, () => TextEditingController(text: p.name));
  }

  FocusNode _focusFor(Person p) {
    return _focus.putIfAbsent(p.id, () => FocusNode());
  }

  LayerLink _deleteLinkFor(Person p) {
    return _deleteLinks.putIfAbsent(p.id, () => LayerLink());
  }

  void _startEdit(Person p) {
    final c = _ctrlFor(p);
    c.text = p.name;
    setState(() => _editingId = p.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusFor(p).requestFocus();
      c.selection = TextSelection.fromPosition(TextPosition(offset: c.text.length));
    });
  }

  void _cancelEdit(Person p) {
    final c = _ctrlFor(p);
    c.text = p.name;
    setState(() => _editingId = null);
  }

  void _saveEdit(Person p) {
    final c = _ctrlFor(p);
    final v = c.text.trim();
    if (v.isEmpty) return;

    setState(() {
      p.name = _capitalizeFirst(v);
      _editingId = null;
    });

    widget.onChanged();
  }

  // ----------------------
  // Avatar editing (per person) popover
  // ----------------------

  Future<void> _pickFromCamera(Person p) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() {
        p.avatarFile = File(picked.path);
        p.avatarIcon = null;
      });
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open camera.")),
      );
    }
  }

  Future<void> _pickFromGallery(Person p) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() {
        p.avatarFile = File(picked.path);
        p.avatarIcon = null;
      });
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open gallery.")),
      );
    }
  }

  Future<void> _showAvatarActionsPopover({
    required GlobalKey anchorKey,
    required Person person,
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
                  final viewInsets = mq.viewInsets;
                  final safePad = mq.padding;

                  final double effectiveH = screenH - viewInsets.bottom;

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

                  const double margin = 12;
                  const double gap = 8;

                  final double popoverWidth =
                      (260.0).clamp(160.0, screenW - (margin * 2)).toDouble();

                  double left = anchorBottomLeft.dx;
                  if (left + popoverWidth > screenW - margin) {
                    left = (screenW - popoverWidth - margin).clamp(margin, screenW);
                  }
                  if (left < margin) left = margin;

                  final double topBelow = anchorBottomLeft.dy + gap;
                  final double availableBelow = (effectiveH - margin) - topBelow;
                  final double availableAbove = (anchorTopLeft.dy - margin) - gap;

                  final bool placeAbove =
                      availableBelow < 140 && availableAbove > availableBelow;

                  final double maxHeight = (placeAbove ? availableAbove : availableBelow)
                      .clamp(120.0, effectiveH - (margin * 2))
                      .toDouble();

                  double top = placeAbove
                      ? (anchorTopLeft.dy - gap - maxHeight)
                      : topBelow;
                  top = top.clamp(margin + safePad.top, effectiveH - margin);

                  final hasAvatar = person.avatarFile != null || person.avatarIcon != null;

                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: viewInsets.bottom),
                    child: Stack(
                      children: [
                        Positioned(
                          left: left,
                          top: top,
                          width: popoverWidth,
                          child: GestureDetector(
                            onTap: () {},
                            child: Material(
                              color: Colors.white,
                              elevation: 12,
                              borderRadius: BorderRadius.circular(16),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: popoverWidth,
                                  maxHeight: maxHeight,
                                ),
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _AvatarAction(
                                          icon: Icons.photo_camera_outlined,
                                          label: "Take a picture",
                                          onTap: () async {
                                            close();
                                            await _pickFromCamera(person);
                                          },
                                        ),
                                        const SizedBox(height: 6),
                                        _AvatarAction(
                                          icon: Icons.photo_library_outlined,
                                          label: "Choose a picture",
                                          onTap: () async {
                                            close();
                                            await _pickFromGallery(person);
                                          },
                                        ),
                                        const SizedBox(height: 6),
                                        _AvatarAction(
                                          icon: Icons.person_outline,
                                          label: "Choose an avatar",
                                          onTap: () async {
                                            close();
                                            await Future.delayed(const Duration(milliseconds: 10));
                                            if (!mounted) return;
                                            await _showAvatarGridPopover(anchorKey: anchorKey, person: person);
                                          },
                                        ),
                                        if (hasAvatar) ...[
                                          const Divider(height: 18),
                                          _AvatarAction(
                                            icon: Icons.delete_outline,
                                            label: "Remove profile picture",
                                            danger: true,
                                            onTap: () {
                                              setState(() {
                                                person.avatarFile = null;
                                                person.avatarIcon = null;
                                              });
                                              widget.onChanged();
                                              close();
                                            },
                                          ),
                                        ],
                                      ],
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

  Future<void> _showAvatarGridPopover({
    required GlobalKey anchorKey,
    required Person person,
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
                  final viewInsets = mq.viewInsets;
                  final safePad = mq.padding;
                  final double effectiveH = screenH - viewInsets.bottom;

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

                  const double margin = 12;
                  const double gap = 8;

                  final double popoverWidth =
                      (300.0).clamp(180.0, screenW - (margin * 2)).toDouble();

                  double left = anchorBottomLeft.dx;
                  if (left + popoverWidth > screenW - margin) {
                    left = (screenW - popoverWidth - margin).clamp(margin, screenW);
                  }
                  if (left < margin) left = margin;

                  final double topBelow = anchorBottomLeft.dy + gap;
                  final double availableBelow = (effectiveH - margin) - topBelow;
                  final double availableAbove = (anchorTopLeft.dy - margin) - gap;

                  final bool placeAbove =
                      availableBelow < 180 && availableAbove > availableBelow;

                  final double maxHeight = (placeAbove ? availableAbove : availableBelow)
                      .clamp(160.0, effectiveH - (margin * 2))
                      .toDouble();

                  double top = placeAbove
                      ? (anchorTopLeft.dy - gap - maxHeight)
                      : topBelow;
                  top = top.clamp(margin + safePad.top, effectiveH - margin);

                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: viewInsets.bottom),
                    child: Stack(
                      children: [
                        Positioned(
                          left: left,
                          top: top,
                          width: popoverWidth,
                          child: GestureDetector(
                            onTap: () {},
                            child: Material(
                              color: Colors.white,
                              elevation: 12,
                              borderRadius: BorderRadius.circular(16),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: popoverWidth,
                                  maxHeight: maxHeight,
                                ),
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            "Choose an avatar",
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        GridView.builder(
                                          shrinkWrap: true,
                                          itemCount: widget.availableAvatars.length,
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 4,
                                            mainAxisSpacing: 10,
                                            crossAxisSpacing: 10,
                                          ),
                                          itemBuilder: (ctx2, i) {
                                            final icon = widget.availableAvatars[i];
                                            return InkWell(
                                              borderRadius: BorderRadius.circular(14),
                                              onTap: () {
                                                setState(() {
                                                  person.avatarIcon = icon;
                                                  person.avatarFile = null;
                                                });
                                                widget.onChanged();
                                                close();
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF3F4F6),
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: Center(child: Icon(icon, size: 26)),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(onPressed: close, child: const Text("Cancel")),
                                        ),
                                      ],
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

  // ----------------------
  // Delete confirm (anchored popover like Notifications)
  // ----------------------

  void _hideConfirm() {
    _confirmEntry?.remove();
    _confirmEntry = null;
    _activeConfirmLink = null;
  }

  void _showConfirmFor(Person p) {
    final link = _deleteLinkFor(p);

    // toggle behavior
    if (_confirmEntry != null && _activeConfirmLink == link) {
      _hideConfirm();
      return;
    }
    _hideConfirm();

    final overlay = Overlay.of(context);

    _activeConfirmLink = link;
    _confirmEntry = OverlayEntry(
      builder: (ctx) {
        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideConfirm,
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
                      borderRadius: BorderRadius.circular(18),
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
                              children: [
                                TextButton(
                                  onPressed: _hideConfirm,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                    textStyle: const TextStyle(fontSize: 13, height: 1.0),
                                  ),
                                  child: const Text("No"),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () {
                                    _hideConfirm();
                                    final next = [...widget.draftPeople]..removeWhere((x) => x.id == p.id);
                                    widget.onDraftChanged(next);
                                    widget.onChanged();
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                    textStyle: const TextStyle(fontSize: 13, height: 1.0),
                                  ),
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

    overlay.insert(_confirmEntry!);
  }

  // ----------------------
  // UI helpers
  // ----------------------

  Widget _miniAvatar(Person p) {
    ImageProvider? bg;
    if (p.avatarFile != null) bg = FileImage(p.avatarFile!);

    final Widget child;
    if (p.avatarFile != null) {
      child = const SizedBox.shrink();
    } else if (p.avatarIcon != null) {
      child = Icon(p.avatarIcon, size: 18);
    } else {
      child = Text(
        _initials(p.name),
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
      );
    }

    final bgColor = p.avatarFile == null && p.avatarIcon == null
        ? _colorFor(p.id)
        : const Color(0xFFE5E7EB);

    return CircleAvatar(
      radius: 18,
      backgroundColor: bgColor,
      backgroundImage: bg,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.draftPeople.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("No people yet.", style: TextStyle(color: Color(0xFF9CA3AF))),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: widget.draftPeople.length,
      separatorBuilder: (_, __) => const Divider(height: 14, thickness: 1, color: Color(0xFFE6E8EF)),
      itemBuilder: (ctx, i) {
        final p = widget.draftPeople[i];
        final isEditing = _editingId == p.id;
        final ctrl = _ctrlFor(p);

        // avatar anchor for popover
        final avatarKey = GlobalKey();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              key: avatarKey,
              onTap: () => _showAvatarActionsPopover(anchorKey: avatarKey, person: p),
              borderRadius: BorderRadius.circular(999),
              child: _miniAvatar(p),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: isEditing
                        ? TextField(
                            controller: ctrl,
                            focusNode: _focusFor(p),
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            maxLines: 1,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) => widget.onChanged(),
                            onSubmitted: (_) => _saveEdit(p),
                            style: const TextStyle(fontSize: 16),
                          )
                        : Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(width: 8),

                  if (!isEditing) ...[
                    InkWell(
                      onTap: () => _startEdit(p),
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.edit_outlined, size: 16),
                      ),
                    ),
                  ] else ...[
                    InkWell(
                      onTap: () => _saveEdit(p),
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.check, size: 18),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _cancelEdit(p),
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 18),
                      ),
                    ),
                  ],

                  const SizedBox(width: 8),

                  // ✅ delete icon = red circle with white minus + anchored confirm under it
                  CompositedTransformTarget(
                    link: _deleteLinkFor(p),
                    child: InkWell(
                      onTap: () => _showConfirmFor(p),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 10,
                          height: 2.2,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Deep clone so edits are draft-only until Save
Person _clonePersonDeep(Person p) {
  return Person(
    id: p.id,
    name: p.name,
    pins: p.pins
        .map(
          (x) => PinItem(
            id: x.id,
            name: x.name,
            muted: x.muted,
            synced: x.synced,
            inRange: x.inRange,
            lastStatusOn: x.lastStatusOn,
          ),
        )
        .toList(),
    avatarFile: p.avatarFile,
    avatarIcon: p.avatarIcon,
  );
}

// =======================================================
// EXISTING INVITE SHEET (DEMO list)
// =======================================================

class _InviteContact {
  final String name;
  final String phone;

  const _InviteContact(this.name, this.phone);
}

class _InviteContactsSheet extends StatefulWidget {
  final String messageBody;

  const _InviteContactsSheet({
    required this.messageBody,
  });

  @override
  State<_InviteContactsSheet> createState() => _InviteContactsSheetState();
}

class _InviteContactsSheetState extends State<_InviteContactsSheet> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  final List<_InviteContact> _all = const [
    _InviteContact("Adama Gueye", "+1 (317) 555-0155"),
    _InviteContact("Aminata Sow", "+1 (317) 555-0134"),
    _InviteContact("Awa Ndiaye", "+1 (317) 555-0191"),
    _InviteContact("Binta Cisse", "+1 (317) 555-0122"),
    _InviteContact("Cheikh Kane", "+1 (317) 555-0129"),
    _InviteContact("Fatou Diop", "+1 (317) 555-0177"),
    _InviteContact("Ibrahima Sarr", "+1 (317) 555-0166"),
    _InviteContact("Khady Seck", "+1 (317) 555-0108"),
    _InviteContact("Mamadou Fall", "+1 (317) 555-0113"),
    _InviteContact("Mariama Ba", "+1 (317) 555-0142"),
    _InviteContact("Moustapha Ndiaye", "+1 (317) 555-0199"),
    _InviteContact("Ousmane Diallo", "+1 (317) 555-0180"),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<int> _filteredIndicesAlphabetical() {
    final q = _search.text.trim().toLowerCase();

    final out = <int>[];
    for (int i = 0; i < _all.length; i++) {
      final c = _all[i];
      if (q.isEmpty || c.name.toLowerCase().contains(q) || c.phone.toLowerCase().contains(q)) {
        out.add(i);
      }
    }

    out.sort((ia, ib) => _all[ia].name.toLowerCase().compareTo(_all[ib].name.toLowerCase()));
    return out;
  }

  Future<void> _openSms({required String phone, required String body}) async {
    // TODO: replace with a real deep link (url_launcher) later
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Open SMS to $phone with message:\n$body")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredIndicesAlphabetical();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: "Search contact",
                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE6E8EF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                ),
                suffixIcon: _search.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: "Clear",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, thickness: 1, color: Color(0xFFE6E8EF), indent: 16),
            itemBuilder: (ctx, row) {
              final idx = filtered[row];
              final c = _all[idx];

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await _openSms(phone: c.phone, body: widget.messageBody);
                  if (!mounted) return;
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              c.phone,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// -------------------------
// Kids privacy (scrollable)
// -------------------------
class _PrivacyKidsScrollable extends StatefulWidget {
  const _PrivacyKidsScrollable();

  @override
  State<_PrivacyKidsScrollable> createState() => _PrivacyKidsScrollableState();
}

class _PrivacyKidsScrollableState extends State<_PrivacyKidsScrollable> {
  final ScrollController _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _ctrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _ctrl,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: const _PrivacyKidsText(),
      ),
    );
  }
}

class _PrivacyKidsText extends StatelessWidget {
  const _PrivacyKidsText();

  @override
  Widget build(BuildContext context) {
    const h = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
    const p = TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF111827));
    const muted = TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF6B7280));

    Widget section(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: h),
              const SizedBox(height: 6),
              Text(body, style: p),
            ],
          ),
        );

    Widget bullets(String title, List<String> items) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: h),
              const SizedBox(height: 6),
              ...items.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("•  ", style: p),
                      Expanded(child: Text(t, style: p)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        section(
          "How we use your information",
          "SUTA is made to help your family stay organized. We only use information needed to run the app and improve it.",
        ),
        bullets(
          "What we may collect",
          [
            "Basic profile info (like your name).",
            "App activity (for example: when you create or edit items).",
            "Device information (to keep the app secure and working well).",
          ],
        ),
        section(
          "What we do NOT do",
          "We do not sell your personal information. We do not show ads based on your activity inside SUTA.",
        ),
        bullets(
          "Your choices",
          [
            "A parent/guardian can review or change account information.",
            "You can ask for help if something does not look right.",
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          "If you have questions, ask a parent/guardian to contact us.",
          style: muted,
        ),
      ],
    );
  }
}

// ---------------------------
// Adults privacy (scrollable)
// ---------------------------
class _PrivacyAdultsScrollable extends StatefulWidget {
  const _PrivacyAdultsScrollable();

  @override
  State<_PrivacyAdultsScrollable> createState() => _PrivacyAdultsScrollableState();
}

class _PrivacyAdultsScrollableState extends State<_PrivacyAdultsScrollable> {
  final ScrollController _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _ctrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _ctrl,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: const _PrivacyAdultsText(),
      ),
    );
  }
}

class _PrivacyAdultsText extends StatelessWidget {
  const _PrivacyAdultsText();

  @override
  Widget build(BuildContext context) {
    const h = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
    const p = TextStyle(fontSize: 13, height: 1.38, color: Color(0xFF111827));
    const muted = TextStyle(fontSize: 12.5, height: 1.38, color: Color(0xFF6B7280));

    Widget section(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: h),
              const SizedBox(height: 6),
              Text(body, style: p),
            ],
          ),
        );

    Widget bullets(String title, List<String> items) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: h),
              const SizedBox(height: 6),
              ...items.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("•  ", style: p),
                      Expanded(child: Text(t, style: p)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        section(
          "Privacy notice (adults)",
          "This notice explains what information SUTA may collect, how it is used, and the choices you have as a parent/guardian or adult user.",
        ),
        bullets(
          "Information we may collect",
          [
            "Account information you provide (name, email).",
            "Content you add in the app (items, notes, status).",
            "Usage and diagnostics (to improve performance and fix bugs).",
            "Device information (for security and compatibility).",
          ],
        ),
        section(
          "How we use information",
          "We use information to provide and improve SUTA, keep the app secure, personalize basic experiences (like showing your profile), and respond to support requests.",
        ),
        section(
          "Sharing",
          "We do not sell personal information. We may share limited data with service providers only to operate the app (for example: hosting, analytics, crash reports), under confidentiality obligations.",
        ),
        bullets(
          "Your choices & rights",
          [
            "Review or update your account information in Settings.",
            "Request deletion of your account data (if implemented in your backend later).",
            "Contact support for questions, issues, or privacy requests.",
          ],
        ),
        const Text(
          "This is a demo privacy notice. Replace with your real legal/privacy text before release.",
          style: muted,
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Color(0x11000000)),
        ],
      ),
      child: child,
    );
  }
}

class _KeyValueEditRowTight extends StatelessWidget {
  final double leftIndent;
  final String label;
  final String value;
  final bool valueGrey;
  final VoidCallback onEdit;
  final GlobalKey? editKey;

  const _KeyValueEditRowTight({
    required this.leftIndent,
    required this.label,
    required this.value,
    required this.valueGrey,
    required this.onEdit,
    this.editKey,
  });

  @override
  Widget build(BuildContext context) {
    const grey = Color(0xFF9CA3AF);

    return Padding(
      padding: EdgeInsets.only(left: leftIndent),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label)),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: valueGrey ? grey : null),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            key: editKey,
            onTap: onEdit,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.edit_outlined, size: 16),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _SimpleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool compact;

  final GlobalKey? arrowKey;
  final Widget? trailingOverride;

  const _SimpleTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.compact = false,
    this.arrowKey,
    this.trailingOverride,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: compact ? 6 : 10),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
            SizedBox(
              key: arrowKey,
              child: trailingOverride ?? const Icon(Icons.keyboard_arrow_right, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _AvatarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFEF4444) : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ Email popover widget
class _EmailPopover extends StatefulWidget {
  final TextStyle popoverTextStyle;
  final double fieldGap;
  final InputDecoration Function(String hint, {Widget? suffix}) popoverDeco;
  final void Function(String email) onSave;
  final VoidCallback close;

  const _EmailPopover({
    required this.popoverTextStyle,
    required this.fieldGap,
    required this.popoverDeco,
    required this.onSave,
    required this.close,
  });

  @override
  State<_EmailPopover> createState() => _EmailPopoverState();
}

class _EmailPopoverState extends State<_EmailPopover> {
  late final TextEditingController emailCtrl;
  late final TextEditingController confirmCtrl;
  String? error;

  @override
  void initState() {
    super.initState();
    emailCtrl = TextEditingController();
    confirmCtrl = TextEditingController();
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  bool isValidEmail(String v) {
    return RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$").hasMatch(v);
  }

  void submit() {
    final a = emailCtrl.text.trim();
    final b = confirmCtrl.text.trim();

    if (a.isEmpty || b.isEmpty) {
      setState(() => error = "Please fill both fields.");
      return;
    }
    if (!isValidEmail(a)) {
      setState(() => error = "Enter a valid email address.");
      return;
    }
    if (a.toLowerCase() != b.toLowerCase()) {
      setState(() => error = "Emails do not match.");
      return;
    }

    widget.onSave(a);
    widget.close();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: widget.popoverTextStyle,
            decoration: widget.popoverDeco("Enter new email"),
            onChanged: (_) => setState(() => error = null),
          ),
          SizedBox(height: widget.fieldGap),
          TextField(
            controller: confirmCtrl,
            keyboardType: TextInputType.emailAddress,
            style: widget.popoverTextStyle,
            decoration: widget.popoverDeco("Confirm new email"),
            onChanged: (_) => setState(() => error = null),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                error!,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: widget.close, child: const Text("Cancel")),
              const SizedBox(width: 8),
              FilledButton(onPressed: submit, child: const Text("Save")),
            ],
          ),
        ],
      ),
    );
  }
}

/// ✅ Password popover widget
class _PasswordPopover extends StatefulWidget {
  final TextStyle popoverTextStyle;
  final double fieldGap;
  final InputDecoration Function(String hint, {Widget? suffix}) popoverDeco;
  final String currentPassword;
  final void Function(String newPassword) onSave;
  final VoidCallback close;

  const _PasswordPopover({
    required this.popoverTextStyle,
    required this.fieldGap,
    required this.popoverDeco,
    required this.currentPassword,
    required this.onSave,
    required this.close,
  });

  @override
  State<_PasswordPopover> createState() => _PasswordPopoverState();
}

class _PasswordPopoverState extends State<_PasswordPopover> {
  late final TextEditingController oldCtrl;
  late final TextEditingController newCtrl;
  late final TextEditingController confirmCtrl;

  bool obscureOld = true;
  bool obscureNew = true;
  bool obscureConfirm = true;

  String? error;

  @override
  void initState() {
    super.initState();
    oldCtrl = TextEditingController();
    newCtrl = TextEditingController();
    confirmCtrl = TextEditingController();
  }

  @override
  void dispose() {
    oldCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  void submit() {
    final oldP = oldCtrl.text;
    final newP = newCtrl.text;
    final confP = confirmCtrl.text;

    if (oldP.isEmpty || newP.isEmpty || confP.isEmpty) {
      setState(() => error = "Please fill all fields.");
      return;
    }
    if (oldP != widget.currentPassword) {
      setState(() => error = "Old password is incorrect.");
      return;
    }
    if (newP.length < 6) {
      setState(() => error = "New password must be at least 6 characters.");
      return;
    }
    if (newP != confP) {
      setState(() => error = "New passwords do not match.");
      return;
    }
    if (newP == oldP) {
      setState(() => error = "New password must be different.");
      return;
    }

    widget.onSave(newP);
    widget.close();
  }

  Widget eye(bool obscure, VoidCallback toggle) {
    return IconButton(
      onPressed: toggle,
      icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: oldCtrl,
            obscureText: obscureOld,
            style: widget.popoverTextStyle,
            decoration: widget.popoverDeco(
              "Old password",
              suffix: eye(obscureOld, () => setState(() {
                    obscureOld = !obscureOld;
                    error = null;
                  })),
            ),
            onChanged: (_) => setState(() => error = null),
          ),
          SizedBox(height: widget.fieldGap),
          TextField(
            controller: newCtrl,
            obscureText: obscureNew,
            style: widget.popoverTextStyle,
            decoration: widget.popoverDeco(
              "New password",
              suffix: eye(obscureNew, () => setState(() {
                    obscureNew = !obscureNew;
                    error = null;
                  })),
            ),
            onChanged: (_) => setState(() => error = null),
          ),
          SizedBox(height: widget.fieldGap),
          TextField(
            controller: confirmCtrl,
            obscureText: obscureConfirm,
            style: widget.popoverTextStyle,
            decoration: widget.popoverDeco(
              "Confirm new password",
              suffix: eye(obscureConfirm, () => setState(() {
                    obscureConfirm = !obscureConfirm;
                    error = null;
                  })),
            ),
            onChanged: (_) => setState(() => error = null),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                error!,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: widget.close, child: const Text("Cancel")),
              const SizedBox(width: 8),
              FilledButton(onPressed: submit, child: const Text("Save")),
            ],
          ),
        ],
      ),
    );
  }
}

// Helper: Title Case (Fatou Ndoye)
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