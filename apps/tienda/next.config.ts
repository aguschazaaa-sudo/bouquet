import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,

  // @bouquet/contratos se publica como fuente TypeScript sin compilar (Node 24
  // la ejecuta borrando tipos, ver su package.json). Next.js por defecto NO
  // transpila node_modules; sin esto, el import de @bouquet/contratos rompe
  // el build con un error de sintaxis.
  transpilePackages: ['@bouquet/contratos'],

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
