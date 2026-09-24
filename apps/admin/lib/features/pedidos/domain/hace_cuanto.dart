/// Hace cuanto se creo un pedido, dicho como lo diria una persona (HU-06.1).
///
/// Dart puro y con [ahora] por parametro: la hora del sistema no se lee aca, asi
/// que se prueba con una hora fija. `null` --un pedido sin `creadaEn`-- no
/// inventa una fecha: dice que no la tiene.
///
/// Los ultimos dos dias se dicen relativos (*"hace 5 min"*, *"ayer"*); despues,
/// la fecha, porque *"hace 9 dias"* obliga a contar.
String haceCuanto(DateTime? creada, DateTime ahora) {
  if (creada == null) return 'sin fecha';
  final minutos = ahora.difference(creada).inMinutes;
  // Un reloj adelantado (el del servidor contra el de esta maquina) puede dar
  // negativo: no es "dentro de 3 minutos", es recien.
  if (minutos < 1) return 'recién';
  if (minutos < 60) return 'hace $minutos min';
  final horas = ahora.difference(creada).inHours;
  if (horas < 24) return 'hace $horas h';
  final ayer = DateTime(ahora.year, ahora.month, ahora.day - 1);
  final dia = DateTime(creada.year, creada.month, creada.day);
  if (dia == ayer) return 'ayer';
  final fecha = '${_dos(creada.day)}/${_dos(creada.month)}';
  return creada.year == ahora.year ? fecha : '$fecha/${creada.year}';
}

String _dos(int n) => n.toString().padLeft(2, '0');
