import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:uuid/uuid.dart';
import 'package:ollama_dart/ollama_dart.dart' as ollama;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:image_picker/image_picker.dart';

import '../provider/main_provider.dart';
import '../helpers/event_bus.dart';
import '../widgets/dialogs.dart';

class MyHome extends StatefulWidget {
  const MyHome({Key? key}) : super(key: key);

  @override
  createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  final ImagePicker _picker = ImagePicker();
  List<types.Message> _messages = [];
  List _questions = [];
  final _user = const types.User(id: '82091008-a484-4a89-ae75-a22bf8d6f3ac');
  final _answerer = const types.User(id: '82091008-a484-4a89-ae75-a22bf8d6f3ad');
  String? _selectedImage;
  TextEditingController _questionController = TextEditingController();
  bool _showWait = false;
  bool _isProcessed = false;


  //--------------------------------------------------------------------------//
  @override
  void initState() {
    super.initState();
    _initEventConnector();
    _init();
  }

  @override
  void dispose() {
    super.dispose();
  }

  //--------------------------------------------------------------------------//
  Future<void> _init() async {
    Widget recheck = IconButton(onPressed: _reloadServerModel, icon: Icon(Icons.network_check, color: Colors.white));
    Widget newnote = IconButton(onPressed: _newNote, icon: Icon(Icons.add_comment_outlined));
    Widget shareAll = IconButton(onPressed: _shareAll, icon: Icon(Icons.share, color: Colors.white));
    MyEventBus().fire(ChangeTitleEvent(tr("l_myollama"), [recheck, newnote, shareAll]));
  }

  //--------------------------------------------------------------------------//
  void _initEventConnector() async {
    MyEventBus().on<LoadHistoryGroupListEvent>().listen((event) {
      _loadHistoryChats();
    });
    MyEventBus().on<NewChatBeginEvent>().listen((event) {
      _newNote();
    });
  }

  //--------------------------------------------------------------------------//
  void _reloadServerModel() async {
    final result = await context.read<MainProvider>().checkServerConnection();
    if (result) {
      showToast(tr("l_success"), context: context, position: StyledToastPosition.center);
    } else {
      showToast(tr("l_error_url"), context: context, position: StyledToastPosition.center);
    }
    MyEventBus().fire(ReloadModelEvent());
    setState(() {});
  }

  //--------------------------------------------------------------------------//
  void _loadHistoryChats() async {
    _showWait = true;
    setState(() {});

    _messages = [];
    _questions = await context.read<MainProvider>().qdb.getDetails(context.read<MainProvider>().curGroupId);
    _questions.reversed.forEach((item) {
      if (item["image"] != null) {
        _makeImageMessageAdd(item["image"]);
      }
      int qtime = DateTime.parse(item["created"]).millisecondsSinceEpoch;
      _makeMessageAdd(_answerer, item["question"], Uuid().v4(), qtime, item["id"]);

      String answer = item["answer"];
      _makeMessageAdd(_user, answer, Uuid().v4(), qtime, item["id"]);
    });

    _showWait = false;
    if (mounted) setState(() {});
  }

  //--------------------------------------------------------------------------//
  void _makeMessageAdd(types.User user, String text, String unique, int time, [int? id = null]) async {
    final msg = types.TextMessage(
      author: user,
      createdAt: time,
      id: unique,
      text: text,
      metadata: {'id': id},
    );

    _messages.insert(0, msg);
    if (mounted) setState(() {});
  }

  //--------------------------------------------------------------------------//
  void _shareAll() {
    String sharedData = "";
    _questions.forEach((item) {
      sharedData += item["question"] + "\n\n" + item["answer"] + "\n\n" + item["engine"] + "\n" + item["created"] + "\n\n";
    });
    Share.share(sharedData);
  }

  //--------------------------------------------------------------------------//
  void _newNote([String? question]) {
    final provider = context.read<MainProvider>();
    provider.curGroupId = Uuid().v4();

    _messages = [];
    _questions = [];

    if (question != null) {
      _questionController.text = question;
    }
    setState(() {});
  }

  //--------------------------------------------------------------------------//
  Future<void> _startGeneration(String question) async {
    final provider = context.read<MainProvider>();

    String curAnswer = "...";
    types.TextMessage ansMwssage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: curAnswer,
    );
    _messages.insert(0, ansMwssage);
    setState(() {});

    List<ollama.Message> qmsg = [];

    // add previous questions
    // it's import for the model to understand the context
    _questions.forEach((item) {
      qmsg.add(ollama.Message(
        role: ollama.MessageRole.system,
        content: item["question"],
      ));
      qmsg.add(ollama.Message(
        role: ollama.MessageRole.user,
        content: item["answer"],
      ));
    });

    // add instruction
    qmsg.add(ollama.Message(
      role: ollama.MessageRole.system,
      content: provider.instruction,
    ));

    // add current question
    qmsg.add(ollama.Message(
      role: ollama.MessageRole.user,
      content: question,
      images: _selectedImage != null ? [_selectedImage!] : [],
    ));

    // generate chat
    try {
      final stream = provider.ollient!.generateChatCompletionStream(
        request: ollama.GenerateChatCompletionRequest(
          model: provider.selectedModel!,
          messages: qmsg,
          keepAlive: 1,
          options: ollama.RequestOptions(
            temperature: provider.temperature,
          ),
        ),
      );

      // get answer from stream
      String answer = '';
      _isProcessed = true;
      await for (final res in stream) {
        answer += (res.message.content ?? '');
        if (_messages.isNotEmpty) {
          if (_messages[0] is types.TextMessage) {
            _messages[0] = (_messages[0] as types.TextMessage).copyWith(text: answer);
          } else {
            _messages[0] = types.TextMessage(
              author: _answerer,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: const Uuid().v4(),
              text: answer,
            );
          }
          setState(() {});
        }
      }

      // Add Model Name to Answer
      answer += "\n\n_MyOllama - " + provider.selectedModel! + "_";
      setState(() {});
      _isProcessed = false;

      // save to DB
      await provider.qdb.insertQuestion(provider.curGroupId, provider.instruction, question, answer, _selectedImage, provider.selectedModel!);

      // Drawer Menu Reload
      MyEventBus().fire(RefreshMainListEvent());

      // Reload History
      _loadHistoryChats();
      _selectedImage = null;
    } catch (e) {
      _messages[0] = (_messages[0] as types.TextMessage).copyWith(text: tr("l_error_1"));
      setState(() {});
      print(e);
    }
  }

  //--------------------------------------------------------------------------//
  void _handleAttachmentPressed() async {
    XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500
    );
    if (image != null) {
      File file = File(image.path);
      List<int> imageBytes = file.readAsBytesSync();
      _selectedImage = base64Encode(imageBytes);
      _makeImageMessageAdd(_selectedImage!);
    }
  }

  //--------------------------------------------------------------------------//
  void _handlePreviewDataFetched(types.TextMessage message, types.PreviewData previewData) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final updatedMessage = (_messages[index] as types.TextMessage).copyWith(
      previewData: previewData,
    );

    setState(() {
      _messages[index] = updatedMessage;
    });
  }

  //--------------------------------------------------------------------------//
  void _beginAsking(types.PartialText message) async {
    FocusScope.of(context).requestFocus(FocusNode());

    types.TextMessage ask = types.TextMessage(
      author: _answerer,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );

    setState(() {
      _messages.insert(0, ask);
    });
    await _startGeneration(message.text);
  }

  //--------------------------------------------------------------------------//
  void _makeImageMessageAdd(String base64image) {
    final msg = types.CustomMessage(
      author: _answerer,
      id: Uuid().v4(),
      metadata: {'data': base64image, 'type': 'image'},
    );

    _messages.insert(0, msg);
    if (mounted) setState(() {});
  }

  //--------------------------------------------------------------------------//
  Widget _customMessageBuilder(types.CustomMessage message, {required int messageWidth}) {
    if (message.metadata!['type'] == 'image') {
      return RepaintBoundary(
        child: Image.memory(
          base64Decode(message.metadata!['data']),
          fit: BoxFit.contain,
        ),
      );
    }
    return const SizedBox();
  }

  //--------------------------------------------------------------------------//
  void _menuRunner(int number, types.TextMessage message) async {
    final provider = context.read<MainProvider>();

    final id = message.metadata!['id'];
    final record = await provider.qdb.getDetailsById(id);
    if (record.length > 0) {
      final question = record[0]["question"];
      final answer = record[0]["answer"];
      final created = record[0]["created"];
      final model = record[0]["engine"];
      final sharedData = "$question\n\n$answer\n\n$model\n$created";

      if (number == 0) {
        _newNote(question);
      } else if (number == 1) {
        Clipboard.setData(ClipboardData(text: sharedData));
        showToast(tr("l_copyed"), context: context, position: StyledToastPosition.center);
      } else if (number == 2) {
        Share.share(sharedData);
      } else if (number == 3) {
        final result = await AskDialog.show(context, title: tr("l_delete"), message: tr("l_delete_question"));
        if (result == true) {
          await provider.qdb.deleteRecord(id);
          // check is last data?
          provider.qdb.getDetails(context.read<MainProvider>().curGroupId).then((value) {
            if (value.length == 0) {
              MyEventBus().fire(RefreshMainListEvent());
              _newNote();
            } else {
              _loadHistoryChats();
            }
          });
        }
      }
    }
  }

  //--------------------------------------------------------------------------//
  Widget _messageMenu(types.TextMessage message) {

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(onPressed: (){
          _menuRunner(0, message);
        }, icon: Icon(Icons.open_in_new, color: Colors.white,)),
        IconButton(onPressed: (){
          _menuRunner(1, message);
        }, icon: Icon(Icons.copy, color: Colors.white,)),
        IconButton(onPressed: (){
          _menuRunner(2, message);
        }, icon: Icon(Icons.share, color: Colors.white,)),
        IconButton(onPressed: (){
          _menuRunner(3, message);
        }, icon: Icon(Icons.delete_outline, color: Colors.white,)),
      ],
    );
  }

  //--------------------------------------------------------------------------//
  Widget _textMessageBuilder(types.TextMessage message, {required int messageWidth, bool? showName}) {
    final isAnswer = message.author.id == _user.id;

    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        children: [
          MarkdownBody(
            data: message.text,
            selectable: true,
            onTapLink: (text, href, title) {
              launchUrl(Uri.parse(href!));
            },
          ),
          if (isAnswer && !_isProcessed) Column(
            children: [
              Divider(color: Colors.black12,),
              _messageMenu(message)
            ],
          )
        ],
      )
    );
  }

  //--------------------------------------------------------------------------//
  Widget _chatUI() {
    final provider = context.read<MainProvider>();

    return Chat(
      theme: DefaultChatTheme(
        primaryColor: Colors.orangeAccent,
        inputBackgroundColor: Colors.indigo,
        inputTextCursorColor: Colors.white,
        backgroundColor: Colors.grey.shade200,
        messageInsetsHorizontal: 16,
        messageInsetsVertical: 10,
      ),
      inputOptions: InputOptions(
        textEditingController: _questionController,
      ),
      messages: _messages,
      onAttachmentPressed: _handleAttachmentPressed,
      onPreviewDataFetched: _handlePreviewDataFetched,
      onSendPressed: _beginAsking,
      user: _user,
      l10n: ChatL10nEn(
          inputPlaceholder: tr("l_input_question"),
          emptyChatPlaceholder: provider.serveConnected ? tr("l_no_conversation") : tr("l_no_server")
      ),
      customMessageBuilder: _customMessageBuilder,
      textMessageBuilder: (message, {required messageWidth, required showName}) =>
          _textMessageBuilder(message, messageWidth: messageWidth, showName: showName),
    );
  }

  //--------------------------------------------------------------------------//
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: Scaffold(
          body: Stack(
            children: [
              _chatUI(),
              _showWait ? Center(child: CircularProgressIndicator()) : SizedBox()
            ],
          ),
        ));
  }
}
