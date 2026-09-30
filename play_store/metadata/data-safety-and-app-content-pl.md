# Arkusz deklaracji Google Play — Jumping Adventure 1.1.0 / code 2

Stan kodu sprawdzony w repozytorium 29.09.2026. Wypełnij formularz w Play Console dopiero dla dokładnie tego AAB i ponownie sprawdź wszystkie biblioteki w gotowym pakiecie. Formularz może zmienić nazwy lub kolejność pytań.

## Data safety / Bezpieczeństwo danych

Google definiuje zbieranie jako przesłanie danych poza urządzenie; dane przetwarzane chwilowo w pamięci wciąż należy uwzględnić w odpowiedziach. W grze nie ma serwera gry: przesyłanie uruchamia sam użytkownik i odbywa się bezpośrednio w lokalnej sieci do drugiego uczestnika. Wybierz zgodnie z bieżącym brzmieniem pytań:

| Pytanie / rodzaj | Odpowiedź robocza | Dlaczego |
|---|---|---|
| Czy aplikacja zbiera lub udostępnia dane? | **Tak — zbieranie danych przetwarzanych chwilowo** | Tylko jeśli użytkownik uruchomi lokalny wyścig: urządzenia wymieniają dane poza urządzeniem. Nie trafiają do wydawcy ani serwera. |
| Aktywność w aplikacji → Inne działania | **Zbierane; przetwarzane chwilowo; użytkownik może zdecydować; funkcjonalność aplikacji** | Sterowanie i stan gry (pozycje, punkty, postać, etap wyścigu) są wysyłane w czasie rzeczywistym do symulacji wspólnego wyścigu, potem usuwane z pamięci sesji. |
| Urządzenie lub inne identyfikatory | **Zbierane i przetwarzane chwilowo; funkcjonalność aplikacji; użytkownik decyduje** | Konserwatywnie uwzględnij lokalny adres IP, identyfikator sesji i tymczasowy token, które służą do połączenia i uwierzytelnienia. Gra nie używa identyfikatora Androida, reklamowego ID ani lokalizacji. |
| Udostępnianie partnerowi wyścigu | **Nie — akcja jest inicjowana przez użytkownika i oczekiwana** | Google wyłącza z „sharing” transfer następujący po konkretnej akcji użytkownika, gdy udostępnienie jest dla niego zrozumiałe. Gracz sam wybiera tryb dwuosobowy, skanuje zaproszenie i dołącza do osoby w tej samej sieci. Jeśli bieżący formularz nie stosuje tego wyjątku do połączenia peer-to-peer, zaznacz „shared” i cel „App functionality” dla tych samych dwóch kategorii. |
| Zdjęcia i filmy / dane z aparatu | **Nie** | Kamera służy do lokalnego odczytu QR. Obraz nie jest zapisywany ani wysyłany; nie jest przechowywany poza skanerem. |
| Lokalizacja, dane osobowe, wiadomości, pliki, kontakty | **Nie** | Nie znaleziono dostępu do GPS, danych osobowych, czatu, plików użytkownika ani kontaktów. Gra nie wylicza lokalizacji z prywatnego adresu Wi-Fi. |
| Dane diagnostyczne / crash logs | **Nie** | Brak usługi raportowania awarii, analityki i telemetryki. |
| Dane pozostają w urządzeniu / szyfrowane end-to-end? | **Nie deklaruj E2E** | Multiplayer jest lokalny, ale nie ma szyfrowania end-to-end. Nie ma trwałej synchronizacji z serwerem. |
| Konto, usuwanie konta, logowanie | **Nie dotyczy** | Aplikacja nie tworzy kont ani nie wymaga logowania. |

**Ważne:** kod używa `INTERNET` i `ACCESS_NETWORK_STATE` do transportu LAN. Te uprawnienia nie oznaczają komunikacji z serwerem internetowym. Wersja robocza przyjmuje konserwatywnie dwie kategorie danych i wyjątek dla udostępnienia wybranemu peerowi przez użytkownika. Przed wysłaniem ponownie sprawdź dokładną zawartość AAB, raport SDK i aktualne odpowiedzi formularza. Nie wybieraj „brak danych” bez uwzględnienia peer-to-peer.

## App content / Zawartość aplikacji

- **Reklamy:** nie.
- **Dostęp do aplikacji:** recenzent ma dostęp do całej gry bez logowania, kodów ani płatności.
- **Wiek/odbiorcy:** projekt opisuje łatwy tryb jako przeznaczony dla wieku 6–8 lat, a średni/trudny od 9 lat. To grywalna platformówka o przyjaznej oprawie. Wybierz grupy zgodnie z rzeczywistym marketingiem i przeznaczeniem. Uwaga: tryb LAN umożliwia dwóm graczom bezpośrednią, równoczesną interakcję w wyścigu. Wskazówki Play dla 9–12 lat wymieniają taką interakcję jako możliwą przesłankę, że aplikacja nie jest odpowiednia dla tej grupy; przed zaznaczeniem 9–12 przejrzyj ekran Audience oraz Families. Nie ukrywaj funkcji multiplayer w opisie.
- **Rodzina/Families:** jeżeli zaznaczysz jakąkolwiek grupę poniżej 13 lat, obowiązują odpowiednie wymagania Families. Przed wydaniem zweryfikuj komponenty aplikacji/SDK wobec aktualnych zasad Families.
- **IARC / klasyfikacja treści:** odpowiedz „nie” dla realistycznej przemocy, krwi, strachu/horroru, wulgaryzmów, seksualności/nagości, narkotyków, hazardu z nagrodą, treści generowanych przez użytkownika i czatu. Odpowiedz „tak” na pytanie o możliwość interakcji między użytkownikami, jeśli obejmuje ono wspólny lokalny wyścig. Wskaż wyłącznie interakcję lokalną: dwóch uczestników tej samej sieci, bez czatu, profili, wyszukiwania graczy i treści użytkownika. Wynik ratingu nada IARC — nie wpisuj PEGI/ESRB ręcznie.
- **Treści online:** brak zdalnego serwera i przeglądania sieci. Wyścig LAN wymaga świadomego połączenia w tej samej sieci.
- **Prywatność:** wklej publiczny, aktywny i nieedytowalny adres polityki po jej wdrożeniu. Aplikacja musi też pokazywać samą politykę lub bezpośredni link z interfejsu.
- **Aplikacja informacyjna/rządowa/finansowa/zdrowotna:** nie.
- **Kategoria sklepu:** Gra → Przygodowe, ewentualnie Zręcznościowe.

## Zależności i inspekcja pakietu

W kodzie zidentyfikowano Godot 4.7.2, natywny most Androida do skanowania ZXing Embedded 4.3.0, ZXing i biblioteki AndroidX/Kotlin; nie ma w projekcie SDK reklam, analityki, Firebase ani crash reporting. Przed publikacją potwierdź transitive dependencies i ich polityki z gotowego AAB. Jeśli zmieni się zestaw SDK, sprawdź odpowiedzi ponownie.
