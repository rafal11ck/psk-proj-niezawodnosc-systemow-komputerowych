# Niezawodność Systemów Komputerowych — projekt

Analiza niezawodnościowa serwera brzegowego monitoringu przemysłowego.

```sh
task        # sprawdza system.yaml i składa spr.pdf
task check  # sama walidacja danych
task test   # testy walidacji
task watch  # przebudowuje raport na bieżąco
```

| ścieżka       | rola                                                 |
|---------------|------------------------------------------------------|
| `system.yaml` | dane: `N`, elementy, połączenia                      |
| `spr/spr.typ` | treść raportu; tabele i schemat lecą z `system.yaml` |
| `src/`        | wczytanie i walidacja `system.yaml`                  |

