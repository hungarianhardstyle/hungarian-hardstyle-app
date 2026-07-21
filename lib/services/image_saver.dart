import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class ImageSaver {
  static const _channel = MethodChannel('hu_hs/media');
  static final Dio _dio = Dio();

  static Future<void> saveFromUrl(String url, {required String name}) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('A kép letöltése sikertelen.');
    }
    await _channel.invokeMethod<void>('saveImage', <String, dynamic>{
      'bytes': Uint8List.fromList(bytes),
      'name': name,
    });
  }
}
