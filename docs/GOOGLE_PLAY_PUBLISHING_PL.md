# Jak opublikować Jumping Adventure w Google Play

Instrukcja dla osoby, która publikuje grę po raz pierwszy. Nazwy części menu Google Play Console mogą się nieznacznie zmieniać.

Sprawdzone 25 września 2026 r. Wymagania i układ Play Console mogą się zmienić.

## Najważniejsze informacje o tym projekcie

- Projekt otwiera się w **Godot 4.7.2 Standard**. To edycja Godota dla GDScript; nie pobieraj edycji .NET. Najprościej edytować skrypty wbudowanym edytorem Godota. Android Studio służy tu głównie do zainstalowania Android SDK i JDK — nie jest potrzebne do tworzenia scen ani skryptów gry. Visual Studio Code jest opcjonalną alternatywą do edycji skryptów, ale wymaga skonfigurowania w Godocie.
- Identyfikator aplikacji (package name) to **`pl.zarajczyk.jumpingpenguin`**. To techniczna tożsamość aplikacji; nazwa widoczna w sklepie to **Jumping Adventure**.
- Minimalna wersja Androida to Android 9 (API 28), a projekt kieruje się do Androida 16 (API 36). Wymóg Google Play dla nowych aplikacji i aktualizacji od 31 sierpnia 2026 r. wynosi API 36, więc obecna konfiguracja spełnia wymóg API.
- Workflow GitHub buduje podpisane pliki **APK i AAB** oraz publikuje oba w GitHub Releases. AAB trzeba przesłać z GitHub Releases do Play Console; workflow nie publikuje bezpośrednio w sklepie.
- Gra działa offline; w projekcie nie ma kont, reklam, zakupów ani analityki. Postęp i ustawienia są zapisywane lokalnie na urządzeniu.

## 1. Sprawdź, czy to ma być nowa aplikacja, czy aktualizacja

Otwórz [swój panel Google Play Console](https://play.google.com/console/u/0/developers/7466061695590636374/app/4972105751499630118/app-dashboard). To inna aplikacja, więc utwórz nową pozycję dla Jumping Adventure. W Play Console wybierz **Create app / Utwórz aplikację**, wpisz nazwę „Jumping Adventure” i jako package name podaj dokładnie `pl.zarajczyk.jumpingpenguin`. Nie da się później zmienić identyfikatora aplikacji opublikowanej w Google Play.

### Dodatkowe sprawdzenie: rejestracja nazwy pakietu Androida

Google wdraża obecnie Android developer verification. Nowe pozycje utworzone w Play Console są zwykle rejestrowane automatycznie, ale sprawdź status na stronie głównej konsoli. Termin rejestracji pozostałych nazw pakietów aplikacji Play przypada na 30 września 2026 r.; jeżeli konsola wyświetla ostrzeżenie, załatw je przed publikacją. [Aktualne informacje o rejestracji pakietów](https://support.google.com/googleplay/android-developer/answer/16984799?hl=pl).

## 2. Zdecyduj o podpisie, zanim utworzysz pierwsze wydanie

Podpis cyfrowy pozwala Androidowi rozpoznać, że aktualizacja pochodzi od autora tej samej aplikacji. Nie publikuj pliku keystore, haseł ani ich kopii w repozytorium.

Ten projekt ma istniejący klucz wydania zapisany poza repozytorium i używa go do APK instalowanych z GitHub Releases. Nie trać tego klucza: jego kopia potrzebna jest do kolejnych APK i AAB. Hasło znajduje się w prywatnym GitHub Actions secret.

- Jeśli w Play Console jest już aplikacja o tym samym identyfikatorze, użyj konfiguracji podpisu wskazanej dla tej aplikacji. Play Console rozróżnia **klucz podpisu aplikacji** od **klucza przesyłania** pliku AAB; w razie wątpliwości zatrzymaj się i sprawdź sekcję „App integrity”.
- Jeśli tworzysz nową pozycję, Google domyślnie może wygenerować i bezpiecznie przechowywać klucz podpisu aplikacji. To dobre ustawienie domyślne. Jednak APK instalowane bezpośrednio z GitHuba są podpisane kluczem projektu. Gdy klucz podpisu aplikacji w Google Play będzie inny, Android nie zaktualizuje takiej instalacji „na miejscu”; trzeba będzie odinstalować APK i zainstalować grę z Google Play. Zapis gry jest lokalny, więc odinstalowanie może skasować zapisany postęp.
- Jeśli chcesz, by dotychczasowe instalacje z APK mogły przejść na wersję ze sklepu bez odinstalowania, trzeba skonfigurować Play App Signing z dotychczasowym kluczem podpisu aplikacji. Wybór klucza dla pierwszego wydania ma skutki dla aktualizacji. Zanim potwierdzisz ten wybór, zachowaj bezpieczną kopię klucza i sprawdź, czy nie ma już istniejącego klucza w Play Console.

Play App Signing pozwala Google podpisywać pliki dostarczane użytkownikom, a osobnym kluczem podpisujesz AAB wysyłany do konsoli. [Opis podpisywania aplikacji w Play Console](https://support.google.com/googleplay/android-developer/answer/9842756?hl=pl) wyjaśnia te dwa klucze i wybór własnego klucza.

## 3. Przygotuj plik AAB

Google Play wymaga AAB dla nowych aplikacji. APK służy do instalacji bezpośredniej na telefonie; nie przesyłaj APK z GitHub Releases jako pierwszego wydania w Play Console.

### Przygotowanie Godota na komputerze

1. Zainstaluj **Godot 4.7.2 Standard** oraz pasujące do tej wersji Android Export Templates.
2. Zainstaluj Android Studio, uruchom je raz i dokończ konfigurację Android SDK. Do eksportu z tego projektu potrzebne są JDK 21, Android SDK Platform 36, Build Tools 36.1.0 i Platform Tools. Godot musi wskazywać ścieżki do JDK i Android SDK w **Editor Settings > Export > Android**. Android Studio może zarządzać pakietami SDK, ale edycję gry nadal wykonujesz w Godocie.
3. Na macOS przygotowanie lokalnych narzędzi projektu można uruchomić poleceniem `python3 tools/bootstrap.py`; pobiera ono Godota i szablony Androida. Skrypt bootstrapu w tym repozytorium jest przeznaczony dla macOS. Na Windows lub Linux zainstaluj Godota 4.7.2 i szablony osobno.
4. Otwórz projekt w Godocie i wybierz **Project > Install Android Build Template** (zainstaluj szablon Gradle). Projekt już ma włączoną kompilację Gradle, potrzebną do AAB.

### Eksport z interfejsu Godota

1. Wybierz **Project > Export** i zaznacz preset Android.
2. Sprawdź, czy **Gradle Build** jest włączony, identyfikator aplikacji to `pl.zarajczyk.jumpingpenguin`, a **Target SDK** to 36.
3. Wybierz preset **Android AAB** (osobny preset w projekcie zapisuje plik `build/JumpingAdventure.aab`). Preset **Android** nadal eksportuje APK.
4. W ustawieniach podpisu użyj klucza przesyłania zgodnego z pozycją w Play Console. Przy pierwszym wydaniu nowej aplikacji ustaw podpis Play App Signing zgodnie z decyzją z poprzedniego kroku. Nie wpisuj haseł do dokumentacji ani nie commituj ich w Git.
5. Eksportuj jako **Release** (bez debugowania) i zapisz plik np. jako `build/JumpingAdventure.aab`.
6. Zainstaluj AAB przez ścieżkę testową Google Play, aby sprawdzić dokładnie wersję, którą otrzymają testerzy. AAB nie otwiera się bezpośrednio na telefonie jak APK.

W Godocie trzeba mieć szablony eksportu pasujące do wersji silnika, a eksport AAB wymaga kompilacji Gradle. Zobacz [instrukcję eksportu Android w Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html) oraz [konfigurację kompilacji Gradle](https://docs.godotengine.org/en/4.7/tutorials/export/android_gradle_build.html).

### Numer wersji

Każdy kolejny plik wysyłany do tej samej aplikacji musi mieć większy `versionCode` niż wszystkie wcześniejsze wydania. W repozytorium bazowy preset ma numer 2. Workflow GitHub podnosi go automatycznie w presetach APK i AAB. Ręczny eksport w Godocie korzysta z numeru zapisanego w presecie.

## 4. Uzupełnij informacje o aplikacji w Play Console

Wybierz właściwą aplikację, potem przejdź po zadaniach widocznych na jej panelu. Google może zmieniać nazwy i kolejność sekcji. Trzeba przygotować:

- **Opis i nazwę sklepową.** „Jumping Adventure” ma limit 30 znaków, krótki opis 80, a pełny opis 4000. Przykładowy krótki opis: „Skacz między wyspami, zbieraj gwiazdki i poznawaj pięć zwierzęcych postaci.”
- **Grafiki.** Ikona strony sklepu: PNG 512×512 px (maks. 1 MB). Grafika promocyjna: JPEG lub PNG bez przezroczystości 1024×500 px. Dodaj zrzuty ekranu rzeczywistej gry z telefonu; nie pokazuj funkcji, których aplikacja nie ma.
- **Politykę prywatności.** W repozytorium nie ma jeszcze gotowej polityki prywatności ani linku do niej w grze. Przygotuj prawdziwy, publiczny URL (na przykład na stronie, którą kontrolujesz), dodaj go w Play Console i umieść dostępny z aplikacji link albo tekst. Nawet aplikacja, która nie zbiera danych, potrzebuje polityki i wypełnionego formularza Data safety.
- **Data safety / Bezpieczeństwo danych.** Odpowiadaj na podstawie faktycznej wersji APK/AAB, w tym bibliotek i SDK. Obecna gra zapisuje postęp lokalnie, nie wysyła go do serwera i nie używa reklam, kont ani analityki; potwierdź jednak formularz zgodnie z listą danych w konkretnej wersji, którą publikujesz.
- **Target audience / Odbiorcy.** Gra jest projektowana także dla dzieci w wieku 6–8 lat. Zaznacz grupy wiekowe zgodnie z rzeczywistym przeznaczeniem gry. Gdy choć jedna grupa obejmuje dzieci, obowiązują wymagania Google Play Families; nie deklaruj „nie dla dzieci” tylko po to, by ominąć te wymagania.
- **Content rating / Klasyfikacja treści.** Wypełnij kwestionariusz IARC rzetelnie.
- **App access / Dostęp do aplikacji.** Gra nie wymaga logowania; odpowiedz zgodnie z tym stanem.
- **Ads / Reklamy.** Projekt nie ma reklam. Zaznacz ten stan i zmień odpowiedź, jeżeli reklamy zostaną kiedyś dodane.
- **Cena i kraje.** Wybierz „Free”, jeśli gra ma być bezpłatna, oraz kraje, w których ma być dostępna. Późniejsza zmiana z płatnej aplikacji na darmową ma ograniczenia, więc wybierz model przed publikacją.

Google Play wymaga grafiki promocyjnej, ikony i wypełnionych deklaracji. Obowiązek polityki prywatności i Data safety dotyczy również aplikacji, która nie zbiera danych. Zobacz oficjalne strony o [grafikach i zrzutach](https://support.google.com/googleplay/android-developer/answer/9866151?hl=pl), [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=pl) i [odbiorcach oraz treściach](https://support.google.com/googleplay/android-developer/answer/9867159?hl=pl).

## 5. Przetestuj wydanie przed publikacją

1. Zacznij od **Internal testing / Testów wewnętrznych**. Utwórz wydanie, prześlij AAB, dodaj swój adres Google jako testera, zapisz i uruchom test. Otwórz link testowy na telefonie z tym samym kontem Google i zainstaluj grę z Google Play.
2. Sprawdź instalację, dźwięk, sterowanie poziome, powrót z pauzy, zapis postępu i aktualizację. Poproś kilka osób o przetestowanie gry przed publicznym wydaniem.
3. Jeśli typ Twojego konta tego wymaga, utwórz **Closed testing / Test zamknięty**, dodaj testerów, a następnie wyślij im link do dołączenia. Wymóg co najmniej 12 testerów przez 14 kolejnych dni dotyczy osobistych kont deweloperskich utworzonych po 13 listopada 2023 r. Po teście trzeba złożyć w Play Console wniosek o dostęp do produkcji. Jeżeli Twoje istniejące konto nie jest objęte tym warunkiem, Play Console pokaże dostępne ścieżki bez tego wymogu.

## 6. Wyślij grę do publicznego sklepu

Gdy panel aplikacji nie pokazuje brakujących zadań:

1. Otwórz **Test and release > Production** (Testowanie i publikowanie > Produkcja).
2. Wybierz **Create new release**, prześlij AAB, wpisz krótką informację o wydaniu i zapisz.
3. Przejdź dalej przez podsumowanie błędów i ostrzeżeń. Błędy blokujące publikację trzeba naprawić; ostrzeżenia przeczytaj i oceń.
4. Wybierz **Start rollout to production** / rozpocznij wdrażanie. Przy pierwszej publikacji Google sprawdzi aplikację i wpis sklepu. Po akceptacji status w konsoli zmieni się, a strona sklepu stanie się dostępna.

Alternatywnie po testach można najpierw opublikować mały etap wdrażania produkcyjnego, jeżeli Play Console pokaże taką możliwość, a potem zwiększyć zasięg. [Oficjalna instrukcja przygotowania i wdrożenia wydania](https://support.google.com/googleplay/android-developer/answer/9859348?hl=pl) opisuje aktualne ekrany.

## Co jest jeszcze do zrobienia w tym projekcie

1. Utworzyć nową aplikację w Play Console z pakietem `pl.zarajczyk.jumpingpenguin`.
2. Podjąć świadomą decyzję o kluczu podpisu. Zmiana pakietu oznacza, że Android pokaże grę jako nową aplikację; stare instalacje `pl.rafal.jumpingpenguin` i ich lokalne zapisy nie zostaną automatycznie przeniesione.
3. Przygotować publiczną politykę prywatności i dodać odnośnik dostępny z gry.
4. Pobrać AAB z GitHub Release, przygotować ikonę sklepową, grafikę 1024×500 i zrzuty ekranu.
5. Uzupełnić formularze, przeprowadzić testy i zlecić wydanie Google Play do sprawdzenia.

Wymogi sklepu i układ panelu zmieniają się. Przed wysłaniem sprawdź komunikaty w Play Console oraz aktualne [wymagania poziomu API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=pl).
