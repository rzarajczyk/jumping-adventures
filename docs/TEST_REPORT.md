# Raport weryfikacji — Jumping Adventure 1.1.0

## Podniebny podróżnik — 27 września 2026

`python3 tools/test.py`: **1360 sprawdzeń, 0 niepowodzeń**, bez błędów skryptów i zasobów. Wszystkie dziewięć tras ukończono zwykłymi skokami z wynikiem **11/11 gwiazdek**, zbierając oba artefakty i zachowując po trzy niewykorzystane ładunki.

Testy mocy mierzą rzeczywistą fizykę przy 60 Hz: dla wektora `(300, -600)` zwykły skok osiągnął wysokość **145,03** i zasięg **300,04**, a skok z mnożnikiem √2 — **293,00** i **593,98** jednostek. Niewielkie odchylenie od dokładnego ×2 wynika z dyskretnej integracji i momentu wykrycia lądowania. Sprawdzono maksymalne wybicie, brak przenikania platform, widoczność postaci pod HUD-em i nieruchomą ekranową linię oceanu podczas oddalania kamery.

Sprawdzono po trzy użycia, anulowanie gestu, uzbrajanie i rozbrajanie, blokadę drugiego palca, puszczenie gestu nad przyciskiem, aktywację kotwiczki przy naciśnięciu, przerwanie wznoszenia/szczytu/opadania, jedną kotwiczkę na lot, połączenie obu mocy i lądowanie na ruchomej wyspie. Zweryfikowano reset po wodzie, ręcznym restarcie i zmianie planszy, zachowanie ładunków po pauzie i powrocie z tła oraz zatrzymanie podpowiedzi i animacji perełek podczas pauzy. Wszystkie sześć postaci wykonało super-skok, użyło kotwiczki i wylądowało.

Kontrola wizualna w Godot: artefakty, wszystkie sześć postaci z akcesoriami, uzbrojona strzałka i pasek ×2, chmurkowy start, linka i fala kotwiczki oraz maksymalny skok na trudnej trasie. Zrzuty 1280×720 i 1600×720: `build/powers-*.png`; odtwarzalny scenariusz: `tests/capture_powers.gd`. Nowe tekstury mają mipmapy, aby zachować gładkie krawędzie przy rozmiarach 16–56 jednostek.

`python3 tools/build_android.py` zakończył się sukcesem. Utworzono podpisane `build/JumpingAdventure.apk` (**94,3 MiB**) i `build/JumpingAdventure.aab` (**45,3 MiB**), pakiet `pl.zarajczyk.jumpingpenguin`, z dotychczasowym kluczem. Weryfikacja podpisów zakończyła się powodzeniem. Nie publikowano wydania ani nie zmieniano numeru wersji.

APK zainstalowano i uruchomiono na emulatorze **Pixel 10, ARM64, Android 37, ekran 2424×1080**. Gestami Androida zebrano butelkę i kotwiczkę, potwierdzono napełnienie perełek i obie podpowiedzi. Użyto super-skoku, następnie połączono kolejny super-skok z kotwiczką i bezpiecznym lądowaniem. Liczniki potwierdziły zużycie po jednym ładunku obu mocy, a kamera wróciła do zwykłego widoku. Efekty są rozpoznawalne wizualnie przy wyciszonym emulatorze. Zrzuty: `build/powers-android-bottle.png`, `build/powers-android-anchor-collected.png`, `build/powers-android-combo-success.png`, `build/powers-android-combo-landed.png`. Logi: `build/powers-android-logcat.txt`.

**Nie było podłączonego fizycznego telefonu.** Nie potwierdzono wygody palca na rzeczywistym ekranie, wydajności telefonu, odsłuchu nowych dźwięków ani balansu w testach z dziećmi. Przebieg w emulatorze nie stanowi pomiaru FPS na urządzeniu.

## Dodanie pandy — 26 września 2026

`python3 tools/test.py`: **1241 sprawdzeń, 0 niepowodzeń**, bez błędów skryptów i zasobów. Testy objęły wszystkie sześć postaci, w tym wybór pandy, zapis i odczyt wyboru, trzy klatki animacji, skok, lądowanie, ponowny start po upadku i zwycięstwo. Dodano sprawdzenie, że każda karta postaci mieści się na ekranie. Wszystkie dziewięć tras ukończono z wynikiem **11/11 gwiazdek**.

Obejrzano zrzuty Godota: menu sześciu postaci w rozdzielczościach 1280×720 i 1600×720 oraz pandę w grze. Pliki: `build/characters.png`, `build/characters-wide.png`, `build/character-panda.png`. W tej aktualizacji sprawdzono projekt na macOS; nie przebudowano APK/AAB ani nie testowano pandy na Androidzie.

## Aktualizacja z 25 września 2026

APK release `build/JumpingAdventure.apk`, kod wersji 2, nazwa **Jumping Adventure**. Zachowano pakiet `pl.rafal.jumpingpenguin` i klucz podpisujący poprzednią wersję. Godot 4.7.2, Compatibility, ARM64, min SDK 28, target SDK 36.

### Automatyczne testy

`python3 tools/test.py`: **1224 sprawdzenia, 0 niepowodzeń**, bez błędów skryptów. Wszystkie dziewięć tras ukończonych w rzeczywistej fizyce Godot z wynikiem **11/11 gwiazdek**. Surowy raport: `build/test-results.txt`.

Oprócz dotychczasowych testów gestów, fizyki, pauzy i resetu sprawdzono:

- wybór każdej z pięciu postaci, dostępność klatek animacji, skok, lądowanie i zachowanie wyboru po upadku;
- trwały zapis wyboru i migrację starych wyników oraz odblokowań;
- pojedyncze naliczanie dużej gwiazdy, brak zwycięstwa od samego lądowania na ostatniej wyspie oraz zwycięstwo po dotknięciu gwiazdy;
- dokładną liczbę gwiazdek w podsumowaniu, obecność fajerwerków i przejście do kolejnej planszy.

### Wygląd

Obejrzano zrzuty Godot: menu, pięć kart wyboru postaci, każdą postać w grze, dużą gwiazdę i planszę zwycięstwa z fajerwerkami. Kontrola obejmowała 1280×720 i 1600×720. Grafiki postaci i gwiazdki są zapisane w `assets/art`; pełne prompty: `docs/ART_ADVENTURE.md`.

### Działający APK na Androidzie

Emulator Pixel 10, ARM64, obraz `android-37.0/google_apis_playstore_ps16k/arm64-v8a`, poziomy ekran 2424×1080, host Apple M1 Pro.

- Instalacja przez `adb install -r` na istniejącą wersję 1.0.0: sukces.
- Przed aktualizacją wyciszono muzykę; nowa wersja zachowała to ustawienie, pozostawiając efekty włączone.
- Wybór pieska dotykiem, wymuszone zamknięcie i ponowne uruchomienie: wybór zachowany.
- Uruchomienie planszy, skoki sterowane gestami, lądowanie oraz zebranie gwiazdki: potwierdzone na emulatorze (HUD 1/11).
- W odczytanym logcat Godot/AndroidRuntime brak błędów skryptów i awarii.
- Metadane APK potwierdzają nową nazwę, wersję 1.1.0, min SDK 28, target SDK 36 oraz ARM64. `apksigner verify --verbose` potwierdza podpis v2.

Zrzuty Androida: `build/android-new-settings.png`, `build/android-characters.png`, `build/android-character-persistence.png`, `build/android-adventure-game.png`, `build/android-star-collected.png`.

**Wersji 1.1.0 nie sprawdzono na fizycznym telefonie.** Telefony były odłączone. Nie deklarujemy potwierdzonych 60 FPS ani balansu i czasu przejścia w testach z dziećmi. Aktualizacja nie została jeszcze zainstalowana na telefonach użytkownika.

---

# Archiwalny raport wersji 1.0.0 — 24 września 2026

## Wersja

- Godot 4.7.2.stable.official.ed1daf0bf, GDScript, Compatibility, fizyka 60 Hz.
- APK release 1.0.0, `pl.rafal.jumpingpenguin`, min SDK 28, target SDK 36, ARM64.
- Środowisko budowania: macOS Apple Silicon, Apple M1 Pro, JDK 21, Gradle 8.11.1, Android SDK Platform 36 i Build Tools 36.1.0.
- Pobrany silnik i szablony zweryfikowano z oficjalnym SHA512-SUMS wydania 4.7.2.

## Automatyczne sprawdzenia

Uruchomienie: `python3 tools/test.py`. Raport surowy: `build/test-results.txt`.

**1158 sprawdzeń, 0 niepowodzeń.** Testy wykonują fizykę Godot, nie tylko obliczenia zasięgu. Końcowy przebieg nie zgłasza błędów skryptów ani zasobów. Dźwięk jest wyłączony podczas testów bez ekranu.

| Trasa | Easy | Medium | Hard |
|---|---|---|---|
| Chmurkowy Ogród | meta, 10/10 rybek | meta, 10/10 rybek | meta, 10/10 rybek |
| Kryształowe Wyspy | meta, 10/10 rybek | meta, 10/10 rybek | meta, 10/10 rybek |
| Zorza nad Oceanem | meta, 10/10 rybek | meta, 10/10 rybek | meta, 10/10 rybek |

Zakres testów:

- Martwa strefa, limit siły, kierunek, gest w dół, anulowanie przez powrót do początku.
- Pierwszy palec ma kontrolę; drugi palec, jego puszczenie i anulowanie nie zmieniają pierwszego gestu.
- Wszystkie 180 skoków między kolejnymi wyspami, rzeczywiste lądowania i widoczność następnego celu.
- Brak skoków w powietrzu i dodatkowej prędkości poziomej od ruchomej wyspy.
- Przewożenie stojącego pingwina przez ruchome wyspy.
- Skok z maksymalną siłą i lądowanie na cienkiej powierzchni; przejście od dołu przez jednostronną platformę i lądowanie podczas opadania.
- Progi gwiazdek 0/4/5/9/10 rybek, zachowanie najlepszego wyniku, odblokowania osobne dla trudności i zapis/odczyt ustawień.
- Pauza zamraża zegar planszy i anuluje celowanie. Powrót aplikacji z tła wymaga wznowienia.
- Upadek resetuje rybki, pozycję, fazę ruchu, postęp próby i pierwszą podpowiedź tutorialu.
- Prawdziwy przycisk pauzy przez zdarzenia wejścia viewportu konsumuje dotyk zamiast rozpoczynać skok.
- Sygnał ukończenia planszy zapisuje wynik, otwiera podsumowanie, a przycisk wyniku uruchamia następną trasę.

Automatyczna trasa korzysta z precyzyjnych, obliczonych skoków i jednej powtarzalnej sekwencji czasowej. Potwierdza osiągalność, a nie łatwość przejścia przez dziecko lub wszystkie możliwe fazy ruchu.

## Kontrola wizualna

Obejrzano zrzuty renderowane przez Godot na Apple M1 Pro: menu, wybór planszy, celowanie, gra, pauza, wariant zorzy oraz proporcje 16:9 (1280×720) i wydłużone (1600×720). Poprawiono wykryte błędy rozmiarów ilustracji i wag fontu. Używane są finalne grafiki, a nie atrapy.

Pliki podglądowe w `build`: `menu.png`, `levels.png`, `game.png`, `aim.png`, `pause.png`, `victory.png`, `aurora.png`, `wide.png`.

## Android

Test na emulatorze **Pixel 10**, obraz `android-37.0/google_apis_playstore_ps16k/arm64-v8a`, ekran 2424×1080 w poziomie, strona pamięci 16 KB, host Apple M1 Pro.

- Instalacja APK i aktualizacja tej samej aplikacji: sukces.
- Start z aktywności launchera, polskie menu, wybór planszy i grafika: sprawdzone.
- Zdarzenia dotykowe, rozgrywka, zbieranie rybek i przewijanie planszy: obserwowane na działającym APK.
- Ekran główny Androida → powrót do gry: pojawia się pauza z przyciskiem wznowienia.
- Odczyt `godot` i `AndroidRuntime` w logcat podczas testu: brak błędów wykonania i awarii aplikacji.
- Po aktualizacji APK emulator zgłosił ostrzeżenie o ponownej kompilacji zapamiętanego shadera; gra następnie uruchomiła się poprawnie.
- Metadane APK potwierdzają min SDK 28, target SDK 36 i wyłącznie ARM64. Nie deklaruje uprawnień do internetu, sieci ani plików.
- `apksigner verify --verbose`: poprawny podpis v2. Informacje licencyjne są dołączone do APK; pliki klucza podpisującego nie są dołączone.

Pierwszy zimny start emulatora z systemową podpowiedzią pełnego ekranu był wolny; kolejny start raportowany przez `am start -W` zajął około 0,75 sekundy. Nie jest to pomiar wydajności telefonu.

## Pozostałe testy odbiorcze

Nie było podłączonego fizycznego telefonu ani możliwości przeprowadzenia testu z dziećmi. Dlatego **nie potwierdzono jeszcze**:

- wygody sterowania palcem na fizycznym ekranie;
- stabilnych 60 FPS, temperatury i zużycia baterii na telefonie;
- rzeczywistego czasu 90–150 sekund i balansu easy dla 6–8 lat oraz medium/hard dla 9+;
- działania na fizycznym Androidzie 9 (minimalna wersja jest ustawiona w manifeście; emulator miał nowszy system);
- subiektywnej głośności i przyjemności muzyki przez odsłuch na telefonie.

### Krótki rodzinny test

1. Zainstalować APK na telefonie, wybrać easy i sprawdzić, czy dziecko rozumie pierwsze trzy podpowiedzi bez tłumaczenia.
2. Zmierzyć trzy udane przejścia każdej planszy po zapoznaniu się ze sterowaniem. Czas liczyć od pierwszego gestu do mety, bez wcześniejszych nieudanych prób.
3. Sprawdzić krótkie i długie gesty, celowanie z obu stron ekranu, cofnięcie gestu, drugi palec oraz pauzę.
4. Odczekać na ruchomej wyspie, wykonać skok, celowo wpaść do wody, ukończyć planszę i sprawdzić odblokowanie.
5. Wyciszyć muzykę i efekty, zamknąć aplikację, uruchomić ponownie i sprawdzić ustawienia oraz gwiazdki.
6. Zagrać przez 10 minut; zanotować model telefonu, wersję Androida, płynność i to, które skoki są zbyt trudne lub zbyt łatwe. Parametry do korekty są w `resources/difficulties` i `resources/levels`.

Publikacja w Google Play, konta deweloperskie i materiały sklepowe nie należą do tego wydania APK.
