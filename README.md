# Jumping Penguin

Polska gra 2D na Androida: mały pingwin, latające wyspy i ocean. Trzy ręcznie zaprojektowane trasy × trzy trudności, oryginalna grafika kawaii, animacje, muzyka i efekty. Gra działa całkowicie offline.

## Instalacja na telefonie

1. Skopiuj `build/JumpingPenguin.apk` na telefon z Androidem 9+ i procesorem ARM64.
2. Otwórz APK w aplikacji Pliki. Jeśli Android o to poprosi, zezwól tej aplikacji na instalowanie aplikacji z tego źródła.
3. Wybierz **Zainstaluj**, następnie uruchom **Jumping Penguin**. Trzymaj telefon poziomo.

APK jest podpisane lokalnym kluczem projektu. Aktualizacje podpisane tym samym kluczem można instalować na istniejącą wersję, zachowując postęp. Nie odinstalowuj gry przed aktualizacją, jeśli chcesz zachować gwiazdki.

Po podłączeniu telefonu z włączonym debugowaniem USB można użyć:

```sh
adb install -r build/JumpingPenguin.apk
adb shell am start -n pl.rafal.jumpingpenguin/com.godot.game.GodotAppLauncher
```

## Jak grać

- Wybierz trudność i odblokowaną planszę.
- Przeciągnij palec w kierunku skoku, zwykle w górę i w prawo. Im dłuższy gest, tym większa siła. Puszczenie palca wykonuje skok.
- Możesz rozpocząć gest w dowolnym miejscu poza przyciskami. Cofnięcie do punktu startu albo gest w dół anuluje skok.
- Strzałka i pasek pokazują kierunek oraz siłę. Nie ma podglądu toru lotu ani sterowania w powietrzu.
- Wyspy poruszają się także podczas celowania. Wpadnięcie do wody rozpoczyna tę planszę od nowa. Próby są nieograniczone.
- Za metę dostajesz jedną gwiazdkę, za minimum 5 rybek dwie, a za wszystkie 10 — trzy. Kolejne plansze odblokowują się osobno dla każdej trudności.
- Pauza zatrzymuje planszę; w jej menu można zmienić dźwięk, rozpocząć ponownie lub wybrać inną planszę.

Easy jest przeznaczony dla dzieci 6–8 lat, medium i hard dla 9+. Każda trasa ma 20 odcinków między 21 wyspami. Docelowy czas udanej próby to 90–150 sekund z czasem na celowanie; nie ma limitu czasu. To cel projektowy do potwierdzenia w testach z dziećmi, nie wynik pomiaru na grupie odbiorców.

## Uruchomienie projektu

Otwórz `project.godot` w **Godot 4.7.2 Standard**, bez .NET, i naciśnij F5. Na komputerze gest wykonuje się lewym przyciskiem myszy. Escape otwiera pauzę.

Na tym Macu silnik jest już w `.tools/Godot.app`. Uruchomienie z terminala:

```sh
.tools/Godot.app/Contents/MacOS/Godot --path .
```

Przy odtwarzaniu projektu na innym Macu z Pythonem 3.11+:

```sh
python3 tools/bootstrap.py
```

Skrypt pobiera oficjalny silnik 4.7.2 i szablony, sprawdza SHA512, rozpakowuje tylko potrzebne szablony Android i ustawia lokalny katalog danych edytora. Pobieranie archiwów zajmuje około 1,4 GB. `.tools` nie należy dodawać do repozytorium ani paczki źródeł.

## Budowanie APK

Potrzebne są JDK 21 (szablony używają języka Java 17), Android SDK Platform 36, Build Tools 36.1.0, Platform Tools i zaakceptowane licencje SDK. Android Studio może zainstalować te pakiety. Gradle 8.11.1 i zależności pobierają się przez wrapper przy pierwszej kompilacji. Korzystamy z gotowych bibliotek Godot; nie kompilujemy silnika z C++.

```sh
python3 tools/test.py
python3 tools/build_android.py
```

Skrypt budowania importuje zasoby, instaluje szablon projektu Gradle, eksportuje wariant release i weryfikuje podpis APK. Domyślnie używa SDK z `~/Library/Android/sdk` oraz JDK z `/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home`.

Ścieżki można zmienić zmiennymi `PENGUIN_GODOT`, `PENGUIN_ANDROID_SDK` i `PENGUIN_JAVA`. Własny silnik macOS powinien korzystać z lokalnego trybu `_sc_`, którego katalog `editor_data` znajduje się w `.tools`; skrypt jest przygotowany i sprawdzony dla układu tworzonego przez `bootstrap.py`.

Klucz `.tools/jumping-penguin.keystore` oraz hasło w `.tools/signing.json` powstają raz, automatycznie. **Zachowaj ich prywatną kopię**, aby następne APK mogły aktualizować tę instalację. Nie są dołączane do APK, paczki źródeł ani repozytorium. Identyfikator aplikacji: `pl.rafal.jumpingpenguin`, wersja: `1.0.0`, min SDK 28, target SDK 36, ABI `arm64-v8a`.

## Organizacja i strojenie

- `scripts/gesture.gd`: martwa strefa 16 jednostek, pełna siła przy 240 jednostkach gestu, maksymalna prędkość 850. Współrzędne są normalizowane przez skalowanie viewportu Godot.
- `scripts/penguin.gd`: CharacterBody2D, grawitacja 1200, fizyka 60 Hz, brak przejęcia prędkości wyspy przy opuszczeniu powierzchni.
- `scripts/world.gd`: przebieg próby, sinusoidalny ruch wysp, rybki, reset, kamera i meta.
- `resources/levels`: trzy definicje tras; `resources/difficulties`: szerokości, odstępy i ruch dla easy/medium/hard. Do zmiany balansu nie trzeba edytować interfejsu.
- `scripts/main.gd`: polski interfejs, pauza, bezpieczne marginesy i obsługa przejścia aplikacji do tła.
- `scripts/progress.gd`: lokalny zapis `user://progress.cfg`, osobny postęp dla każdej trudności; zapis przez plik tymczasowy.
- `assets/art`: oryginalne obrazy PNG, w tym trzy klatki pingwina; `docs/ART_PROMPTS.md`: pełne prompty użyte we wbudowanym imagegen.
- `tools/generate_audio.py`: odtwarzalny generator autorskiej 40-sekundowej melodii i sześciu efektów; wystarcza biblioteka standardowa Pythona.

Zmiana oryginalnych PNG wymaga aktualizacji regionów `AtlasTexture` w `scripts/art.gd`. Kontur fizyczny wyspy zaznacza jasny rant. Cała gra korzysta z renderera Compatibility.

## Weryfikacja

`python3 tools/test.py` uruchamia testy w rzeczywistym silniku Godot. Skrypt sprawdza kod wyjścia, liczbę wykonanych sprawdzeń i błędy skryptów, zapisując raport do `build/test-results.txt`. Automat wykonuje skoki przez wszystkie dziewięć tras i zbiera po 10 rybek. Nie zastępuje oceny wygody sterowania ani balansu przez dzieci.

Zrzuty kontrolne interfejsu można odtworzyć poleceniem:

```sh
.tools/Godot.app/Contents/MacOS/Godot --path . --script tests/capture.gd
```

Dokładne wyniki, sprawdzone urządzenia i ograniczenia znajdują się w `docs/TEST_REPORT.md`.

## Zasoby i licencje

Grafiki powstały wbudowanym narzędziem imagegen, a muzyka i efekty z autorskiego generatora. Nunito jest objęte SIL Open Font License (`assets/fonts/OFL.txt`). Informacje o licencji Godot i jego bibliotek są w `assets/licenses` i są dołączane do APK. Projekt nie zawiera usług sieciowych, analityki, reklam ani zakupów.
