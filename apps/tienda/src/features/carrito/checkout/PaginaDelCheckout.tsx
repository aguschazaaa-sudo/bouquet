'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import {
  botellasEnCarrito,
  cajasADespachar,
  cargaDelPedido,
  conEnvioSinCargo,
  faltaParaSinCargo,
  nombreDeProvincia,
  pesoDelPedidoKg,
  resolverCarrito,
  sePuedeCobrar,
  type Centavos,
  type ProductoPublicado,
} from '@bouquet/contratos';

import { useCarrito, useHidratado } from '../useCarrito';
import { ADondeVa } from './ADondeVa';
import { ComoViaja } from './ComoViaja';
import { ElResumen } from './ElResumen';
import { PedidoVacio } from './PedidoVacio';
import { QuienRecibe } from './QuienRecibe';
import { BORRADOR_VACIO, validarBorrador, type Borrador } from './borrador';
import { TEXTOS } from './textos';
import { useCotizacion, type Cotizador, type EstadoDeCotizacion } from './useCotizacion';

/* /pedido — terminar la compra. Papel sin excepción (direccion.md §3).
 *
 * El carrito vive en localStorage, así que esta pantalla es del navegador de
 * punta a punta: el servidor manda la proyección del catálogo —la misma de
 * /vinos y /carrito, cero lecturas de más— y la Server Action que cotiza.
 *
 * ⚠️ NO COBRA. `EL_CHECKOUT_NO_COBRA` está en `true` y el botón está
 * deshabilitado: `crearOrden` no existe, no hay preferencia de Mercado Pago y
 * no hay webhook. Está armada entera para poder MIRARLA, que es lo único que
 * distingue una pantalla que funciona de una que compila. */

type Props = {
  productos: readonly ProductoPublicado[];
  cotizar: Cotizador;
  /** Desde qué monto la entrega sale sin cargo, o `null` si no hay (HU-11.1). */
  sinCargoDesde: Centavos | null;
  whatsapp: string;
};

export function PaginaDelCheckout({ productos, cotizar, sinCargoDesde, whatsapp }: Props) {
  const hidratado = useHidratado();
  const carrito = useCarrito();
  const resuelto = useMemo(() => resolverCarrito(carrito, productos), [carrito, productos]);
  const botellas = botellasEnCarrito(resuelto);
  /* Lo que de verdad viaja, separado por cómo viaja: las sueltas se juntan de a
   * seis y lo que trae su propia caja es un bulto por unidad. Aplanarlo a un
   * total de botellas cotizaba tres packs como una sola caja (ADR 009 §10). */
  const carga = cargaDelPedido(resuelto);

  const [borrador, setBorrador] = useState<Borrador>(BORRADOR_VACIO);
  const [elegidaId, setElegidaId] = useState<string | null>(null);
  const [cpAplicado, setCpAplicado] = useState<string | null>(null);

  /* La provincia viaja a la cotización sólo si ya es la de ESTE código postal
   * —la precargó su propia cotización, o la corrigió el comprador después—.
   * Con un código recién escrito, la del anterior no vale: la adivina el
   * servidor (ADR 030). */
  const provinciaDelCp = cpAplicado === borrador.codigoPostal.trim() ? borrador.provincia : '';
  const cotizada = useCotizacion(cotizar, borrador.codigoPostal, carga, provinciaDelCp);
  /* El umbral de la entrega sin cargo se aplica ACÁ, sobre lo que cotizó el
   * servidor y con el subtotal de esta pantalla (HU-11.1, ADR 026): si el
   * pedido llega, todas las opciones salen sin cargo, y la lista, el resumen y
   * la opción elegida lo dicen igual. Es lo que se MUESTRA: lo que se cobre lo
   * recalcula `crearOrden` en el servidor, con el subtotal que calcule él. */
  const cotizacion = useMemo((): EstadoDeCotizacion => {
    if (cotizada.fase !== 'lista' || !cotizada.resultado.ok) return cotizada;
    const opciones = conEnvioSinCargo(cotizada.resultado.opciones, resuelto.total, sinCargoDesde);
    return opciones === cotizada.resultado.opciones
      ? cotizada
      : { fase: 'lista', resultado: { ...cotizada.resultado, opciones } };
  }, [cotizada, resuelto.total, sinCargoDesde]);
  const listo = cotizacion.fase === 'lista' && cotizacion.resultado.ok ? cotizacion.resultado : null;

  /* La cotización trae la localidad y la provincia que pudo deducir, y las pone
   * UNA sola vez POR CÓDIGO POSTAL: mientras el código no cambie, son del
   * comprador y pisarlas le borraría la corrección a quien sabe dónde vive.
   *
   * ⚠️ Cuando el código SÍ cambia, la localidad se reemplaza aunque la nueva
   * venga vacía. La primera versión la conservaba —`|| b.localidad`— y con eso
   * un pedido a 1425 seguía diciendo "Villa Giardino": la dirección quedaba
   * mezclando dos lugares. Se vio en la captura. */
  useEffect(() => {
    if (listo === null || listo.destino.codigoPostal === cpAplicado) return;
    setCpAplicado(listo.destino.codigoPostal);
    setBorrador((b) => ({
      ...b,
      provincia: listo.destino.provincia,
      localidad: listo.destino.localidad,
    }));
  }, [listo, cpAplicado]);

  /* Una opción elegida que ya no está en la lista no vale: cambió el código
   * postal o cambiaron las cajas, y con eso cambió el precio. Se cae a la
   * primera, que es la que la lista ofrece arriba. */
  useEffect(() => {
    if (listo === null) {
      setElegidaId(null);
      return;
    }
    setElegidaId((id) => (listo.opciones.some((o) => o.id === id) ? id : (listo.opciones[0]?.id ?? null)));
  }, [listo]);

  const opcion = listo?.opciones.find((o) => o.id === elegidaId) ?? null;
  const envio = opcion?.precio ?? null;
  const validacion = validarBorrador(borrador, listo?.destino.propio ?? false);

  const impedimento = !sePuedeCobrar(resuelto)
    ? TEXTOS.cajaIncompleta
    : !validacion.ok
      ? TEXTOS.faltanDatos
      : envio === null
        ? TEXTOS.faltaElEnvio
        : null;

  const eco = listo
    ? [listo.destino.localidad || nombreDeProvincia(listo.destino.provincia), listo.destino.propio ? TEXTOS.loLlevamosNosotros : null]
        .filter(Boolean)
        .join(' · ')
    : null;

  const cambiar = (campo: keyof Borrador, valor: string) => setBorrador((b) => ({ ...b, [campo]: valor }));

  /* En el servidor no hay carrito: se reserva el lugar en vez de mostrar un
   * pedido vacío que no es el de nadie (direccion.md §6). */
  if (!hidratado) {
    return (
      <main className="pagina-checkout papel">
        <div className="pagina-checkout__contenedor">
          <div className="pagina-checkout__reservado" />
        </div>
      </main>
    );
  }

  if (botellas === 0) return <PedidoVacio />;

  return (
    <main className="pagina-checkout papel">
      <div className="pagina-checkout__contenedor">
        <header className="pagina-checkout__cabecera">
          <h1 className="display">{TEXTOS.titulo}</h1>
          <p className="pagina-checkout__bajada">{TEXTOS.bajada}</p>
        </header>

        <form className="pagina-checkout__columnas" onSubmit={(e) => e.preventDefault()}>
          <div className="pagina-checkout__partes">
            <QuienRecibe borrador={borrador} alCambiar={cambiar} />
            <ADondeVa
              borrador={borrador}
              alCambiar={cambiar}
              eco={eco}
              cotizacion={
                <ComoViaja
                  estado={cotizacion}
                  elegida={elegidaId}
                  alElegir={(o) => setElegidaId(o.id)}
                  whatsapp={whatsapp}
                />
              }
            />
            <p className="pagina-checkout__volver">
              <Link className="enlace-blando" href="/carrito">
                {TEXTOS.volver}
              </Link>
            </p>
          </div>

          <ElResumen
            resuelto={resuelto}
            envio={envio}
            cajas={cajasADespachar(carga)}
            pesoKg={pesoDelPedidoKg(carga)}
            impedimento={impedimento}
            faltaParaSinCargo={faltaParaSinCargo(resuelto.total, sinCargoDesde)}
            whatsapp={whatsapp}
          />
        </form>
      </div>
    </main>
  );
}
