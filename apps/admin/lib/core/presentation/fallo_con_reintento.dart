import 'package:flutter/material.dart';

import 'aviso.dart';

/// Algo no se pudo leer, y hay forma de volver a intentarlo.
///
/// ⚠️ **Existe para que una lectura fallida NO se vea como una lista vacia.**
/// Son dos cosas opuestas —"no cargaste nada todavia" y "no pude leer lo que
/// cargaste"— y la segunda pintada como la primera manda a alguien a cargar
/// de nuevo lo que ya existe.
class FalloConReintento extends StatelessWidget {
  const FalloConReintento({
    super.key,
    required this.texto,
    required this.alReintentar,
  });

  final String texto;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Aviso(texto: texto, tono: TonoDelAviso.error),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: alReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Volver a intentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
