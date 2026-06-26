class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '/api',
  );
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  static String get origin {
    if (baseUrl.startsWith('http://') || baseUrl.startsWith('https://')) {
      return baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    }
    return '';
  }

  static String? resolveUrl(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return path.startsWith('/') ? '$origin$path' : '$origin/$path';
  }
}
