import 'package:dio/dio.dart';

const speechConnectTimeout = Duration(seconds: 15);
const speechSendTimeout = Duration(seconds: 30);
const speechReceiveTimeout = Duration(seconds: 120);

Dio createSpeechDio() {
  return Dio(
    BaseOptions(
      connectTimeout: speechConnectTimeout,
      sendTimeout: speechSendTimeout,
      receiveTimeout: speechReceiveTimeout,
    ),
  );
}
