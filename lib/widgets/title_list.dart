import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../provider/main_provider.dart';
import '../helpers/event_bus.dart';

import 'dialogs.dart';

class TitleList extends StatefulWidget {
  const TitleList({Key? key}) : super(key: key);

  @override
  createState()=>_TitleListState();
}

class _TitleListState extends State<TitleList> {
  bool _showWait = false;
  List _titles = [];
  int _selectedIndex = 0;
  TextEditingController _search = TextEditingController();


  @override
  void initState() {
    super.initState();
    _initEventConnector();
    _loadData(refresh: true);
  }

  @override
  void dispose() {
    super.dispose();
  }

  //--------------------------------------------------------------------------//
  void _initEventConnector() async {
    MyEventBus().on<RefreshMainListEvent>().listen((event) {
      _loadData();
    });
  }


  //--------------------------------------------------------------------------//
  void _loadData({bool refresh = false}) async {
    if (mounted) {
      _showWait = true;
      setState(() {});

      _titles = await context.read<MainProvider>().qdb.getTitles();
      if (refresh) {
        if (_titles.length > 0) _selectTitle(0);
      }

      _showWait = false;
      setState(() {});
    }
  }

  //--------------------------------------------------------------------------//
  void _deleteQuestion(String groupid) async {
    final provider = context.read<MainProvider>();
    final result = await AskDialog.show(context, title: tr("l_delete"), message: tr("l_delete_question"));
    if (result == true) {
      await provider.qdb.deleteQuestions(groupid);
      _loadData();
      _selectedIndex = 0;
      setState(() {});
    }
  }

  //--------------------------------------------------------------------------//
  Widget _titlePanel(int index) {
    String title = _titles[index]["question"];
    if (title.length > 70) {
      title = title.substring(0, 70) + "...";
      title = title.replaceAll("\n", " ");
      title = title.trimLeft();
    }

    return Container(
      color : _selectedIndex == index ? Colors.grey.shade200 : Colors.transparent,
      padding: EdgeInsets.fromLTRB(14, 6, 10, 6),
      child: Row(
        children: [
          Expanded(
              child : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
                    Text(_titles[index]["created"].toString(), style: TextStyle(fontSize: 12, color: Colors.grey))
                  ]
              )
          ),
          Row(
            children: [
              IconButton(onPressed: () {
                _deleteQuestion(_titles[index]["groupid"]);
              }, icon: Icon(Icons.delete_outline, size: 20, color: Colors.black54,))
            ],
          )
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------//
  void _selectTitle(int index) {
    final provider = context.read<MainProvider>();

    _selectedIndex = index;
    provider.curGroupId = _titles[index]["groupid"];
    MyEventBus().fire(CloseDrawerEvent());
    MyEventBus().fire(LoadHistoryGroupListEvent());
    setState(() {});
  }

  //--------------------------------------------------------------------------//
  void _startSearch() async {
    _showWait = true;
    setState(() {});

    final provider = context.read<MainProvider>();
    if (_search.text != "") {
      _titles = await provider.qdb.searchKeywords(_search.text);
    }
    _showWait = false;
    setState(() {});
  }

  //--------------------------------------------------------------------------//
  Widget _searchPanel() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: tr("l_search"),
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(10, 0, 10, 0),
              ),
              onSubmitted: (String value) {
                _startSearch();
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: _startSearch,
          ),
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              FocusScope.of(context).requestFocus(FocusNode());
              _search.text = "";
              _loadData();
            },
          )
        ],
      ),
    );
  }


  //--------------------------------------------------------------------------//
  Widget _listView() {
    return CustomScrollView(
      slivers: [
        SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return InkWell(
                child: _titlePanel(index),
                onTap: (){
                  _selectTitle(index);
                },
              );
            }, childCount: _titles.length)
        )
      ],
    );
  }

  //--------------------------------------------------------------------------//
  @override
  Widget build(BuildContext context) {

    return Container(
      child: Stack(
        children: [
          Column(
            children: [
              _searchPanel(),
              Expanded(child: _listView())
            ],
          ),
          _showWait ? Center(child: CircularProgressIndicator()) : SizedBox()
        ],
      ),
    );

  }

}
