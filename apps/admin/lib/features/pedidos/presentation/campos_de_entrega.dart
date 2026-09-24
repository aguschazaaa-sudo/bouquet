import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/contratos/pedido.dart';
import '../../../core/contratos/provincias.dart';
import '../domain/entrega_escrita.dart';
import 'textos_de_carga.dart';

/// Los datos de quien recibe y a donde va (HU-10.1): lo que hace falta para
/// despachar. Una sola pantalla, sin pasos.
///
/// - **El telefono se pega como vino del chat** y dice **como va a quedar** antes
///   de confirmar: es lo que lee `wa.me`, y uno mal armado abre el chat de otra
///   persona.
/// - **Cada texto tiene su tope de largo**, el mismo que el servidor
///   (`largosDeEntrega`): no se puede escribir de mas, asi que no hay que rechazar
///   despues.
/// - **Solo se marca el primer campo que falta**, y **solo despues de intentar
///   confirmar** ([problema]): no se le grita a alguien que todavia esta
///   escribiendo.
///
/// Es dueno de sus controles y le avisa al padre con cada cambio. La provincia no
/// se preselecciona: una provincia que "queda puesta" es un despacho a la
/// provincia equivocada.
class CamposDeEntrega extends StatefulWidget {
  const CamposDeEntrega({
    super.key,
    required this.alCambiar,
    this.problema,
    this.habilitado = true,
  });

  final ValueChanged<EntregaEscrita> alCambiar;

  /// El campo a marcar, si el operador ya intento confirmar.
  final CampoDeEntrega? problema;
  final bool habilitado;

  @override
  State<CamposDeEntrega> createState() => _CamposDeEntregaState();
}

class _CamposDeEntregaState extends State<CamposDeEntrega> {
  EntregaEscrita _e = const EntregaEscrita();

  void _cambiar(EntregaEscrita nueva) {
    setState(() => _e = nueva);
    widget.alCambiar(nueva);
  }

  Widget _campo({
    required String etiqueta,
    required int maximo,
    required ValueChanged<String> alCambiar,
    CampoDeEntrega? campo,
    TextInputType? teclado,
    TextCapitalization mayusculas = TextCapitalization.sentences,
    String? ayuda,
    bool soloDigitos = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        enabled: widget.habilitado,
        keyboardType: teclado,
        textCapitalization: mayusculas,
        inputFormatters: [
          LengthLimitingTextInputFormatter(maximo),
          if (soloDigitos) FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: etiqueta,
          helperText: ayuda,
          helperMaxLines: 2,
          errorText: campo != null && widget.problema == campo
              ? textoDelProblema(campo)
              : null,
          errorMaxLines: 3,
          counterText: '',
        ),
        onChanged: alCambiar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    final normalizado = e.telefonoNormalizado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _campo(
          etiqueta: 'Nombre',
          maximo: largosDeEntrega['nombre']!,
          campo: CampoDeEntrega.nombre,
          mayusculas: TextCapitalization.words,
          alCambiar: (t) => _cambiar(e.copiarCon(nombre: t)),
        ),
        _campo(
          etiqueta: 'Teléfono',
          // Largo holgado: el numero se pega con espacios, guiones y +54, y lo
          // que importa es lo que queda normalizado, no lo que se escribio.
          maximo: 40,
          campo: CampoDeEntrega.telefono,
          teclado: TextInputType.phone,
          ayuda: normalizado != null
              ? textoVaAQuedarComo(normalizado)
              : textoTelefonoAyuda,
          alCambiar: (t) => _cambiar(e.copiarCon(telefono: t)),
        ),
        _campo(
          etiqueta: 'Mail (si lo tiene)',
          maximo: largosDeEntrega['email']!,
          campo: CampoDeEntrega.email,
          teclado: TextInputType.emailAddress,
          mayusculas: TextCapitalization.none,
          alCambiar: (t) => _cambiar(e.copiarCon(email: t)),
        ),
        _campo(
          etiqueta: 'Calle',
          maximo: largosDeEntrega['calle']!,
          campo: CampoDeEntrega.calle,
          mayusculas: TextCapitalization.words,
          alCambiar: (t) => _cambiar(e.copiarCon(calle: t)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _campo(
                etiqueta: 'Número',
                maximo: largosDeEntrega['numero']!,
                campo: CampoDeEntrega.numero,
                alCambiar: (t) => _cambiar(e.copiarCon(numero: t)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _campo(
                etiqueta: 'Piso o depto',
                maximo: largosDeEntrega['piso']!,
                alCambiar: (t) => _cambiar(e.copiarCon(piso: t)),
              ),
            ),
          ],
        ),
        _campo(
          etiqueta: 'Referencia (si ayuda)',
          maximo: largosDeEntrega['referencia']!,
          alCambiar: (t) => _cambiar(e.copiarCon(referencia: t)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _campo(
                etiqueta: 'Código postal',
                maximo: 4,
                campo: CampoDeEntrega.codigoPostal,
                teclado: TextInputType.number,
                soloDigitos: true,
                alCambiar: (t) => _cambiar(e.copiarCon(codigoPostal: t)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _campo(
                etiqueta: 'Localidad',
                maximo: largosDeEntrega['localidad']!,
                campo: CampoDeEntrega.localidad,
                mayusculas: TextCapitalization.words,
                alCambiar: (t) => _cambiar(e.copiarCon(localidad: t)),
              ),
            ),
          ],
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Provincia',
            errorText: widget.problema == CampoDeEntrega.provincia
                ? textoDelProblema(CampoDeEntrega.provincia)
                : null,
          ),
          items: [
            for (final p in provincias)
              DropdownMenuItem(value: p.iso, child: Text(p.nombre)),
          ],
          onChanged: widget.habilitado
              ? (iso) => _cambiar(e.copiarCon(provincia: iso ?? ''))
              : null,
        ),
      ],
    );
  }
}
