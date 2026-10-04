# ulik.no

Små eksperimenter, rare ideer og verktøy. Elm eier sider, tilstand og navigasjon. JavaScript brukes ved nettlesergrensene: canvas, Three.js, lyd, tale, skjermdeling og tekstsammenligning.

## Kom i gang

Installer [Bun](https://bun.sh), og kjør:

```sh
bun install
bun run dev
```

`dev` starter Vite og `elm-watch hot`. Elm-kompilatoren følger med som utviklingsavhengighet. Elm-endringer oppdateres av elm-watch; CSS og JavaScript håndteres av Vite.

```sh
bun run check       # Elm-kompilering og JavaScript-syntaks
bun run lint        # elm-format og Biome
bun run test        # Vitest for adaptere, elm-test for Elm-logikk
bun run test:e2e    # Playwright mot produksjonsbygget
bun run build      # elm-watch make --optimize, Vite og statisk HTML
```

Installer nettleseren før første E2E-kjøring: `bunx playwright install chromium`.

## Koden

- `src/elm/Main.elm`: `Browser.application`, ruter og sidens livsløp
- `src/elm/Pages/`: én modul per eksperiment med `init`, `update`, `view` og `subscriptions`
- `src/elm/Projects.elm` og `Discovery.elm`: prosjektkatalog og oppdagelse
- `src/elm/Ports.elm`: én utgående port (`send`) og én inngående (`receive`)
- `src/browser/`: små adaptere for det Elm ikke kan gjøre direkte
- `src/styles/`: sidens CSS, avgrenset med sideklasser
- `tests/` og `e2e/`: Elm-enhetstester og nettlesertester

Alternativer og tilstander uttrykkes som union types. Records brukes til data som naturlig hører sammen, for eksempel en prosjektbeskrivelse eller et sett feltinnstillinger. Det er ingen generell side- eller effektplattform å lære først.

Portmeldinger har et `domain` og en `action`; hver adapter dekoder sitt avgrensede innhold. Ved navigasjon ryddes ressursene før neste side startes. Det stopper animasjoner, lyd og skjermdeling, også når en eldre asynkron forespørsel kommer tilbake sent. Three.js lastes først når robotsiden åpnes.

`diff`-biblioteket beholdes for de eksisterende linje- og ordforskjellene. Elm eier input, visning, statistikk og versjonering av resultatet. WebGL og canvas-rendering ligger i JavaScript, mens kontrollene og deres tilstand ligger i Elm.

## Statisk innhold og publisering

Produksjonsbygget ligger i `build/`. `scripts/prerender.js` kjører de samme Elm-visningene i JSDOM og lager HTML for alle eksisterende ruter. Katalog, lenker, beskrivelser og illusjonenes SVG er dermed tilgjengelige uten JavaScript; interaksjon krever JavaScript. Nettleseren starter deretter den samme Elm-appen.

`APP_VERSION` vises i bunnteksten. Push til `main` publiserer fortsatt til beta. En publisert release bruker den eksisterende produksjonsflyten. Pull requests får egne Firebase-preview-kanaler, bygget uten deploy-hemmeligheter og publisert fra en separat runner. Migreringen endrer ikke disse publiseringsmålene.
