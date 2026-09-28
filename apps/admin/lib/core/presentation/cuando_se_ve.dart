/// Cuando se ve en la tienda lo que se guardo en el panel (HU-09.4, ADR 023).
///
/// Dos plazos, porque la tienda lee de dos maneras:
///
/// - **El catalogo** —`/vinos`, la ficha, el carrito y las cajas sugeridas— se
///   rearma solo, y un cambio tarda **hasta unos 13 minutos** con poco trafico:
///   60 s de datos, la pagina vencida que Next sirve hasta 360 s, 60 del borde
///   y 300 de `stale-while-revalidate` (ADR 008, corregido por `revisor-pagos`
///   de 8 a 13). Vale para el precio, publicar, la ficha y las fotos.
/// - **La portada** se arma UNA vez, al publicar la tienda (ADR 008 §7): un
///   cambio de la seleccion no se ve hasta la proxima publicacion.
///
/// Sin esto, quien guarda mira la tienda, no ve el cambio, y concluye que no
/// se guardo: lo vuelve a hacer, o llama a alguien.
///
/// ⚠️ **Estos textos cambian el dia del tramo 4** (Cloudflare con purga por
/// tag, ADR 005): el catalogo pasa a verse en segundos, y si la portada entra
/// a la purga, tambien ella. Un texto que promete "13 minutos" despues de eso
/// miente al reves. Por eso viven en UN archivo, y el pendiente del tramo 4 en
/// `docs/vault/_index.md` apunta aca.
library;

/// Despues de guardar algo que la tienda muestra en el catalogo o en la ficha.
const textoTardaEnLaTienda =
    'La tienda puede tardar hasta unos 13 minutos en mostrarlo.';

/// Despues de cambiar la seleccion de la portada.
const textoTardaEnLaPortada =
    'La portada no cambia al guardar: se actualiza la próxima vez que se '
    'publique la tienda.';
