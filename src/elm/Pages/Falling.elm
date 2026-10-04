module Pages.Falling exposing (Model, Msg(..), Phase(..), init, subscriptions, update, view)

import Html exposing (Html, button, div, h1, p, section, span, text)
import Html.Attributes exposing (attribute, class, disabled, type_)
import Html.Events exposing (onClick)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports


type Phase
    = Dropping
    | Settled
    | Restored


type alias Model =
    { phase : Phase, cloneCount : Int }


type Msg
    = Drop
    | Reset
    | Received Decode.Value


init : ( Model, Cmd Msg )
init =
    ( { phase = Dropping, cloneCount = 0 }, command "mount" )


command : String -> Cmd Msg
command action =
    Ports.send (Encode.object [ ( "domain", Encode.string "falling" ), ( "action", Encode.string action ), ( "data", Encode.null ) ])


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Drop ->
            ( { model | phase = Dropping }, command "drop" )

        Reset ->
            ( { phase = Restored, cloneCount = 0 }, command "reset" )

        Received event ->
            case Decode.decodeValue eventDecoder event of
                Ok ( "reset", _ ) ->
                    update Reset model

                Ok ( "count", count ) ->
                    ( { model | cloneCount = count }, Cmd.none )

                Ok ( "settled", _ ) ->
                    ( { model | phase = Settled }, Cmd.none )

                _ ->
                    ( model, Cmd.none )


eventDecoder : Decode.Decoder ( String, Int )
eventDecoder =
    Decode.field "domain" Decode.string
        |> Decode.andThen
            (\domain ->
                if domain == "falling" then
                    Decode.map2 Tuple.pair (Decode.field "action" Decode.string) (Decode.field "data" Decode.int)

                else
                    Decode.fail "Event belongs to another page"
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Ports.receive Received


view : Model -> Html Msg
view model =
    div [ class "falling-page" ]
        [ section [ class "terminal-panel head" ]
            [ p [ class "prompt" ] [ text "$ ./fall-haug --slipp-alt" ]
            , div [ class "head-row" ] [ h1 [] [ text "fall≠ned" ], span [ class "status active" ] [ text "aktiv" ] ]
            , p [ class "desc" ] [ text "Denne versjonen slipper de faktiske elementene på siden: logo, meny, seksjoner, footer, og denne info-boksen ned." ]
            ]
        , section [ class "terminal-panel dock" ]
            [ div [ class "controls" ]
                [ button [ type_ "button", disabled (model.phase == Dropping), onClick Drop ]
                    [ text
                        (if model.phase == Dropping then
                            "slipper…"

                         else
                            "slipp alt igjen"
                        )
                    ]
                ]
            , p [ class "meta" ]
                [ text
                    (if model.cloneCount > 0 then
                        String.fromInt model.cloneCount ++ " elementer sluppet."

                     else
                        "forbereder slipp..."
                    )
                ]
            ]
        , div [ class "reset-wrap", attribute "data-no-fall" "" ] [ button [ type_ "button", class "reset-fixed", onClick Reset ] [ text "reset side" ] ]
        ]
