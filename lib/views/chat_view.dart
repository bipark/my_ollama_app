import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:uuid/uuid.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:image_picker/image_picker.dart';

import '../provider/main_provider.dart';
import '../helpers/event_bus.dart';
import '../widgets/dialogs.dart';
import '../widgets/drop_menu.dart';
import '../services/chat_service.dart';

import 'settings.dart';
import '../utils/platform_utils.dart';

class ChatView extends StatefulWidget {
  const ChatView({Key? key}) : super(key: key);

  @override
  createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final ImagePicker _picker = ImagePicker();
  List<types.Message> _messages = [];
  List _questions = [];
  final _user = const types.User(id: '82091008-a484-4a89-ae75-a22bf8d6f3ac');
  final _answerer =
      const types.User(id: '82091008-a484-4a89-ae75-a22bf8d6f3ad');
  String? _selectedImage;
  TextEditingController _questionController = TextEditingController();
  bool _showWait = false;
  bool _isProcessed = false;
  late final ChatService _chatService;
  String _currentGroupId = '';

  //--------------------------------------------------------------------------//
  @override
  void initState() {
    super.initState();
    _initEventConnector();
    _init();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _chatService.dispose();
    super.dispose();
  }

  //--------------------------------------------------------------------------//
  Future<void> _init() async {
    _chatService = ChatService(
        context: context,
        questions: _questions,
        messages: _messages,
        answerer: _answerer,
        user: _user,
        setState: () => setState(() {}),
        onMessageUpdate: _handleMessageUpdate);

    final rightMenu = [
      IconButton(onPressed: _newNote, icon: Icon(Icons.add)),
      DropMenu(_reloadServerModel, _newNote, _shareAll, _showSettings)
    ];
    MyEventBus().fire(ChangeTitleEvent(tr("l_myollama"), rightMenu));
  }

  //--------------------------------------------------------------------------//
  void _showSettings() {
    // 설정 열기 전 현재 서버 주소 저장
    final provider = context.read<MainProvider>();
    final oldServerUrl = provider.baseUrl;

    if (isDesktopOrTablet()) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          final size = MediaQuery.of(context).size;
          return Dialog(
            child: Container(
              width: size.width * 0.8,
              height: size.height * 0.8,
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(tr("l_settings"),
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop();

                          // 설정 창이 닫힐 때 서버 주소 변경 확인
                          final newServerUrl = provider.baseUrl;
                          if (oldServerUrl != newServerUrl) {
                            // 서버 주소가 변경되었으면 모델 리로드
                            MyEventBus().fire(ReloadModelEvent());
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: MySettings(),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MySettings()),
      ).then((_) {
        final newServerUrl = provider.baseUrl;
        if (oldServerUrl != newServerUrl) {
          // 서버 주소가 변경되었으면 모델 리로드
          MyEventBus().fire(ReloadModelEvent());
        }
      });
    }
  }

  //--------------------------------------------------------------------------//
  void _initEventConnector() async {
    MyEventBus().on<LoadHistoryGroupListEvent>().listen((event) {
      _loadHistoryChats();
    });
    MyEventBus().on<NewChatBeginEvent>().listen((event) {
      _newNote();
    });
    MyEventBus().on<ChatDoneEvent>().listen((event) {
      _loadHistoryChats();
      _isProcessed = false;
      setState(() {});
    });
  }

  //--------------------------------------------------------------------------//
  void _reloadServerModel() async {
    final result = await context.read<MainProvider>().checkServerConnection();
    MyEventBus().fire(ReloadModelEvent());
    setState(() {});

    if (result) {
      showToast(tr("l_success"),
          context: context, position: StyledToastPosition.center);
    } else {
      showToast(tr("l_error_url"),
          context: context, position: StyledToastPosition.center);
    }
  }

  //--------------------------------------------------------------------------//
  void _loadHistoryChats() async {
    _showWait = true;
    setState(() {});

    _messages = [];
    _questions = await context
        .read<MainProvider>()
        .qdb
        .getDetails(context.read<MainProvider>().curGroupId);
    _questions.reversed.forEach((item) {
      if (item["image"] != null) {
        _makeImageMessageAdd(item["image"]);
      }
      int qtime = DateTime.parse(item["created"]).millisecondsSinceEpoch;
      _makeMessageAdd(_user, item["question"], Uuid().v4(), qtime, item["id"]);

      String answer = item["answer"];
      _makeMessageAdd(_answerer, answer, Uuid().v4(), qtime, item["id"]);
    });

    _showWait = false;
    if (mounted) setState(() {});
  }

  //--------------------------------------------------------------------------//
  void _makeMessageAdd(types.User user, String text, String unique, int time,
      [int? id = null]) async {
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
    if (_questions.length == 0) return;

    _questions.forEach((item) {
      sharedData += item["question"] +
          "\n\n" +
          item["answer"] +
          "\n\n" +
          item["engine"] +
          "\n" +
          item["created"] +
          "\n\n";
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
    } else {
      _questionController.clear();
    }

    setState(() {});
  }

  //--------------------------------------------------------------------------//
  void _handleMessageUpdate(String content) {
    // 디버그 로그
    if (_messages.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    // 첫 번째 메시지가 응답자(AI)의 메시지인지 확인
    if (_messages[0].author.id != _answerer.id) {
      return;
    }

    // 현재 메시지 텍스트 확인
    final currentText = (_messages[0] as types.TextMessage).text;
    if (currentText == content) {
      return;
    }

    setState(() {
      _messages[0] =
          (_messages[0] as types.TextMessage).copyWith(text: content);
    });
  }

  //--------------------------------------------------------------------------//
  void _beginAsking(types.PartialText message) async {
    // 질문이 입력되면 키보드 감추기
    FocusScope.of(context).unfocus();

    final provider = context.read<MainProvider>();
    String question = message.text;

    if (question.isEmpty) return;

    // 이미 처리 중인 경우 중복 요청 방지
    if (_isProcessed) {
      return;
    }

    // 사용자 메시지 추가
    types.TextMessage ask = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: question,
    );

    setState(() {
      _messages.insert(0, ask);
      _isProcessed = true; // 처리 중 상태 설정
    });

    // 선택된 모델 확인
    String? modelToUse = provider.selectedModel;

    // 선택된 모델이 없으면 첫 번째 모델 사용
    if (modelToUse == null && provider.modelList!.isNotEmpty) {
      modelToUse = provider.modelList!.first.model;
      if (modelToUse != null) {
        provider.setSelectedModel(modelToUse);
      } else {
        setState(() {
          _isProcessed = false;
        });
        showToast(tr("l_error_no_models"),
            context: context, position: StyledToastPosition.center);
        return;
      }
    }

    if (mounted) {
      _chatService.selectedImage = _selectedImage;

      try {
        // 응답 메시지 미리 생성
        types.TextMessage ansMessage = types.TextMessage(
          author: _answerer,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          text: "...",
        );

        setState(() {
          _messages.insert(0, ansMessage);
        });

        // 채팅 서비스를 통해 응답 생성 시작
        await _chatService.startGeneration(
          question: question,
          modelName: modelToUse!,
          onMessageUpdate: (content) {
            // 디버그 로그 추가
            _handleMessageUpdate(content);
          },
          onError: (error) {
            // 오류 메시지로 UI 업데이트
            if (_messages.isNotEmpty &&
                _messages[0].author.id == _answerer.id) {
              setState(() {
                _messages[0] = (_messages[0] as types.TextMessage).copyWith(
                  text: "오류: $error",
                );
              });
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
            setState(() {
              _isProcessed = false;
            });
          },
          onComplete: () {
            setState(() {
              _isProcessed = false;
            });
          },
        );
      } catch (e) {
        // 오류 메시지로 UI 업데이트
        if (_messages.isNotEmpty && _messages[0].author.id == _answerer.id) {
          setState(() {
            _messages[0] = (_messages[0] as types.TextMessage).copyWith(
              text: "오류: $e",
            );
          });
        }

        setState(() {
          _isProcessed = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("오류: $e")),
        );
      }
    }
  }

  //--------------------------------------------------------------------------//
  void _handleAttachmentPressed() async {
    XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500);
    if (image != null) {
      File file = File(image.path);
      List<int> imageBytes = file.readAsBytesSync();
      _selectedImage = base64Encode(imageBytes);
      _makeImageMessageAdd(_selectedImage!);
    }
  }

  //--------------------------------------------------------------------------//
  void _handlePreviewDataFetched(
      types.TextMessage message, types.PreviewData previewData) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final updatedMessage = (_messages[index] as types.TextMessage).copyWith(
      previewData: previewData,
    );

    setState(() {
      _messages[index] = updatedMessage;
    });
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
  Widget _customMessageBuilder(types.CustomMessage message,
      {required int messageWidth}) {
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
        _newNote();
      } else if (number == 1) {
        Clipboard.setData(ClipboardData(text: sharedData));
        showToast(tr("l_copyed"),
            context: context, position: StyledToastPosition.center);
      } else if (number == 2) {
        Share.share(sharedData);
      } else if (number == 3) {
        final result = await AskDialog.show(context,
            title: tr("l_delete"), message: tr("l_delete_question"));
        if (result == true) {
          await provider.qdb.deleteRecord(id);
          // check is last data?
          provider.qdb
              .getDetails(context.read<MainProvider>().curGroupId)
              .then((value) {
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
        IconButton(
            onPressed: () {
              _menuRunner(0, message);
            },
            icon: Icon(
              Icons.open_in_new,
              color: Colors.white,
            )),
        IconButton(
            onPressed: () {
              _menuRunner(1, message);
            },
            icon: Icon(
              Icons.copy,
              color: Colors.white,
            )),
        IconButton(
            onPressed: () {
              _menuRunner(2, message);
            },
            icon: Icon(
              Icons.share,
              color: Colors.white,
            )),
        IconButton(
            onPressed: () {
              _menuRunner(3, message);
            },
            icon: Icon(
              Icons.delete_outline,
              color: Colors.white,
            )),
      ],
    );
  }

  //--------------------------------------------------------------------------//
  Widget _textMessageBuilder(types.TextMessage message,
      {required int messageWidth, bool? showName}) {
    final isAnswer = message.author.id == _answerer.id;

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
            if (isAnswer && !_isProcessed)
              Column(
                children: [
                  Divider(
                    color: Colors.black12,
                  ),
                  _messageMenu(message)
                ],
              )
          ],
        ));
  }

  //--------------------------------------------------------------------------//
  Widget _chatUI() {
    final provider = context.read<MainProvider>();

    return Chat(
      theme: DefaultChatTheme(
        primaryColor: Colors.white,
        secondaryColor: Colors.orangeAccent,
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
          emptyChatPlaceholder: provider.serveConnected
              ? tr("l_no_conversation")
              : tr("l_no_server")),
      customMessageBuilder: _customMessageBuilder,
      textMessageBuilder: (message,
              {required messageWidth, required showName}) =>
          _textMessageBuilder(message,
              messageWidth: messageWidth, showName: showName),
    );
  }

  //--------------------------------------------------------------------------//
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              // 화면의 빈 공간을 터치하면 키보드 숨기기
              FocusScope.of(context).unfocus();
            },
            child: _chatUI(),
          ),
          _showWait ? Center(child: CircularProgressIndicator()) : SizedBox()
        ],
      ),
    );
  }
}
