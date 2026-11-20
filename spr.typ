#import "@preview/diagraph:0.3.8"
#import "@preview/lilaq:0.6.0" as lq
#import "@preview/zero:0.6.1"
#import "rbd.typ": rbd

#let cfg = yaml("system.yaml")
#let res = yaml("out/results.yaml")

// Polski separator dziesiętny; liczby formatuje program.
#let pl(x) = str(x).replace(".", ",")
#zero.set-num(decimal-separator: ",")
#let liczba(x) = zero.num(str(x))

// Długie sumy łamane na wiersze: lewa strona, kolejne wiersze składników,
// na końcu wynik. Bez tego podstawienia nie mieszczą się w szerokości strony.
#let rownanie(lewa, skladniki, wynik, na-wiersz: 3) = {
  let wiersze = skladniki.chunks(na-wiersz).map(w => w.join($$))
  let linie = wiersze
    .enumerate()
    .map(((k, w)) => if k == 0 { $#lewa &= #w$ } else { $& #w$ })
  linie.push($&= #wynik$)
  math.equation(block: true, linie.join($ \ $))
}

// ── Dane do strony tytułowej ────────────────────────────────────────────────
// Układ strony wg szablonu z treści zadania. Numer grupy bierze się z danych
// (`res.N`)
#let uczelnia = "Politechnika Świętokrzyska"
#let wydzial = "Wydział Elektrotechniki, Automatyki i Informatyki"
#let przedmiot = "Niezawodność Systemów Komputerowych"
#let analiza = "Analiza niezawodnościowa serwera brzegowego monitoringu przemysłowego"
#let kierunek = "Informatyka"

// Tytuł, autor i data to metadane dokumentu, trafiają też do właściwości PDF-a.
#set document(
  title: analiza,
  author: (
    "inż. Rafał Grot",
    "inż. Bartłomiej Karkoszka",
    "inż. Filip Stępień",
  ),
  date: datetime(year: 2026, month: 10, day: 21),
)
#let autorzy = context document.author.join(linebreak())



// ── Opis elementów (pkt 1a i 1c)
#let podzespoly = (
  "1": "Mean Well RSP-320-12 (320 W, 12 V DC)",
  "2": "Supermicro X11SDV-4C-TLN2F (Intel Xeon D-2123IT, 4 rdzenie, 60 W TDP)",
  "3": "Micron MTA18ASF2G72PDZ, 16 GB DDR4-2666 ECC RDIMM",
  "4": "Samsung PM893, 480 GB, SATA 6 Gb/s",
  "5": "Samsung PM893, 480 GB, SATA 6 Gb/s",
  "6": "Intel I350-T2, 2 x 1 GbE",
  "7": "Sierra Wireless AirPrime EM7455, mini PCIe",
  "8": "Sunon PF80251B1-000U-A99, wentylator 80 mm",
)

// Kryterium uszkodzenia cecha, na podstawie której stwierdza się przejście
// elementu ze stanu zdatności do niezdatności.
#let kryterium = (
  "1": "Zanik napięcia wyjściowego lub wyjście poza tolerancję 12 V ± 5 %.",
  "2": "Zatrzymanie wykonywania instrukcji lub utrata obsługi magistral.",
  "3": "Błąd pamięci niemożliwy do skorygowania mechanizmem ECC.",
  "4": "Brak odpowiedzi dysku na żądanie odczytu lub zapisu.",
  "5": "Brak odpowiedzi dysku na żądanie odczytu lub zapisu.",
  "6": "Brak łączności przewodowej z centrum przetwarzania.",
  "7": "Brak łączności bezprzewodowej z centrum przetwarzania.",
  "8": "Spadek wydajności chłodzenia powodujący przekroczenie progu termicznego.",
)

// Role wynikają ze struktury niezawodnościowej: elementy w jednym węźle `par`
// pełnią funkcje alternatywne.
#let dzieci(n) = n.at("ser", default: n.at("par", default: ()))
#let elementy(n) = if "el" in n { (n.el,) } else {
  dzieci(n).map(elementy).flatten()
}

// Dla każdego elementu: lista elementów zamiennych (pusta, gdy krytyczny).
#let zamienniki-z(n) = {
  let out = (:)
  if "par" in n {
    let grupy = n.par.map(elementy)
    for (k, g) in grupy.enumerate() {
      let inne = grupy
        .enumerate()
        .filter(p => p.at(0) != k)
        .map(p => p.at(1))
        .flatten()
      for e in g { out.insert(str(e), inne) }
    }
  }
  for c in dzieci(n) {
    for (k, v) in zamienniki-z(c) { out.insert(k, v) }
  }
  out
}
#let zamienniki = zamienniki-z(cfg.structure)

// Wszystkie podstruktury równoległe, np. "E4/E5 oraz E6/E7".
#let grupy-z(n) = {
  let out = ()
  if "par" in n { out.push(n.par.map(elementy).flatten()) }
  for c in dzieci(n) { out += grupy-z(c) }
  out
}
#let rownolegle = {
  let g = grupy-z(cfg.structure).map(p => p.map(i => "E" + str(i)).join("/"))
  if g.len() < 2 { g.join("") } else {
    g.slice(0, -1).join(", ") + " oraz " + g.last()
  }
}

#let rola(e) = {
  let inne = zamienniki.at(str(e.id), default: ())
  if inne.len() == 0 { "krytyczny" } else {
    "alternatywny (z " + inne.map(i => "E" + str(i)).join(", ") + ")"
  }
}
#let krytyczne = {
  cfg
    .elements
    .filter(e => zamienniki.at(str(e.id), default: ()).len() == 0)
    .map(e => "E" + str(e.id))
    .join(", ")
}

// Ustawienia dokumentu
#set page(paper: "a4", margin: 2.5cm, numbering: "1")
#set text(lang: "pl", size: 11pt)
#set par(justify: true)
// Numeracja jak w treści zadania: punkty 1., 2., ... i podpunkty a), b), c).
#set heading(numbering: (..n) => {
  let poziom = n.pos()
  if poziom.len() == 1 { numbering("1.", poziom.last()) } else if (
    poziom.len() == 2
  ) { numbering("a)", poziom.last()) }
})
#show table.cell.where(y: 0): strong

// Odnośnik do podpunktu pokazuje pełny numer ("1d"), mimo że sam nagłówek
// jest numerowany samą literą, jak w treści zadania.
#show ref: it => {
  let el = it.element
  if el != none and el.func() == heading and el.level <= 2 {
    let n = counter(heading).at(el.location())
    numbering("1", n.at(0))
    if el.level == 2 { numbering("a", n.at(1)) }
  } else { it }
}

// Strona tytułowa
#page(numbering: none)[
  #set par(justify: false)
  #align(center)[
    #text(size: 14pt)[#uczelnia] \
    #text(size: 12pt)[#wydzial] \
    #v(0.4cm)
    #text(size: 12pt)[#przedmiot]
  ]

  #v(4cm)
  #align(center)[
    #text(size: 16pt, weight: "bold")[Projekt] \
    #v(0.6cm)
    #text(size: 14pt)[#analiza]
  ]

  #v(3cm)
  #align(right)[
    #grid(
      columns: (auto, auto),
      column-gutter: 0.6em,
      row-gutter: 0.45em,
      align: (left, left),
      [Wykonali:], autorzy,
      [Kierunek:], [#kierunek],
      [Grupa:], [#res.N],
    )
  ]

  #v(1fr)
  #align(center)[Kielce, #context document.date.display("[year]")]
]
#counter(page).update(1)

= Zbudować przykładowy system komputerowy składający się z 8 elementów nieodnawialnych, z których przynajmniej 2 będą względem siebie pełniły alternatywne funkcje

Przedmiotem analizy jest serwer brzegowy monitoringu przemysłowego, czyli stanowisko
zbierające dane pomiarowe ze sterowników na hali produkcyjnej, buforujące je
lokalnie i przesyłające do centrum przetwarzania. System złożono z
#cfg.elements.len() elementów nieodnawialnych, spośród których dwie pary pełnią względem
siebie funkcje alternatywne.

== Opis funkcjonowania systemu oraz poszczególnych elementów systemu

Serwer pracuje w trybie ciągłym. Zasilacz (E1) dostarcza napięcie 12 V do
płyty głównej i do układu chłodzenia. Płyta główna z procesorem (E2) stanowi
jednostkę obliczeniową i węzeł wszystkich magistral: obsługuje pamięć operacyjną
(E3) przez DDR4, dyski (E4, E5) przez SATA oraz interfejsy komunikacyjne
(E6, E7) przez PCIe. Dane pomiarowe trafiają na dyski pracujące w zwierciadle
RAID 1, a następnie są wysyłane do centrum przetwarzania zwykłym łączem
Ethernet albo, gdy jest ono niedostępne, przez modem LTE. Układ chłodzenia (E8)
odprowadza ciepło z obudowy; jego uszkodzenie prowadzi do przegrzania i
zatrzymania serwera.

*Kryterium zdatności systemu.* System uznaje się za zdatny wtedy i tylko
wtedy, gdy umożliwia jednoczesne realizowanie wszystkich trzech funkcji
użytkowych:

#list(
  [przyjmowanie danych pomiarowych ze sterowników],
  [trwały zapis tych danych w pamięci masowej],
  [przesyłanie ich do centrum przetwarzania],
)

Utrata choćby jednej z nich oznacza niezdatność systemu: dane niezapisane albo
nieprzesłane są tracone bezpowrotnie, więc nie ma tu stanów pośrednich:
system albo wykonuje swoje zadanie w całości, albo nie wykonuje go wcale.

*Elementy pełniące funkcje alternatywne.* Dyski E4 i E5 przechowują identyczną
kopię danych, więc do poprawnej pracy systemu wystarczy dowolny z nich.
Podobnie interfejs Ethernet (E6) i modem LTE (E7) realizują to samo zadanie
(transmisję do centrum przetwarzania) i każdy z osobna jest wystarczający.
Pozostałe elementy są niezbędne: uszkodzenie któregokolwiek z nich zatrzymuje
system.

#figure(
  table(
    columns: (auto, 1fr, 1.4fr),
    align: (center, left, left),
    table.header[Nr][Funkcja w systemie][Przykładowy podzespół],
    ..cfg
      .elements
      .map(e => (
        [E#e.id],
        [#e.name],
        [#podzespoly.at(str(e.id))],
      ))
      .flatten(),
  ),
  caption: [Elementy systemu wraz z przykładowymi podzespołami rzeczywistymi.],
)

== Schemat funkcjonalny systemu (schemat połączeń elementów systemu)

Schemat przedstawia połączenia między elementami: szynę zasilania wychodzącą
z zasilacza oraz magistrale, którymi płyta główna komunikuje się z pozostałymi
podzespołami.

#let akcent = maroon
#let tlo = akcent.lighten(85%)
#let etykieta(e) = "E" + str(e.id) + "\n" + e.name
#let dot-of(elementy, polaczenia, zapasy: ()) = {
  let nowe = zapasy.map(z => z.id)
  let wezly = elementy
    .filter(e => e.id not in nowe)
    .map(e => (
      e,
      ..zapasy
        .filter(z => z.of == e.id)
        .map(z => elementy.find(x => x.id == z.id)),
    ))
    .flatten()
  let poz(id) = wezly.position(e => e.id == id)
  let koncowy(id) = polaczenia.all(l => l.from != id)
  let z-prawej(id) = (
    id in nowe and polaczenia.filter(l => l.from == id).all(l => koncowy(l.to))
  )
  let kolor = "color=\"" + akcent.to-hex() + "\""
  let blok = (
    ", penwidth=1.5, style=\"rounded,filled\", fillcolor=\""
      + tlo.to-hex()
      + "\", "
      + kolor
  )
  let krawedz = ", " + kolor + ", fontcolor=\"" + akcent.to-hex() + "\""
  (
    "digraph {\n"
      + "  rankdir=LR; splines=polyline; nodesep=0.35; ranksep=0.7; ordering=out;\n"
      + "  node [shape=box, style=rounded, fontsize=10, width=1.5, height=0.6];\n"
      + "  edge [fontsize=9];\n"
      + wezly
        .map(e => (
          "  "
            + str(e.id)
            + " [label=\""
            + etykieta(e)
            + "\""
            + if e.id in nowe { blok } else { "" }
            + "];\n"
        ))
        .join("")
      + polaczenia
        .sorted(key: l => poz(l.from) * wezly.len() + poz(l.to))
        .map(l => (
          "  "
            + if z-prawej(l.from) {
              str(l.to) + " -> " + str(l.from) + " [dir=back, "
            } else { str(l.from) + " -> " + str(l.to) + " [" }
            + "label=\""
            + l.label
            + "\""
            + if l.from in nowe or l.to in nowe { krawedz } else { "" }
            + "];\n"
        ))
        .join("")
      + "}"
  )
}

#figure(
  diagraph.render(dot-of(cfg.elements, cfg.links), width: 100%),
  caption: [Schemat funkcjonalny systemu.],
)

== Opis niezawodnościowy elementów systemu

Opis niezawodnościowy elementu obejmuje kryterium uszkodzenia, klasyfikację
uszkodzeń oraz przyjęty model czasu poprawnej pracy. Uszkodzenie to zdarzenie
polegające na przejściu obiektu ze stanu zdatności do stanu niezdatności, a
kryterium uszkodzenia to cecha lub zespół cech, na których podstawie ustala
się fakt jego powstania.

=== Przyjęte założenia

Wszystkie elementy systemu są nieodnawialne, zgodnie z treścią zadania:
nie przewiduje się ich naprawy ani wymiany, więc uszkodzenie
elementu jest zdarzeniem nieodwracalnym.

Czas poprawnej pracy każdego elementu ma rozkład wykładniczy; jest to
założenie przyjęte w punkcie 2 treści zadania. Rozkład ten odznacza
się brakiem pamięci (obiekt nieuszkodzony jest tak samo niezawodny jak nowy)
i stosuje się go do obiektów o uszkodzeniach czysto przypadkowych.
Intensywność uszkodzeń jest wówczas niezależna od czasu,
$lambda(t) = lambda = "const"$, co odpowiada drugiemu przedziałowi krzywej
życia, czyli okresowi normalnej eksploatacji, w którym dominują uszkodzenia
wywołane czynnikami losowymi.

Stałość intensywności uszkodzeń prowadzi wprost do wykładniczej postaci funkcji
niezawodności. Intensywność uszkodzeń jest bowiem z definicji względną
prędkością ubywania obiektów zdatnych:

$ lambda = - 1/(R(t)) dot (dif R(t))/(dif t), $

co po rozdzieleniu zmiennych daje równanie różniczkowe $dif R \/ dif t =
-lambda R(t)$ z warunkiem początkowym $R(0) = 1$, bo w chwili rozpoczęcia pracy
element jest zdatny. Jego rozwiązaniem jest

$ R(t) = e^(-lambda t). $

Podstawą potęgi jest stała Eulera $e approx$ 2,718.

Element opisują wtedy funkcje:

$
  R_i (t) = e^(-lambda_i t), quad F_i (t) = 1 - e^(-lambda_i t), quad
  f_i (t) = lambda_i e^(-lambda_i t), quad E T_i = lambda_i^(-1),
$

gdzie:

#grid(
  columns: (auto, 1fr),
  row-gutter: 0.5em,
  column-gutter: 1em,
  align: (right + top, left),
  [$i$], [numer elementu systemu, $i = 1, dots, #cfg.elements.len()$,],
  [$t$], [czas pracy systemu, $t >= 0$, w godzinach,],
  [$e$], [stała Eulera, $e approx$ 2,718,],
  [$lambda_i$],
  [intensywność uszkodzeń elementu $i$, stała w czasie, w $1\/"h"$,],

  [$R_i (t)$],
  [funkcja niezawodności elementu $i$, czyli prawdopodobieństwo, że
    element nie ulegnie uszkodzeniu do chwili $t$,],

  [$F_i (t)$],
  [dystrybuanta trwałości, czyli prawdopodobieństwo, że element
    ulegnie uszkodzeniu do chwili $t$; $F_i (t) = 1 - R_i (t)$,],

  [$f_i (t)$], [gęstość prawdopodobieństwa czasu poprawnej pracy elementu,],
  [$E T_i$], [oczekiwany czas zdatności elementu, w godzinach.],
)

=== Klasyfikacja uszkodzeń

Uszkodzenia elementów rozpatrywanego systemu sklasyfikowano następująco.

#figure(
  table(
    columns: (1.4fr, 1fr, 1.6fr),
    align: (left, left, left),
    table.header[Kryterium klasyfikacji][Przyjęty rodzaj][Uzasadnienie],
    [Stopień wpływu na zdolność do poprawnej pracy],
    [całkowite],
    [przyjęto model dwustanowy: element jest zdatny albo niezdatny],

    [Fizyczny charakter powstania],
    [katastroficzne],
    [uszkodzenie powoduje całkowitą utratę zdolności do poprawnej pracy],

    [Związek z innymi uszkodzeniami],
    [niezależne],
    [uszkodzenie elementu nie wywołuje uszkodzeń pozostałych],

    [Charakter procesu pojawienia się],
    [nagłe],
    [stała intensywność uszkodzeń wyklucza dominację procesów zużyciowych],

    [Czas występowania],
    [stałe],
    [elementy są nieodnawialne, więc stan niezdatności jest trwały],
  ),
  caption: [Klasyfikacja uszkodzeń elementów systemu.],
)

=== Charakterystyka elementów

Elementy krytyczne (#krytyczne) nie mają zastępstwa: uszkodzenie
któregokolwiek z nich powoduje niezdatność systemu. Elementy alternatywne
tworzą dwie pary: dyski E4 i E5 przechowują tę samą kopię danych, a interfejsy
E6 i E7 realizują tę samą transmisję, więc w każdej parze wystarczy jeden
element zdatny.

#figure(
  table(
    columns: (auto, 1.1fr, 1.6fr, auto),
    align: (center, left, left, center),
    table.header[Nr][Element][Kryterium uszkodzenia][Rola],
    ..cfg
      .elements
      .map(e => (
        [E#e.id],
        [#e.name],
        [#kryterium.at(str(e.id))],
        [#rola(e)],
      ))
      .flatten(),
  ),
  caption: [Kryteria uszkodzenia i rola elementów w systemie.],
)

== Struktura niezawodnościowa systemu, schemat <struktura>

System ma strukturę szeregowo-równoległą. Część szeregową tworzą elementy
#krytyczne, a podstruktury równoległe tworzą pary #rownolegle.

#figure(
  rbd(cfg.structure, i => text(size: 10pt)[E#i]),
  caption: [Struktura niezawodnościowa systemu.],
)

= Zakładamy

Czas poprawnej pracy elementów jest zgodny z rozkładem wykładniczym,
o intensywnościach uszkodzeń zadanych w treści projektu dla numeru grupy
projektowej $N = #res.N$:

$
  lambda_i = 2 N i dot 10^(-6) thin [1\/h] quad & "dla" i "nieparzystych", \
  lambda_i = 3 N (#(res.count + 1) - i) dot 10^(-6) thin [1\/h] quad & "dla" i "parzystych".
$

Wartości funkcji niezawodności wyznaczono dla chwili
$t = 100 + 5 N = 100 + 5 dot #res.N = #res.t$ h.

Dla każdego elementu daje to:

#let lam-wzor(e) = if calc.odd(e.id) {
  $2 dot #res.N dot #e.id$
} else {
  $3 dot #res.N dot (#(res.count + 1) - #e.id)$
}

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: (center + horizon, left, left, left),
    inset: (x: 7pt, y: 5pt),
    table.header(
      [Nr],
      [$lambda_i thin [1\/h]$],
      [$R_i (#res.t "h") = e^(-lambda_i t)$],
      [$E T_i = 1\/lambda_i thin ["h"]$],
    ),
    ..res
      .elements
      .map(e => (
        [E#e.id],
        $#lam-wzor(e) dot 10^(-6) = #e.lambdaUnits dot 10^(-6)$,
        $e^(-#e.lambdaUnits dot 10^(-6) dot #res.t) = #pl(e.R)$,
        $1 / (#e.lambdaUnits dot 10^(-6)) = #pl(e.et)$,
      ))
      .flatten(),
  ),
  caption: [Intensywności uszkodzeń i niezawodność elementów dla $N = #res.N$.],
)

== Funkcja niezawodności systemu $R_s (t)$ <rs>

Funkcja niezawodności systemu $R_s (t)$ to prawdopodobieństwo, że system będzie
poprawnie pracował w chwili $t$. System ma strukturę szeregowo-równoległą
(punkt @struktura), dla której

$
  R_s (t) = product_(r = 1)^p R^((r))(t), quad "przy czym" quad
  R^((r))(t) = 1 - product_(i = 1)^(n_r) [1 - R_(r,i)(t)],
$

gdzie:

#grid(
  columns: (auto, 1fr),
  row-gutter: 0.5em,
  column-gutter: 1em,
  align: (right + top, left),
  [$p$], [liczba układów połączonych szeregowo,],
  [$n_r$], [liczba części składowych $r$-tego układu, połączonych równolegle,],
  [$R^((r))(t)$], [funkcja niezawodności $r$-tego układu,],
  [$R_(r,i)(t)$],
  [funkcja niezawodności $i$-tej części składowej $r$-tego układu.],
)

#let uklady = cfg.structure.ser
#let poj = uklady.filter(w => "el" in w).len()
#let par-n = uklady.len() - poj

W analizowanym systemie $p = #uklady.len()$: #poj układy są jednoelementowe,
a #par-n złożone z dwóch części połączonych równolegle. Po podstawieniu
struktury, wymnożeniu nawiasów i podstawieniu $R_i (t) = e^(-lambda_i t)$:

#let czynnik-wykl(w) = if "el" in w {
  $R_#w.el$
} else {
  $[1 - #elementy(w).map(i => $(1 - R_#i)$).join()]$
}
#let czynnik-rozw(w) = if "el" in w {
  $R_#w.el$
} else {
  let e = elementy(w)
  if e.len() == 2 {
    $(R_#e.at(0) + R_#e.at(1) - R_#e.at(0) R_#e.at(1))$
  } else { czynnik-wykl(w) }
}
#let wyraz(tm, pierwszy) = {
  let znak = if tm.coeff < 0 { $-$ } else if pierwszy { none } else { $+$ }
  let a = calc.abs(tm.coeff)
  let wsp = if a == 1 { none } else { $#a$ }
  $#znak #wsp e^(-#tm.rate mu t)$
}
#let wyrazy = {
  res
    .terms
    .enumerate()
    .map(((k, tm)) => wyraz(tm, k == 0))
    .chunks(5)
    .map(w => w.join($$))
}

$
  R_s (t) & = #uklady.map(czynnik-wykl).join() \
          & = #uklady.map(czynnik-rozw).join() \
          & = sum_j c_j e^(-r_j mu t) \
          & = #wyrazy.at(0) \
          & #h(1em) #wyrazy.at(1),
$

gdzie:

#grid(
  columns: (auto, 1fr),
  row-gutter: 0.5em,
  column-gutter: 1em,
  align: (right + top, left),
  [$j$], [numer wyrazu postaci wykładniczej, $j = 1, dots, #res.terms.len()$,],
  [$c_j$], [współczynnik całkowity $j$-tego wyrazu,],
  [$r_j$], [wykładnik $j$-tego wyrazu, wyrażony w krotnościach $mu$,],
  [$mu$], [jednostka intensywności uszkodzeń, $mu = 10^(-6)$ $1\/h$.],
)

#let zebrane = res.terms.filter(tm => calc.abs(tm.coeff) > 1)
#let lista(xs) = xs.map(x => [#x]).join([, ], last: [ i ])

Wymnożenie nawiasów daje #res.monomials.len() jednomianów, po jednym na każdy
wybór gałęzi w obu podstrukturach równoległych. Wykładniki składników iloczynu
sumują się, a jednomiany o jednakowym wykładniku zbierają się w jeden wyraz.
#if zebrane.len() > 0 [
  Wykładnik#if zebrane.len() > 1 [i] #lista(zebrane.map(tm => tm.rate))
  #if zebrane.len() == 1 [występuje] else [występują] więcej niż raz, stąd
  współczynnik#if zebrane.len() > 1 [i] #lista(zebrane.map(tm => tm.coeff))#[.]
]

#let iloczyn(m) = m.elements.map(i => $R_#i$).join()
#let suma(m) = (
  m.elements.map(i => str(res.elements.at(i - 1).lambdaUnits)).join(" + ")
)

#figure(
  table(
    columns: (auto, auto, 1fr, auto),
    align: (center, left, right, right),
    table.header[Znak][Jednomian][Suma $lambda_i dot 10^6$][Wykładnik],
    ..res
      .monomials
      .map(m => (
        [#if m.coeff < 0 [$-$] else [$+$]],
        [$#iloczyn(m)$],
        [#suma(m)],
        [#m.rate],
      ))
      .flatten(),
  ),
  caption: [Jednomiany rozwinięcia $R_s (t)$ i ich wykładniki.],
)

Podstawiając $t = #res.t$ h:

#let czlon(tm, pierwszy) = {
  let znak = if tm.coeff < 0 { $-$ } else if pierwszy { none } else { $+$ }
  let a = calc.abs(tm.coeff)
  let wsp = if a == 1 { none } else { $#a$ }
  $#znak #wsp e^(-#tm.rate dot 10^(-6) dot #res.t)$
}

#rownanie(
  $R_s (#res.t "h")$,
  res.terms.enumerate().map(((k, tm)) => czlon(tm, k == 0)),
  $#pl(res.rs).$,
)

== Prawdopodobieństwo braku uszkodzenia w przedziale $(t, t + Delta)$

$P_s (t, t + Delta)$ to prawdopodobieństwo, że system nie ulegnie uszkodzeniu
w przedziale czasu $(t, t + Delta)$, przy czym w chwili $t$ mógł on już być
niezdatny. Dla $Delta = #res.deltaT$ h, czyli przedziału
$(#res.t, #(res.t + res.deltaT))$ h:

$
  P_s (t, t + Delta) & = 1 - [R_s (t) - R_s (t + Delta)] \
                     & = 1 - [#pl(res.rs) - #pl(res.rsDelta)] = #pl(res.ps).
$

== Oczekiwany czas zdatności systemu

Oczekiwany czas zdatności systemu $E T_s$ to wartość oczekiwana czasu pracy
systemu do pierwszego uszkodzenia; zgodnie z treścią zadania wyznacza się go
jako pole pod wykresem funkcji niezawodności.

Funkcja $R_s (t)$ jest skończoną sumą wykładników, więc całka sumy równa się
sumie całek, a każda z nich jest elementarna:
$integral_0^infinity e^(-a t) dif t = 1\/a$. Stąd

#let ulamek(tm, pierwszy) = {
  let znak = if tm.coeff < 0 { $-$ } else if pierwszy { none } else { $+$ }
  let a = calc.abs(tm.coeff)
  $#znak #a/#tm.rate$
}
#let ulamki = {
  res.terms.enumerate().map(((k, tm)) => ulamek(tm, k == 0)).join($$)
}

$
  E T_s & = integral_0^infinity R_s (t) dif t \
        & = integral_0^infinity sum_j c_j e^(-r_j mu t) dif t \
        & = sum_j c_j integral_0^infinity e^(-r_j mu t) dif t \
        & = sum_j c_j / (r_j mu) = 1/mu sum_j c_j / r_j, quad
          1/mu = 1/10^(-6) = 10^6 thin "h" \
        & = 10^6 dot lr((#math.inline(ulamki))) \
        & = 10^6 dot #pl(res.etsSum) \
        & approx #pl(res.ets) thin "h".
$

== Zbiór minimalnych ścieżek zdatności

Podzbiór elementów systemu nazywa się ścieżką zdatności, jeżeli przy
zdatności wszystkich jego elementów system jest zdatny niezależnie od stanu
pozostałych. Ścieżka jest minimalna, jeżeli nie zawiera żadnej innej ścieżki
zdatności.

#let zbior(s) = $\{#s.map(str).join(", ")\}$
#let xs(s) = s.map(i => $x_#i$).join()

$ #res.paths.map(zbior).join($,$) $

Minimalna formuła alternatywna, w której każdemu składnikowi sumy odpowiada dokładnie
jedna minimalna ścieżka zdatności:

$ f^((#res.count))(x) = #res.paths.map(xs).join($ or $) $

== Zbiór minimalnych cięć

Podzbiór elementów nazywa się cięciem, jeżeli przy niezdatności wszystkich
jego elementów system jest niezdatny niezależnie od stanu pozostałych. Cięcie
jest minimalne, jeżeli nie zawiera żadnego innego cięcia.

$ #res.cuts.map(zbior).join($,$) $

Minimalna formuła koniunkcyjna, w której każdemu czynnikowi iloczynu odpowiada
dokładnie jedno minimalne cięcie:

$
  f^((#res.count))(x) = #res.cuts.map(c => {
    if c.len() == 1 { $x_#c.at(0)$ } else { $(#c.map(i => $x_#i$).join($ or $))$ }
  }).join($ and $)
$

#let mala(s) = {
  let c = s.clusters()
  lower(c.first()) + c.slice(1).join()
}
#let odbiorniki(v, zap) = (
  v
    .links
    .filter(l => l.from == zap.id)
    .map(l => {
      mala(v.elements.find(e => e.id == l.to).name) + " (E" + str(l.to) + ")"
    })
)

#let para-r(zap) = $R_(#zap.of parallel #zap.id)$
#let zapas(n, v) = if (
  "par" in n and n.par.len() == 2 and n.par.all(c => "el" in c)
) {
  v.spares.find(zap => zap.of == n.par.at(0).el and zap.id == n.par.at(1).el)
}
#let blok(n, v, para) = {
  let zap = zapas(n, v)
  if zap != none { para(zap) } else if "el" in n { $R_#n.el$ } else if (
    "ser" in n
  ) {
    n.ser.map(c => blok(c, v, para)).join()
  } else if n.par.len() == 2 {
    let (a, b) = n.par.map(c => blok(c, v, para))
    $(#a + #b - #a #b)$
  } else {
    $[1 - #n.par.map(c => $(1 - #blok(c, v, para))$).join()]$
  }
}

#let wariant(v, schemat: none, struktura: none) = {
  let jeden = v.spares.len() == 1
  let dwa(t) = v.spares.map(zap => $(2 - R_#zap.of #t)$).join()
  let wyk(zap, t) = $2 - e^(-lambda_#zap.of #t)$
  let n-wzor(t) = if jeden { wyk(v.spares.first(), t) } else {
    v.spares.map(zap => $(#wyk(zap, t))$).join()
  }
  let rozw = if jeden { $= 2 R_s (t) - R_#v.spares.first().of (t) R_s (t)$ }
  let nowe = v.spares.map(z => z.id)
  let wyroznienie = [#if jeden [Element rezerwowy wyróżniono] else [Elementy rezerwowe wyróżniono] kolorem.]

  [
    == Schemat funkcjonalny systemu z redundancją

    #schemat

    #figure(
      diagraph.render(
        dot-of(v.elements, v.links, zapasy: v.spares),
        width: 100%,
      ),
      caption: [Schemat funkcjonalny systemu z redundancją. #wyroznienie],
    )

    == Struktura niezawodnościowa systemu z redundancją

    #struktura

    #figure(
      rbd(
        v.structure,
        i => text(size: 10pt)[E#i],
        styl: i => if i in nowe {
          (fill: tlo, stroke: 1pt + akcent)
        } else { (:) },
      ),
      caption: [Struktura niezawodnościowa systemu z redundancją. #wyroznienie],
    )

    == Wyznaczenie $R_r (t)$, $P_r (t, t + Delta)$ oraz $E T_r$

    #if jeden [Niezawodność pary z elementem rezerwowym:] else [Niezawodność par z elementami rezerwowymi:]

    #for zap in v.spares [
      $
        #para-r(zap) (t) & = 1 - (1 - R_#zap.of)^2 = 1 - (1 - 2 R_#zap.of + R_#zap.of^2) \
        & = 2 R_#zap.of - R_#zap.of^2 = R_#zap.of (2 - R_#zap.of).
      $
    ]

    Niezawodność systemu z redundancją:

    #if v.series [
      $
        R_r (t) & = #blok(v.structure, v, para-r) \
                & = #dwa(none) dot #blok(cfg.structure, v, para-r) \
                & = #dwa($(t)$) dot R_s (t) #rozw,
      $

      gdzie $R_s (t)$ to funkcja niezawodności systemu bez redundancji (punkt @rs).
    ] else [
      $
        R_r (t) & = #blok(v.structure, v, para-r) \
                & = #blok(v.structure, v, zap => $R_#zap.of (2 - R_#zap.of)$).
      $
    ]

    #block(breakable: false, width: 100%)[
      Dla $t = #res.t$ h:

      #rownanie(
        $R_r (#res.t "h")$,
        v.terms.enumerate().map(((k, tm)) => czlon(tm, k == 0)),
        $#pl(v.rr).$,
      )
    ]

    Prawdopodobieństwo braku uszkodzenia w przedziale $(t, t + Delta)$:

    $
      P_r (t, t + Delta) & = 1 - [R_r (t) - R_r (t + Delta)] \
                         & = 1 - [#pl(v.rr) - #pl(v.rrDelta)] = #pl(v.pr).
    $

    Oczekiwany czas zdatności:

    $
      E T_r = integral_0^infinity R_r (t) dif t
      = integral_0^infinity sum_j c_j e^(-r_j mu t) dif t
      = 1/mu sum_j c_j / r_j,
    $

    #rownanie(
      $sum_j c_j / r_j$,
      v.terms.enumerate().map(((k, tm)) => ulamek(tm, k == 0)),
      $#pl(v.etrSum),$,
      na-wiersz: 6,
    )

    $ E T_r = 10^6 dot #pl(v.etrSum) approx #pl(v.etr) thin "h". $

    == Wskaźniki korzyści z redundancji

    Wyniki dla $t = #res.t$ h i $t = 0$:

    #figure(
      table(
        columns: (auto, auto, auto),
        align: (left, center, right),
        inset: (x: 8pt, y: 5pt),
        table.header[Wskaźnik][Definicja][Wartość],
        [$N_(R(t))$], $R_r (t) \/ R_s (t)$, [#pl(v.nrT)],
        [$N_(R(0))$], $R_r (0) \/ R_s (0)$, [#pl(v.nr0)],
        [$N_(P(t, t+Delta))$],
        $P_r (t, t+Delta) \/ P_s (t, t+Delta)$,
        [#pl(v.npT)],

        [$N_(E T)$], $E T_r \/ E T_s$, [#pl(v.net)],
      ),
      caption: [Wskaźniki korzyści z redundancji.],
    )

    == Chwila $t^*$ maksymalnej korzyści $N_(R(t))$

    #if v.series [
      Po podstawieniu $R_r (t)$:

      $
        N_(R(t)) = (R_r (t)) / (R_s (t)) = (#dwa($(t)$) R_s (t)) / (R_s (t)) = #n-wzor($t$).
      $
    ]

    #if v.series [
      Największa wartość $N_(R(t))$ w przedziale $[0, #liczba(v.horizon)]$ h:
    ] else [
      Największą wartość $N_(R(t))$ w przedziale $[0, #liczba(v.horizon)]$ h
      wyznaczono numerycznie, obliczając $N_(R(t))$ co~#v.step~h:
    ]

    $
      t^* = #liczba(v.tStar) thin "h", quad max N_(R(t)) #if v.series { $= #n-wzor($t^*$)$ } = #pl(v.maxNr).
    $

    #figure(
      lq.diagram(
        width: 12cm,
        height: 6.5cm,
        xaxis: (exponent: 0, tick-distance: v.horizon / 5),
        xlabel: $t thin ["h"]$,
        ylabel: $N_(R(t))$,
        lq.plot(v.plot.map(p => p.t), v.plot.map(p => p.nr), mark: none),
        lq.hlines(float(v.maxNr), stroke: (paint: gray, dash: "dashed")),
        lq.vlines(v.tStar, stroke: (paint: gray, dash: "dashed")),
        lq.scatter((v.tStar,), (float(v.maxNr),), color: maroon, size: 6pt),
        lq.place(0%, float(v.maxNr), align: left + top, pad(
          0.3em,
        )[$max N_(R(t))$]),
        lq.place(
          v.tStar,
          100%,
          align: (if v.tStar > v.horizon / 2 { right } else { left }) + bottom,
          pad(0.3em)[$t^*$],
        ),
      ),
      caption: [Wskaźnik $N_(R(t))$ w zależności od czasu.],
    )
  ]
}

#let red = res.variants.at(0)
#let zap = red.spares.first()

#pagebreak(weak: true)
= Zdublować pierwszy element, czyli dodać jeden element (nr #zap.id o intensywności $lambda_#zap.of$ i funkcji niezawodności $R_#zap.of (t)$) i umieścić go jako redundancję dla pierwszego elementu systemu <p3>

Pierwszym elementem jest zasilacz (E#zap.of). Jest on połączony szeregowo z
resztą systemu, więc jego awaria od razu wyłącza cały serwer (cięcie
$\{#zap.of\}$). Równolegle do niego dodano drugi, taki sam zasilacz
(E#zap.id) o intensywności uszkodzeń
$lambda_#zap.id = lambda_#zap.of = #zap.units dot 10^(-6) thin 1\/h$.
Jest to rezerwowanie stałe: drugi zasilacz jest przyłączony na stałe i pracuje
razem z pierwszym od chwili $t = 0$, a serwer traci zasilanie dopiero po
uszkodzeniu obu.

#wariant(
  red,
  schemat: [
    Drugi zasilacz (E#zap.id) podłączono równolegle do pierwszego. Z obu
    zasilane są: #odbiorniki(red, zap).join(", ", last: " i ").
  ],
  struktura: [
    Pojedynczy blok zasilacza (E#zap.of) zastąpiono równoległą parą zasilaczy
    (E#zap.of i E#zap.id), reszta struktury się nie zmienia.
  ],
)

#let nazwa(id) = cfg.elements.find(e => e.id == id).name
#let z-id(id) = [#mala(nazwa(id)) (E#id)]
#let el(id) = res.elements.find(e => e.id == id)
#let oznaczenie(v) = v.spares.map(z => [E#z.of #sym.parallel E#z.id]).join([, ])

#let opis(v) = for zap in v.spares {
  let inne = zamienniki.at(str(zap.of), default: ())
  let ciecie = res.cuts.find(c => zap.of in c)
  [
    Dublowanym elementem jest #z-id(zap.of).
    #if inne.len() == 0 [
      Element ten jest połączony szeregowo z resztą systemu, więc jego
      uszkodzenie od razu powoduje niezdatność systemu (cięcie #zbior(ciecie)).
    ] else [
      Element ten i #lista(inne.map(z-id)) pełnią funkcje alternatywne, więc
      niezdatność systemu powoduje dopiero uszkodzenie
      #if inne.len() == 1 [obu] else [wszystkich] (cięcie #zbior(ciecie)).
    ]
    Element rezerwowy (E#zap.id) jest taki sam jak element dublowany i ma
    intensywność uszkodzeń
    $lambda_#zap.id = lambda_#zap.of = #zap.units dot 10^(-6) thin 1\/h$.

  ]
}

#let dalsze = res.variants.slice(1)

#pagebreak(weak: true)
= Zdublować kolejne elementy systemu, czyli dodać element rezerwowy (nr #dalsze.slice(0, 2).map(v => str(v.spares.first().id)).join(", ") itd.) kolejno do pozostałych elementów systemu i powtórzyć działania z pkt. #ref(<p3>)a) do #ref(<p3>)e)

Każdy wariant rozpatrywano osobno: do systemu z punktu @struktura dodano jeden
element rezerwowy, przyłączony na stałe równolegle do elementu dublowanego
(rezerwowanie stałe), a wskaźniki korzyści odniesiono do systemu bez redundancji.

#{
  set heading(numbering: (..n) => {
    let p = n.pos()
    if p.len() == 2 { numbering("1.1.", ..p) } else if p.len() == 3 {
      numbering("a)", p.last())
    }
  })
  for (k, v) in dalsze.enumerate() {
    if k > 0 { pagebreak(weak: true) }
    heading(
      level: 2,
      v
        .spares
        .map(z => [#nazwa(z.of) (E#z.of) i element rezerwowy (E#z.id)])
        .join([, ]),
    )
    opis(v)
    {
      set heading(offset: 1)
      wariant(
        v,
        schemat: v
          .spares
          .map(z => [
            Element rezerwowy (E#z.id) ma te same połączenia co element
            dublowany (E#z.of).
          ])
          .join(),
        struktura: v
          .spares
          .map(z => [
            Blok elementu dublowanego (E#z.of) zastąpiono równoległą parą
            (E#z.of i E#z.id), reszta struktury się nie zmienia.
          ])
          .join(),
      )
    }
  }
}

= Zestawić w tabeli dla każdego wariantu rezerwowania obliczone wskaźniki $R_r (t)$, $P_r (t, t + Delta)$, $E T_r$, $N_(R(t))$, $N_(P(t, t + Delta))$, $N_(E T)$, $t^*$, $max N_(R(t))$

Wartości dla $t = #res.t$ h i $Delta = #res.deltaT$ h:

#figure(
  text(size: 9pt, table(
    columns: 9,
    align: (left,) + (right,) * 8,
    inset: (x: 4pt, y: 5pt),
    table.header(
      [Wariant],
      $R_r (t)$,
      $P_r (t, t + Delta)$,
      [$E T_r$ [h]],
      $N_(R(t))$,
      $N_(P(t, t + Delta))$,
      $N_(E T)$,
      [$t^*$ [h]],
      $max N_(R(t))$,
    ),
    ..res
      .variants
      .map(v => (
        oznaczenie(v),
        pl(v.rr),
        pl(v.pr),
        pl(v.etr),
        pl(v.nrT),
        pl(v.npT),
        pl(v.net),
        pl(v.tStar),
        pl(v.maxNr),
      ))
      .flatten(),
  )),
  caption: [Wskaźniki niezawodności i korzyści z redundancji dla wariantów rezerwowania.],
) <zestawienie>

#let wv(i) = res.variants.at(i)
#let po-nr = res.order.nrT.map(wv)
#let po-net = res.order.net.map(wv)
#let b-nr = po-nr.first()
#let b-net = po-net.first()
#let zap-nr = b-nr.spares.first()
#let zap-net = b-net.spares.first()
#let w-rown = res.variants.filter(v => not v.series)
#let w-srodek = res.variants.filter(v => v.tStar < v.horizon)
#let horyzont = res.variants.first().horizon
#let dubl(v) = lista(v.spares.map(z => z-id(z.of)))
#let kolory = lq.color.map.petroff10

= Wnioski

== Ocena wpływu wprowadzenia redundancji na wartości obliczanych wskaźników niezawodności

W chwili $t = 0$ wszystkie elementy są zdatne, więc $R_r (0) = R_s (0) = 1$ i
$N_(R(0)) = 1$ w każdym wariancie. Element rezerwowy zaczyna dawać korzyść dopiero
wtedy, gdy element dublowany może już być uszkodzony.

Dla $t = #res.t$ h wskaźniki $R_r (t)$ i $P_r (t, t + Delta)$ rosną niewiele
(@zestawienie[tabela]). Dla elementu połączonego szeregowo
$N_(R(t)) = 2 - R_k (t) = 1 + F_k (t)$, czyli niezawodność systemu rośnie
względnie o prawdopodobieństwo uszkodzenia elementu dublowanego do chwili $t$, a
to prawdopodobieństwo jest jeszcze małe.
#if b-nr.series [
  W wariancie o największym $N_(R(t))$ dublowanym elementem jest
  #z-id(zap-nr.of):
  $N_(R(t)) = 2 - R_#zap-nr.of (#res.t "h") = 2 - #pl(el(zap-nr.of).R) = #pl(b-nr.nrT)$.
]

#if w-rown.len() > 0 [
  Elementy z podstruktur równoległych, czyli #lista(w-rown.map(dubl)), mają już
  element alternatywny, więc korzyść z ich zdublowania jest w chwili $t$ jeszcze
  mniejsza. Podstruktura równoległa jest niezdatna dopiero po uszkodzeniu
  wszystkich swoich elementów, więc jej zawodność jest iloczynem zawodności tych
  elementów i w chwili $t$ jest bardzo mała. Dodatkowy element zmniejsza ją
  jeszcze bardziej, ale prawie nie zmienia $R_r (t)$.
]

Znacznie silniej redundancja wpływa na oczekiwany czas zdatności: największe
$N_(E T) = #pl(b-net.net)$, a największe $N_(R(t)) = #pl(b-nr.nrT)$. Czas
$E T_r$ obejmuje cały okres pracy systemu, także ten, w którym uszkodzenie
dublowanego elementu jest już prawdopodobne.

#figure(
  lq.diagram(
    width: 12cm,
    height: 7cm,
    xaxis: (exponent: 0, tick-distance: horyzont / 5),
    xlabel: $t thin ["h"]$,
    ylabel: $N_(R(t))$,
    legend: (position: left + top, dx: 100%),
    ..res
      .variants
      .enumerate()
      .map(((k, v)) => {
        let kolor = kolory.at(calc.rem(k, kolory.len()))
        (
          lq.plot(
            v.plot.map(p => p.t),
            v.plot.map(p => p.nr),
            mark: none,
            color: kolor,
            label: oznaczenie(v),
          ),
          lq.scatter((v.tStar,), (float(v.maxNr),), color: kolor, size: 5pt),
          ..if v.tStar < v.horizon {
            (
              lq.vlines(v.tStar, max: float(v.maxNr), stroke: (
                paint: kolor,
                dash: "dashed",
              )),
            )
          } else { () },
        )
      })
      .flatten(),
  ),
  caption: [Wskaźnik $N_(R(t))$ w zależności od czasu dla wariantów rezerwowania. Punkty oznaczają $max N_(R(t))$ w chwili $t^*$.],
) <przebiegi>

Przebieg $N_(R(t))$ w przedziale $[0, #liczba(horyzont)]$ h
(@przebiegi[rysunek]) zależy od tego, gdzie leży element dublowany. Dla elementu połączonego szeregowo
$N_(R(t)) = 2 - e^(-lambda_k t)$ rośnie przez cały czas, więc $t^*$ wypada na
końcu przedziału. W podstrukturze równoległej po długim czasie o zdatności
decyduje jej najbardziej niezawodny element. Gdy dubluje się element bardziej
zawodny od elementu alternatywnego, jego zapas z czasem traci znaczenie i
$N_(R(t))$ ma maksimum wewnątrz przedziału.
#if w-srodek.len() > 0 [
  Tak jest dla elementów: #lista(w-srodek.map(dubl)). W pozostałych wariantach
  $t^*$ wypada na końcu przedziału.
]

== Ocena korzyści uzyskanej z wprowadzenia do systemu elementu rezerwowego i przeanalizowanie, dla którego elementu systemu dodanie elementu rezerwowego dałoby największą korzyść z redundancji $N_(R(t))$, $N_(P(t, t + Delta))$, $N_(E T)$

Kolejność wariantów według wskaźników korzyści przedstawiono w
@ranking[tabeli].

#figure(
  table(
    columns: 5,
    align: center,
    table.header(
      [Miejsce], $N_(R(t))$, $N_(P(t, t + Delta))$, $N_(E T)$, $max N_(R(t))$
    ),
    ..range(res.variants.len())
      .map(k => (
        [#(k + 1).],
        ..(res.order.nrT, res.order.npT, res.order.net, res.order.maxNr).map(
          o => oznaczenie(wv(o.at(k))),
        ),
      ))
      .flatten(),
  ),
  caption: [Kolejność wariantów rezerwowania według wskaźników korzyści.],
) <ranking>

#let pierwsze = (res.order.nrT, res.order.npT, res.order.net).map(
  o => o.first(),
)
#if pierwsze.dedup().len() == 1 [
  Elementem, którego zdublowanie daje największą korzyść $N_(R(t))$,
  $N_(P(t, t + Delta))$ i $N_(E T)$, jest #z-id(zap-nr.of).
] else [
  Największą korzyść daje zdublowanie elementu: według $N_(R(t))$
  #dubl(b-nr), według $N_(P(t, t + Delta))$ #dubl(wv(res.order.npT.first())),
  według $N_(E T)$ #dubl(b-net).
]
#if b-nr.series [
  Jest to element połączony szeregowo, a dla takiego elementu
  $N_(R(t)) = 2 - e^(-lambda_k t)$ rośnie razem z $lambda_k$. Spośród elementów
  połączonych szeregowo ten ma największą intensywność uszkodzeń,
  $lambda_#zap-nr.of = #zap-nr.units dot 10^(-6) thin 1\/h$.
]
Element rezerwowy (E#zap-net.id) wydłuża oczekiwany czas zdatności systemu z
$E T_s = #pl(res.ets)$ h do $E T_r = #pl(b-net.etr)$ h. Dlatego element
rezerwowy najlepiej dodać właśnie do tego elementu.

#let najpewniejszy = po-nr.filter(v => v.series).last().spares.first().of
#if res.order.net != res.order.nrT [
  W chwili $t$ uszkodzenia są jeszcze rzadkie, więc najwięcej dają zapasy
  elementów szeregowych. $N_(E T)$ i $max N_(R(t))$ opisują długi czas pracy, w
  którym uszkadzają się także elementy z podstruktur równoległych, dlatego w tych
  wskaźnikach zapas w podstrukturze równoległej może dać więcej niż zapas
  elementu szeregowego o małej intensywności uszkodzeń (@ranking[tabela]). Na
  przykład #z-id(najpewniejszy) ma
  $lambda_#najpewniejszy = #el(najpewniejszy).lambdaUnits dot 10^(-6) thin 1\/h$ i
  $E T_#najpewniejszy = #pl(el(najpewniejszy).et)$ h, znacznie więcej niż
  $E T_s = #pl(res.ets)$ h, więc w czasie pracy systemu rzadko się uszkadza i
  zapas tego elementu rzadko jest potrzebny.
]
