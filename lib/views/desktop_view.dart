import 'package:flutter/material.dart';
import 'package:split_view/split_view.dart';
import 'package:easy_localization/easy_localization.dart';

import 'chat_view.dart';
import '../widgets/title_list.dart';
import '../widgets/model_selector.dart';
import '../widgets/list_header.dart';
import '../widgets/app_title.dart';
import '../helpers/event_bus.dart';

class DesktopView extends StatefulWidget {
  const DesktopView({Key? key}) : super(key: key);

  @override
  createState() => _DesktopViewState();
}

class _DesktopViewState extends State<DesktopView> {
  final double _initialWeight = 0.35;
  List<Widget>? _action;

  @override
  void initState() {
    super.initState();
    _initEventConnector();
  }

  @override
  void dispose() {
    super.dispose();
  }

  //--------------------------------------------------------------------------//
  void _initEventConnector() async {
    MyEventBus().on<ChangeTitleEvent>().listen((event) {
      if (mounted) {
        _action = event.action;
        setState(() {});
      }
    });
  }

  //--------------------------------------------------------------------------//
  PreferredSizeWidget _buildToolbar() {
    return AppBar(
      title: Row(
        children: [
          AppTitle(textColor: Colors.white),
          SizedBox(width: 20),
          ModelSelector(),
          Spacer(),
        ],
      ),
      backgroundColor: Theme.of(context).primaryColor,
      elevation: 1,
      actions: _action,
    );
  }

  //--------------------------------------------------------------------------//
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildToolbar(),
      body: SplitView(
        viewMode: SplitViewMode.Horizontal,
        indicator: SplitIndicator(
          viewMode: SplitViewMode.Horizontal,
          color: Colors.grey,
        ),
        activeIndicator: SplitIndicator(
          viewMode: SplitViewMode.Horizontal,
          color: Colors.blue,
        ),
        controller:
            SplitViewController(weights: [_initialWeight, 1 - _initialWeight]),
        children: [
          // Left panel (1 part)
          Container(
            color: Theme.of(context).colorScheme.background,
            child: TitleList(),
          ),
          // Right panel (4 parts)
          Container(
            color: Theme.of(context).colorScheme.background,
            child: ChatView(),
          ),
        ],
      ),
    );
  }
}
