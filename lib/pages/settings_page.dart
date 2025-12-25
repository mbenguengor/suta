import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ✅ Temporary placeholders (replace later with real user/account storage)
  String _fullName = "Ngor";
  String _email = "user@email.com";

  // Store a "real" password for demo validation (DON'T do this in production like this)
  String _password = "123456";

  // ✅ Inline name editing (no dialog) + save/cancel icons
  bool _isEditingName = false;
  late final TextEditingController _nameController;
  final FocusNode _nameFocus = FocusNode();
  String _nameDraftBeforeEdit = "";
  bool _nameEmptyError = false;

  // ✅ Profile picture / avatar state
  final ImagePicker _picker = ImagePicker();
  File? _profileFile; // camera/gallery result
  IconData? _selectedAvatarIcon; // app-provided avatar choice

  // ✅ Keys to anchor popovers under the crayons / avatar
  final GlobalKey _avatarEditKey = GlobalKey();
  final GlobalKey _emailEditKey = GlobalKey();
  final GlobalKey _passwordEditKey = GlobalKey();

  // ✅ prevent multiple popovers at once (overlap)
  bool _popoverOpen = false;

  // ---- layout tuning ----
  static const double _avatarRadius = 18; // small like footer
  static const double _nameStartIndent = (_avatarRadius * 2) + 12; // avatar diameter + gap
  static const double _tileDividerIndent = 40.0; // 6 pad + 22 icon + 12 gap (starts at title)
  static const Color _dividerColor = Color(0xFFE6E8EF);

  // ---- shared popover form style (email + password SAME) ----
  static const TextStyle _popoverTextStyle = TextStyle(fontSize: 14);
  static const double _fieldGap = 10;

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
    _nameController = TextEditingController(text: _fullName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  // -------------------------
  // Avatar picker UI + logic
  // -------------------------

  // List of “app provided” avatars (icons). Replace with your own assets later if you want.
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

  Future<void> _pickFromCamera() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() {
        _profileFile = File(picked.path);
        _selectedAvatarIcon = null; // camera overrides avatar icon
      });
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

      setState(() {
        _profileFile = File(picked.path);
        _selectedAvatarIcon = null; // gallery overrides avatar icon
      });
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
                  // wait 1 tick so the first popover fully closes before opening the next
                  await Future.delayed(const Duration(milliseconds: 10));
                  if (!mounted) return;
                  await _showAvatarGridPopover();
                },
              ),
              if (_profileFile != null || _selectedAvatarIcon != null) ...[
                const Divider(height: 18),
                _AvatarAction(
                  icon: Icons.delete_outline,
                  label: "Remove profile picture",
                  danger: true,
                  onTap: () {
                    setState(() {
                      _profileFile = null;
                      _selectedAvatarIcon = null;
                    });
                    close();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAvatarGridPopover() async {
    await _showAnchoredPopover<void>(
      anchorKey: _avatarEditKey,
      builder: (close, popConstraints) {
        final maxH = popConstraints.maxHeight;
        // leave some space for padding
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
                        setState(() {
                          _selectedAvatarIcon = icon;
                          _profileFile = null; // avatar overrides image
                        });
                        close();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(icon, size: 26),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: close,
                  child: const Text("Cancel"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ Inline name edit logic
  void _startEditName() {
    setState(() {
      _nameDraftBeforeEdit = _fullName;
      _nameController.text = _fullName;
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

    setState(() {
      _fullName = _capitalizeFirst(v);
      _isEditingName = false;
      _nameEmptyError = false;
    });

    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _cancelNameEdit() {
    setState(() {
      _fullName = _nameDraftBeforeEdit;
      _nameController.text = _nameDraftBeforeEdit;
      _isEditingName = false;
      _nameEmptyError = false;
    });

    FocusManager.instance.primaryFocus?.unfocus();
  }

  // ✅ Measure text width so the field stays short and grows while typing
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

  // ✅ Responsive anchored popover shown under a widget
  // ✅ recompute sizing/position INSIDE dialog so it reacts to screen resize
  Future<T?> _showAnchoredPopover<T>({
    required GlobalKey anchorKey,
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

                  const double margin = 12;
                  const double gap = 8;

                  // ✅ fixed target width (shrinks on smaller screens)
                  final double popoverWidth =
                      (260.0).clamp(180.0, screenW - (margin * 2)).toDouble();

                  double left = anchorBottomLeft.dx;
                  if (left + popoverWidth > screenW - margin) {
                    left = (screenW - popoverWidth - margin).clamp(margin, screenW);
                  }
                  if (left < margin) left = margin;

                  final double topBelow = anchorBottomLeft.dy + gap;
                  final double availableBelow = (effectiveH - margin) - topBelow;
                  final double availableAbove = (anchorTopLeft.dy - margin) - gap;

                  final bool placeAbove = availableBelow < 200 && availableAbove > availableBelow;

                  final double maxHeight = (placeAbove ? availableAbove : availableBelow)
                      .clamp(180.0, effectiveH - (margin * 2))
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

  // -------- Email popover (anchored under crayon) --------
  Future<void> _showChangeEmailDialog() async {
    await _showAnchoredPopover<void>(
      anchorKey: _emailEditKey,
      builder: (close, constraints) {
        return _EmailPopover(
          popoverTextStyle: _popoverTextStyle,
          fieldGap: _fieldGap,
          popoverDeco: _popoverDeco,
          onSave: (newEmail) => setState(() => _email = newEmail),
          close: close,
        );
      },
    );
  }

  // -------- Password popover (anchored under crayon) --------
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

  @override
  Widget build(BuildContext context) {
    const nameStyle = TextStyle(fontSize: 18);

    // Decide what to show inside CircleAvatar
    Widget avatarChild() {
      if (_profileFile != null) return const SizedBox.shrink();
      if (_selectedAvatarIcon != null) return Icon(_selectedAvatarIcon, size: 18);
      return const Icon(Icons.person, size: 18);
    }

    ImageProvider? avatarBgImage() {
      if (_profileFile != null) return FileImage(_profileFile!);
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
                  // ✅ CLICKABLE AVATAR (ANCHOR KEY HERE)
                  InkWell(
                    key: _avatarEditKey,
                    onTap: _showAvatarPopover, // ✅ anchored dialog below avatar
                    borderRadius: BorderRadius.circular(999),
                    child: CircleAvatar(
                      radius: _avatarRadius,
                      backgroundImage: avatarBgImage(),
                      child: avatarChild(),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ✅ short field that grows + pushes icons
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
                                _isEditingName ? _nameController.text : _capitalizeFirst(_fullName);

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
                value: _email,
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
              const Divider(height: 1, thickness: 1, color: _dividerColor, indent: _tileDividerIndent),
              _SimpleTile(
                icon: Icons.notifications_none,
                title: "Notifications",
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Notification settings (next step)")),
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
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Privacy notice for kids (next step)")),
                  );
                },
              ),
              const Divider(height: 1, thickness: 1, color: _dividerColor, indent: _tileDividerIndent),
              _SimpleTile(
                icon: Icons.shield_outlined,
                title: "Privacy notice for parents",
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Privacy notice for parents (next step)")),
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
                icon: Icons.help_outline,
                title: "Help & feedback",
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Help & feedback (next step)")),
                  );
                },
              ),
              const Divider(height: 1, thickness: 1, color: _dividerColor, indent: _tileDividerIndent),
              _SimpleTile(
                icon: Icons.share_outlined,
                title: "Invite a friend",
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invite a friend (next step)")),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        _Card(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              _SimpleTile(
                icon: Icons.info_outline,
                title: "Infos & licenses",
                compact: true,
                onTap: () {
                  showLicensePage(context: context, applicationName: "SUTA");
                },
              ),
            ],
          ),
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

  const _SimpleTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.compact = false,
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
            const Icon(Icons.keyboard_arrow_right, size: 16),
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

/// ✅ Email popover widget (controllers live here)
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

/// ✅ Password popover widget (controllers live here)
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