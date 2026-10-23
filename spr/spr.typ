#import "@preview/diagraph:0.3.8"
#import "rbd.typ": rbd

#let cfg = yaml("/system.yaml")
#let res = yaml("/out/results.yaml")

// Polski separator dziesiętny; liczby formatuje program.
#let pl(x) = str(x).replace(".", ",")

// Długie sumy łamane na wiersze: lewa strona, kolejne wiersze składników,
// na końcu wynik. Bez tego podstawienia nie mieszczą się w szerokości strony.
#let rownanie(lewa, skladniki, wynik, na-wiersz: 3) = {
  let wiersze = skladniki.chunks(na-wiersz).map(w => w.join($ $))
  let linie = wiersze
    .enumerate()
    .map(((k, w)) => if k == 0 { $#lewa &= #w$ } else { $& #w$ })
  linie.push($&= #wynik$)
  math.equation(block: true, linie.join($ \ $))
}

// ── Dane do strony tytułowej (uzupełnić) ────────────────────────────────────
// Tytuł, autor i data to metadane dokumentu — trafiają też do właściwości PDF-a.
#set document(
  title: [
    Projekt -- Niezawodność systemów komputerowych \
    Analiza niezawodnościowa serwera brzegowego monitoringu przemysłowego],
  author: (
    "inż. Rafał Grot",
    "inż. Bartłomiej Karkoszka",
    "inż. Filip Stępień",
  ),
  date: datetime(year: 2026, month: 10, day: 21),
)



// ── Opis elementów (pkt 1a i 1c) — treść, nie dane obliczeniowe ──────────────
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

// Kryterium uszkodzenia — cecha, na podstawie której stwierdza się przejście
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
// pełnią funkcje alternatywne. Nic nie jest wpisywane osobno.
#let dzieci(n) = n.at("ser", default: n.at("par", default: ()))
#let elementy(n) = if "el" in n { (n.el,) } else { dzieci(n).map(elementy).flatten() }

// Dla każdego elementu: lista elementów zamiennych (pusta, gdy krytyczny).
#let zamienniki-z(n) = {
  let out = (:)
  if "par" in n {
    let grupy = n.par.map(elementy)
    for (k, g) in grupy.enumerate() {
      let inne = grupy.enumerate().filter(p => p.at(0) != k).map(p => p.at(1)).flatten()
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
  if g.len() < 2 { g.join("") } else { g.slice(0, -1).join(", ") + " oraz " + g.last() }
}

#let rola(e) = {
  let inne = zamienniki.at(str(e.id), default: ())
  if inne.len() == 0 { "krytyczny" } else {
    "alternatywny (z " + inne.map(i => "E" + str(i)).join(", ") + ")"
  }
}
#let krytyczne = {
  cfg.elements
    .filter(e => zamienniki.at(str(e.id), default: ()).len() == 0)
    .map(e => "E" + str(e.id))
    .join(", ")
}

// ── Ustawienia dokumentu ─────────────────────────────────────────────────────
#set page(paper: "a4", margin: 2.5cm, numbering: "1")
#set text(lang: "pl", size: 11pt)
#set par(justify: true)
// Numeracja jak w treści zadania: punkty 1., 2., ... i podpunkty a), b), c).
#set heading(numbering: (..n) => {
  let poziom = n.pos()
  if poziom.len() == 1 { numbering("1.", poziom.last()) } else if poziom.len() == 2 { numbering("a)", poziom.last()) }
})
#show table.cell.where(y: 0): strong

// Odnośnik do podpunktu pokazuje pełny numer ("1d)"), mimo że sam nagłówek
// jest numerowany samą literą, jak w treści zadania.
#show ref: it => {
  let el = it.element
  if el != none and el.func() == heading and el.level == 2 {
    let n = counter(heading).at(el.location())
    numbering("1", n.at(0)) + numbering("a)", n.at(1))
  } else { it }
}

// ── Strona tytułowa ──────────────────────────────────────────────────────────
#page(numbering: none)[
  #align(center)[
    #v(3cm)
    #title()
    #v(2cm)
    #context document.author.join(linebreak())
  ]
  #align(center)[Kielce, #context document.date.display("[year]")]
]
#counter(page).update(1)

= Zbudować przykładowy system komputerowy składający się z 8 elementów nieodnawialnych, z których przynajmniej 2 będą względem siebie pełniły alternatywne funkcje

Przedmiotem analizy jest *serwer brzegowy monitoringu przemysłowego* — stanowisko
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
RAID 1, a następnie są wysyłane do centrum przetwarzania — zwykłym łączem
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
nieprzesłane są tracone bezpowrotnie, więc nie ma tu stanów pośrednich ---
system albo wykonuje swoje zadanie w całości, albo nie wykonuje go wcale.

*Elementy pełniące funkcje alternatywne.* Dyski E4 i E5 przechowują identyczną
kopię danych, więc do poprawnej pracy systemu wystarczy dowolny z nich.
Podobnie interfejs Ethernet (E6) i modem LTE (E7) realizują to samo zadanie —
transmisję do centrum przetwarzania — i każdy z osobna jest wystarczający.
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

#let etykieta(e) = "E" + str(e.id) + "\n" + e.name
#let dot-src = (
  "digraph {\n"
    + "  rankdir=LR; splines=ortho; nodesep=0.35; ranksep=0.7;\n"
    + "  node [shape=box, style=rounded, fontsize=10, width=1.5, height=0.6];\n"
    + "  edge [fontsize=9];\n"
    + cfg.elements.map(e => "  " + str(e.id) + " [label=\"" + etykieta(e) + "\"];\n").join("")
    + cfg
      .links
      .map(l => (
        "  " + str(l.from) + " -> " + str(l.to) + " [label=\"" + l.label + "\"];\n"
      ))
      .join("")
    + "}"
)

#figure(
  diagraph.render(dot-src, width: 100%),
  caption: [Schemat funkcjonalny systemu — połączenia elementów.],
)

== Opis niezawodnościowy elementów systemu

Opis niezawodnościowy elementu obejmuje kryterium uszkodzenia, klasyfikację
uszkodzeń oraz przyjęty model czasu poprawnej pracy. *Uszkodzenie* to zdarzenie
polegające na przejściu obiektu ze stanu zdatności do stanu niezdatności, a
*kryterium uszkodzenia* to cecha lub zespół cech, na których podstawie ustala
się fakt jego powstania.

=== Przyjęte założenia

Wszystkie elementy systemu są *nieodnawialne*, zgodnie z treścią zadania
-- nie przewiduje się ich naprawy ani wymiany, więc uszkodzenie
elementu jest zdarzeniem nieodwracalnym.

Czas poprawnej pracy każdego elementu ma *rozkład wykładniczy*; jest to
założenie przyjęte w punkcie 2 treści zadania. Rozkład ten odznacza
się brakiem pamięci -- obiekt nieuszkodzony jest tak samo niezawodny jak nowy --
i stosuje się go do obiektów o uszkodzeniach czysto przypadkowych.
Intensywność uszkodzeń jest wówczas niezależna od czasu,
$lambda(t) = lambda = "const"$, co odpowiada drugiemu przedziałowi krzywej
życia, czyli okresowi normalnej eksploatacji, w którym dominują uszkodzenia
wywołane czynnikami losowymi. Element opisują wtedy funkcje:

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
  [$lambda_i$], [intensywność uszkodzeń elementu $i$, stała w czasie, w $1\/"h"$,],
  [$R_i (t)$],
  [funkcja niezawodności elementu $i$ --- prawdopodobieństwo, że
    element nie ulegnie uszkodzeniu do chwili $t$,],

  [$F_i (t)$],
  [dystrybuanta trwałości --- prawdopodobieństwo, że element
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

    [Związek z innymi uszkodzeniami], [niezależne], [uszkodzenie elementu nie wywołuje uszkodzeń pozostałych],

    [Charakter procesu pojawienia się], [nagłe], [stała intensywność uszkodzeń wyklucza dominację procesów zużyciowych],
    [Czas występowania], [stałe], [elementy są nieodnawialne, więc stan niezdatności jest trwały],
  ),
  caption: [Klasyfikacja uszkodzeń elementów systemu.],
)

=== Charakterystyka elementów

Elementy *krytyczne* (#krytyczne) nie mają zastępstwa -- uszkodzenie
któregokolwiek z nich powoduje niezdatność systemu. Elementy *alternatywne*
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

== Struktura niezawodnościowa systemu -- schemat <struktura>

System ma strukturę *szeregowo-równoległą*. Część szeregową tworzą elementy
#krytyczne, a podstruktury równoległe -- #rownolegle.

#figure(
  rbd(cfg.structure, i => text(size: 10pt)[E#i]),
  caption: [Struktura niezawodnościowa systemu.],
)

= Zakładamy

Czas poprawnej pracy elementów jest zgodny z rozkładem wykładniczym,
o intensywnościach uszkodzeń zadanych w treści projektu dla numeru grupy
projektowej $N = #res.N$ i liczby elementów $n = #res.count$:

$ lambda_i = 2 N i dot 10^(-6) thin [1\/h] quad & "dla" i "nieparzystych", \
  lambda_i = 3 N (n + 1 - i) dot 10^(-6) thin [1\/h] quad & "dla" i "parzystych". $

Wartości funkcji niezawodności wyznaczono dla chwili
$t = 100 + 5 N = 100 + 5 dot #res.N = #res.t$ h.

Dla każdego elementu daje to:

#let lam-wzor(e) = if calc.odd(e.id) {
  $2 dot #res.N dot #e.id$
} else {
  $3 dot #res.N dot (#res.count + 1 - #e.id)$
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
    ..res.elements.map(e => (
      [E#e.id],
      $#lam-wzor(e) dot 10^(-6) = #e.lambdaUnits dot 10^(-6)$,
      $e^(-#e.lambdaUnits dot 10^(-6) dot #res.t) = #pl(e.R)$,
      $1 / (#e.lambdaUnits dot 10^(-6)) = #pl(e.et)$,
    )).flatten()
  ),
  caption: [Intensywności uszkodzeń i niezawodność elementów dla $N = #res.N$.],
)

== Funkcja niezawodności systemu $R_s (t)$

Funkcja niezawodności systemu $R_s (t)$ to prawdopodobieństwo, że system będzie
poprawnie pracował w chwili $t$. System ma strukturę szeregowo-równoległą
(punkt @struktura), dla której

$ R_s (t) = product_(r = 1)^p R^((r))(t), quad "przy czym" quad
  R^((r))(t) = 1 - product_(i = 1)^(n_r) [1 - R_(r,i)(t)], $

gdzie:

#grid(
  columns: (auto, 1fr),
  row-gutter: 0.5em,
  column-gutter: 1em,
  align: (right + top, left),
  [$p$], [liczba układów połączonych szeregowo,],
  [$n_r$], [liczba części składowych $r$-tego układu, połączonych równolegle,],
  [$R^((r))(t)$], [funkcja niezawodności $r$-tego układu,],
  [$R_(r,i)(t)$], [funkcja niezawodności $i$-tej części składowej $r$-tego układu.],
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
  res.terms
    .enumerate()
    .map(((k, tm)) => wyraz(tm, k == 0))
    .chunks(5)
    .map(w => w.join($ $))
}

$ R_s (t) &= #uklady.map(czynnik-wykl).join() \
          &= #uklady.map(czynnik-rozw).join() \
          &= sum_j c_j e^(-r_j mu t) \
          &= #wyrazy.at(0) \
          &#h(1em) #wyrazy.at(1), $

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

Wymnożenie nawiasów daje #res.monomials.len() jednomianów --- po jednym na każdy
wybór gałęzi w obu podstrukturach równoległych. Wykładniki składników iloczynu
sumują się, a jednomiany o jednakowym wykładniku zbierają się w jeden wyraz;
wykładnik 168 występuje dwukrotnie, stąd przy nim współczynnik 2.

#let iloczyn(m) = m.elements.map(i => $R_#i$).join()
#let suma(m) = m.elements.map(i => str(res.elements.at(i - 1).lambdaUnits)).join(" + ")

#figure(
  table(
    columns: (auto, auto, 1fr, auto),
    align: (center, left, right, right),
    table.header[Znak][Jednomian][Suma $lambda_i dot 10^6$][Wykładnik],
    ..res.monomials.map(m => (
      [#if m.coeff < 0 [$-$] else [$+$]],
      [$#iloczyn(m)$],
      [#suma(m)],
      [#m.rate],
    )).flatten()
  ),
  caption: [Rozwinięcie $R_s (t)$ --- jednomiany i ich wykładniki.],
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

$ P_s (t, t + Delta) &= 1 - [R_s (t) - R_s (t + Delta)] \
  &= 1 - [#pl(res.rs) - #pl(res.rsDelta)] = #pl(res.ps). $

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
  res.terms.enumerate().map(((k, tm)) => ulamek(tm, k == 0)).join($ $)
}

$ E T_s &= integral_0^infinity R_s (t) dif t \
        &= integral_0^infinity sum_j c_j e^(-r_j mu t) dif t \
        &= sum_j c_j integral_0^infinity e^(-r_j mu t) dif t \
        &= sum_j c_j / (r_j mu) = 1/mu sum_j c_j / r_j \
        &= 10^6 lr((#math.inline(ulamki))) \
        &= 10^6 dot #pl(res.etsSum) \
        &approx #pl(res.ets) " h". $

== Zbiór minimalnych ścieżek zdatności

Podzbiór elementów systemu nazywa się *ścieżką zdatności*, jeżeli przy
zdatności wszystkich jego elementów system jest zdatny niezależnie od stanu
pozostałych. Ścieżka jest *minimalna*, jeżeli nie zawiera żadnej innej ścieżki
zdatności.

#let zbior(s) = $\{#s.map(str).join(", ")\}$
#let xs(s) = s.map(i => $x_#i$).join()

$ #res.paths.map(zbior).join($, $) $

Minimalna formuła alternatywna --- każdemu składnikowi sumy odpowiada dokładnie
jedna minimalna ścieżka zdatności:

$ f^((#res.count))(x) = #res.paths.map(xs).join($ or $) $

== Zbiór minimalnych cięć

Podzbiór elementów nazywa się *cięciem*, jeżeli przy niezdatności wszystkich
jego elementów system jest niezdatny niezależnie od stanu pozostałych. Cięcie
jest *minimalne*, jeżeli nie zawiera żadnego innego cięcia.

$ #res.cuts.map(zbior).join($, $) $

Minimalna formuła koniunkcyjna --- każdemu czynnikowi iloczynu odpowiada
dokładnie jedno minimalne cięcie:

$ f^((#res.count))(x) = #res.cuts.map(c => {
  if c.len() == 1 { $x_#c.at(0)$ } else { $(#c.map(i => $x_#i$).join($ or $))$ }
}).join($ and $) $
