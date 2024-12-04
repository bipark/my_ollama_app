import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:ollama_dart/ollama_dart.dart' as ollama;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../provider/main_provider.dart';
import '../helpers/event_bus.dart';

class ChatService {
  final BuildContext context;
  final List questions;
  final List<types.Message> messages;
  final types.User answerer;
  final types.User user;
  final Function setState;
  String? selectedImage;
  final _messageController = StreamController<String>.broadcast();

  Stream<String> get messageStream => _messageController.stream;

  ChatService({
    required this.context,
    required this.questions,
    required this.messages,
    required this.answerer,
    required this.user,
    required this.setState,
    this.selectedImage,
  });

  void dispose() {
    _messageController.close();
  }

  Future<void> startGeneration(String question) async {
    final provider = context.read<MainProvider>();

    String curAnswer = "...";
    types.TextMessage ansMwssage = types.TextMessage(
      author: user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: curAnswer,
    );
    messages.insert(0, ansMwssage);
    setState();

    List<ollama.Message> qmsg = [];

    // add previous questions
    questions.forEach((item) {
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
      images: selectedImage != null ? [selectedImage!] : [],
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
      int totalTokens = 0;
      final startTime = DateTime.now();
      String currentTokensPerSecond = "0.0";

      await for (final res in stream) {
        totalTokens += ((res.message.content ?? '').length / 4).ceil();
        final currentTime = DateTime.now();
        final elapsedSeconds = currentTime.difference(startTime).inMilliseconds / 1000.0;
        currentTokensPerSecond = (totalTokens / elapsedSeconds).toStringAsFixed(1);

        final newContent = res.message.content ?? '';
        answer += newContent;

        _messageController.add(answer + '\n\nToken/Sec: $currentTokensPerSecond');
      }

      // Calculate final tokens per second
      final endTime = DateTime.now();
      final totalElapsedSeconds = endTime.difference(startTime).inMilliseconds / 1000.0;
      final finalTokensPerSecond = (totalTokens / totalElapsedSeconds).toStringAsFixed(1);

      // Add Model Name and final tokens per second to Answer
      answer += "\n\n   _MyOllama - ${provider.selectedModel!}   " + "\nToken/Sec: $finalTokensPerSecond" + "_";
      _messageController.add(answer);

      // End of Chat
      MyEventBus().fire(ChatDoneEvent());

      // save to DB
      await provider.qdb.insertQuestion(provider.curGroupId, provider.instruction, question, answer, selectedImage, provider.selectedModel!);

      // Drawer Menu Reload
      MyEventBus().fire(RefreshMainListEvent());

      selectedImage = null;
    } catch (e) {
      _messageController.add(tr("l_error_1"));
      print(e);
    }
  }
}
