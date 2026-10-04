module Pages.Diff exposing (Change, Mode(..), Model, Msg(..), init, statistics, subscriptions, update, view)

import Html exposing (Html, button, div, h1, label, p, pre, section, span, text, textarea)
import Html.Attributes exposing (attribute, class, classList, placeholder, spellcheck, type_, value)
import Html.Events exposing (onClick, onInput)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports


type Mode
    = Lines
    | Words


type alias Change =
    { value : String
    , count : Int
    , added : Bool
    , removed : Bool
    }


type alias Model =
    { left : String
    , right : String
    , mode : Mode
    , changes : List Change
    , revision : Int
    }


type Msg
    = EditLeft String
    | EditRight String
    | SetMode Mode
    | Swap
    | Clear
    | Received Decode.Value


init : ( Model, Cmd Msg )
init =
    recompute
        { left = "# handleliste\nmelk\nbrød\negg\nkaffe\nsjokolade"
        , right = "# handleliste\nhavremelk\nbrød\negg\nkaffe\nte\nmørk sjokolade"
        , mode = Lines
        , changes = []
        , revision = 0
        }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        EditLeft input ->
            recompute { model | left = input }

        EditRight input ->
            recompute { model | right = input }

        SetMode mode ->
            recompute { model | mode = mode }

        Swap ->
            recompute { model | left = model.right, right = model.left }

        Clear ->
            recompute { model | left = "", right = "" }

        Received raw ->
            case Decode.decodeValue resultDecoder raw of
                Ok ( revision, changes ) ->
                    if revision == model.revision then
                        ( { model | changes = changes }, Cmd.none )

                    else
                        ( model, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )


recompute : Model -> ( Model, Cmd Msg )
recompute model =
    let
        revision =
            model.revision + 1
    in
    ( { model | revision = revision }
    , Ports.send
        (Encode.object
            [ ( "domain", Encode.string "tools" )
            , ( "action", Encode.string "diff" )
            , ( "revision", Encode.int revision )
            , ( "left", Encode.string model.left )
            , ( "right", Encode.string model.right )
            , ( "mode"
              , Encode.string
                    (case model.mode of
                        Lines ->
                            "lines"

                        Words ->
                            "words"
                    )
              )
            ]
        )
    )


resultDecoder : Decode.Decoder ( Int, List Change )
resultDecoder =
    Decode.field "domain" Decode.string
        |> Decode.andThen
            (\domain ->
                if domain == "diff" then
                    Decode.map2 Tuple.pair
                        (Decode.field "revision" Decode.int)
                        (Decode.field "changes" (Decode.list changeDecoder))

                else
                    Decode.fail "Not a diff result"
            )


changeDecoder : Decode.Decoder Change
changeDecoder =
    Decode.map4 Change
        (Decode.field "value" Decode.string)
        (Decode.field "count" Decode.int)
        (Decode.field "added" Decode.bool)
        (Decode.field "removed" Decode.bool)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Ports.receive Received


statistics : Mode -> List Change -> { added : Int, removed : Int }
statistics mode changes =
    List.foldl
        (\part totals ->
            let
                count =
                    case mode of
                        Lines ->
                            part.count

                        Words ->
                            String.length part.value
            in
            if part.added then
                { totals | added = totals.added + count }

            else if part.removed then
                { totals | removed = totals.removed + count }

            else
                totals
        )
        { added = 0, removed = 0 }
        changes


view : Model -> Html Msg
view model =
    div [ class "diff-page" ]
        [ section [ class "terminal-panel head" ]
            [ p [ class "prompt" ] [ text "$ diff ./venstre.txt ./hoyre.txt" ]
            , div [ class "head-row" ]
                [ h1 [] [ text "tekst≠diff" ]
                , span [ class "status active" ] [ text "aktiv" ]
                ]
            , p [ class "desc" ] [ text "Lim inn tekst i de to boksene, så vises forskjellene under. Bytt mellom linje- og ordsammenlikning, bytt om sidene, eller tøm alt." ]
            , div [ class "controls" ]
                [ div [ class "mode", attribute "role" "group", attribute "aria-label" "Sammenlikningsmodus" ]
                    [ modeButton model.mode Lines "linjer"
                    , modeButton model.mode Words "ord"
                    ]
                , button [ type_ "button", onClick Swap ] [ text "↔ bytt" ]
                , button [ type_ "button", onClick Clear ] [ text "tøm" ]
                ]
            ]
        , section [ class "inputs" ]
            [ inputPane "~ /venstre" "lim inn første tekst…" model.left EditLeft
            , inputPane "~ /høyre" "lim inn andre tekst…" model.right EditRight
            ]
        , output model
        ]


modeButton : Mode -> Mode -> String -> Html Msg
modeButton selected mode caption =
    button
        [ type_ "button"
        , classList [ ( "active", selected == mode ) ]
        , attribute "aria-pressed"
            (if selected == mode then
                "true"

             else
                "false"
            )
        , onClick (SetMode mode)
        ]
        [ text caption ]


inputPane : String -> String -> String -> (String -> Msg) -> Html Msg
inputPane title hint input edit =
    label [ class "pane" ]
        [ span [ class "pane-head" ] [ text title ]
        , textarea [ value input, onInput edit, spellcheck False, placeholder hint ] []
        ]


output : Model -> Html Msg
output model =
    let
        totals =
            statistics model.mode model.changes

        result =
            if model.left == "" && model.right == "" then
                p [ class "empty" ] [ text "ingen inndata enda." ]

            else if model.left == model.right then
                p [ class "empty" ] [ text "tekstene er identiske." ]

            else
                pre [ class "diff" ] (List.map changeView model.changes)
    in
    section [ class "terminal-panel diff-output", attribute "aria-label" "Diff-resultat" ]
        [ div [ class "diff-head" ]
            [ p [ class "prompt" ] [ text "$ cat ./diff.patch" ]
            , div [ class "stats" ]
                [ span [ class "added" ] [ text ("+" ++ String.fromInt totals.added) ]
                , span [ class "removed" ] [ text ("-" ++ String.fromInt totals.removed) ]
                ]
            ]
        , result
        ]


changeView : Change -> Html Msg
changeView change =
    span
        [ class
            ("line "
                ++ (if change.added then
                        "added"

                    else if change.removed then
                        "removed"

                    else
                        "context"
                   )
            )
        ]
        [ text change.value ]
