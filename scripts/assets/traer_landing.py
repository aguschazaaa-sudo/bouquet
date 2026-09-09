# -*- coding: utf-8 -*-
"""Trae y prepara los assets fotograficos de la home desde Wikimedia Commons.

Por que un script y no las fotos sueltas: la composicion especifica el HUECO,
no la foto. Este archivo es ese hueco escrito en codigo — rol, recorte, foco y
licencia por plano. Cambiar una foto cuesta editar una fila de PLANOS y volver
a correr; sin el script cuesta adivinar de donde salio el .webp que esta en
produccion.

De donde salen las fotos, y por que de ahi:

  Commons es la UNICA fuente alcanzable desde esta maquina que devuelve la
  licencia POR ARCHIVO en la respuesta de la API. Openverse no responde y
  Unsplash y Pexels exigen clave. Medido, no supuesto.

  Y ademas encaja: direccion.md §8 pide "superficies reales: madera, lino,
  piedra, vidrio, corcho" y "cero superficies de estudio". El look de banco de
  imagenes es exactamente el generico que §10 prohibe.

⚠️ ESTA TANDA SE ELIGIO POR LUMINANCIA MEDIDA, NO MIRANDO MINIATURAS.
La tanda anterior tenia Y_p95 entre 0,044 y 0,47, y las cuatro mas oscuras
componian POR DEBAJO del fondo vacio de la pagina (0,0069). Medida la pagina
renderizada por octavos, los ocho daban entre 0,014 y 0,025: seis pantallas de
scroll sin una sola variacion de luz. Eso es lo que el dueño llamo "lugubre", y
tiene numero.

Aca la luz es un CRITERIO DE BUSQUEDA: se midio el p95 de cada candidato antes
de bajarlo, y `--verificar` vuelve a medirlo sobre el .webp ya recortado.

Uso:  python scripts/assets/traer_landing.py [--verificar]
"""

import io
import json
import os
import re
import sys
import urllib.parse
import urllib.request

from PIL import Image

API = "https://commons.wikimedia.org/w/api.php"
UA = "bouquet-landing/1.0 (https://github.com/aguschazaaa-sudo/bouquet)"
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
DESTINO = os.path.normpath(os.path.join(RAIZ, "apps", "tienda", "public", "landing"))

# Medidas por rol.
#
# ⚠️ LA CALIDAD SALE DEL FILTRO QUE LE CAE ENCIMA, NO DE UN GUSTO.
# sistema.css pinta cada plano con un brightness distinto y al detalle le mete
# blur(3px). Un plano que se va a desenfocar 3px no necesita los bits.
#
# ⚠️ EL TECHO SE AFLOJO A PEDIDO DEL DUENO (2026-09-08): parallax.md §8 fijaba
# 450 KB de primera pantalla en movil y con 391 KB de tipografias ya arrancaba
# con el 87 % gastado — un presupuesto que ninguna foto podia cumplir sin
# quedar sucia. La palanca es suya y la corrio: *"parallax.md fue demasiado
# rata con los pesos, podes ser mas generoso"*.
#
# Sigue habiendo un techo, porque el comprador lo paga igual: el numero real
# esta en el informe de assets que imprime este script, y la primera pantalla
# se mira aparte del total.
MEDIDAS = {
    "ambiente": {"v": (1200, 1640), "h": (1920, 1080), "calidad": 55},
    "escenario": {"v": (1700, 2550), "h": (2560, 1440), "calidad": 66},
    "sujeto": {"v": (1300, 1740), "h": (1740, 1305), "calidad": 84},
}

# Un plano por fila. `foco` es el centro del recorte en fracciones del origen,
# elegido MIRANDO la foto en una hoja de contacto.
#
# `una_pieza` = el plano no se recorta a dos formas, porque Plano.tsx arma
# `<base>.webp` a secas cuando `dosDirecciones` es falso. Guardarlo como
# `<base>-v.webp` da un <img> que resuelve 404 y mide 0x0.
PLANOS = [
    {
        "base": "ambiente",
        "escena": "1 y 2 · fondo lejano",
        "rol": "ambiente",
        "una_pieza": True,
        "titulo": "File:Pol Roger pupitre 3.jpg",
        "foco": {"v": (0.32, 0.46), "h": (0.36, 0.50)},
        "zoom": 0.78,
        "por_que": "Un muro de culos de botella en su pupitre, oscuro y de "
                   "contraste bajo. Es el plano MAS LEJANO y tiene que quedar "
                   "asi: parallax.md §3.4 pide que el contraste caiga hacia los "
                   "extremos. Lo que se corrigio no es su oscuridad — es que "
                   "antes TODOS los planos estaban igual de oscuros que este.",
    },
    {
        "base": "rack",
        "escena": "1 · El problema",
        "rol": "escenario",
        "titulo": "File:Wine Cellar at Chateau Kirwan.jpg",
        "foco": {"v": (0.50, 0.52), "h": (0.50, 0.54)},
        "por_que": "Tunel de barricas axial con punto de fuga centrado y la luz "
                   "cayendo a lo largo del corredor. Lo ceremonial es axial "
                   "(direccion.md §7.3), y es la foto de la tanda que mas se "
                   "parece a 'una cava iluminada' en vez de 'una tienda oscura'.",
    },
    {
        "base": "botella",
        "escena": "1 · El problema",
        "rol": "sujeto",
        "una_pieza": True,
        "titulo": "File:Riddling racks, Veuve Clicquot cellars.jpg",
        # ⚠️ Foco elegido por BARRIDO MEDIDO, no a ojo: se probaron 25 centros
        # de recorte y se midio el p95 de cada uno. El que habia puesto a
        # mano daba 0,113; este da 0,533 — cuatro veces y media. Es la
        # esquina donde la pared de creta iluminada toca el rack.
        "foco": {"v": (0.35, 0.32), "h": (0.35, 0.34)},
        "zoom": 0.45,
        "por_que": "Culos de botella en su rack contra pared de creta calida, "
                   "cerca y nitido. Es el MISMO tema que el ambiente pero a otra "
                   "profundidad: dos planos del mismo material a distinta "
                   "distancia es exactamente lo que hace legible un parallax. "
                   "Y dice lo que dice la escena — botellas guardadas.",
    },
    {
        "base": "cava",
        "escena": "3 · La custodia",
        "rol": "escenario",
        "titulo": "File:Wine cellar of Mrva & Stanko Winery, Trnava, Slovakia - 20140723-02.jpg",
        "foco": {"v": (0.42, 0.50), "h": (0.46, 0.52)},
        "por_que": "Toneles de roble de frente, madera calida y veta real. La "
                   "escena habla de los tres mecanismos de la guarda, asi que el "
                   "fondo tiene que ser el lugar donde se guarda, no una metafora.",
    },
]

# ⚠️ `mesa-h.webp` y `mesa-v.webp` NO LOS MANEJA ESTE SCRIPT, A PROPOSITO.
#
# La foto de la escena 4 —una mesa tendida con una vela encendida, copas y
# mantel— ya estaba en el repo desde v0.7.0 y es la que el dueño eligio
# mirando: *"la ultima foto que habia antes si me gustaba"*. El reemplazo que
# habia traido de Commons ("Table of wine and snacks") se descarto por la misma
# via: *"parece una comida con un vaso de cerveza negra"*.
#
# Se listan aca abajo en FORANEOS para que `--verificar` las siga cubriendo. Si
# volvieran a PLANOS, la proxima corrida las pisaria en silencio — que es
# exactamente como se pierde un asset que alguien eligio a mano.
#
# ⚠️ Su procedencia es DESCONOCIDA y es el unico agujero de licencia que queda.
# Esta anotado en docs/vault/design/licencias-de-imagenes.md.
FORANEOS = ["mesa-h.webp", "mesa-v.webp"]


def lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminancia(im):
    """Y medio y p95 en luz LINEAL, que es la unidad con la que se discutio
    'lugubre'. El p95 importa mas que el medio: dice si la foto tiene altas
    luces que revelar o si es negra hasta arriba."""
    px = list(im.convert("RGB").resize((80, 80)).getdata())
    ys = sorted(0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b) for r, g, b in px)
    return sum(ys) / len(ys), ys[int(len(ys) * 0.95)]


def metadata(titulos):
    """La licencia sale de extmetadata: es dato de la API, no una suposicion."""
    fuera = {}
    for i in range(0, len(titulos), 20):
        p = {
            "action": "query", "format": "json", "formatversion": "2",
            "titles": "|".join(titulos[i:i + 20]), "prop": "imageinfo",
            "iiprop": "url|size|extmetadata|mime",
            "iiextmetadatafilter":
                "LicenseShortName|LicenseUrl|Artist|Credit|AttributionRequired",
        }
        req = urllib.request.Request(API + "?" + urllib.parse.urlencode(p),
                                     headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=120) as r:
            d = json.load(r)
        for pg in d["query"]["pages"]:
            ii = (pg.get("imageinfo") or [{}])[0]
            em = ii.get("extmetadata", {})
            v = lambda k: (em.get(k) or {}).get("value", "")
            fuera[pg["title"]] = {
                "titulo": pg["title"],
                "nativo": [ii.get("width"), ii.get("height")],
                "pagina": "https://commons.wikimedia.org/wiki/"
                          + urllib.parse.quote(pg["title"].replace(" ", "_")),
                "licencia": v("LicenseShortName"),
                "licencia_url": v("LicenseUrl"),
                "autor": limpiar(v("Artist")),
                "atribucion_requerida": v("AttributionRequired"),
            }
    return fuera


def limpiar(html):
    """El campo Artist viene con HTML. Solo se quiere el nombre."""
    return " ".join(re.sub(r"<[^>]+>", " ", html or "").split())[:160]


def bajar(titulo, ancho):
    """Pide a Commons la version ya escalada: bajar el original serian decenas
    de MB por una foto de la que se usa un recorte."""
    p = {"action": "query", "format": "json", "formatversion": "2",
         "titles": titulo, "prop": "imageinfo", "iiprop": "url",
         "iiurlwidth": str(ancho)}
    req = urllib.request.Request(API + "?" + urllib.parse.urlencode(p),
                                 headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as r:
        d = json.load(r)
    ii = d["query"]["pages"][0]["imageinfo"][0]
    req = urllib.request.Request(ii.get("thumburl") or ii["url"],
                                 headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=300) as r:
        return Image.open(io.BytesIO(r.read()))


def recortar(im, destino, foco, zoom=1.0):
    """Recorte por foco declarado, nunca centrado a ciegas.

    Toma la ventana MAS GRANDE del origen con la proporcion de destino, la
    centra en el foco y la corre hacia adentro si se sale del borde.

    `zoom` < 1 achica esa ventana y por lo tanto ACERCA. Existe porque el rol
    `sujeto` es un PRIMER PLANO: parallax.md §3.4 le pide la nitidez maxima y
    z2 sale del stack como lo que esta cerca. Con la ventana maxima, la foto
    del rack entraba entera y se leia como un plano general — un sujeto que se
    ve lejos contradice su propia velocidad de parallax. Se vio mirando la hoja
    de contacto de los .webp, no leyendo el codigo.
    """
    dw, dh = destino
    ow, oh = im.size
    prop = dw / dh
    if ow / oh > prop:
        cw, ch = int(round(oh * prop)), oh
    else:
        cw, ch = ow, int(round(ow / prop))
    cw, ch = int(round(cw * zoom)), int(round(ch * zoom))
    x = max(0, min(int(round(foco[0] * ow - cw / 2)), ow - cw))
    y = max(0, min(int(round(foco[1] * oh - ch / 2)), oh - ch))
    return im.crop((x, y, x + cw, y + ch)).resize(destino, Image.LANCZOS)


def ancho_necesario(nativo, med):
    """El ancho minimo de origen que da los DOS recortes sin agrandar."""
    ow, oh = nativo
    prop_v = med["v"][0] / med["v"][1]
    return int(min(max(med["v"][0] * (ow / oh) / prop_v, med["h"][0]), ow))


def rutas_de(p):
    """Los nombres se arman IGUAL que en Plano.tsx. Si esta funcion los armara
    distinto, se verificarian unos archivos y el navegador pediria otros — que
    es exactamente como se cuela un 404 con el verificador en verde."""
    if p.get("una_pieza"):
        return [(None, os.path.join(DESTINO, p["base"] + ".webp"))]
    return [(f, os.path.join(DESTINO, f'{p["base"]}-{f}.webp')) for f in ("v", "h")]


def main():
    os.makedirs(DESTINO, exist_ok=True)
    meta = metadata([p["titulo"] for p in PLANOS])
    registro = []

    for p in PLANOS:
        m = meta[p["titulo"]]
        med = MEDIDAS[p["rol"]]
        piezas = []
        fuente = bajar(p["titulo"], ancho_necesario(m["nativo"], med)
                       if not p.get("una_pieza") else med["v"][0])
        modo = "RGBA" if fuente.mode == "RGBA" else "RGB"

        for forma, ruta in rutas_de(p):
            if forma is None:
                im = recortar(fuente.convert(modo), med["v"], p["foco"]["v"],
                              p.get("zoom", 1.0))
            else:
                im = recortar(fuente.convert(modo), med[forma], p["foco"][forma],
                              p.get("zoom", 1.0))
            im.save(ruta, "WEBP", quality=p.get("calidad", med["calidad"]), method=6)
            y_med, y_p95 = luminancia(im)
            piezas.append({"archivo": os.path.basename(ruta), "px": list(im.size),
                           "kb": os.path.getsize(ruta) // 1024,
                           "y_medio": round(y_med, 4), "y_p95": round(y_p95, 4)})

        registro.append({**{k: p[k] for k in ("base", "escena", "rol", "por_que")},
                         "fuente": m, "piezas": piezas})
        print(f'  {p["base"]:<10} {m["licencia"]:<15} ' + "  ".join(
            f'{q["archivo"]} {q["kb"]}KB Y={q["y_medio"]:.3f}/p95 {q["y_p95"]:.3f}'
            for q in piezas))

    with open(os.path.join(DESTINO, "_assets.json"), "w", encoding="utf-8") as f:
        json.dump(registro, f, ensure_ascii=False, indent=1)
    total = sum(q["kb"] for r in registro for q in r["piezas"])
    print(f'\n  -> {sum(len(r["piezas"]) for r in registro)} assets, {total} KB')
    return verificar()


def verificar():
    """Control positivo Y negativo sobre lo que quedo en disco."""
    faltan, malos, oscuros = [], [], []
    for nombre in FORANEOS:
        ruta = os.path.join(DESTINO, nombre)
        if not os.path.exists(ruta):
            faltan.append(nombre + " (foraneo: NO lo trae este script)")
    for p in PLANOS:
        for forma, ruta in rutas_de(p):
            if not os.path.exists(ruta):
                faltan.append(os.path.basename(ruta))
                continue
            im = Image.open(ruta)
            if forma and tuple(im.size) != MEDIDAS[p["rol"]][forma]:
                malos.append(f"{os.path.basename(ruta)} mide {im.size}")
            # El control de fondo: el p95 tiene que superar la luminancia de la
            # tinta (0,0069). Un asset por debajo de eso es indistinguible de
            # no poner nada, que es el defecto que esta tanda vino a arreglar.
            _, p95 = luminancia(im)
            if p95 < 0.05:
                oscuros.append(f"{os.path.basename(ruta)} p95={p95:.4f}")
    print(f"  faltan: {faltan or 'ninguno'}")
    print(f"  medidas mal: {malos or 'ninguna'}")
    print(f"  demasiado oscuros (p95 < 0,05): {oscuros or 'ninguno'}")
    inventado = os.path.join(DESTINO, "no-existe-este-plano-v.webp")
    print(f"  control negativo (un asset inventado existe?): {os.path.exists(inventado)}")
    return 1 if (faltan or malos or oscuros) else 0


if __name__ == "__main__":
    sys.exit(verificar() if "--verificar" in sys.argv else main())
