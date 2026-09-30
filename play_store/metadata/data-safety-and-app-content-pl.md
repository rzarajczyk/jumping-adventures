# Arkusz deklaracji Google Play — Jumping Adventure 1.1.0 / code 2

Stan kodu jednoosobowej wersji sprawdzony w repozytorium 01.10.2026. Wypełnij formularz w Play Console dopiero dla dokładnie tego AAB i ponownie sprawdź wszystkie biblioteki w gotowym pakiecie. Formularz może zmienić nazwy lub kolejność pytań.

## Data safety / Bezpieczeństwo danych

Gra zapisuje postępy i ustawienia na urządzeniu, bez przesyłania ich do serwera ani innych użytkowników. Google wyłącza dane przetwarzane wyłącznie lokalnie z deklaracji zbierania. Źródło: [oficjalne objaśnienia Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=pl).

| Pytanie / rodzaj | Odpowiedź robocza | Dlaczego |
|---|---|---|
| Czy aplikacja zbiera lub udostępnia dane? | **Nie** | W tej wersji kodu nie ma przesyłania danych poza urządzenie ani udostępniania ich innym aplikacjom. |
| Aktywność w aplikacji | **Nie jest zbierana** | Wybrana postać, postępy, wyniki i ustawienia są zapisywane tylko lokalnie. |
| Urządzenie lub inne identyfikatory | **Nie** | Gra nie tworzy identyfikatorów kont, połączeń ani urządzeń i nie używa reklamowego ID. |
| Zdjęcia i filmy / dane z aparatu | **Nie** | Gra nie korzysta z aparatu. |
| Lokalizacja, dane osobowe, wiadomości, pliki, kontakty | **Nie** | Nie znaleziono dostępu do GPS, danych osobowych, czatu, plików użytkownika ani kontaktów. |
| Dane diagnostyczne / crash logs | **Nie** | Brak usługi raportowania awarii, analityki i telemetryki. |
| Konto, usuwanie konta, logowanie | **Nie dotyczy** | Aplikacja nie tworzy kont ani nie wymaga logowania. |

Presety eksportu nie włączają uprawnień do Internetu, stanu sieci ani aparatu. Przed wysłaniem potwierdź uprawnienia oraz zależności w dokładnym APK/AAB i dostosuj odpowiedzi do formularza.

## App content / Zawartość aplikacji

- **Reklamy:** nie.
- **Dostęp do aplikacji:** recenzent ma dostęp do całej gry bez logowania, kodów ani płatności.
- **Wiek/odbiorcy:** projekt opisuje łatwy tryb jako przeznaczony dla wieku 6–8 lat, a średni/trudny od 9 lat. To grywalna platformówka o przyjaznej oprawie. Wybierz grupy zgodnie z rzeczywistym marketingiem i przeznaczeniem.
- **Rodzina/Families:** jeżeli zaznaczysz jakąkolwiek grupę poniżej 13 lat, obowiązują odpowiednie wymagania Families. Przed wydaniem zweryfikuj komponenty aplikacji/SDK wobec aktualnych zasad Families.
- **IARC / klasyfikacja treści:** odpowiedz „nie” dla realistycznej przemocy, krwi, strachu/horroru, wulgaryzmów, seksualności/nagości, narkotyków, hazardu z nagrodą, treści generowanych przez użytkownika i czatu. Gra jednoosobowa nie udostępnia interakcji między użytkownikami. Wynik ratingu nada IARC — nie wpisuj PEGI/ESRB ręcznie.
- **Treści online:** brak zdalnego serwera i przeglądania sieci.
- **Prywatność:** wklej publiczny, aktywny i nieedytowalny adres polityki po jej wdrożeniu. Aplikacja musi też pokazywać samą politykę lub bezpośredni link z interfejsu.
- **Aplikacja informacyjna/rządowa/finansowa/zdrowotna:** nie.
- **Kategoria sklepu:** Gra → Przygodowe, ewentualnie Zręcznościowe.

## Zależności i inspekcja pakietu

W kodzie zidentyfikowano Godot 4.7.2; nie ma w projekcie SDK reklam, analityki, Firebase ani crash reporting. Przed publikacją potwierdź transitive dependencies i ich polityki z gotowego AAB. Jeśli zmieni się zestaw SDK, sprawdź odpowiedzi ponownie.
