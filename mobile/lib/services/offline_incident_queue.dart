import 'dart:convert';

import 'package:sqflite/sqflite.dart';

class OfflineIncidentQueue {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = '${await getDatabasesPath()}/resqdrive_queue.db';
    _database = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE incident_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    });
    return _database!;
  }

  Future<void> enqueue(Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert('incident_queue', {'payload': jsonEncode(payload), 'created_at': DateTime.now().toUtc().toIso8601String()});
  }

  Future<List<Map<String, dynamic>>> pending() async {
    final db = await database;
    final rows = await db.query('incident_queue', orderBy: 'id ASC');
    return rows.map((row) => {
      'id': row['id'] as int,
      'payload': jsonDecode(row['payload'] as String) as Map<String, dynamic>,
    }).toList();
  }

  Future<void> remove(int id) async {
    final db = await database;
    await db.delete('incident_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}