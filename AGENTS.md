# AGENTS.md

Projekt z Niezawodności Systemów Komputerowych (PŚk): sprawozdanie w Typst,
liczone przez program w Go.

## Źródła

- Treść zadania: `~/psk/semestr2/niezawodnosc systemow komputerowych/proj/materialy/NSK-zad projekt.pdf`
  (punkty 1–5 i wnioski). Nagłówki i zakres podpunktów biorą się stąd.
- Wykład: `~/psk/semestr2/niezawodnosc systemow komputerowych/wyklad/materialy/NSK 30-stud.pptx`
  (rezerwowanie: slajdy 76–92).
- `zakleta-ksiega-w-niej-kryje-sie-potega.pdf` to skan książki (s. 208–213,
  $F$, $R$, $f$, $\lambda$, $ET$), a nie treść zadania.

Do sprawozdania trafia tylko to, czego wymaga zadanie, a wzory i nazwy pochodzą
z wykładu. Nie dopisywać niczego od siebie, na przykład pochodnej przy $t^*$, której
nie ma ani w zadaniu, ani na wykładzie. Terminologia: zapas przyłączony na stałe
i pracujący od $t = 0$ to „rezerwowanie stałe” (slajd 84), a nie „rezerwa
obciążona” (ta wymaga przełącznika, slajdy 85–86).

## Przepływ

```
system.yaml ─► Go (cmd/nsk, internal/) ─► out/results.yaml ─► spr.typ ─► spr.pdf
```

```sh
task        # calc + build
task calc   # system.yaml -> out/results.yaml
task build  # spr.pdf
task test   # go test ./...
task fmt    # typstyle -i spr.typ rbd.typ, gofmt -w .
```

- Wszystko liczy Go. `spr.typ` tylko wczytuje `out/results.yaml` i wyświetla
  wyniki. W Typst nie liczyć i nie wpisywać na sztywno liczb, numerów elementów,
  wzorów działających tylko dla jednego przypadku ani przedziałów.
- Stałe z treści zadania ($t = 100 + 5N$, $\Delta$, przedział $[0, 100\,000]$ h)
  są w `internal/reliability/element.go`.
- Plik `out/results.yaml` jest generowany i nie wolno go edytować.
- Wariant rezerwowania to wpis w `redundancy` w `system.yaml` (`- dup: [k]`).
  Go numeruje zapasy dalej (9, 10, 11 …), a w raporcie wariant to
  `#wariant(res.variants.at(k))`. Kolejnych punktów nie kopiować, tylko dodawać
  dane.

## Styl sprawozdania

Tekst ma wyglądać na pisany przez studenta, a nie przez czat.

- Bez myślników (`—`, `–`, `--`, `---`) w tekście, podpisach i komentarzach.
  Zamiast nich przecinek, dwukropek, nawias albo „czyli”.
- Bez pogrubień w środku zdań i bez wykładania teorii. Krótkie zdania.
- Bez myślenia na głos przy wzorach („tak samo jak w punkcie 2b”, „całkując
  każdy wyraz osobno”). Przed wzorem krótka etykieta („Dla $t = 115$ h:”) i tyle.
- Pod tabelą lub wykresem nie streszczać tego, co w nich widać.
- Podpisy rysunków i tabel bez wartości liczbowych.
- Elementy nazywać po nazwie, ID tylko w nawiasie: „drugi zasilacz (E9)”.
- Odnośniki wyłącznie natywne: `<etykieta>` i `@etykieta`, nigdy ręcznie
  „z punktu 2a)”.
- Liczby z polskim przecinkiem (`pl()`, `liczba()`, `zero.set-num`).

Po zmianie raportu złożyć PDF i obejrzeć strony, bo łamanie stron i wykresy
łatwo się psują. Poppler nie jest zainstalowany:

```sh
nix-shell -p poppler-utils --run 'pdftotext -layout spr.pdf - ; pdftoppm -r 60 -png spr.pdf /tmp/p'
```

## Kod

- Bez komentarzy opisujących, co robi kod. Komentarz tylko dla nieoczywistego
  „dlaczego”.
- Po każdej zmianie w `.typ` albo `.go` uruchomić `task fmt`. Typst formatuje
  `typstyle` (ten sam, którego używa Tinymist w VS Code), a Go formatuje `gofmt`.
  Nie formatować ręcznie pod siebie, bo przy następnym `task fmt` i tak się zmieni.
- Przed oddaniem: `task fmt`, `typstyle --check spr.typ rbd.typ`, `go vet ./...`,
  `task test`, `task`.

## Git

- Commit tylko na prośbę.
- Styl wiadomości: `feat: punkt 3`, `fix: punkt 2`, `chore: lekkie poprawki`.
- Bez stopek i bez wzmianek o AI w commitach i opisach PR.
