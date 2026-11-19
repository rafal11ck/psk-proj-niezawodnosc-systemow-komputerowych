// Schemat struktury niezawodnościowej rysowany z drzewa `structure`.
//
// Układ wyznacza się z drzewa wprost:
//   szeregowo  -> szerokości się sumują, wysokość = maksimum
//   równolegle -> wysokości się sumują, szerokość = maksimum

#import "@preview/cetz:0.5.1"

#let XU = 1.9 // cm na jednostkę szerokości
#let YU = 1.3 // cm na jednostkę wysokości
#let BW = 1.3 // szerokość bloku [cm]
#let BH = 0.85 // wysokość bloku [cm]

#let dzieci(n) = n.at("ser", default: n.at("par", default: ()))

/// Rozmiar poddrzewa w jednostkach siatki.
#let size(n) = {
  if "el" in n { return (w: 1, h: 1) }
  let s = dzieci(n).map(size)
  if "ser" in n {
    (w: s.map(c => c.w).sum(), h: calc.max(..s.map(c => c.h)))
  } else {
    (w: calc.max(..s.map(c => c.w)), h: s.map(c => c.h).sum())
  }
}

/// Rysuje poddrzewo w pasie zaczynającym się w x0, wyśrodkowane na wysokości yc.
#let draw(n, x0, yc, etykieta) = {
  import cetz.draw: *
  let sz = size(n)
  let x1 = x0 + sz.w * XU

  if "el" in n {
    let cx = (x0 + x1) / 2
    rect((cx - BW / 2, yc - BH / 2), (cx + BW / 2, yc + BH / 2))
    content((cx, yc), etykieta(n.el))
    line((x0, yc), (cx - BW / 2, yc))
    line((cx + BW / 2, yc), (x1, yc))
  } else if "ser" in n {
    let x = x0
    for c in n.ser {
      draw(c, x, yc, etykieta)
      x += size(c).w * XU
    }
  } else {
    let gora = yc + sz.h * YU / 2
    let zajete = 0.0
    let srodki = ()
    for c in n.par {
      let cs = size(c)
      let cyc = gora - (zajete + cs.h / 2) * YU
      zajete += cs.h
      let cx0 = x0 + (sz.w - cs.w) * XU / 2
      draw(c, cx0, cyc, etykieta)
      line((x0, cyc), (cx0, cyc))
      line((cx0 + cs.w * XU, cyc), (x1, cyc))
      srodki.push(cyc)
    }
    line((x0, srodki.first()), (x0, srodki.last()))
    line((x1, srodki.first()), (x1, srodki.last()))
  }
}

/// Kompletny schemat z wejściem i wyjściem.
#let rbd(drzewo, etykieta) = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  set-style(stroke: 0.5pt)
  let sz = size(drzewo)
  let lead = 0.6
  draw(drzewo, lead, 0, etykieta)
  line((0, 0), (lead, 0))
  line((sz.w * XU + lead, 0), (sz.w * XU + 2 * lead, 0))
  circle((0, 0), radius: 0.06, fill: black)
  circle((sz.w * XU + 2 * lead, 0), radius: 0.06, fill: black)
})
