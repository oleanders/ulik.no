module Pages.Robot exposing (Model, Msg(..), Status(..), init, subscriptions, update, view)

import Browser.Events
import Html exposing (Html, button, div, h1, p, section, span, strong, text)
import Html.Attributes exposing (attribute, class, classList, disabled, id, tabindex, type_)
import Html.Events exposing (custom, on, onClick)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports


type Status
    = Starting
    | Ready
    | Failed String


type alias Model =
    { status : Status
    , running : Bool
    , reducedMotion : Bool
    , keys : List String
    , touchKey : Maybe String
    }


type Msg
    = KeyDown String
    | KeyUp String
    | TouchDown String
    | TouchUp
    | ToggleRunning
    | Reset
    | Received Decode.Value


init : ( Model, Cmd Msg )
init =
    ( { status = Starting, running = False, reducedMotion = False, keys = [], touchKey = Nothing }
    , command "mount" Encode.null
    )


command : String -> Encode.Value -> Cmd Msg
command action data =
    Ports.send (Encode.object [ ( "domain", Encode.string "robot" ), ( "action", Encode.string action ), ( "data", data ) ])


sendInput : Model -> Cmd Msg
sendInput model =
    command "input" (Encode.list Encode.string (model.keys ++ Maybe.withDefault [] (Maybe.map List.singleton model.touchKey)))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        KeyDown key ->
            if List.member key model.keys then
                ( model, Cmd.none )

            else
                let
                    next =
                        { model | keys = key :: model.keys }
                in
                ( next, sendInput next )

        KeyUp key ->
            let
                next =
                    { model | keys = List.filter ((/=) key) model.keys }
            in
            ( next, sendInput next )

        TouchDown key ->
            let
                next =
                    { model | touchKey = Just key }
            in
            ( next, sendInput next )

        TouchUp ->
            let
                next =
                    { model | touchKey = Nothing }
            in
            ( next, sendInput next )

        ToggleRunning ->
            let
                next =
                    { model | running = not model.running, keys = [], touchKey = Nothing }
            in
            ( next, Cmd.batch [ command "running" (Encode.bool next.running), sendInput next ] )

        Reset ->
            ( { model | keys = [], touchKey = Nothing }, command "reset" Encode.null )

        Received event ->
            case Decode.decodeValue eventDecoder event of
                Ok ( "ready", data ) ->
                    let
                        reduced =
                            Decode.decodeValue Decode.bool data |> Result.withDefault False
                    in
                    ( { model | status = Ready, running = not reduced, reducedMotion = reduced }, command "running" (Encode.bool (not reduced)) )

                Ok ( "motion", data ) ->
                    let
                        reduced =
                            Decode.decodeValue Decode.bool data |> Result.withDefault False
                    in
                    ( { model | reducedMotion = reduced, running = model.running && not reduced }
                    , if reduced then
                        command "running" (Encode.bool False)

                      else
                        Cmd.none
                    )

                Ok ( "clearKeys", _ ) ->
                    let
                        next =
                            { model | keys = [], touchKey = Nothing }
                    in
                    ( next, sendInput next )

                Ok ( "releaseTouch", _ ) ->
                    update TouchUp model

                Ok ( "error", data ) ->
                    ( { model | status = Failed (Decode.decodeValue Decode.string data |> Result.withDefault "Nettleseren kunne ikke starte 3D-verdenen."), running = False }, Cmd.none )

                _ ->
                    ( model, Cmd.none )


eventDecoder : Decode.Decoder ( String, Decode.Value )
eventDecoder =
    Decode.field "domain" Decode.string
        |> Decode.andThen
            (\domain ->
                if domain == "robot" then
                    Decode.map2 Tuple.pair (Decode.field "action" Decode.string) (Decode.field "data" Decode.value)

                else
                    Decode.fail "Event belongs to another page"
            )


keyDecoder : Decode.Decoder String
keyDecoder =
    Decode.map2 Tuple.pair
        (Decode.field "key" Decode.string |> Decode.map String.toLower)
        (Decode.oneOf [ Decode.at [ "target", "tagName" ] Decode.string, Decode.succeed "" ])
        |> Decode.andThen
            (\( key, tag ) ->
                if List.member key [ "w", "a", "s", "d", "arrowup", "arrowleft", "arrowdown", "arrowright" ] && not (List.member tag [ "INPUT", "TEXTAREA", "SELECT" ]) then
                    Decode.succeed key

                else
                    Decode.fail "Not a robot control"
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch [ Ports.receive Received, Browser.Events.onKeyDown (Decode.map KeyDown keyDecoder), Browser.Events.onKeyUp (Decode.map KeyUp keyDecoder) ]


view : Model -> Html Msg
view model =
    let
        ready =
            model.status == Ready

        status =
            case model.status of
                Starting ->
                    "starter"

                Ready ->
                    if model.running then
                        "aktiv"

                    else
                        "på pause"

                Failed _ ->
                    "utilgjengelig"
    in
    div [ class "robot-page" ]
        [ section [ class "terminal-panel head" ]
            [ p [ class "prompt" ] [ text "$ ./robot-tohjul --simuler" ]
            , div [ class "head-row" ] [ h1 [] [ text "robot≠tohjul" ], span [ classList [ ( "status", True ), ( "active", ready && model.running ) ] ] [ text status ] ]
            , p [ class "desc" ]
                [ text "Styr roboten med ", strong [] [ text "WASD" ], text " eller piltaster. Den kjører på to hjul i en liten 3D-verden med hindringer. Treffer den en boks, krasjer den, rister, velter bakover, spretter rundt og kjører videre i tilfeldig retning." ]
            ]
        , div [ class "world terminal-panel", id "robot-world", tabindex 0, attribute "role" "group", attribute "aria-label" "Robotens 3D-verden. Bruk WASD, piltaster eller knappene under for å kjøre." ] []
        , div [ class "robot-controls", attribute "aria-label" "Styr roboten" ]
            [ button [ type_ "button", disabled (not ready), onClick ToggleRunning ]
                [ text
                    (if model.running then
                        "pause"

                     else
                        "spill av"
                    )
                ]
            , button [ type_ "button", disabled (not ready), onClick Reset ] [ text "start på nytt" ]
            , directionButton model "w" "↑" "Kjør framover (W)"
            , directionButton model "s" "↓" "Rygg (S)"
            , directionButton model "a" "←" "Sving til venstre (A)"
            , directionButton model "d" "→" "Sving til høyre (D)"
            ]
        , if model.reducedMotion then
            p [ class "motion-note" ] [ text "Redusert bevegelse er valgt. Verdenen starter stille; spill av når du vil." ]

          else
            text ""
        , case model.status of
            Failed message ->
                p [ class "error", attribute "role" "status" ] [ text message ]

            _ ->
                text ""
        ]


directionButton : Model -> String -> String -> String -> Html Msg
directionButton model key glyph description =
    button
        [ type_ "button"
        , class "direction"
        , disabled (not model.running)
        , attribute "aria-label" description
        , attribute "aria-pressed"
            (if model.touchKey == Just key || List.member key model.keys then
                "true"

             else
                "false"
            )
        , custom "pointerdown" (Decode.succeed { message = TouchDown key, stopPropagation = False, preventDefault = True })
        , on "pointerup" (Decode.succeed TouchUp)
        , on "pointerleave" (Decode.succeed TouchUp)
        , on "pointercancel" (Decode.succeed TouchUp)
        , on "keydown"
            (Decode.field "key" Decode.string
                |> Decode.andThen
                    (\pressed ->
                        if pressed == " " || pressed == "Enter" then
                            Decode.succeed (TouchDown key)

                        else
                            Decode.fail "Not a button key"
                    )
            )
        , on "keyup" (Decode.succeed TouchUp)
        , on "blur" (Decode.succeed TouchUp)
        ]
        [ text glyph ]
