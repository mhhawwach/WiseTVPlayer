import 'package:dio/dio.dart';

/// A short, user-facing reason for a failed content load.
///
/// Never shows the raw exception: Dio's messages quote the request URL, which
/// carries the playlist's username and password.
String friendlyLoadError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return "The server didn't respond in time. Try again, or use Refresh "
            'in the side menu.';
      case DioExceptionType.connectionError:
        return "Can't reach the server. Check the internet connection.";
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        return 'The server returned an error${code != null ? ' ($code)' : ''}.';
      case DioExceptionType.unknown:
        if (error.error is FormatException) {
          return 'The server sent an incomplete response. Use Refresh in the '
              'side menu to try again.';
        }
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        break;
    }
  }
  return "Couldn't load this list. Use Refresh in the side menu to try again.";
}
