import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app_settings/app_settings.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import '../utils/platform_utils.dart';

import '../widgets/text_fields.dart';
import '../provider/main_provider.dart';
import '../widgets/dialogs.dart';
import '../helpers/event_bus.dart';

final title_style = TextStyle(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.bold);
final linkStyle = TextStyle(fontSize: 15, color: Colors.blueAccent, fontWeight: FontWeight.bold);
final TextStyle midSizeStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54);
final TextStyle dvcSubStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.black38);

class MySettings extends StatefulWidget {
  const MySettings({Key? key}) : super(key: key);

  @override
  createState()=>_MySettingsState();
}

class _MySettingsState extends State<MySettings> {
  final server_address = TextEditingController();
  final instruction = TextEditingController();
  final temperature = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    super.dispose();
  }

  //--------------------------------------------------------------------------//
  void _loadPreferences() {
    final provider = context.read<MainProvider>();
    provider.loadPreferences();

    server_address.text = provider.baseUrl;
    instruction.text = provider.instruction;
    temperature.text = provider.temperature.toString();
  }

  //--------------------------------------------------------------------------//
  void _deleteAllRecords() async {
    final provider = context.read<MainProvider>();
    final result = await AskDialog.show(context, title: 'Delete all data', message: 'Are you sure?');
    if (result == true) {
      await provider.qdb.deleteAllRecords();
      MyEventBus().fire(NewChatBeginEvent());
      MyEventBus().fire(RefreshMainListEvent());
    }
  }


  //--------------------------------------------------------------------------//
  Widget ActionCardPanel(IconData leadIcon, String title, String? subtitle, IconData trailIcon, Function action) {
    return Card(
      child: ListTile(
        leading: Icon(leadIcon),
        title: Text(title, style: midSizeStyle),
        subtitle: subtitle != null ? Text(subtitle, style: dvcSubStyle) : null,
        trailing: Icon(trailIcon),
        onTap: action as void Function()?,
      ),
    );
  }

  //--------------------------------------------------------------------------//
  bool _isValidUrl(String url) {
    final urlPattern = RegExp(
      r'^(http|https):\/\/([\w-]+\.)+[\w-]+(:\d+)?(\/[\w- .\/?%&=]*)?$',
      caseSensitive: false,
      multiLine: false,
    );
    return urlPattern.hasMatch(url);
  }

  //--------------------------------------------------------------------------//
  @override
  Widget build(BuildContext context) {
    final provider = context.read<MainProvider>();
    final version = provider.version + ' (' + provider.buildNumber.toString() + ')';
    final isDesktop = isDesktopOrTablet();  // Use the new function

    final widgets = [
      ListTile(title: Text(tr("l_ollama_setting"), style: title_style)),
      Row(
        children: [
          Expanded(
            child:QTextField(tr("l_server_address"), server_address, (_){})
          ),
          IconButton(
            icon: Icon(Icons.network_check, size: 30,),
            onPressed: () async {
              if (_isValidUrl(server_address.text)) {
                final reached = await provider.setBaseUrl(server_address.text);
                if (reached) {
                  MyEventBus().fire(ReloadModelEvent());
                  showToast(tr("l_success"), context: context, position: StyledToastPosition.center);
                } else {
                  showToast(tr("l_error_url"), context: context, position: StyledToastPosition.center);
                }
              } else {
                AskDialog.show(context, title: tr("l_error"), message: tr("l_invalid_url"));
              }
            },
          )
        ],
      ),
      QTextField(tr("l_instructions"), instruction, (String value){
        provider.setInstruction(value);
      }, maxLines: 5),
      QTextField(tr("l_temp"), temperature, (String value){
        provider.setTemperature(double.parse(value));
      }),
      ActionCardPanel(Icons.download_for_offline_outlined, tr("l_download"), tr("l_download_ollama"), Icons.arrow_forward_ios, () {
        launchUrl(Uri.parse("https://ollama.com/download"));
      }),
      ActionCardPanel(Icons.help_outline, tr("l_howto"), tr("l_howto_1"), Icons.arrow_forward_ios, () {
        launchUrl(Uri.parse("http://practical.kr/?p=809"));
      }),
      ListTile(title: Text(tr("l_app_info"), style: title_style)),
      ActionCardPanel(Icons.memory, tr("l_open_source"), tr("l_open_comment"), Icons.arrow_forward_ios, () {
        launchUrl(Uri.parse("https://github.com/bipark/my_ollama_app"));
      }),
      ActionCardPanel(Icons.delete_forever_outlined, tr("l_delete"), tr("l_delete_all"), Icons.arrow_forward_ios, () {
        _deleteAllRecords();
      }),
      ActionCardPanel(Icons.settings_applications_outlined, tr("l_app_info"), null, Icons.arrow_forward_ios, (){
        AppSettings.openAppSettings();
      }),
      ActionCardPanel(Icons.info, tr("l_myollama"), tr("l_version") + version, Icons.arrow_forward_ios, () {
        launchUrl(Uri.parse("http://practical.kr"));
      }),
    ];

    final content = Container(
      padding: const EdgeInsets.all(10.0),
      child: Material(
        child: CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => widgets[index],
                childCount: widgets.length,
              ),
            ),
          ],
        ),
      ),
    );

    if (isDesktop) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(tr("l_settings"), style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              _loadPreferences();
            },
            icon: Icon(Icons.refresh, color: Colors.white)
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: content,
      ),
    );
  }
}
