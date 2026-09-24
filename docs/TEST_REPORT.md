# Raport weryfikacji — 24 września 2026

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
