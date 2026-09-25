import 'package:flutter/material.dart';

import '../domain/nota_del_pedido.dart';
import 'textos_de_notas.dart';

/// Escribir o cambiar la nota interna de un pedido (HU-07.7).
///
/// **No escribe nada**: devuelve el texto y quien la abre lo guarda, como
/// `HojaDeDespacho`. `null` es *"no guardar"* (se cerro la hoja); un texto vacio
/// es *"borrar la nota"*, y lo decide `notaAGuardar`, no la hoja.
///
/// El tope es el de las reglas: con mas, el boton no guarda y lo dice. El
/// contador de `maxLength` no se usa para cortar: cortar en silencio perderia
/// el final de lo que alguien pego.
class HojaDeNota extends StatefulWidget {
  const HojaDeNota({super.key, required this.numero, this.actual});

  final int numero;
  final String? actual;

  static Future<String?> mostrar(
    BuildContext context, {
    required int numero,
    String? actual,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HojaDeNota(numero: numero, actual: actual),
    );
  }

  @override
  State<HojaDeNota> createState() => _HojaDeNotaState();
}

class _HojaDeNotaState extends State<HojaDeNota> {
  late final _texto = TextEditingController(text: widget.actual ?? '');

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!notaEntra(_texto.text)) return;
    Navigator.of(context).pop(_texto.text);
  }

  @override
  Widget build(BuildContext context) {
    final entra = notaEntra(_texto.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              textoTituloDeLaNota(widget.numero),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 4),
          const Text(textoNotasSoloFamilia),
          const SizedBox(height: 16),
          TextField(
            controller: _texto,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: textoEjemploDeNota,
              errorText: entra ? null : textoNotaLarga(largoMaximoDeNota),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: entra ? _guardar : null,
            child: const Text(textoGuardarNota),
          ),
        ],
      ),
    );
  }
}
