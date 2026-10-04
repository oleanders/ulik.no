module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Deploy
import Discovery
import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Decode as Decode
import Json.Encode as Encode
import Pages.Diff as Diff
import Pages.Falling as Falling
import Pages.Flow as Flow
import Pages.Illusions as Illusions
import Pages.Morse as Morse
import Pages.Nato as Nato
import Pages.Robot as Robot
import Pages.Screen as Screen
import Ports
import Projects
import Url exposing (Url)


type Route
    = Home
    | Catalog
    | About
    | Project Projects.Id String
    | NotFound


type Page
    = HomePage
    | CatalogPage
    | AboutPage
    | PlaceholderPage
    | NotFoundPage
    | FlowPage Flow.Model
    | RobotPage Robot.Model
    | FallingPage Falling.Model
    | NatoPage Nato.Model
    | MorsePage Morse.Model
    | DiffPage Diff.Model
    | ScreenPage Screen.Model
    | IllusionsPage Illusions.Model


type alias Flags =
    { version : String, prerender : Bool }


type alias Model =
    { key : Nav.Key
    , url : Url
    , route : Route
    , page : Page
    , discovery : Discovery.Model
    , deploy : Deploy.Model
    , version : String
    , scrollToTop : Bool
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | Received Decode.Value
    | DiscoveryMsg Discovery.Msg
    | DeployMsg Deploy.Msg
    | FlowMsg Flow.Msg
    | RobotMsg Robot.Msg
    | FallingMsg Falling.Msg
    | NatoMsg Nato.Msg
    | MorseMsg Morse.Msg
    | DiffMsg Diff.Msg
    | ScreenMsg Screen.Msg
    | IllusionsMsg Illusions.Msg


main : Program Flags Model Msg
main =
    Browser.application { init = init, update = update, view = view, subscriptions = subscriptions, onUrlRequest = LinkClicked, onUrlChange = UrlChanged }


routeFromUrl : Url -> Route
routeFromUrl url =
    case String.split "/" url.path |> List.filter ((/=) "") of
        [] ->
            Home

        [ "projects" ] ->
            Catalog

        [ "om" ] ->
            About

        [ "projects", "morsekode" ] ->
            Project Projects.Morse "oversikt"

        [ "projects", "morsekode", subpage ] ->
            if List.member subpage [ "oversikt", "motta", "sende" ] then
                Project Projects.Morse subpage

            else
                NotFound

        [ "projects", slug ] ->
            Projects.fromSlug slug |> Maybe.map (\id -> Project id "") |> Maybe.withDefault NotFound

        _ ->
            NotFound


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        route =
            routeFromUrl url

        ( page, pageCmd ) =
            initPage route url

        ( deploy, deployCmd ) =
            Deploy.init
    in
    ( { key = key, url = url, route = route, page = page, discovery = Discovery.init, deploy = deploy, version = flags.version, scrollToTop = False }
    , if flags.prerender then
        pageCmd

      else
        Cmd.batch [ lifecycle url False, Cmd.map DeployMsg deployCmd ]
    )


lifecycle : Url -> Bool -> Cmd Msg
lifecycle url scrollToTop =
    Ports.send (Encode.object [ ( "domain", Encode.string "navigation" ), ( "action", Encode.string "route" ), ( "url", Encode.string (Url.toString url) ), ( "scrollToTop", Encode.bool scrollToTop ) ])


initPage : Route -> Url -> ( Page, Cmd Msg )
initPage route url =
    case route of
        Home ->
            ( HomePage, Ports.send (Encode.object [ ( "domain", Encode.string "preview" ), ( "action", Encode.string "mount" ) ]) )

        Catalog ->
            ( CatalogPage, Cmd.none )

        About ->
            ( AboutPage, Cmd.none )

        NotFound ->
            ( NotFoundPage, Cmd.none )

        Project id subpage ->
            case id of
                Projects.Prompt ->
                    ( PlaceholderPage, Cmd.none )

                Projects.Flow ->
                    Flow.init (Url.toString url) |> Tuple.mapBoth FlowPage (Cmd.map FlowMsg)

                Projects.Robot ->
                    Robot.init |> Tuple.mapBoth RobotPage (Cmd.map RobotMsg)

                Projects.Falling ->
                    Falling.init |> Tuple.mapBoth FallingPage (Cmd.map FallingMsg)

                Projects.Nato ->
                    Nato.init |> Tuple.mapBoth NatoPage (Cmd.map NatoMsg)

                Projects.Morse ->
                    Morse.init subpage |> Tuple.mapBoth MorsePage (Cmd.map MorseMsg)

                Projects.Diff ->
                    Diff.init |> Tuple.mapBoth DiffPage (Cmd.map DiffMsg)

                Projects.Screen ->
                    Screen.init |> Tuple.mapBoth ScreenPage (Cmd.map ScreenMsg)

                Projects.Illusion ->
                    Illusions.init |> Tuple.mapBoth IllusionsPage (Cmd.map IllusionsMsg)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.page ) of
        ( LinkClicked (Browser.Internal url), _ ) ->
            if url == model.url then
                ( model, Cmd.none )

            else
                ( { model | scrollToTop = True }, Nav.pushUrl model.key (Url.toString url) )

        ( LinkClicked (Browser.External url), _ ) ->
            ( model, Nav.load url )

        ( UrlChanged url, _ ) ->
            let
                route =
                    routeFromUrl url

                ( page, _ ) =
                    initPage route url
            in
            ( { model | url = url, route = route, page = page, scrollToTop = False }, lifecycle url model.scrollToTop )

        ( Received value, _ ) ->
            case Decode.decodeValue (Decode.map2 Tuple.pair (Decode.field "domain" Decode.string) (Decode.field "url" Decode.string)) value of
                Ok ( "navigation", url ) ->
                    if url == Url.toString model.url then
                        let
                            ( page, cmd ) =
                                initPage model.route model.url
                        in
                        ( { model | page = page }, cmd )

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( DiscoveryMsg childMsg, _ ) ->
            let
                ( discovery, cmd, destination ) =
                    Discovery.update childMsg model.discovery
            in
            ( { model | discovery = discovery, scrollToTop = model.scrollToTop || destination /= Nothing }, Cmd.batch [ Cmd.map DiscoveryMsg cmd, Maybe.map (Projects.href >> Nav.pushUrl model.key) destination |> Maybe.withDefault Cmd.none ] )

        ( DeployMsg childMsg, _ ) ->
            let
                ( deploy, cmd ) =
                    Deploy.update childMsg model.deploy
            in
            ( { model | deploy = deploy }, Cmd.map DeployMsg cmd )

        ( FlowMsg childMsg, FlowPage childModel ) ->
            let
                ( page, cmd ) =
                    Flow.update childMsg childModel
            in
            ( { model | page = FlowPage page }, Cmd.map FlowMsg cmd )

        ( RobotMsg childMsg, RobotPage childModel ) ->
            let
                ( page, cmd ) =
                    Robot.update childMsg childModel
            in
            ( { model | page = RobotPage page }, Cmd.map RobotMsg cmd )

        ( FallingMsg childMsg, FallingPage childModel ) ->
            let
                ( page, cmd ) =
                    Falling.update childMsg childModel
            in
            ( { model | page = FallingPage page }, Cmd.map FallingMsg cmd )

        ( NatoMsg childMsg, NatoPage childModel ) ->
            let
                ( page, cmd ) =
                    Nato.update childMsg childModel
            in
            ( { model | page = NatoPage page }, Cmd.map NatoMsg cmd )

        ( MorseMsg childMsg, MorsePage childModel ) ->
            let
                ( page, cmd ) =
                    Morse.update childMsg childModel
            in
            ( { model | page = MorsePage page }, Cmd.map MorseMsg cmd )

        ( DiffMsg childMsg, DiffPage childModel ) ->
            let
                ( page, cmd ) =
                    Diff.update childMsg childModel
            in
            ( { model | page = DiffPage page }, Cmd.map DiffMsg cmd )

        ( ScreenMsg childMsg, ScreenPage childModel ) ->
            let
                ( page, cmd ) =
                    Screen.update childMsg childModel
            in
            ( { model | page = ScreenPage page }, Cmd.map ScreenMsg cmd )

        ( IllusionsMsg childMsg, IllusionsPage childModel ) ->
            let
                ( page, cmd ) =
                    Illusions.update childMsg childModel
            in
            ( { model | page = IllusionsPage page }, Cmd.map IllusionsMsg cmd )

        _ ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.receive Received
        , Sub.map DiscoveryMsg (Discovery.subscriptions model.discovery)
        , Sub.map DeployMsg (Deploy.subscriptions model.deploy)
        , case model.page of
            FlowPage page ->
                Sub.map FlowMsg (Flow.subscriptions page)

            RobotPage page ->
                Sub.map RobotMsg (Robot.subscriptions page)

            FallingPage page ->
                Sub.map FallingMsg (Falling.subscriptions page)

            NatoPage page ->
                Sub.map NatoMsg (Nato.subscriptions page)

            MorsePage page ->
                Sub.map MorseMsg (Morse.subscriptions page)

            DiffPage page ->
                Sub.map DiffMsg (Diff.subscriptions page)

            ScreenPage page ->
                Sub.map ScreenMsg (Screen.subscriptions page)

            IllusionsPage page ->
                Sub.map IllusionsMsg (Illusions.subscriptions page)

            _ ->
                Sub.none
        ]


view : Model -> Browser.Document Msg
view model =
    { title =
        case model.route of
            Home ->
                "≠ ulik.no"

            Catalog ->
                "Prosjekter — ≠ ulik.no"

            About ->
                "Om — ≠ ulik.no"

            Project id _ ->
                (Projects.byId id).title ++ " — ≠ ulik.no"

            NotFound ->
                "Fant ikke siden — ≠ ulik.no"
    , body =
        [ div [ class "layout" ]
            [ header [ class "shell-header" ]
                [ nav [ attribute "aria-label" "Hovednavigasjon" ]
                    [ a [ href "/", class "logo", attribute "aria-label" "ulik.no hjem" ] [ text "≠" ]
                    , div [ class "nav-links" ]
                        [ navLink "/" "~/hjem" (model.route == Home)
                        , navLink "/projects" "~/prosjekter" (String.startsWith "/projects" model.url.path)
                        , navLink "/om" "~/om" (model.route == About)
                        ]
                    ]
                ]
            , main_ []
                [ viewPage model
                , case model.route of
                    Project id _ ->
                        Html.map DiscoveryMsg (Discovery.onward id)

                    _ ->
                        text ""
                ]
            , footer [ class "shell-footer" ] [ span [] [ text ("≠ ulik.no — " ++ model.version) ], Html.map DeployMsg (Deploy.view model.deploy) ]
            ]
        ]
    }


navLink : String -> String -> Bool -> Html msg
navLink destination label active =
    a
        ([ href destination, classList [ ( "menu-link", True ), ( "active", active ) ] ]
            ++ (if active then
                    [ attribute "aria-current" "page" ]

                else
                    []
               )
        )
        [ text label ]


viewPage : Model -> Html Msg
viewPage model =
    case model.page of
        HomePage ->
            Html.map DiscoveryMsg (Discovery.viewHome model.discovery)

        CatalogPage ->
            Html.map DiscoveryMsg (Discovery.viewCatalog model.discovery)

        AboutPage ->
            div [ class "about-page" ] [ section [ class "terminal-panel about" ] [ p [ class "prompt" ] [ text "$ cat ./om.txt" ], h1 [] [ text "Om" ], p [] [ text "Her samler jeg prototyper, verktøy og idéer som lukter litt kode, kanskje litt språkmodell og litt ren nysgjerrighet." ], p [] [ text "Målet med ulik.no er å være et eksperimentrom for små prosjekter, AI-testing og ting som ikke passer inn andre steder." ] ] ]

        PlaceholderPage ->
            placeholder

        NotFoundPage ->
            section [ class "terminal-panel" ] [ h1 [] [ text "Fant ikke siden" ], a [ href "/projects" ] [ text "Se alle prosjekter" ] ]

        FlowPage page ->
            Html.map FlowMsg (Flow.view page)

        RobotPage page ->
            Html.map RobotMsg (Robot.view page)

        FallingPage page ->
            Html.map FallingMsg (Falling.view page)

        NatoPage page ->
            Html.map NatoMsg (Nato.view page)

        MorsePage page ->
            Html.map MorseMsg (Morse.view page)

        DiffPage page ->
            Html.map DiffMsg (Diff.view page)

        ScreenPage page ->
            Html.map ScreenMsg (Screen.view page)

        IllusionsPage page ->
            Html.map IllusionsMsg (Illusions.view page)


placeholder : Html msg
placeholder =
    div [ class "placeholder-page" ]
        [ section [ class "terminal-panel project-page" ]
            [ p [ class "prompt" ] [ text "$ cat ./prosjekter/prompt-lab/status.log" ]
            , div [ class "project-head" ] [ h1 [] [ text "prompt≠lab" ], span [ class "status wip" ] [ text "under arbeid" ] ]
            , p [ class "description" ] [ text "Eksperimenter med AI-prompts og se hva som skjer." ]
            , div [ class "tags" ] (List.map (\tag -> span [] [ text ("[" ++ tag ++ "]") ]) [ "ai", "llm", "prompting" ])
            ]
        , section [ class "terminal-panel construction" ] [ p [ class "prompt" ] [ text "$ tail -f deploy.log" ], div [ class "notice" ] [ span [ class "signal", attribute "aria-hidden" "true" ] [ text "≠" ], div [] [ h2 [] [ text "Under konstruksjon" ], p [] [ text "Denne prosjektsiden er på vei opp. Inntil videre er prosjektet trygt parkert i terminalkøen." ] ] ] ]
        ]
