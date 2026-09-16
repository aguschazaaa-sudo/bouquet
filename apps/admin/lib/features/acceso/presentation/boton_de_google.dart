import 'package:flutter/material.dart';

/// "Entrar con Google". `alTocar` en `null` lo deja apagado mientras otra
/// operacion esta en curso.
class BotonDeGoogle extends StatelessWidget {
  const BotonDeGoogle({super.key, required this.alTocar});

  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return OutlinedButton(
      onPressed: alTocar,
      style: OutlinedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
              child: Text(
                'G',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('Entrar con Google'),
        ],
      ),
    );
  }
}
