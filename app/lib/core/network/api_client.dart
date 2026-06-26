import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: ApiConstants.connectTimeout,
    receiveTimeout: ApiConstants.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(AuthInterceptor());
  return dio;
});

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final isAuthEntry = options.path == '/auth/login' ||
        options.path == '/auth/register' ||
        options.path == '/auth/wechat';
    if (token != null && !isAuthEntry) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthEntry = err.requestOptions.path == '/auth/login' ||
        err.requestOptions.path == '/auth/register' ||
        err.requestOptions.path == '/auth/wechat';
    if (err.response?.statusCode == 401 && !isAuthEntry) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_user');
    }
    handler.reject(_friendlyError(err));
  }

  DioException _friendlyError(DioException err) {
    final serverMessage = err.response?.data is Map
        ? (err.response?.data as Map)['error']?.toString()
        : null;
    final message = serverMessage ?? switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        '网络好像不太稳，稍后再试试',
      DioExceptionType.connectionError => '吧台暂时连不上，请确认网络或稍后再试',
      DioExceptionType.badResponse => '操作没有成功，请稍后再试',
      _ => '出了点小状况，请稍后再试',
    };
    return DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: message,
      message: message,
    );
  }
}
