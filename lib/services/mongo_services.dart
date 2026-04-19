import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';

class MongoService {
  static final MongoService _instance = MongoService._internal();
  Db? _db;
  DbCollection? _collection;
  final String _source = "mongo_service.dart";

  factory MongoService() => _instance;
  MongoService._internal();

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<DbCollection> _getSafeCollection() async {
    if (_db == null || !_db!.isConnected || _collection == null) {
      await connect();
    }
    return _collection!;
  }

  Future<void> connect() async {
    try {
      final isOnline = await _hasInternetConnection();
      if (!isOnline) {
        throw Exception(
          "Tidak ada koneksi internet. Pastikan WiFi atau data seluler aktif.",
        );
      }

      final dbUri = dotenv.env['MONGODB_URI'];
      if (dbUri == null) throw Exception("MONGODB_URI tidak ditemukan di .env");

      _db = await Db.create(dbUri);
      await _db!.open().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception(
          "Koneksi Timeout. Cek IP Whitelist atau Sinyal HP.",
        ),
      );

      _collection = _db!.collection('logs');

      await LogHelper.writeLog(
        "DATABASE: Terhubung & Koleksi Siap",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "DATABASE: Gagal Koneksi - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  Future<List<LogModel>> getLogs({String? username, String? teamId}) async {
    try {
      final collection = await _getSafeCollection();

      SelectorBuilder query;

      if (teamId != null && teamId.isNotEmpty) {
        query = where.eq('teamId', teamId);
      } else if (username != null) {
        query = where.eq('username', username);
      } else {
        final List<Map<String, dynamic>> data =
            await collection.find().toList();
        return data.map((json) => LogModel.fromMap(json)).toList();
      }

      final List<Map<String, dynamic>> data =
          await collection.find(query).toList();
      return data.map((json) => LogModel.fromMap(json)).toList();
    } catch (e) {
      await LogHelper.writeLog(
          "ERROR: Fetch Failed - $e", source: _source, level: 1);
      rethrow;
    }
  }

  Future<void> insertLog(LogModel log) async {
    try {
      final collection = await _getSafeCollection();
      await collection.insertOne(log.toMap());
      await LogHelper.writeLog(
        "SUCCESS: Data '${log.title}' Saved to Cloud",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
          "ERROR: Insert Failed - $e", source: _source, level: 1);
      rethrow;
    }
  }

  Future<void> updateLog(LogModel log) async {
    try {
      final collection = await _getSafeCollection();
      if (log.id == null) throw Exception("ID Log tidak ditemukan untuk update");
      await collection.replaceOne(where.id(log.id!), log.toMap());
      await LogHelper.writeLog(
        "DATABASE: Update '${log.title}' Berhasil",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
          "DATABASE: Update Gagal - $e", source: _source, level: 1);
      rethrow;
    }
  }

  Future<void> deleteLog(ObjectId id) async {
    try {
      final collection = await _getSafeCollection();
      await collection.remove(where.id(id));
      await LogHelper.writeLog(
        "DATABASE: Hapus ID $id Berhasil",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
          "DATABASE: Hapus Gagal - $e", source: _source, level: 1);
      rethrow;
    }
  }

  /// Hapus log berdasarkan hex string dari ObjectId.
  /// Digunakan saat flush pending-delete queue.
  Future<void> deleteLogByHex(String hexId) async {
    try {
      final objectId = ObjectId.fromHexString(hexId);
      await deleteLog(objectId);
    } catch (e) {
      await LogHelper.writeLog(
          "DATABASE: Hapus by Hex Gagal - $e", source: _source, level: 1);
      rethrow;
    }
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
    }
  }
}