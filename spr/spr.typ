#import "@preview/diagraph:0.3.8"
#import "rbd.typ": rbd

#let cfg = yaml("/system.yaml")

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

== Struktura niezawodnościowa systemu -- schemat

System ma strukturę *szeregowo-równoległą*. Część szeregową tworzą elementy
#krytyczne, a podstruktury równoległe -- #rownolegle.

#figure(
  rbd(cfg.structure, i => text(size: 10pt)[E#i]),
  caption: [Struktura niezawodnościowa systemu.],
)
