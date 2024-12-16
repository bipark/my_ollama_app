import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../helpers/event_bus.dart';
import 'app_title.dart';

class ListHeader extends StatelessWidget {
  const ListHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      height: 56,
      child: Row(
        children: [
          AppTitle(),
          Spacer(),
          IconButton(
            onPressed: () {
              MyEventBus().fire(RefreshMainListEvent());
            },
            icon: Icon(Icons.refresh, color: Colors.black)
          ),
        ],
      ),
    );
  }
}
