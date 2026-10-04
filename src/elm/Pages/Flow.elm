module Pages.Flow exposing (Control(..), Model, Msg(..), Playback(..), Preset(..), init, subscriptions, update, view)

import Char
import Html exposing (Html, button, canvas, div, fieldset, h1, input, label, legend, output, p, section, small, span, text)
import Html.Attributes as Attributes exposing (attribute, class, classList, disabled, for, id, readonly, step, style, tabindex, type_, value)
import Html.Events exposing (custom, onClick, onInput)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports
import Url
import Url.Builder


type Preset
    = Nordlys
    | Virvel
    | Glod


type Playback
    = Starting
    | Playing
    | Paused
    | Unavailable


type Control
    = Speed
    | Density
    | Attraction
    | Hue


type alias Config =
    { preset : Preset, seed : Int, speed : Float, density : Int, attraction : Float, hue : Int }


type alias Model =
    { config : Config
    , playback : Playback
    , reducedMotion : Bool
    , message : String
    , shareUrl : String
    , shareBase : String
    , exporting : Bool
    , pointer : { x : Float, y : Float }
    , keyboardActive : Bool
    }


type Msg
    = SelectPreset Preset
    | ChangeControl Control String
    | TogglePlayback
    | NewUniverse
    | Restart
    | Share
    | SavePng
    | SelectShare
    | Key String
    | Received Decode.Value


init : String -> ( Model, Cmd Msg )
init urlString =
    let
        url =
            Url.fromString urlString

        config =
            parseConfig (url |> Maybe.andThen .query |> Maybe.withDefault "")

        model =
            { config = config
            , playback = Starting
            , reducedMotion = False
            , message = ""
            , shareUrl = ""
            , shareBase = url |> Maybe.map (\u -> Url.toString { u | query = Nothing, fragment = Nothing }) |> Maybe.withDefault "/projects/flyt-felt"
            , exporting = False
            , pointer = { x = 0.5, y = 0.5 }
            , keyboardActive = False
            }
    in
    ( model, command "mount" (encodeConfig config) )


presetId : Preset -> String
presetId preset =
    case preset of
        Nordlys ->
            "nordlys"

        Virvel ->
            "virvel"

        Glod ->
            "glod"


presetName : Preset -> String
presetName preset =
    case preset of
        Nordlys ->
            "Nordlys"

        Virvel ->
            "Virvel"

        Glod ->
            "Glød"


presetDescription : Preset -> String
presetDescription preset =
    case preset of
        Nordlys ->
            "Rolige bånd i grønt og blått."

        Virvel ->
            "Kjølige strømmer rundt et stille sentrum."

        Glod ->
            "Varme, raske spor med mer uro."


presetConfig : Preset -> Int -> Config
presetConfig preset seed =
    case preset of
        Nordlys ->
            { preset = preset, seed = seed, speed = 0.75, density = 900, attraction = -1, hue = 145 }

        Virvel ->
            { preset = preset, seed = seed, speed = 1, density = 1200, attraction = 1, hue = 195 }

        Glod ->
            { preset = preset, seed = seed, speed = 1.5, density = 600, attraction = -0.5, hue = 5 }


limits : Control -> { minimum : Float, maximum : Float, increment : Float }
limits control =
    case control of
        Speed ->
            { minimum = 0.25, maximum = 2, increment = 0.05 }

        Density ->
            { minimum = 300, maximum = 1500, increment = 100 }

        Attraction ->
            { minimum = -2, maximum = 2, increment = 0.1 }

        Hue ->
            { minimum = 0, maximum = 359, increment = 1 }


boundedNumber : Control -> Float -> Float
boundedNumber control number =
    let
        range =
            limits control

        bounded =
            clamp range.minimum range.maximum number
    in
    toFloat (round ((range.minimum + toFloat (round ((bounded - range.minimum) / range.increment)) * range.increment) * 100)) / 100


{-| The URL contains only a small versioned configuration. Reject exponent notation,
oversized values and unknown versions before they reach the renderer.
-}
parseConfig : String -> Config
parseConfig query =
    let
        pairs =
            query
                |> String.split "&"
                |> List.filterMap
                    (\pair ->
                        case String.split "=" pair of
                            key :: remaining ->
                                let
                                    decode raw =
                                        Url.percentDecode (String.replace "+" " " raw) |> Maybe.withDefault raw
                                in
                                Just ( decode key, decode (String.join "=" remaining) )

                            _ ->
                                Nothing
                    )

        get key =
            pairs |> List.filter (Tuple.first >> (==) key) |> List.head |> Maybe.map Tuple.second

        preset =
            case get "preset" of
                Just "virvel" ->
                    Virvel

                Just "glod" ->
                    Glod

                _ ->
                    Nordlys

        defaults =
            presetConfig preset 20261002

        number key control fallback =
            get key
                |> Maybe.andThen validNumber
                |> Maybe.map (boundedNumber control)
                |> Maybe.withDefault fallback

        seed =
            get "seed"
                |> Maybe.andThen
                    (\raw ->
                        if validDigits 10 raw then
                            String.toInt raw

                        else
                            Nothing
                    )
                |> Maybe.andThen
                    (\n ->
                        if n >= 1 && n <= 4294967295 then
                            Just n

                        else
                            Nothing
                    )
                |> Maybe.withDefault defaults.seed
    in
    if String.length query > 1000 || (get "v" /= Nothing && get "v" /= Just "1") then
        presetConfig Nordlys 20261002

    else
        { preset = preset
        , seed = seed
        , speed = number "speed" Speed defaults.speed
        , density = round (number "density" Density (toFloat defaults.density))
        , attraction = number "attraction" Attraction defaults.attraction
        , hue = round (number "hue" Hue (toFloat defaults.hue))
        }


validDigits : Int -> String -> Bool
validDigits maximum raw =
    not (String.isEmpty raw) && String.length raw <= maximum && String.all Char.isDigit raw


validNumber : String -> Maybe Float
validNumber raw =
    let
        unsigned =
            if String.startsWith "-" raw then
                String.dropLeft 1 raw

            else
                raw

        valid =
            case String.split "." unsigned of
                [ whole ] ->
                    validDigits 10 whole

                [ whole, fraction ] ->
                    validDigits 10 whole && validDigits 4 fraction

                _ ->
                    False
    in
    if valid then
        String.toFloat raw

    else
        Nothing


encodeConfig : Config -> Encode.Value
encodeConfig config =
    Encode.object
        [ ( "preset", Encode.string (presetId config.preset) )
        , ( "seed", Encode.int config.seed )
        , ( "speed", Encode.float config.speed )
        , ( "density", Encode.int config.density )
        , ( "attraction", Encode.float config.attraction )
        , ( "hue", Encode.int config.hue )
        ]


command : String -> Encode.Value -> Cmd Msg
command action data =
    Ports.send (Encode.object [ ( "domain", Encode.string "flow" ), ( "action", Encode.string action ), ( "data", data ) ])


configure : Config -> Model -> ( Model, Cmd Msg )
configure config model =
    ( { model | config = config, shareUrl = "", message = "", keyboardActive = False }
    , command "configure" (encodeConfig config)
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SelectPreset preset ->
            configure (presetConfig preset model.config.seed) model

        ChangeControl control raw ->
            case String.toFloat raw of
                Nothing ->
                    ( model, Cmd.none )

                Just number ->
                    let
                        bounded =
                            boundedNumber control number

                        config =
                            model.config

                        next =
                            case control of
                                Speed ->
                                    { config | speed = bounded }

                                Density ->
                                    { config | density = round bounded }

                                Attraction ->
                                    { config | attraction = bounded }

                                Hue ->
                                    { config | hue = round bounded }
                    in
                    configure next model

        TogglePlayback ->
            if model.playback == Starting || model.playback == Unavailable then
                ( model, Cmd.none )

            else
                let
                    running =
                        model.playback /= Playing
                in
                ( { model
                    | playback =
                        if running then
                            Playing

                        else
                            Paused
                  }
                , command "running" (Encode.bool running)
                )

        NewUniverse ->
            ( model, command "newSeed" (Encode.int model.config.seed) )

        Restart ->
            ( { model | pointer = { x = 0.5, y = 0.5 }, keyboardActive = False, message = "Samme univers, tilbake til starten." }
            , command "restart" Encode.null
            )

        Share ->
            let
                config =
                    model.config

                url =
                    model.shareBase
                        ++ Url.Builder.toQuery
                            [ Url.Builder.string "v" "1"
                            , Url.Builder.string "preset" (presetId config.preset)
                            , Url.Builder.int "seed" config.seed
                            , Url.Builder.string "speed" (String.fromFloat config.speed)
                            , Url.Builder.int "density" config.density
                            , Url.Builder.string "attraction" (String.fromFloat config.attraction)
                            , Url.Builder.int "hue" config.hue
                            ]
            in
            ( { model | shareUrl = url }, command "share" (Encode.string url) )

        SavePng ->
            if model.exporting || model.playback == Starting || model.playback == Unavailable then
                ( model, Cmd.none )

            else
                ( { model | exporting = True }
                , command "png" (Encode.string ("flyt-felt-" ++ presetId model.config.preset ++ "-" ++ String.fromInt model.config.seed ++ ".png"))
                )

        SelectShare ->
            ( model, command "selectShare" Encode.null )

        Key key ->
            case key of
                " " ->
                    update TogglePlayback model

                "Escape" ->
                    ( { model | keyboardActive = False }, command "clearPointer" Encode.null )

                _ ->
                    let
                        ( dx, dy ) =
                            case key of
                                "ArrowLeft" ->
                                    ( -0.05, 0 )

                                "ArrowRight" ->
                                    ( 0.05, 0 )

                                "ArrowUp" ->
                                    ( 0, -0.05 )

                                "ArrowDown" ->
                                    ( 0, 0.05 )

                                _ ->
                                    ( 0, 0 )

                        pointer =
                            { x = clamp 0 1 (model.pointer.x + dx), y = clamp 0 1 (model.pointer.y + dy) }
                    in
                    if dx == 0 && dy == 0 then
                        ( model, Cmd.none )

                    else
                        ( { model | pointer = pointer, keyboardActive = True }
                        , command "pointer" (Encode.object [ ( "x", Encode.float pointer.x ), ( "y", Encode.float pointer.y ) ])
                        )

        Received event ->
            case Decode.decodeValue eventDecoder event of
                Err _ ->
                    ( model, Cmd.none )

                Ok ( action, data ) ->
                    receive action data model


receive : String -> Decode.Value -> Model -> ( Model, Cmd Msg )
receive action data model =
    case action of
        "ready" ->
            let
                reduced =
                    Decode.decodeValue Decode.bool data |> Result.withDefault False
            in
            ( { model
                | playback =
                    if reduced then
                        Paused

                    else
                        Playing
                , reducedMotion = reduced
              }
            , command "running" (Encode.bool (not reduced))
            )

        "motion" ->
            let
                reduced =
                    Decode.decodeValue Decode.bool data |> Result.withDefault False
            in
            ( { model
                | reducedMotion = reduced
                , playback =
                    if reduced then
                        Paused

                    else
                        model.playback
              }
            , if reduced then
                command "running" (Encode.bool False)

              else
                Cmd.none
            )

        "pointerUsed" ->
            ( { model | keyboardActive = False }, Cmd.none )

        "seed" ->
            case Decode.decodeValue Decode.int data of
                Err _ ->
                    ( model, Cmd.none )

                Ok seed ->
                    let
                        config =
                            model.config
                    in
                    configure { config | seed = seed } { model | message = "" }
                        |> Tuple.mapFirst (\next -> { next | message = "Et nytt univers er klart." })

        "shared" ->
            ( { model | message = Decode.decodeValue Decode.string data |> Result.withDefault "Kopier lenken fra feltet under." }, Cmd.none )

        "exported" ->
            ( { model | exporting = False, message = Decode.decodeValue Decode.string data |> Result.withDefault "Kunne ikke lage bildet. Prøv igjen." }, Cmd.none )

        "error" ->
            ( { model | playback = Unavailable, message = Decode.decodeValue Decode.string data |> Result.withDefault "Nettleseren kunne ikke starte lerretet. Prøv en annen nettleser." }, Cmd.none )

        _ ->
            ( model, Cmd.none )


eventDecoder : Decode.Decoder ( String, Decode.Value )
eventDecoder =
    Decode.field "domain" Decode.string
        |> Decode.andThen
            (\domain ->
                if domain == "flow" then
                    Decode.map2 Tuple.pair (Decode.field "action" Decode.string) (Decode.field "data" Decode.value)

                else
                    Decode.fail "Event belongs to another page"
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Ports.receive Received


view : Model -> Html Msg
view model =
    let
        ready =
            model.playback == Playing || model.playback == Paused

        running =
            model.playback == Playing

        name =
            presetName model.config.preset

        status =
            case model.playback of
                Starting ->
                    "starter"

                Playing ->
                    "i bevegelse"

                Paused ->
                    "på pause"

                Unavailable ->
                    "utilgjengelig"
    in
    div [ class "flow-page" ]
        [ section [ class "head", attribute "aria-labelledby" "flow-title" ]
            [ p [ class "prompt" ] [ text "$ ./flyt-felt --utforsk" ]
            , div [ class "head-row" ] [ h1 [ id "flow-title" ] [ text "flyt≠felt" ], span [ classList [ ( "status", True ), ( "active", ready && running ) ] ] [ text status ] ]
            , p [ class "desc" ] [ text "Små partikler. Egne veier. Velg en stemning, form strømmen og ta vare på et øyeblikk." ]
            ]
        , section [ class "studio", attribute "aria-label" "Ditt flytfelt" ]
            [ div [ class "canvas-wrap", id "flow-wrapper" ]
                [ canvas [ id "flow-canvas", tabindex 0, attribute "aria-label" ("Flytfelt: " ++ name), attribute "aria-describedby" "flow-help", canvasKeyboard ]
                    [ text "Et generativt bilde av fargede partikler. Nettleseren må støtte canvas for å vise det." ]
                , if model.keyboardActive then
                    span [ class "keyboard-pointer", attribute "aria-hidden" "true", style "left" (String.fromFloat (model.pointer.x * 100) ++ "%"), style "top" (String.fromFloat (model.pointer.y * 100) ++ "%") ] []

                  else
                    text ""
                ]
            , div [ class "canvas-footer" ]
                [ span [] [ text (name ++ " / seed "), span [ attribute "data-testid" "flow-seed" ] [ text (String.fromInt model.config.seed) ] ]
                , span [] [ text (String.fromInt model.config.density ++ " partikler · lokalt i nettleseren") ]
                ]
            , div [ class "toolbar" ]
                [ button [ type_ "button", class "primary", disabled (not ready), onClick TogglePlayback ]
                    [ text
                        (if running then
                            "pause"

                         else
                            "spill av"
                        )
                    ]
                , button [ type_ "button", disabled (not ready), onClick NewUniverse ] [ text "nytt univers" ]
                , button [ type_ "button", disabled (not ready), onClick Restart ] [ text "start på nytt" ]
                , button [ type_ "button", disabled (not ready || model.exporting), onClick SavePng ]
                    [ text
                        (if model.exporting then
                            "lager bilde …"

                         else
                            "lagre PNG"
                        )
                    ]
                , button [ type_ "button", disabled (not ready), onClick Share ] [ text "del univers" ]
                ]
            , p [ class "help", id "flow-help" ] [ text "Beveg pekeren eller dra én finger over bildet. Med tastatur: fokuser bildet og bruk piltastene. Mellomrom pauser, Esc slipper feltet. Du kan rulle siden utenfor bildet." ]
            , if model.reducedMotion then
                p [ class "motion-note" ] [ text "Redusert bevegelse er valgt. Bildet starter stille; spill av når du vil." ]

              else
                text ""
            ]
        , section [ class "terminal-panel settings", attribute "aria-label" "Innstillinger for flytfelt" ]
            [ fieldset [ class "presets" ]
                [ legend [] [ text "01 / velg en stemning" ]
                , div [ class "preset-grid" ] (List.map (presetButton model.config.preset) [ Nordlys, Virvel, Glod ])
                ]
            , fieldset [ class "adjustments" ]
                [ legend [] [ text "02 / finn din flyt" ]
                , div [ class "slider-grid" ]
                    [ slider Speed "flow-speed" "Fart" (fixed 2 model.config.speed ++ "×") "rolig → rask" model.config.speed
                    , slider Density "flow-density" "Tetthet" (String.fromInt model.config.density) "luftig → tett" (toFloat model.config.density)
                    , slider Attraction "flow-attraction" "Tiltrekning" (fixed 1 model.config.attraction) "dytt ← 0 → trekk, ved pekeren" model.config.attraction
                    , slider Hue "flow-hue" "Fargetone" (String.fromInt model.config.hue ++ "°") "hele fargesirkelen" (toFloat model.config.hue)
                    ]
                ]
            , div [ class "settings-footer" ]
                [ p [] [ text "Endringer tegner universet fra starten. Seedet beholdes." ]
                , button [ type_ "button", onClick (SelectPreset model.config.preset) ] [ text "nullstill innstillinger" ]
                ]
            ]
        , div [ class "sharing" ]
            ([ p [ class "feedback", attribute "role" "status", attribute "aria-label" "Melding fra flytfelt" ] [ text model.message ] ]
                ++ (if String.isEmpty model.shareUrl then
                        []

                    else
                        [ label [ for "flow-share" ] [ text "Lenke til universet" ]
                        , input [ id "flow-share", type_ "url", readonly True, value model.shareUrl, onClick SelectShare ] []
                        , p [ class "help" ] [ text "Lenken inneholder bare innstillinger og seed. Bevegelsene dine og det ferdige bildet følger ikke med. Bruk PNG for å bevare akkurat dette øyeblikket." ]
                        ]
                   )
            )
        ]


presetButton : Preset -> Preset -> Html Msg
presetButton selected preset =
    button
        [ type_ "button"
        , class "preset"
        , attribute "aria-pressed"
            (if selected == preset then
                "true"

             else
                "false"
            )
        , onClick (SelectPreset preset)
        ]
        [ span [ class "preset-name" ] [ text (presetName preset) ], span [ class "preset-description" ] [ text (presetDescription preset) ] ]


slider : Control -> String -> String -> String -> String -> Float -> Html Msg
slider control inputId title formatted hint current =
    let
        range =
            limits control
    in
    label [ for inputId ]
        [ span [] [ text title, output [ for inputId ] [ text formatted ] ]
        , input [ id inputId, type_ "range", Attributes.min (String.fromFloat range.minimum), Attributes.max (String.fromFloat range.maximum), step (String.fromFloat range.increment), value (String.fromFloat current), onInput (ChangeControl control) ] []
        , small [] [ text hint ]
        ]


fixed : Int -> Float -> String
fixed places number =
    let
        scale =
            10 ^ places

        rounded =
            abs (round (number * toFloat scale))

        whole =
            String.fromInt (rounded // scale)

        fraction =
            String.padLeft places '0' (String.fromInt (modBy scale rounded))
    in
    (if number < 0 then
        "-"

     else
        ""
    )
        ++ whole
        ++ "."
        ++ fraction


canvasKeyboard : Html.Attribute Msg
canvasKeyboard =
    custom "keydown"
        (Decode.field "key" Decode.string
            |> Decode.map (\key -> { message = Key key, stopPropagation = False, preventDefault = List.member key [ " ", "ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown" ] })
        )
