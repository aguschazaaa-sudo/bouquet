# -*- coding: utf-8 -*-
"""Deriva los paths SVG del isotipo desde el PNG de marca.

Por que desde el PNG y no desde el PDF vectorial: el PDF es CMYK y pinta con
el operador `scn` de 4 componentes. Cualquier extractor que lo abra sin perfil
devuelve #700E0F en vez del borgona real — direccion.md 2.0 ya lo documenta y
la medicion de este repo lo confirma. El PNG es sRGB IEC61966-2.1 con perfil
embebido, 3508x2481, y tiene EXACTAMENTE dos tintas planas:

    #762D2D  4,24 % de los pixeles
    #D2AE6D  2,38 %

Sin antialias de color entre ellas, o sea el mejor origen posible para trazar.

⚠️ ESTO CORRIGE UNA LINEA DEL VAULT QUE PRODUJO CODIGO.
direccion.md 1 dice "copa de trazo MONOLINEAL" y de ahi deduce que todo lo
dibujado del sitio tiene que ser monolineal. Medido con la transformada de
distancia sobre la mascara dorada (1313 muestras de cresta):

    p05 44px | mediana 55px | p95 61px  ->  razon p95/p05 = 1,38

Un monolineal da ~1,0. El isotipo tiene modulacion de bajo contraste: los
gruesos son un 38 % mas anchos que los finos. No es caligrafico (eso seria
3:1), pero no es monolineal. La consecuencia de diseno esta en tokens.css:
el sitio tiene DOS pesos de linea, no uno.

Uso:  python scripts/assets/generar_copa.py [--verificar]
"""

import json
import os
import sys

import numpy as np
import potrace
from PIL import Image

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
ORIGEN = os.path.normpath(os.path.join(RAIZ, "docs", "marca", "logo-bouquet-rgb.png"))
DESTINO = os.path.normpath(
    os.path.join(RAIZ, "apps", "tienda", "src", "components", "marca", "copa.paths.json")
)

ORO = np.array([210, 174, 109])
BORGONA = np.array([118, 45, 45])

# Ventana del isotipo dentro del PNG, con margen. El wordmark arranca en y=1660
# y no entra: el sitio compone el nombre con tipografia, no con la imagen del
# logo (direccion.md 4.3).
VENTANA = (280, 1540, 1390, 2120)  # y0, y1, x0, x1

# Alto del viewBox. 240 da dos decimales de precision sobre un original de
# 1260px de alto sin inflar el path.
ALTO_VB = 240.0

# Tolerancia de color. Generosa a proposito: el PNG tiene 131 colores unicos y
# los ~120 que no son las tres tintas son antialias de borde. Un umbral
# apretado los descarta y deja el trazo dentado.
TOL = 90


def mascaras():
    im = Image.open(ORIGEN).convert("RGB")
    a = np.asarray(im).astype(int)
    y0, y1, x0, x1 = VENTANA
    sub = a[y0:y1, x0:x1]
    return (np.abs(sub - ORO).sum(2) < TOL), (np.abs(sub - BORGONA).sum(2) < TOL)


def trazar(mask):
    """turdsize=8 descarta motas de antialias sueltas; alphamax=1.0 es el
    default de potrace y respeta las esquinas reales del dibujo.

    ⚠️ SE PASA LA MASCARA INVERTIDA. potracer traza las regiones en CERO, no
    las que valen 1. Con la mascara derecha devuelve dos curvas —una de 4
    segmentos que es el borde del lienzo, y la silueta— y el raster da
    IoU=0,0002. Invertida da una sola curva y **IoU=0,9881**. Es empirico: se
    probaron las dos polaridades y se quedo la que el arnes aprobo."""
    return potrace.Bitmap(~mask).trace(turdsize=8, alphamax=1.0, opticurve=1,
                                       opttolerance=0.2)


def aplanar(path):
    """Todas las curvas, incluidos los huecos.

    ⚠️ potracer anida los huecos en `curva.children` y su `curves_tree` esta
    SIN IMPLEMENTAR (devuelve None). Recorrer solo el primer nivel de `path`
    devuelve 2 curvas para un dibujo que tiene el interior de la voluta y el
    del balon como agujeros — y el raster sale macizo."""
    fuera = []

    def bajar(cs):
        for c in cs:
            fuera.append(c)
            bajar(getattr(c, "children", []) or [])

    bajar(path)
    return fuera


def a_path(path, esc):
    p = lambda q: (q.x * esc, q.y * esc)
    d = []
    for curva in aplanar(path):
        x, y = p(curva.start_point)
        d.append(f"M{x:.2f} {y:.2f}")
        for s in curva:
            if s.is_corner:
                cx, cy = p(s.c)
                ex, ey = p(s.end_point)
                d.append(f"L{cx:.2f} {cy:.2f}L{ex:.2f} {ey:.2f}")
            else:
                a1, b1 = p(s.c1)
                a2, b2 = p(s.c2)
                ex, ey = p(s.end_point)
                d.append(f"C{a1:.2f} {b1:.2f} {a2:.2f} {b2:.2f} {ex:.2f} {ey:.2f}")
        d.append("Z")
    return "".join(d)


# ------------------------------------------------------------------ medicion

def ancho_de_trazo(mask):
    """La razon p95/p05 del ancho de trazo. Es el numero que corrige a
    direccion.md 1, asi que se recalcula cada vez que corre el script en vez
    de quedar escrito en un comentario que nadie vuelve a chequear."""
    from scipy import ndimage as nd

    dt = nd.distance_transform_edt(mask)
    cresta = (dt > 2) & (dt >= nd.maximum_filter(dt, size=5) - 1e-9)
    w = np.sort(2 * dt[cresta])
    return w[int(len(w) * 0.05)], np.median(w), w[int(len(w) * 0.95)]


def rasterizar(d, ancho, alto, k):
    """Rasteriza un path SVG aplanando las Bezier. Existe para VERIFICAR el
    trazado contra su propia mascara: sin esto, "el SVG salio bien" es una
    impresion mirando una miniatura.

    ⚠️ `k` reescala de unidades de viewBox a pixeles de mascara, y NO es
    opcional: sin el, el path (que vive en 0..139 x 0..240) se dibuja en la
    esquina de un lienzo de 730x1260 y el IoU da 0,0000 con el trazado
    perfecto. Los dos controles lo separaron de un trazado malo — el positivo
    seguia dando 1,0 y el negativo 0,38, o sea el arnes medía bien y el que
    estaba roto era esto.

    ⚠️ Y el relleno es POR PARIDAD (even-odd), no solido. potrace devuelve los
    huecos como curvas aparte: la voluta y el balon de la copa son agujeros. Si
    cada subpath se rellena solido, el raster tapa los huecos y el IoU se clava
    en 0,23 — que es, justamente, area-del-oro / area-de-la-silueta-maciza.
    """
    from PIL import ImageDraw

    i, n = 0, len(d)
    subpaths, poly, actual = [], [], None

    def num():
        nonlocal i
        j = i
        while j < n and (d[j].isdigit() or d[j] in ".-"):
            j += 1
        v = float(d[i:j])
        i = j
        while i < n and d[i] in " ,":
            i += 1
        return v

    while i < n:
        c = d[i]
        if c in "MLCZ":
            i += 1
            while i < n and d[i] == " ":
                i += 1
        if c == "M":
            if len(poly) > 2:
                subpaths.append(poly)
            x, y = num()*k, num()*k
            actual = (x, y)
            poly = [actual]
        elif c == "L":
            x, y = num()*k, num()*k
            actual = (x, y)
            poly.append(actual)
        elif c == "C":
            x1, y1, x2, y2, x3, y3 = (num()*k for _ in range(6))
            x0, y0 = actual
            for t in np.linspace(0, 1, 14)[1:]:
                u = 1 - t
                poly.append((u**3*x0 + 3*u*u*t*x1 + 3*u*t*t*x2 + t**3*x3,
                             u**3*y0 + 3*u*u*t*y1 + 3*u*t*t*y2 + t**3*y3))
            actual = (x3, y3)
        elif c == "Z":
            if len(poly) > 2:
                subpaths.append(poly)
            poly = []
        else:
            i += 1
    if len(poly) > 2:
        subpaths.append(poly)

    acumulado = np.zeros((alto, ancho), dtype=bool)
    for sp in subpaths:
        capa = Image.new("1", (ancho, alto), 0)
        ImageDraw.Draw(capa).polygon(sp, fill=1)
        acumulado ^= np.asarray(capa, dtype=bool)  # paridad, no union
    return acumulado


def iou(a, b):
    u = (a | b).sum()
    return (a & b).sum() / u if u else 1.0


# --------------------------------------------------------------------- main

def main():
    oro, vino = mascaras()
    y0, y1, x0, x1 = VENTANA
    esc = ALTO_VB / (y1 - y0)
    ancho_vb = (x1 - x0) * esc

    p05, med, p95 = ancho_de_trazo(oro)
    print(f"  ancho de trazo del isotipo: p05={p05:.0f} med={med:.0f} p95={p95:.0f} px"
          f"  ->  RAZON p95/p05 = {p95/p05:.2f}")
    print("  (monolineal daria ~1,00 — direccion.md 1 dice 'monolineal' y no lo es)")

    d_oro = a_path(trazar(oro), esc)
    d_vino = a_path(trazar(vino), esc)

    # La caja del vino en unidades de viewBox. La usa Copa.tsx para el nivel
    # que sube con el scroll: el liquido se recorta contra ESTA franja, asi que
    # nunca se dibuja vino donde el logo no lo tiene.
    ys, xs = np.where(vino)
    caja = {
        "x": round(float(xs.min() * esc), 2),
        "y": round(float(ys.min() * esc), 2),
        "ancho": round(float((xs.max() - xs.min()) * esc), 2),
        "alto": round(float((ys.max() - ys.min()) * esc), 2),
    }

    datos = {
        "viewBox": f"0 0 {ancho_vb:.2f} {ALTO_VB:.0f}",
        "ancho": round(ancho_vb, 2),
        "alto": ALTO_VB,
        "copa": d_oro,
        "vino": d_vino,
        "vinoCaja": caja,
        "modulacion": round(float(p95 / p05), 3),
    }
    os.makedirs(os.path.dirname(DESTINO), exist_ok=True)
    with open(DESTINO, "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=1)

    print(f"  copa: {len(d_oro)} bytes de path | vino: {len(d_vino)} bytes")
    print(f"  viewBox {datos['viewBox']}")
    print(f"  -> {os.path.relpath(DESTINO, RAIZ)}")
    return verificar(datos)


def verificar(datos=None):
    """Control positivo Y negativo, porque un IoU sin control no distingue
    'el trazo es fiel' de 'el rasterizador devuelve la mascara de entrada'."""
    if datos is None:
        datos = json.load(open(DESTINO, encoding="utf-8"))
    oro, vino = mascaras()
    y0, y1, x0, x1 = VENTANA
    esc = ALTO_VB / (y1 - y0)
    h, w = oro.shape

    print("\n  verificacion del trazado (IoU contra la mascara del PNG):")
    ok = True
    for nombre, mask in (("copa", oro), ("vino", vino)):
        r = rasterizar(datos[nombre], w, h, 1.0 / esc)
        v = iou(r, mask)
        print(f"    {nombre:5s} IoU = {v:.4f}   {'OK' if v > 0.97 else 'MAL'}")
        ok = ok and v > 0.97

    # Control positivo: una mascara contra si misma tiene que dar 1,0000.
    print(f"    control positivo (mascara vs si misma) = {iou(oro, oro):.4f}")
    # Control negativo: corrida 40px tiene que caer MUCHO. Sin esto, un
    # rasterizador roto que devuelva la entrada informaria 1,0 en todo.
    corrida = np.roll(oro, 40, axis=1)
    print(f"    control negativo (mascara corrida 40px) = {iou(oro, corrida):.4f}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(verificar() if "--verificar" in sys.argv else main())
