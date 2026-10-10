# Overdracht

Dit project bevat een NativePHP Mobile-plugin met een PHP-API, een Swift-bridge voor CarPlay en een Kotlin-implementatie voor Android Auto. De map begon leeg; het pakket is zelfstandig opgebouwd en nog niet gepubliceerd of ingediend.

De bridge ondersteunt lijsten, secties, grids, informatierijen, berichten, zoeken, tabs, locaties op een kaart, schermnavigatie, ondersteunde schermupdates en interactie-events. CarPlay krijgt daarnaast alerts en Now Playing-weergave. De laatste functie levert zelf geen audioplayer. Navigatie draagt een bestemming over aan de kaartapp; een eigen route-engine is niet inbegrepen.

Er is native opslag voor het startscherm en een eventwachtrij. Hierdoor kan de auto inhoud tonen wanneer de telefooninterface nog niet actief is. PHP leest events later uit en bevestigt hun UUID's. Bij volle opslag wordt de overloop geteld; zakelijke acties moeten door de app idempotent worden verwerkt.

De lokale PHP-, JavaScript-, Swift- en Kotlin-controles slagen. Beide native implementaties zijn gecontroleerd tegen echte SDK's. De gedeelde 76 schermvoorbeelden slagen in alle drie de talen. Er is nog geen volledige ondertekende NativePHP-app met CarPlay/Android Auto uitgevoerd, omdat dit een pluginpakket zonder hostapp, Apple-entitlement of aangesloten head unit is. De precieze resterende tests staan in [VERIFICATION.md](VERIFICATION.md).

Voor gebruik voeg je deze map als Composer path repository toe aan je NativePHP-app en registreer je de plugin. Voor iOS kies je `CARPLAY_CATEGORY=parking`, `charging`, `food` of `audio`, passend bij Apple's toestemming. De buildhook zet de scene en entitlement in de gegenereerde projectbestanden. Android gebruikt de POI-categorie. Zie [INSTALLATION.md](INSTALLATION.md).

De Engelse documentatie is bedoeld voor NativePHP-reviewers. [SUBMISSION.md](SUBMISSION.md) bevat een beschrijving, reviewtekst, pakketinhoud en stappen voor indiening. De Composer-pakketnaam is `noelp-dev/carplay-sdk`; de beoogde repository is [noelp-dev/CarPlaySDK](https://github.com/noelp-dev/CarPlaySDK). De bestaande PHP- en Kotlin-namespaces blijven gelijk. De developer-onboarding van NativePHP vraagt om een ingelogd account. Er is nog niets bij NativePHP ingediend.

Behandel versie 0.1.0 als een reviewkandidaat. Na de host-, simulator-, DHU- en voertuigtests kan de verificatietabel worden bijgewerkt en een definitieve release worden gemaakt.
