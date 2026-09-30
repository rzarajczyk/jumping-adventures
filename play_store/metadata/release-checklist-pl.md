# Checklista publikacji Jumping Adventure

## Uzupełnij przed wysłaniem

- [ ] Uzupełnij prawdziwą nazwę administratora/wydawcy oraz publiczny adres kontaktowy w `privacy-policy.html`.
- [ ] Opublikuj politykę jako zwykłą, publicznie dostępną stronę HTML/WWW pod stałym adresem HTTPS; sprawdź w oknie prywatnym bez logowania. Nie publikuj PDF-u.
- [ ] Dodaj ten adres do Google Play Console.
- [ ] Dodaj w grze widoczny tekst polityki lub bezpośredni link i wydaj nowy AAB. Testowana wersja 1.1.0 jeszcze go nie pokazuje.
- [ ] Zdecyduj o grupie docelowej jednoosobowej gry i sprawdź wymagania Families. Zachowaj spójność między ustawieniem wieku, opisem, IARC i rzeczywistym działaniem.
- [ ] Ustal publiczną nazwę dewelopera, cenę, kraje/regiony oraz adres e-mail obsługi w Play Console.
- [ ] Sprawdź fingerprint certyfikatu AAB z sekcją **App integrity**. AAB jest podpisany lokalnym kluczem; nowa pozycja Play może wymagać osobnego klucza przesyłania. Zachowaj prywatne kopie klucza i haseł.
- [ ] Podnieś `version/code` powyżej 2 przed nowym buildem do sklepu, jeśli code 2 zostanie już przesłany do tej aplikacji.
- [ ] Wypełnij Data safety na podstawie dokładnie przesyłanego AAB i potwierdź lokalne przechowywanie postępów.
- [ ] Wypełnij questionnaire IARC i zapisz wynik nadany w konsoli.
- [ ] Wybierz „bez reklam”; potwierdź brak reklam także w finalnym AAB.

## Materiały sklepu

- [x] Nazwa i opis po polsku (limity opisane przy tekście).
- [x] Ikona aplikacji 512×512 PNG z kanałem alfa.
- [x] Grafika promocyjna 1024×500 JPEG bez kanału alfa.
- [x] Zrzuty gry w orientacji poziomej, bez ramek telefonu, dodatkowych sloganów i nieaktualnej grafiki wcześniejszych supermocy.
- [ ] Jeśli deklarujesz obsługę tabletów: zarejestruj co najmniej cztery zrzuty dużego ekranu w wymaganej rozdzielczości i sprawdź widok na rzeczywistym emulatorze/tablecie. Folder `tablet` jest propozycją 16:9 do weryfikacji urządzenia przed uploadem, nie dowodem testu na urządzeniu.
- [ ] Dodaj zrzuty do Play Console i wpisz przygotowane teksty alternatywne.

## Konsola i testy

- [ ] Utwórz wpis gry z package ID `pl.zarajczyk.jumpingpenguin`; wpis jest niezależny od poprzedniej aplikacji `pl.rafal.jumpingpenguin`.
- [ ] Uzupełnij sekcje App access, Ads, Target audience, Content rating, Data safety, Privacy policy, kategoria, e-mail kontaktowy oraz rynki.
- [ ] Sprawdź nazwę, ikonę, opis, zrzuty, deklaracje, uprawnienia i działanie gry offline w ścieżce Internal testing.
- [ ] Ustal, czy typ i data utworzenia konta wymagają 12 testerów przez 14 kolejnych dni w ścieżce Closed testing. Zastosuj wymóg tylko wtedy, gdy Play Console pokazuje, że dotyczy tego konta.
- [ ] Dopiero po przejściu walidacji przygotuj produkcyjne wydanie i prześlij je do recenzji Google Play.
