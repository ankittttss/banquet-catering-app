/// Base class for all Dawat domain exceptions. Feature code should throw one
/// of these rather than a raw [Exception] so the UI can render a meaningful
/// message and the right retry affordance.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Network / HTTP / Supabase API failures. UI should offer "Retry".
class NetworkException extends AppException {
  const NetworkException({
    String message = 'Network error',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Caller passed invalid input (form validation failed server-side, etc.).
/// UI should usually surface the message inline.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

/// Auth state required but missing (user signed out, token expired).
/// UI should route back to login.
class AuthRequiredException extends AppException {
  const AuthRequiredException({
    String message = 'Please sign in to continue',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Backend refused the request (RLS, permissions, etc.).
class PermissionException extends AppException {
  const PermissionException({
    String message = 'Not allowed',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Catch-all for anything else. Prefer the specific subclasses above.
class UnknownException extends AppException {
  const UnknownException({
    String message = 'Something went wrong',
    Object? cause,
  }) : super(message, cause: cause);
}

/// Map a raw thrown object into the most specific [AppException] we can.
AppException asAppException(Object error) {
  if (error is AppException) return error;
  final s = error.toString().toLowerCase();
  if (s.contains('socket') ||
      s.contains('network') ||
      s.contains('timeout') ||
      s.contains('connection')) {
    return NetworkException(message: error.toString(), cause: error);
  }
  if (s.contains('not authenticated') ||
      s.contains('jwt')) {
    return AuthRequiredException(message: error.toString(), cause: error);
  }
  if (s.contains('row-level security') ||
      s.contains('permission') ||
      s.contains('denied')) {
    return PermissionException(message: error.toString(), cause: error);
  }
  return UnknownException(message: error.toString(), cause: error);
}
