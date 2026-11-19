# Projekt z Niezawodności Systemów Komputerowych

Analiza niezawodnościowa serwera brzegowego monitoringu przemysłowego.
Sprawozdanie jest w Typst, a obliczenia robi program w Go.

## Jak zbudować

```sh
task        # przelicza dane i składa spr.pdf
task calc   # tylko obliczenia: system.yaml -> out/results.yaml
task build  # tylko PDF
task watch  # przebudowuje PDF przy każdej zmianie
task test   # testy
```

Potrzebne są Go, Typst i Task.

## Jak to działa

```
system.yaml  ->  program w Go  ->  out/results.yaml  ->  spr.typ  ->  spr.pdf
```

W `system.yaml` są dane systemu: numer grupy `N`, elementy, połączenia,
struktura niezawodnościowa i warianty rezerwowania. Program w Go liczy z nich
wszystko, co potrzebne do sprawozdania, i zapisuje wynik do `out/results.yaml`.
Typst tylko wczytuje ten plik i składa PDF. W sprawozdaniu nie ma liczb ani
numerów elementów wpisanych ręcznie, więc po zmianie danych wystarczy
uruchomić `task`.

| plik | co zawiera |
|---|---|
| `system.yaml` | dane wejściowe |
| `cmd/nsk/` | program: wczytuje dane i zapisuje wyniki |
| `internal/model/` | typy danych i sprawdzanie poprawności `system.yaml` |
| `internal/reliability/` | $\lambda_i$, $R(t)$, $ET$, ścieżki i cięcia |
| `spr.typ` | treść sprawozdania |
| `rbd.typ` | rysowanie struktury niezawodnościowej |

## Dokładność

Intensywności uszkodzeń są całkowitymi krotnościami $10^{-6}$ 1/h, więc
$R(t)$ po rozwinięciu to suma wyrazów $c_j e^{-r_j \mu t}$ z całkowitymi $c_j$
i $r_j$. Dzięki temu $ET$ liczy się dokładnie, jako suma ułamków $c_j / r_j$,
bez całkowania numerycznego. Zaokrąglenie pojawia się tylko przy liczeniu
wartości $e^x$.

## Kolejny wariant rezerwowania

1. Dopisać wariant w `system.yaml` pod `redundancy`, np. `- dup: [2]`.
   Wybrany element dostaje równolegle drugi taki sam, a program sam nadaje mu
   kolejny numer (9, 10, 11 …).
2. Uruchomić `task calc`.
3. W `spr.typ` dodać punkt z nagłówkiem, krótkim opisem i
   `#wariant(res.variants.at(1))`, gdzie indeks to pozycja wariantu w
   `redundancy` liczona od zera.
