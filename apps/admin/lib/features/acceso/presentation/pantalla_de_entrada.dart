import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import 'formulario_de_contrasena.dart';
import 'formulario_de_entrada.dart';
import 'panel_de_marca.dart';

/// `/entrar`. Alterna entre entrar y pedir el correo de contrasena sin
/// cambiar de ruta: el mail escrito viaja de un formulario al otro.
class PantallaDeEntrada extends StatefulWidget {
  const PantallaDeEntrada({super.key});

  @override
  State<PantallaDeEntrada> createState() => _PantallaDeEntradaState();
}

class _PantallaDeEntradaState extends State<PantallaDeEntrada> {
  bool _pidiendoContrasena = false;
  String _mail = '';

  void _mostrar({required bool contrasena, required String mail}) {
    setState(() {
      _pidiendoContrasena = contrasena;
      _mail = mail;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final contenido = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              _pidiendoContrasena ? 'Tu contraseña' : 'Entrar',
              style: tema.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (_pidiendoContrasena)
            FormularioDeContrasena(
              key: const ValueKey('contrasena'),
              mailInicial: _mail,
              alVolver: (mail) => _mostrar(contrasena: false, mail: mail),
            )
          else
            FormularioDeEntrada(
              key: const ValueKey('entrada'),
              mailInicial: _mail,
              alPedirContrasena: (mail) =>
                  _mostrar(contrasena: true, mail: mail),
            ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: tema.colorScheme.surface,
      body: LayoutBuilder(
        builder: (context, limites) {
          final ancha = limites.maxWidth >= Medidas.anchoDeEscritorio;
          final desplazable = SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: ancha ? 48 : 20,
              vertical: ancha ? 48 : 28,
            ),
            child: Center(child: contenido),
          );

          if (!ancha) {
            return Column(
              children: [
                const PanelDeMarca(ancho: false),
                Expanded(child: desplazable),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: 440, child: PanelDeMarca(ancho: true)),
              Expanded(child: Center(child: desplazable)),
            ],
          );
        },
      ),
    );
  }
}
