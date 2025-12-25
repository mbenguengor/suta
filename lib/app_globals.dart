import 'package:flutter/material.dart';

/// ✅ Global messenger so we can show SnackBars without using BuildContext
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();