/// Excepciones compartidas por los repositorios sociales cuando
/// contenido es rechazado por la capa de moderación o por reglas
/// de negocio (bloqueo entre usuarios, largo máximo, etc.).
class ContentRejectedException implements Exception {
  final String reason;
  const ContentRejectedException(this.reason);
  @override
  String toString() => reason;
}

class BlockedUserException implements Exception {
  const BlockedUserException();
  @override
  String toString() =>
      'No podés enviar mensajes a este usuario (bloqueo activo).';
}
