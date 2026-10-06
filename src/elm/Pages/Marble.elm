module Pages.Marble exposing (Camera(..), Color(..), Model, Msg(..), Phase(..), Segment(..), init, subscriptions, update, view)

import Html exposing (Html, button, canvas, div, h1, h2, p, section, span, text)
import Html.Attributes exposing (attribute, class, disabled, id, type_)
import Html.Events exposing (onClick)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports


type Segment
    = Sweep
    | Spiral
    | Jump


type Camera
    = Overview
    | Follow


type Color
    = Coral
    | Mint
    | Violet


type Phase
    = Loading
    | Ready
    | Running
    | Finished
    | Failed String


type alias Model =
    { segments : List Segment
    , camera : Camera
    , color : Color
    , phase : Phase
    }


type Msg
    = CycleSegment Int
    | ChooseColor Color
    | ChooseCamera Camera
    | Launch
    | Reset
    | Received Decode.Value


init : ( Model, Cmd Msg )
init =
    let
        model =
            { segments = [ Sweep, Spiral, Jump ], camera = Overview, color = Coral, phase = Loading }
    in
    ( model, command "mount" model )


segmentName : Segment -> String
segmentName segment =
    case segment of
        Sweep ->
            "sweep"

        Spiral ->
            "spiral"

        Jump ->
            "jump"


colorName : Color -> String
colorName color =
    case color of
        Coral ->
            "coral"

        Mint ->
            "mint"

        Violet ->
            "violet"


command : String -> Model -> Cmd Msg
command action model =
    Ports.send
        (Encode.object
            [ ( "domain", Encode.string "marble" )
            , ( "action", Encode.string action )
            , ( "data"
              , Encode.object
                    [ ( "segments", Encode.list (segmentName >> Encode.string) model.segments )
                    , ( "camera"
                      , Encode.string
                            (if model.camera == Overview then
                                "overview"

                             else
                                "follow"
                            )
                      )
                    , ( "color", Encode.string (colorName model.color) )
                    ]
              )
            ]
        )


available : Model -> Bool
available model =
    case model.phase of
        Loading ->
            False

        Failed _ ->
            False

        _ ->
            True


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CycleSegment index ->
            if not (available model) || index < 0 || index >= List.length model.segments then
                ( model, Cmd.none )

            else
                let
                    cycle segment =
                        case segment of
                            Sweep ->
                                Spiral

                            Spiral ->
                                Jump

                            Jump ->
                                Sweep

                    next =
                        { model
                            | segments =
                                List.indexedMap
                                    (\i segment ->
                                        if i == index then
                                            cycle segment

                                        else
                                            segment
                                    )
                                    model.segments
                            , phase = Ready
                        }
                in
                ( next, command "configure" next )

        ChooseColor color ->
            if available model then
                let
                    next =
                        { model | color = color, phase = Ready }
                in
                ( next, command "configure" next )

            else
                ( model, Cmd.none )

        ChooseCamera camera ->
            if available model then
                let
                    next =
                        { model | camera = camera }
                in
                ( next, command "camera" next )

            else
                ( model, Cmd.none )

        Launch ->
            if available model && model.phase /= Running then
                ( { model | phase = Running }, command "launch" model )

            else
                ( model, Cmd.none )

        Reset ->
            if available model then
                ( { model | phase = Ready }, command "reset" model )

            else
                ( model, Cmd.none )

        Received value ->
            case Decode.decodeValue eventDecoder value of
                Ok ( "ready", _ ) ->
                    if model.phase == Loading then
                        ( { model | phase = Ready }, Cmd.none )

                    else
                        ( model, Cmd.none )

                Ok ( "finished", _ ) ->
                    if model.phase == Running then
                        ( { model | phase = Finished }, Cmd.none )

                    else
                        ( model, Cmd.none )

                Ok ( "error", message ) ->
                    ( { model | phase = Failed message }, Cmd.none )

                _ ->
                    ( model, Cmd.none )


eventDecoder : Decode.Decoder ( String, String )
eventDecoder =
    Decode.field "domain" Decode.string
        |> Decode.andThen
            (\domain ->
                if domain == "marble" then
                    Decode.map2 Tuple.pair
                        (Decode.field "action" Decode.string)
                        (Decode.oneOf [ Decode.field "message" Decode.string, Decode.succeed "Nettleseren kunne ikke vise 3D-banen. Prøv en nettleser med WebGL." ])

                else
                    Decode.fail "Event belongs to another page"
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Ports.receive Received


pressed : Bool -> Html.Attribute msg
pressed selected =
    attribute "aria-pressed"
        (if selected then
            "true"

         else
            "false"
        )


view : Model -> Html Msg
view model =
    div [ class "marble-page" ]
        [ section [ class "marble-heading" ]
            [ div [] [ p [ class "marble-eyebrow" ] [ text "ET LITE SIDESPOR / 3D" ], h1 [] [ text "kule≠bane" ] ]
            , p [] [ text "Banen er klar. Slipp kula, len deg tilbake. Eller bytt en bit og se hva som skjer." ]
            ]
        , section [ class "marble-studio", attribute "aria-label" "Kulebane" ]
            [ div [ class "marble-stage" ]
                [ canvas [ id "marble-canvas", attribute "aria-label" "3D-kulebane med blanke skinner og en glasskule. Bruk knappene under for å endre banen og starte." ] []
                , div [ class "marble-stage-label", attribute "aria-hidden" "true" ] [ span [] [ text "03 BITER / UENDELIG NYSGJERRIGHET" ], span [] [ text "↓ START → MÅL" ] ]
                , div [ class "marble-camera", attribute "role" "group", attribute "aria-label" "Kamera" ]
                    [ button [ type_ "button", onClick (ChooseCamera Overview), pressed (model.camera == Overview), disabled (not (available model)) ] [ text "Oversikt" ]
                    , button [ type_ "button", onClick (ChooseCamera Follow), pressed (model.camera == Follow), disabled (not (available model)) ] [ text "Følg kula" ]
                    ]
                ]
            , div [ class "marble-console" ]
                [ div [ class "marble-launch-row" ]
                    [ div [ class "marble-launch-buttons" ]
                        [ button [ type_ "button", class "marble-launch", disabled (not (available model) || model.phase == Running), onClick Launch ]
                            [ text
                                (if model.phase == Finished then
                                    "Slipp igjen ↗"

                                 else
                                    "Slipp kula ↗"
                                )
                            ]
                        , button [ type_ "button", class "marble-reset", disabled (not (available model)), onClick Reset ] [ text "Til start" ]
                        ]
                    , p [ class "marble-status", attribute "role" "status", attribute "aria-live" "polite" ]
                        [ text
                            (case model.phase of
                                Loading ->
                                    "Gjør banen klar …"

                                Ready ->
                                    "Alt passer. Klar når du er."

                                Running ->
                                    "På vei gjennom banen …"

                                Finished ->
                                    "I mål! En runde til?"

                                Failed message ->
                                    message
                            )
                        ]
                    ]
                , div [ class "marble-customize" ]
                    [ div [ class "marble-pieces" ]
                        [ h2 [] [ text "Bytt en bit" ]
                        , p [] [ text "Ett trykk bytter form. Endene passer alltid." ]
                        , div [ class "marble-slots" ] (List.indexedMap (slot model) model.segments)
                        ]
                    , div [ class "marble-colors" ]
                        [ h2 [] [ text "Din kule" ]
                        , div [ attribute "role" "group", attribute "aria-label" "Kulefarge" ]
                            (List.map (\( color, label ) -> button [ type_ "button", class ("marble-swatch " ++ colorName color), onClick (ChooseColor color), pressed (model.color == color), disabled (not (available model)), attribute "aria-label" label ] [ span [ attribute "aria-hidden" "true" ] [ text "●" ] ]) [ ( Coral, "Korall" ), ( Mint, "Mint" ), ( Violet, "Fiolett" ) ])
                        ]
                    ]
                ]
            ]
        , p [ class "marble-note" ] [ text "En leken, animert bane: kula følger et tegnet spor. Bytter du en bit eller farge, går kula tilbake til start. Ingen byggeregler å lære." ]
        ]


slot : Model -> Int -> Segment -> Html Msg
slot model index segment =
    let
        ( glyph, label ) =
            case segment of
                Sweep ->
                    ( "∿", "Sving" )

                Spiral ->
                    ( "◎", "Spiral" )

                Jump ->
                    ( "⌒", "Hopp" )
    in
    button [ type_ "button", class "marble-slot", onClick (CycleSegment index), disabled (not (available model)), attribute "aria-label" ("Bytt del " ++ String.fromInt (index + 1) ++ ": " ++ label) ]
        [ span [ class "marble-slot-number" ] [ text ("0" ++ String.fromInt (index + 1)) ]
        , span [ class "marble-slot-glyph", attribute "aria-hidden" "true" ] [ text glyph ]
        , span [] [ text label ]
        , span [ class "marble-slot-swap", attribute "aria-hidden" "true" ] [ text "↻" ]
        ]
