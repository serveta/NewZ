import 'package:newz/auth.dart';
import 'package:newz/pages/login_register_page.dart';
import 'package:flutter/material.dart';
import 'package:newz/pages/homeCurrent.dart';

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: Auth().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const VerticalSwipe();
          } else {
            return const CreateAccountPage();
          }
        });
  }
}
