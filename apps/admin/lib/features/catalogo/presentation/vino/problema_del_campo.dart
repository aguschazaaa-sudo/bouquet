import 'package:flutter/material.dart';

/// El problema de un campo que no es un `TextField` —los chips, el color, las
/// botellas—, con el mismo aspecto que el `errorText` de uno que si lo es.
/// `null` no dibuja nada.
class ProblemaDelCampo extends StatelessWidget {
  const ProblemaDelCampo({super.key, required this.texto});

  final String? texto;

  @override
  Widget build(BuildContext context) {
    final problema = texto;
    if (problema == null) return const SizedBox.shrink();
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(
          problema,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.error,
          ),
        ),
      ),
    );
  }
}
