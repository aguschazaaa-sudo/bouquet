import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,

  // @bouquet/contratos se publica como fuente TypeScript sin compilar (Node 24
  // la ejecuta borrando tipos, ver su package.json). Next.js por defecto NO
  // transpila node_modules; sin esto, el import de @bouquet/contratos rompe
  // el build con un error de sintaxis.
  transpilePackages: ['@bouquet/contratos'],

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
