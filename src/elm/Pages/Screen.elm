module Pages.Screen exposing (Model, Msg(..), ShareState(..), init, subscriptions, update, view)

import Html exposing (Html, button, code, div, h1, input, label, p, section, span, text, video)
import Html.Attributes exposing (attribute, autoplay, checked, class, controls, disabled, id, property, type_)
import Html.Events exposing (onCheck, onClick)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports


type ShareState
    = Idle
    | Sharing
    | Error


type alias Model =
    { supported : Bool
    , shareState : ShareState
    , statusText : String
    , sourceLabel : String
    , includeAudio : Bool
    }


type Msg
    = Start
    | Stop
    | IncludeAudio Bool
    | Received Decode.Value


type BrowserEvent
    = Support Bool
    | Started String
    | Stopped
    | Failed String


init : ( Model, Cmd Msg )
init =
    ( { supported = False
      , shareState = Idle
      , statusText = "Trykk start for å velge skjerm, vindu eller fane."
      , sourceLabel = "Ingen aktiv kilde"
      , includeAudio = False
      }
    , send "screenSupport" []
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Start ->
            if model.supported && model.shareState /= Sharing then
                ( { model | shareState = Idle, sourceLabel = "Ingen aktiv kilde" }
                , send "screenStart" [ ( "audio", Encode.bool model.includeAudio ) ]
                )

            else
                ( model, Cmd.none )

        Stop ->
            ( { model | shareState = Idle, sourceLabel = "Ingen aktiv kilde" }
            , send "screenStop" []
            )

        IncludeAudio includeAudio ->
            ( { model | includeAudio = includeAudio }, Cmd.none )

        Received raw ->
            case Decode.decodeValue browserEventDecoder raw of
                Ok (Support supported) ->
                    ( { model | supported = supported }, Cmd.none )

                Ok (Started sourceLabel) ->
                    ( { model
                        | shareState = Sharing
                        , statusText = "Skjermdeling er aktiv."
                        , sourceLabel = sourceLabel
                      }
                    , Cmd.none
                    )

                Ok Stopped ->
                    ( { model
                        | shareState = Idle
                        , statusText = "Skjermdeling ble stoppet fra nettleseren."
                        , sourceLabel = "Ingen aktiv kilde"
                      }
                    , Cmd.none
                    )

                Ok (Failed message) ->
                    ( { model | shareState = Error, statusText = message, sourceLabel = "Ingen aktiv kilde" }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )


send : String -> List ( String, Encode.Value ) -> Cmd Msg
send action fields =
    Ports.send
        (Encode.object
            (( "domain", Encode.string "tools" )
                :: ( "action", Encode.string action )
                :: fields
            )
        )


browserEventDecoder : Decode.Decoder BrowserEvent
browserEventDecoder =
    Decode.field "domain" Decode.string
        |> Decode.andThen
            (\domain ->
                if domain == "screen" then
                    Decode.field "action" Decode.string |> Decode.andThen eventDecoder

                else
                    Decode.fail "Not a screen event"
            )


eventDecoder : String -> Decode.Decoder BrowserEvent
eventDecoder action =
    case action of
        "support" ->
            Decode.map Support (Decode.field "supported" Decode.bool)

        "started" ->
            Decode.map Started (Decode.field "sourceLabel" Decode.string)

        "stopped" ->
            Decode.succeed Stopped

        "error" ->
            Decode.map Failed (Decode.field "message" Decode.string)

        _ ->
            Decode.fail "Unknown screen event"


subscriptions : Model -> Sub Msg
subscriptions _ =
    Ports.receive Received


stateClass : ShareState -> String
stateClass state =
    case state of
        Idle ->
            "idle"

        Sharing ->
            "sharing"

        Error ->
            "error"


view : Model -> Html Msg
view model =
    let
        sharing =
            model.shareState == Sharing

        state =
            stateClass model.shareState
    in
    div [ class "screen-page" ]
        [ section [ class "terminal-panel head" ]
            [ p [ class "prompt" ] [ text "$ ./skjermdeling-lab --start" ]
            , div [ class "head-row" ]
                [ h1 [] [ text "skjerm≠deling" ]
                , span [ class ("status " ++ state) ]
                    [ text
                        (if sharing then
                            "aktiv"

                         else
                            "klar"
                        )
                    ]
                ]
            , p [ class "description" ]
                [ text "En enkel testlab for skjermdeling i nettleseren med "
                , code [] [ text "navigator.mediaDevices.getDisplayMedia" ]
                , text "."
                ]
            ]
        , section [ class "terminal-panel controls" ]
            [ p [ class "prompt" ] [ text "$ getdisplaymedia --preview" ]
            , div [ class "actions" ]
                [ button [ type_ "button", onClick Start, disabled (not model.supported || sharing) ] [ text "Start skjermdeling" ]
                , button [ type_ "button", class "ghost", onClick Stop, disabled (not sharing) ] [ text "Stopp" ]
                ]
            , label [ class "option" ]
                [ input [ type_ "checkbox", checked model.includeAudio, onCheck IncludeAudio, disabled sharing ] []
                , text "Del systemlyd hvis tilgjengelig"
                ]
            , p [ class ("status-line " ++ state), attribute "role" "status" ] [ text model.statusText ]
            , p [ class "source" ] [ text ("Kilde: " ++ model.sourceLabel) ]
            , div
                [ class "preview"
                , attribute "data-active"
                    (if sharing then
                        "true"

                     else
                        "false"
                    )
                ]
                [ video
                    [ id "screen-preview"
                    , autoplay True
                    , attribute "playsinline" ""
                    , property "muted" (Encode.bool True)
                    , controls sharing
                    ]
                    []
                ]
            ]
        ]
