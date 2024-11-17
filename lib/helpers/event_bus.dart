import 'package:flutter/material.dart';
import 'package:event_bus/event_bus.dart';

//----------------------------------------------------------------------------//
class MyEventBus extends EventBus {
  static final MyEventBus _instance = MyEventBus._internal();

  factory MyEventBus() {
    return _instance;
  }

  MyEventBus._internal() {
    EventBus _instance = EventBus();
  }
}

class UserLogStatusChangeEvent {
  UserLogStatusChangeEvent();
}

class ChangeTitleEvent {
  String title;
  List<Widget> action;
  ChangeTitleEvent(this.title, this.action);
}

class RefreshMainListEvent {
  RefreshMainListEvent();
}

class LoadHistoryGroupListEvent {
  LoadHistoryGroupListEvent();
}

class CloseDrawerEvent {
  CloseDrawerEvent();
}

class NewChatBeginEvent {
  NewChatBeginEvent();
}