import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as server;

class Manager {
  static const _storagePath = 'storage';

  static const _address = 'localhost';
  static const _port = 8080;

  static void start() {
    _createStorage();

    _createRouter();
  }

  static void _createStorage() async {
    final storage = Directory(_storagePath);

    if (!await storage.exists()) {
      storage.create();
    }
  }

  static void _createRouter() async {
    final router = Router()
      ..head('/<filePath|.*>', _head)
      ..put('/<filePath|.*>', _put)
      ..get('/<fileOrDirectoryPath|.*>', _get)
      ..delete('/<filePath|.*>', _delete);   

    await server.serve(router.call, _address, _port);
  }

  static Future<Response> _put(Request request) async {
    final filePath = request.params['filePath'] ?? '';

    final file = File('$_storagePath/$filePath');

    if (await file.exists()) {
      file.delete();
    }
    file.create(recursive: true);

    final content = await request.readAsString();

    await file.writeAsString(content);

    return Response(HttpStatus.created);
  }

  static Future<Response> _get(Request request) async {
    final fileOrDirectoryPath = request.params['fileOrDirectoryPath'] ?? '';

    final file = File('$_storagePath/$fileOrDirectoryPath');
    final directory = Directory('$_storagePath/$fileOrDirectoryPath');

    if (await file.exists()) {
      return Response.ok(await file.readAsBytes(), 
                         headers: { HttpHeaders.contentTypeHeader: lookupMimeType(fileOrDirectoryPath) ?? 'application/octet-stream', });
    } else if (await directory.exists()) {
      final files = await directory.list().toList();
      return Response.ok(jsonEncode(files.map((f) => f.path.split('/').last).toList()), 
                         headers: { HttpHeaders.contentTypeHeader: 'application/json', });
    } else {
      return Response.notFound('File or directory not found');
    }
  }

  static Future<Response> _head(Request request) async {
    final filePath = request.params['filePath'] ?? '';

    final file = File('$_storagePath/$filePath');
    
    if (!await file.exists()) {
      return Response.notFound('File not found');
    }

    final stat = await file.stat();
    final size = stat.size;
    final changed = stat.changed;
    
    return Response.ok('', headers: {
      'X-File-Size': size.toString(),
      'X-File-Changed': changed.toString(),
    });
  }

  static Future<Response> _delete(Request request) async {
    final filePath = request.params['filePath'] ?? '';

    final file = File('$_storagePath/$filePath');

    if (await file.exists()) {
      await file.delete();
      return Response.ok('File deleted');
    } else {
      return Response.notFound('File not found');
    }
  }
}