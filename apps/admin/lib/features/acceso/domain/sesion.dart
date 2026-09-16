/// En que estado esta quien abrio el panel. Es un tipo cerrado: las rutas y
/// las pantallas hacen `switch` sobre el y el compilador avisa si falta un
/// caso.
///
/// El permiso es el custom claim `rol: admin` (ARQUITECTURA §9.2), un solo
/// rol para toda la familia. Lo que diga el token en el cliente NO protege
/// nada —eso lo hacen las reglas, que miran el mismo claim—: aca solo decide
/// que pantalla se muestra.
sealed class Sesion {
  const Sesion();
}

/// Todavia no se sabe: Firebase esta leyendo la sesion guardada.
final class Resolviendo extends Sesion {
  const Resolviendo();
}

/// Nadie entro.
final class SinSesion extends Sesion {
  const SinSesion();
}

/// Entro una cuenta que no tiene el claim (HU-01.2).
final class SinPermiso extends Sesion {
  const SinPermiso(this.mail);
  final String mail;
}

/// Entro una cuenta y su token no se pudo leer, casi siempre por la red.
///
/// Existe para que un corte NO se lea como "no tenes permiso": es el reverso
/// de HU-01.2, que pide no confundir un permiso que falta con un panel roto.
final class Inaccesible extends Sesion {
  const Inaccesible(this.mail);
  final String mail;
}

/// Entro alguien de la familia.
final class Operador extends Sesion {
  const Operador(this.mail);
  final String mail;
}

/// El valor del claim `rol` que abre el panel. Es el mismo string que mira
/// `esAdmin()` en `firestore.rules` y que escribe `scripts/acceso/acceso.mjs`.
const rolDelPanel = 'admin';

/// La sesion de una cuenta que entro, a partir de los claims de su token.
Sesion sesionDesde({
  required String? mail,
  required Map<String, dynamic>? claims,
}) {
  final quien = mail ?? '';
  return claims?['rol'] == rolDelPanel ? Operador(quien) : SinPermiso(quien);
}
