# Niezawodność Systemów Komputerowych — projekt

Analiza niezawodnościowa serwera brzegowego monitoringu przemysłowego.

```sh
task        # sprawdza system.yaml i składa spr.pdf
task check  # sama walidacja danych
task test   # testy walidacji
task watch  # przebudowuje raport na bieżąco
```

| ścieżka | rola |
|---|---|
| `system.yaml` | dane: `N`, elementy, połączenia, struktura niezawodnościowa |
| `spr/spr.typ` | treść raportu |
| `spr/rbd.typ` | rysowanie schematu struktury niezawodnościowej (CeTZ) |
| `src/` | wczytanie i walidacja `system.yaml` |

Punkt 1 jest opisowy — nie ma w nim obliczeń. Program sprawdza tylko spójność
danych: numery elementów tworzą zbiór 1..n, połączenia wskazują na istniejące
elementy, struktura obejmuje każdy element dokładnie raz i zawiera węzeł
równoległy (wymóg „przynajmniej 2 elementy alternatywne").

Z drzewa `structure` wyprowadzane są: schemat w 1d, podział na elementy
krytyczne i alternatywne oraz kolumna „Rola" w tabeli. Nic z tego nie jest
wpisane w tekst ręcznie.

## Stan

- [x] 1a opis systemu i elementów
- [x] 1b schemat funkcjonalny
- [x] 1c opis niezawodnościowy elementów
- [x] 1d struktura niezawodnościowa — schemat
- [ ] 2–5 λᵢ, Rᵢ(t), Rs(t), Ps, ETs, ścieżki i cięcia, redundancja, wnioski
