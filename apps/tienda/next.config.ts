import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,

  // @bouquet/contratos se publica como fuente TypeScript sin compilar (Node 24
  // la ejecuta borrando tipos, ver su package.json). Next.js por defecto NO
  // transpila node_modules; sin esto, el import de @bouquet/contratos rompe
  // el build con un error de sintaxis.
  transpilePackages: ['@bouquet/contratos'],

  /* La caché de las páginas del catálogo (ADR 008). `/vinos`, `/vinos/[slug]`
   * y `/carrito` son ISR con `revalidate = 60`, y Next les arma el
   * Cache-Control solo: `s-maxage={revalidate}, stale-while-revalidate=
   * {expireTime - revalidate}` (node_modules/next/dist/docs/01-app/02-guides/
   * cdn-caching.md). Con 360 sale `s-maxage=60, stale-while-revalidate=300`.
   * No se escribe a mano en headers(): el Cache-Control de una página lo pone
   * Next al renderizarla.
   *
   * Afecta a TODA página con `revalidate`, y hoy son sólo esas tres. La home y
   * /oficio son estáticas y siguen con `s-maxage=31536000`. */
  expireTime: 360,

  /* `Cache-Tag` es lo que va a purgar Cloudflare en el tramo 4 (ADR 005).
   *
   * ⚠️ La ficha lleva el SLUG, no el id del producto: acá la ruta sólo conoce
   * el slug, y un header de next.config no puede buscar nada. El trigger de
   * purga tiene el documento de antes y el de después, así que conoce los dos
   * slugs si cambia (ADR 008). */
  async headers() {
    return [
      /* PREVIEW CERRADA (ADR 017). Se prende SOLO con `PREVIEW_CERRADA=1` en
       * el `apphosting.yaml` de esta carpeta, y por eso vive acá y no fijo:
       * el día que se publique la tienda de verdad, salir con `noindex` la
       * dejaría afuera de Google sin un solo error. Se lee al BUILD --
       * `headers()` se compila en el manifiesto de rutas --, así que la
       * variable tiene que estar disponible en `BUILD`, no sólo en `RUNTIME`. */
      ...(process.env.PREVIEW_CERRADA === '1'
        ? [
            {
              source: '/:path*',
              headers: [{ key: 'X-Robots-Tag', value: 'noindex, nofollow, noarchive' }],
            },
          ]
        : []),
      { source: '/vinos', headers: [{ key: 'Cache-Tag', value: 'catalogo' }] },
      { source: '/vinos/:slug', headers: [{ key: 'Cache-Tag', value: 'catalogo, producto-:slug' }] },
      { source: '/carrito', headers: [{ key: 'Cache-Tag', value: 'catalogo' }] },
    ];
  },

  /* ⚠️ `/contacto` YA NO ES UNA SECCIÓN, PERO SU URL SIGUE VIVA.
   *
   * El contacto se plegó como cierre de `/oficio` —el arco de esa página
   * termina en quién es "nosotros"—, así que la ruta vieja redirige al ancla
   * del bloque en vez de morir. No es una redirección de cortesía: los textos
   * ya escritos en `voz.md §9.3` y `§9.5` dicen "escribinos" y van a necesitar
   * un destino el día que alguien los lea.
   *
   * `permanent: true` es un **308** (no un 301): mantiene el método, que es lo
   * correcto para una URL que dejó de existir como sección y no va a volver.
   *
   * ⚠️ Y `/custodia` NO redirige, a propósito. Nada está desplegado todavía, así
   * que no hay un solo enlace entrante que preservar: da 404, que es la verdad.
   * Inventar una redirección para una URL que nunca existió públicamente es
   * escribir código para un caso que no ocurre. */
  async redirects() {
    return [
      {
        source: '/contacto',
        destination: '/oficio#mostrador',
        permanent: true,
      },
    ];
  },

  images: {
    // Las fotos de producto viven en Firebase Storage (ARQUITECTURA §5.4, §9.3).
    // TODO(/disenio): tamaños, breakpoints y `deviceSizes` reales cuando exista
    // la dirección visual — hoy los componentes usan medidas fijas mínimas.
    remotePatterns: [
      { protocol: 'https', hostname: 'firebasestorage.googleapis.com' },
      { protocol: 'https', hostname: 'storage.googleapis.com' },
    ],
  },
};

export default nextConfig;
