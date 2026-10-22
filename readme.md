# Niezawodność Systemów Komputerowych — projekt

Analiza niezawodnościowa serwera brzegowego monitoringu przemysłowego.

```sh
task        # przelicza dane i składa spr.pdf
task calc   # system.yaml -> out/results.yaml
task test   # testy
task watch  # przebudowuje raport na bieżąco
```

```
system.yaml  ──►  src/ (Go)  ──►  out/results.yaml  ──►  spr/spr.typ  ──►  spr.pdf
```

| ścieżka | rola |
|---|---|
| `system.yaml` | dane: `N`, elementy, połączenia, struktura niezawodnościowa |
| `cmd/nsk/` | program: wczytanie, złożenie wyniku |
| `internal/model/` | typy danych i ich walidacja |
| `internal/reliability/` | $\lambda_i$, $R_s(t)$, ścieżki i cięcia |
| `spr/spr.typ` | treść raportu |
| `spr/rbd.typ` | rysowanie schematu struktury niezawodnościowej (CeTZ) |

Żadna liczba ani etykieta w raporcie nie jest wpisana ręcznie. Ze struktury
wyprowadzane są: schemat, podział na elementy krytyczne i alternatywne,
postać wykładnicza $R_s(t)$ oraz ścieżki i cięcia minimalne.

## Dokładność

Intensywności $\lambda_i$ to całkowite krotności $10^{-6}$ 1/h, a współczynniki
i wykładniki postaci wykładniczej $R_s(t)=\sum c_j e^{-r_j \mu t}$ są całkowite.
$ET_s$ liczone jest jako suma ułamków na `big.Rat`, więc **dokładnie** —
całkowania numerycznego nie ma. Jedyne zaokrąglenie w całym rachunku to
`math.Exp` przy drukowaniu $R_s$ i $P_s$.

## Stan

- [x] 1a–1d opis systemu, schemat funkcjonalny, opis niezawodnościowy, struktura
- [x] 2a $R_s(t)$ w postaci wykładniczej
- [x] 2b $P_s(t, t+\Delta)$
- [x] 2c $ET_s$
- [x] 2d minimalne ścieżki zdatności
- [x] 2e minimalne cięcia
- [ ] 3–5 redundancja, warianty rezerwowania, wnioski
