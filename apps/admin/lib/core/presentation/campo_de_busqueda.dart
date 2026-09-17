import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// El buscador. La direccion visual del panel es *"la busqueda y los
/// renglones de la libreta"* (la mezcla C que eligio el dueno, ADR 011 §4):
/// la busqueda esta arriba de todo y es lo primero que se ve.
///
/// No guarda su propio texto: lo recibe y lo avisa. Asi lo que se escribio
/// **sobrevive a ir a otra pantalla y volver**, que es lo que hace un
/// `StateProvider` y no hace un `TextEditingController` adentro del widget.
class CampoDeBusqueda extends StatefulWidget {
  const CampoDeBusqueda({
    super.key,
    required this.valor,
    required this.alCambiar,
    required this.etiqueta,
  });

  final String valor;
  final ValueChanged<String> alCambiar;

  /// Lo que dice el campo vacio. Es tambien la etiqueta del lector de
  /// pantalla: "Buscar" a secas no dice buscar QUE.
  final String etiqueta;

  @override
  State<CampoDeBusqueda> createState() => _CampoDeBusquedaState();
}

class _CampoDeBusquedaState extends State<CampoDeBusqueda> {
  late final TextEditingController _control = TextEditingController(
    text: widget.valor,
  );

  @override
  void didUpdateWidget(CampoDeBusqueda anterior) {
    super.didUpdateWidget(anterior);
    // Solo cuando el valor de afuera dejo de coincidir: asignar el texto en
    // cada rebuild mueve el cursor al final en la mitad de una palabra.
    if (widget.valor != _control.text) _control.text = widget.valor;
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final hayTexto = widget.valor.isNotEmpty;

    return TextField(
      controller: _control,
      onChanged: widget.alCambiar,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.etiqueta,
        prefixIcon: Icon(Icons.search, color: esquema.onSurfaceVariant),
        suffixIcon: hayTexto
            ? IconButton(
                icon: const Icon(Icons.close),
                // El lector de pantalla no ve la crucecita.
                tooltip: 'Limpiar la búsqueda',
                constraints: const BoxConstraints(
                  minWidth: Medidas.tactil,
                  minHeight: Medidas.tactil,
                ),
                onPressed: () {
                  _control.clear();
                  widget.alCambiar('');
                },
              )
            : null,
      ),
    );
  }
}
