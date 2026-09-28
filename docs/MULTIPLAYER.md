# Multiplayer LAN

„Graj we dwoje” łączy dwa urządzenia w tej samej sieci Wi-Fi albo ręcznie utworzonym hotspocie. Gospodarz wybiera „Utwórz grę”, drugi gracz skanuje QR. Po wyborze postaci, trasy i trudności oboje naciskają „Gotowy”. Wszystkie dziewięć kombinacji tras i trudności jest dostępnych niezależnie od kampanii. Internet nie jest potrzebny; QR nie konfiguruje Wi-Fi.

## Reguły

- Dziesięć małych gwiazdek i dwa artefakty są wspólne. Przedmiot trafia do jednej osoby; artefakt daje trzy ładunki mocy.
- Duża gwiazda kończy trasę po dotknięciu i nie daje punktu. Po pierwszej mecie drugi gracz ma 30 sekund aktywnej gry. Ukończenie przez obu kończy rundę wcześniej.
- Osobne wyróżnienia: „Pierwszy na mecie” i „Najwięcej gwiazdek”. Remisy są możliwe; przy 0:0 nie ma wyróżnienia za gwiazdki. Nieukończenie trasy nie kasuje gwiazdek.
- Upadek usuwa moce. Po trzech sekundach gracz wraca na środek ostatniej odwiedzonej wyspy w jej aktualnym położeniu. Gwiazdki i wspólny świat zostają zachowane.
- Przezroczysty przeciwnik ma numer gracza i nie zderza się z postacią. Strzałka z miniaturą wskazuje go poza ekranem; podczas odrodzenia wskazuje wyspę powrotu.
- Pauza zatrzymuje obu graczy, wyspy i liczniki rozgrywki. Wznowienie wymaga gotowości obu i odliczania. Ukończony gracz obserwuje rywala.
- Rewanż wymaga dwóch potwierdzeń, bez kolejnego QR. Multiplayer nie zapisuje wyników ani odblokowań kampanii.

## Architektura

| Plik | Odpowiedzialność |
| --- | --- |
| `race_simulation.gd` | Jawny stan, krok 60 Hz, wspólna fizyka serwera i przewidywania, kontakty i wyniki. Bez węzłów, zegara systemowego i transportu. |
| `race_session.gd` | Autoload `Race`: ENet, uwierzytelnienie, lobby, serwer opóźniony o 9 kroków, zegar, pauza i odzyskiwanie. |
| `race_protocol.gd` | Wersja, fingerprint dziewięciu układów poziomów, walidacja. Zmiana reguł wymaga podniesienia `VERSION`. |
| `race_prediction.gd` | Odtwarzanie stanu i poleceń, natychmiastowy ekwipunek i ruch lokalny, ghost do 18 kroków poza snapshot. |
| `race_world.gd`, `race_actor.gd` | Grafiki, sterowanie, kamera, efekty. Korekta fizyki jest natychmiastowa; grafiki trwa najwyżej 100 ms. |
| `opponent_indicator.gd`, `race_menu.gd` | Strzałka z histerezą i bezpiecznymi marginesami, ekrany multiplayera. |
| `lan_pairing.gd` | Autoload `Lan`: QR, tokeny, adresy interfejsów, most Androida. |
| `android/lan_plugin` | Kotlin, plugin Godot v2, wbudowany ZXing, aparat, Wi-Fi/hotspot i `SystemClock.elapsedRealtime()`. |

Skrypty GDScript znajdują się w `scripts/`. Faza wysp jawnie odwzorowuje opóźnienie zatwierdzania pozycji `AnimatableBody2D` o jeden krok w kampanii. Prezentacja używa tej samej fazy, bez dodatkowej fizyki postaci/platform.

## Sieć

Domyślny port: UDP 7777. Host dopuszcza jeden transport klienta. Miejsce uczestnika i token odzyskiwania istnieją niezależnie od ID połączenia ENet. Zaproszenie zawiera wersję, IPv4, port, ID sesji i losowy token 128-bitowy. Po przyjęciu uczestnika wygasa. Zmiana adresu przed przyjęciem uczestnika regeneruje zaproszenie.

| Kanał | Tryb i dane |
| --- | --- |
| 0 | Reliable: sterowanie, pełny stan, wydarzenia, wyniki. |
| 1 | Reliable: polecenia, zapowiedzi, statusy. |
| 2 | Unreliable ordered, 20 Hz: snapshot z rewizją, rozstrzygnięciami i powtórzonymi zapowiedziami niewykonanych poleceń. DEFLATE ogranicza rozmiar datagramu; powtórzenia ograniczają opóźnienie ghosta przy utracie pakietów. |
| 3 | Unreliable: numerowany heartbeat i pomiar zegara. |

Osiem początkowych wymian ustanawia czas; dalsze pomiary odbywają się z heartbeatami co 250 ms. Preferowane są próbki z najniższym RTT w ostatnim oknie. Oba telefony, także host, przewidują ruch przed autorytatywną symulacją.

Polecenie wskazuje rundę, epokę, sekwencję, dokładny krok, życie, lądowanie i lot. Kotwiczka dotyczy konkretnego skoku. Spóźnione polecenie jest odrzucane, nigdy przesuwane. `RECEIVED` zachowuje polecenie do odtworzenia; `EXECUTED` i `REJECTED` rozstrzygają jego los. Klient nie zgłasza autorytatywnych pozycji ani punktów.

Historia obejmuje dwie sekundy; brak historii wywołuje pauzę i pełną synchronizację. Można natychmiast użyć przewidywanej butelki. Jeżeli serwer przyzna ją rywalowi, odrzuca zależny super-skok w całości. Identyfikatory efektów zapobiegają powtórzeniom. Kontakty obu graczy są porównywane wewnątrz kroku. Różnica do 1 ms używa wcześniej wylosowanego priorytetu przedmiotu; na mecie oznacza remis.

## Odzyskiwanie

Brak potwierdzonej komunikacji przez sekundę zamraża stan. Host usuwa stare połączenie ENet i jego wpis w SceneMultiplayer, zachowując miejsce uczestnika. Klient próbuje co dwie sekundy. Wymagany jest token odzyskiwania; wiadomości starej generacji są odrzucane.

Termin wynosi 60 sekund rzeczywistych od wykrytej przerwy. Krótkie nawroty go nie przedłużają. Androidowy zegar uwzględnia głęboki sen. Wznowienie nie nadrabia kroków. Wymagane są nowa epoka, pełny stan i potwierdzony hash, synchronizacja czasu oraz dwie sekundy poprawnej komunikacji w obu kierunkach: RTT do 250 ms, odstępy potwierdzeń do 500 ms. Następnie sesja wraca do zwykłej pauzy; czekanie na gotowość nie zużywa terminu odzyskiwania.

Upływ minuty albo opuszczenie gry przerywa rundę. Bez migracji hosta, kont, Internetu, discovery, Bluetooth i automatycznego hotspotu. Zakres: LAN IPv4, dwóch graczy i zaufany host.

Po świadomym wyjściu odłączony transport przez maksymalnie dwie sekundy kończy dostarczanie niezawodnego komunikatu wyjścia. Menu jest dostępne od razu. Cache poleceń i odpowiedzi sprawdza także rundę/epokę, aby stara wiadomość nie blokowała ponownie użytego numeru sekwencji po rewanżu.

## Build i testy

```sh
python3 tools/test.py
python3 tools/test_multiplayer.py
godot --path . --script tests/capture_multiplayer.gd
python3 tools/build_android.py
```

Build przygotowuje Gradle z szablonu Godota, kompiluje plugin, kopiuje AAR do ignorowanego `addons/lan_pairing/bin`, importuje zasoby i eksportuje podpisane APK/AAB. Przed ręcznym eksportem zbuduj plugin tym skryptem. Narzędzia i zmienne środowiskowe opisuje README.

ZXing Android Embedded 4.3.0 i zależności są w APK. Pierwszy build pobiera zależności Gradle; skanowanie działa offline. Zgoda na aparat jest żądana przy skanowaniu. Min SDK: 28; target SDK: 36. Podniesienie target do 37 wymaga osobnego wdrożenia zgody LAN.

Źródła: [ZXing Embedded](https://github.com/journeyapps/zxing-android-embedded), [uprawnienie LAN](https://developer.android.com/privacy-and-security/local-network-permission), [SystemClock](https://developer.android.com/reference/android/os/SystemClock), [wymuszone rozłączenie ENet](https://docs.godotengine.org/en/stable/classes/class_multiplayerpeer.html#class-multiplayerpeer-method-disconnect-peer).

Testy porównują fizykę z `CharacterBody2D` i uruchamiają osobne procesy hosta/klienta. Przekaźnik UDP dodaje RTT 150 ms, jitter do ±40 ms, stratę 2%, duplikację i zmianę kolejności. Dodatkowy scenariusz odcina jeden kierunek. Raporty: `build/race-tests.txt`, `build/network-*.txt`; zrzuty: `build/race-*.png`. `--network-only` pomija testy fizyki. Na komputerze dostępne są kopiowanie i wklejanie kodu połączenia.

Odbiór na dwóch fizycznych telefonach wymaga jeszcze QR bez Internetu, routera i hotspotu w obu rolach, pełnej rundy/rewanżu, uśpienia obu telefonów, powrotu po ponad minucie oraz pomiaru wydajności i rzeczywistego obrazu. Pomiary prezentacji w procesach Godota nie mierzą czasu wyświetlacza telefonu.
