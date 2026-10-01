# Pakiet Google Play — Jumping Adventure

Przygotowany dla aplikacji `pl.zarajczyk.jumpingpenguin`, wersji 1.1.0 (version code 2), w języku polskim.

## Pliki

- `metadata/store-listing-pl.md` — nazwa, krótki i pełny opis oraz propozycja kategorii.
- `metadata/release-notes-pl.txt` — informacja o wersji do Play Console.
- `metadata/privacy-policy.html` — responsywna polityka prywatności PL/EN do umieszczenia pod publicznym adresem HTTPS. Przed publikacją uzupełnij oznaczone pola operatora i kontaktu.
- `metadata/data-safety-and-app-content-pl.md` — robocze odpowiedzi do Data safety, IARC, odbiorców, dostępu do aplikacji i reklam.
- `metadata/release-checklist-pl.md` — kolejność prac w Play Console i elementy do sprawdzenia przed wysłaniem.
- `assets/app-icon-512.png` — ikona 512×512.
- `assets/feature-graphic-1024x500.jpg` — grafika promocyjna 1024×500.
- `assets/screenshots/phone/` — zrzuty ekranu telefonu.
- `assets/screenshots/tablet/` — zrzuty ekranu dużego ekranu.
- `metadata/alt-text-pl.md` — podpisy alternatywne do wklejenia w konsoli.

Bundle Android App Bundle powstaje po uruchomieniu `python3 tools/build_android.py` w `build/JumpingAdventure.aab`. GitHub Actions publikuje podpisany AAB dla aktualnego commita w Releases, z wersją `1.1.N` i kodem `1000000 + N`. Do testów użyj paczki zbudowanej z aktualnego kodu. Przed wydaniem publicznym upewnij się, że klucz przesyłania odpowiada temu skonfigurowanemu w Play Console i version code jest wyższy od poprzednio przesłanego.

## Przed publikacją

W polityce prywatności trzeba wpisać prawdziwe dane administratora oraz kontaktowy adres e-mail, opublikować plik jako stronę WWW (nie PDF), a następnie dodać URL w Play Console i tekst/link w samej aplikacji. Aktualna wersja gry nie ma jeszcze tego odnośnika w interfejsie, więc nie przesyłaj jej jako końcowego wydania przed dodaniem dostępu do polityki w aplikacji i przebudowaniem AAB.

Odpowiedzi Data safety w pliku roboczym zakładają dokładnie wersję kodu 2 i wymagają potwierdzenia w aktualnym formularzu Play Console. Odbiorcy wieku, cena, rynki dystrybucji i dane prawne wydawcy są decyzjami właściciela konta.
