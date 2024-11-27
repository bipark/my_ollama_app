import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:path/path.dart';
import '../provider/main_provider.dart';


class QDatabase {
  static final QDatabase _instance = QDatabase._init();
  static Database? _database;

  final sql_questions = '''
        CREATE TABLE IF NOT EXISTS questions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          groupid TEXT NOT NULL,
          instruction TEXT,
          question TEXT,
          answer TEXT,
          image TEXT,
          created TEXT,
          engine TEXT
        );''';
  //--------------------------------------------------------------------------//
  QDatabase._init() {
  }

  //--------------------------------------------------------------------------//
  factory QDatabase() {
    return _instance;
  }

  //--------------------------------------------------------------------------//
  Future<Database> init() async {
    if (_database != null) return _database!;
    _database = await _initDB('my_ollama.db');
    _makeFirstRow();
    return _database!;
  }

  //--------------------------------------------------------------------------//
  Future<Database> _initDB(String filePath) async {

    final dbPath = await getDatabasesPath();
    final path = dbPath + "/" + filePath;
    // print("DB Path: $path");

    final options = OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB
    );

    return await databaseFactory.openDatabase(path, options: options);
  }

  //--------------------------------------------------------------------------//
  Future _makeFirstRow() async {
    final db = await _instance.init();

    final groupid = Uuid().v4();
    final questions = await db.rawQuery("SELECT * FROM questions");
    if (questions.length == 0) {
      insertQuestion(groupid, "", tr("l_q1"), tr("l_a1"), null, "ollama");
      insertQuestion(groupid, "", tr("l_q2"), tr("l_a2"), null, "ollama");
      insertQuestion(groupid, "", tr("l_q3"), tr("l_a3"), null, "ollama");
    }
  }

  //--------------------------------------------------------------------------//
  Future _createDB(Database db, int version) async {
    try {
      // Master
      await db.execute(sql_questions);
    } catch (e) {
      print("Error Creating TABLES: $e");
    }
  }

  //--------------------------------------------------------------------------//
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
    } catch (e) {
      print("Error Upgrading TABLES: $e");
    }
  }

  //--------------------------------------------------------------------------//
  Future<void> insertQuestion(String groupid, String instruction, String question, String answer, String? image, String engine) async {
    try {
      String created = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final db = await _instance.init();
      await db.rawInsert('INSERT INTO questions(groupid, instruction, question, answer, image, created, engine) VALUES(?, ?, ?, ?, ?, ?, ?)',
          [groupid, instruction, question, answer, image, created, engine]);
    } catch (e) {
      print("Error Inserting Master: $e");
    }
  }

  //--------------------------------------------------------------------------//
  Future<List> getTitles() async {
    final db = await _instance.init();
    return await db.rawQuery("select * from questions group by groupid order by id desc");
  }

  //--------------------------------------------------------------------------//
  Future<List> getDetails(String groupid) async {
    final db = await _instance.init();
    List details = await db.rawQuery("SELECT * FROM questions WHERE groupid = ? ORDER BY created DESC", [groupid]);
    return details;
  }

  //--------------------------------------------------------------------------//
  Future<List> getDetailsById(int id) async {
    final db = await _instance.init();
    List details = await db.rawQuery("SELECT * FROM questions WHERE id = ?", [id]);
    return details;
  }

  //--------------------------------------------------------------------------//
  Future<List> searchKeywords(String keyword) async {
    final db = await _instance.init();
    final sql = "SELECT m.* FROM questions m "+
        "LEFT JOIN qdetails d ON m.id = d.pid "+
        "WHERE d.question LIKE ? OR d.answer LIKE ? "+
        "ORDER BY m.created DESC";
    return await db.rawQuery(sql, ["%$keyword%", "%$keyword%"]);
  }

  //--------------------------------------------------------------------------//
  Future<void> deleteQuestions(String groupid) async {
    try {
      final db = await _instance.init();
      await db.rawDelete('DELETE FROM questions WHERE groupid = ?', [groupid]);
    } catch (e) {
      print("Error Deleting Master: $e");
    }
  }

  //--------------------------------------------------------------------------//
  Future<void> deleteRecord(int id) async {
    try {
      final db = await _instance.init();
      await db.rawDelete('DELETE FROM questions WHERE id = ?', [id]);
    } catch (e) {
      print("Error Deleting Master: $e");
    }
  }

  //--------------------------------------------------------------------------//
  Future<void> deleteAllRecords() async {
    try {
      final db = await _instance.init();
      await db.rawDelete('DELETE FROM questions', []);
    } catch (e) {
      print("Error Deleting Master: $e");
    }
  }

}