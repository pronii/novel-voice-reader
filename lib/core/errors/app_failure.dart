final class AppFailure {
  const AppFailure(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppFailure && message == other.message;

  @override
  int get hashCode => message.hashCode;
}
