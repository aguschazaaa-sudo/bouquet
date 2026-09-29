/// Que mira la bandeja: tres fichas, no siete (ADR 027). Antes habia una por
/// estado de entrega mas *"Requieren acción"*, y un pedido entregado se buscaba
/// adivinando en cual estaba.
///
/// Es la clave de la familia del provider: un `enum` tiene igualdad por valor,
/// asi que volver a elegir la misma ficha no la relee. El orden es el de las
/// fichas; *Para hacer* va primero, que es con la que abre la pantalla.
enum VistaDeBandeja {
  /// Lo que todavia no salio, lo que volvio sin entregar y lo terminado que
  /// pide plata ([tramosParaHacer]).
  paraHacer,

  /// Lo que salio y todavia no llego.
  enCamino,

  /// Entregados y cancelados.
  terminados,
}
