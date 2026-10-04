module Pages.Morse exposing (Model, Msg(..), init, subscriptions, update, view)

import Browser.Events
import Html exposing (Html, a, button, div, form, h1, h2, input, label, li, p, section, span, text, ul)
import Html.Attributes as Attributes exposing (attribute, autocomplete, class, classList, disabled, for, href, id, maxlength, placeholder, spellcheck, tabindex, type_, value)
import Html.Events exposing (on, onClick, onInput, onSubmit, preventDefaultOn)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports
import Random


type Mode
    = Overview
    | Receive
    | Send


type Game
    = NotStarted
    | ChoosingTarget
    | Practicing Round


type alias Round =
    { target : String
    , answer : String
    , buffer : String
    , result : RoundResult
    }


type RoundResult
    = AwaitingAnswer
    | Answered String


type Playback
    = Silent
    | Playing { request : Int, letter : String, lightOn : Bool }


type Key
    = Released
    | Pressed Float


type alias HistoryEntry =
    { mode : Mode, target : String, answer : String, correct : Bool }


type alias Model =
    { mode : Mode
    , wpm : Int
    , game : Game
    , playback : Playback
    , nextRequest : Int
    , key : Key
    , showCode : Bool
    , history : List HistoryEntry
    , streak : Int
    }


type Msg
    = ChangeSpeed String
    | PlayLetter String
    | Replay
    | StartRound
    | TargetChosen String
    | ChangeAnswer String
    | Submit
    | ToggleCode
    | PressKey Float
    | ReleaseKey Float
    | AddSymbol String
    | Backspace
    | ClearBuffer
    | AudioEvent Decode.Value
    | NoOp


init : String -> ( Model, Cmd Msg )
init subpage =
    ( { mode = modeFromString subpage
      , wpm = 15
      , game = NotStarted
      , playback = Silent
      , nextRequest = 1
      , key = Released
      , showCode = False
      , history = []
      , streak = 0
      }
    , audioCommand "morse-init" []
    )


modeFromString : String -> Mode
modeFromString subpage =
    case subpage of
        "motta" ->
            Receive

        "sende" ->
            Send

        _ ->
            Overview


modeName : Mode -> String
modeName mode =
    case mode of
        Overview ->
            "oversikt"

        Receive ->
            "motta"

        Send ->
            "sende"


alphabet : List ( String, String )
alphabet =
    -- JavaScript's original object puts numeric keys first in the overview.
    [ ( "0", "-----" )
    , ( "1", ".----" )
    , ( "2", "..---" )
    , ( "3", "...--" )
    , ( "4", "....-" )
    , ( "5", "....." )
    , ( "6", "-...." )
    , ( "7", "--..." )
    , ( "8", "---.." )
    , ( "9", "----." )
    , ( "A", ".-" )
    , ( "B", "-..." )
    , ( "C", "-.-." )
    , ( "D", "-.." )
    , ( "E", "." )
    , ( "F", "..-." )
    , ( "G", "--." )
    , ( "H", "...." )
    , ( "I", ".." )
    , ( "J", ".---" )
    , ( "K", "-.-" )
    , ( "L", ".-.." )
    , ( "M", "--" )
    , ( "N", "-." )
    , ( "O", "---" )
    , ( "P", ".--." )
    , ( "Q", "--.-" )
    , ( "R", ".-." )
    , ( "S", "..." )
    , ( "T", "-" )
    , ( "U", "..-" )
    , ( "V", "...-" )
    , ( "W", ".--" )
    , ( "X", "-..-" )
    , ( "Y", "-.--" )
    , ( "Z", "--.." )
    ]


morseCode : String -> String
morseCode letter =
    alphabet |> List.filter (\( candidate, _ ) -> candidate == letter) |> List.head |> Maybe.map Tuple.second |> Maybe.withDefault ""


decodeMorse : String -> Maybe String
decodeMorse code =
    alphabet |> List.filter (\( _, candidate ) -> candidate == code) |> List.head |> Maybe.map Tuple.first


formatMorse : String -> String
formatMorse =
    String.replace "." "·" >> String.replace "-" "—"


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChangeSpeed speed ->
            ( { model | wpm = speed |> String.toInt |> Maybe.withDefault model.wpm |> clamp 5 30 }, Cmd.none )

        PlayLetter letter ->
            if model.mode == Overview then
                play letter model

            else
                ( model, Cmd.none )

        Replay ->
            case model.game of
                Practicing round ->
                    play round.target model

                _ ->
                    ( model, Cmd.none )

        StartRound ->
            if model.mode == Overview || model.game == ChoosingTarget then
                ( model, Cmd.none )

            else
                ( { model | game = ChoosingTarget, key = Released, playback = Silent }
                , Cmd.batch
                    [ audioCommand "morse-stop" []
                    , audioCommand "morse-unlock" []
                    , Random.generate TargetChosen (Random.uniform "0" (List.map Tuple.first (List.drop 1 alphabet)))
                    ]
                )

        TargetChosen target ->
            let
                next =
                    { model | game = Practicing { target = target, answer = "", buffer = "", result = AwaitingAnswer } }
            in
            if model.mode == Receive then
                play target next

            else
                ( next, Cmd.none )

        ChangeAnswer answer ->
            ( mapRound (\round -> { round | answer = answer }) model, Cmd.none )

        Submit ->
            submit model

        ToggleCode ->
            ( { model | showCode = not model.showCode }, Cmd.none )

        PressKey timestamp ->
            if canSend model && model.key == Released then
                ( { model | key = Pressed timestamp }, audioCommand "morse-unlock" [] )

            else
                ( model, Cmd.none )

        ReleaseKey timestamp ->
            case model.key of
                Released ->
                    ( model, Cmd.none )

                Pressed started ->
                    let
                        duration =
                            timestamp - started

                        released =
                            { model | key = Released }
                    in
                    if duration < 40 then
                        ( released, Cmd.none )

                    else
                        update
                            (AddSymbol
                                (if duration < 250 then
                                    "."

                                 else
                                    "-"
                                )
                            )
                            released

        AddSymbol symbol ->
            if canSend model then
                ( mapRound (\round -> { round | buffer = round.buffer ++ symbol }) model, audioCommand "morse-unlock" [] )

            else
                ( model, Cmd.none )

        Backspace ->
            ( mapRound (\round -> { round | buffer = String.dropRight 1 round.buffer }) model, Cmd.none )

        ClearBuffer ->
            ( mapRound (\round -> { round | buffer = "" }) model, Cmd.none )

        AudioEvent event ->
            case Decode.decodeValue audioDecoder event of
                Ok ( request, light ) ->
                    case model.playback of
                        Playing playback ->
                            if request == playback.request then
                                ( { model
                                    | playback =
                                        case light of
                                            Just isOn ->
                                                Playing { playback | lightOn = isOn }

                                            Nothing ->
                                                Silent
                                  }
                                , Cmd.none
                                )

                            else
                                ( model, Cmd.none )

                        Silent ->
                            ( model, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


canSend : Model -> Bool
canSend model =
    case model.game of
        Practicing { result } ->
            model.mode == Send && result == AwaitingAnswer

        _ ->
            False


mapRound : (Round -> Round) -> Model -> Model
mapRound transform model =
    case model.game of
        Practicing round ->
            if round.result == AwaitingAnswer then
                { model | game = Practicing (transform round) }

            else
                model

        _ ->
            model


play : String -> Model -> ( Model, Cmd Msg )
play letter model =
    if model.playback /= Silent || morseCode letter == "" then
        ( model, Cmd.none )

    else
        ( { model
            | playback = Playing { request = model.nextRequest, letter = letter, lightOn = False }
            , nextRequest = model.nextRequest + 1
          }
        , audioCommand "morse-play"
            [ ( "request", Encode.int model.nextRequest )
            , ( "durations"
              , morseCode letter
                    |> String.toList
                    |> List.map
                        (\symbol ->
                            (if symbol == '-' then
                                3

                             else
                                1
                            )
                                * 1200
                                / toFloat model.wpm
                        )
                    |> Encode.list Encode.float
              )
            , ( "gap", Encode.float (1200 / toFloat model.wpm) )
            ]
        )


submit : Model -> ( Model, Cmd Msg )
submit model =
    case model.game of
        Practicing round ->
            if round.result /= AwaitingAnswer || (model.mode == Send && round.buffer == "") then
                ( model, Cmd.none )

            else
                let
                    code =
                        formatMorse (morseCode round.target)

                    decoded =
                        decodeMorse round.buffer

                    answer =
                        if model.mode == Receive then
                            let
                                normalized =
                                    String.toUpper (String.trim round.answer)
                            in
                            if normalized == "" then
                                "∅"

                            else
                                normalized

                        else
                            Maybe.withDefault round.buffer decoded

                    correct =
                        answer == round.target

                    feedback =
                        if model.mode == Receive then
                            if correct then
                                "Riktig! " ++ round.target ++ " er " ++ code ++ "."

                            else
                                "Det var " ++ round.target ++ " (" ++ code ++ "). Du svarte " ++ answer ++ "."

                        else if correct then
                            "Riktig! " ++ code ++ " = " ++ round.target ++ "."

                        else
                            case decoded of
                                Just letter ->
                                    "Du sendte " ++ formatMorse round.buffer ++ " = " ++ letter ++ ", men det skulle være " ++ code ++ " = " ++ round.target ++ "."

                                Nothing ->
                                    formatMorse round.buffer ++ " er ikke en gyldig morsekode. Riktig svar er " ++ code ++ " = " ++ round.target ++ "."
                in
                ( { model
                    | game = Practicing { round | result = Answered feedback }
                    , history = { mode = model.mode, target = round.target, answer = answer, correct = correct } :: model.history
                    , streak =
                        if correct then
                            model.streak + 1

                        else
                            0
                    , key = Released
                  }
                , Cmd.none
                )

        _ ->
            ( model, Cmd.none )


audioCommand : String -> List ( String, Encode.Value ) -> Cmd msg
audioCommand action data =
    Ports.send (Encode.object [ ( "domain", Encode.string "audio" ), ( "action", Encode.string action ), ( "data", Encode.object data ) ])


audioDecoder : Decode.Decoder ( Int, Maybe Bool )
audioDecoder =
    Decode.field "domain" Decode.string
        |> Decode.andThen
            (\domain ->
                if domain == "morse" then
                    Decode.map2 Tuple.pair
                        (Decode.field "request" Decode.int)
                        (Decode.field "action" Decode.string
                            |> Decode.andThen
                                (\action ->
                                    case action of
                                        "signal" ->
                                            Decode.map Just (Decode.field "lightOn" Decode.bool)

                                        "done" ->
                                            Decode.succeed Nothing

                                        _ ->
                                            Decode.fail "Unknown Morse event"
                                )
                        )

                else
                    Decode.fail "Unrelated browser event"
            )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.receive AudioEvent
        , if model.mode == Overview then
            Browser.Events.onKeyDown (Decode.field "key" Decode.string |> Decode.map (String.toUpper >> PlayLetter))

          else
            Sub.none
        ]


view : Model -> Html Msg
view model =
    div [ class "morse-page" ]
        [ section [ class "terminal-panel head" ]
            [ p [ class "prompt" ] [ text ("$ ./morse --subpage " ++ modeName model.mode) ]
            , div [ class "head-row" ] [ h1 [] [ text "morse≠kode" ], span [ class "status active" ] [ text "aktiv" ] ]
            , p [ class "desc" ] [ text "Øv deg på å sende og motta morsekode. Trykk start, lytt, se lyset og bruk mellomromstasten som nøkkel." ]
            , div [ class "subpage-group", attribute "role" "group", attribute "aria-label" "Velg modus" ]
                (List.map (modeLink model.mode) [ Overview, Receive, Send ])
            ]
        , section [ class "terminal-panel game", attribute "aria-label" "Morsekode-øving" ]
            (div [ class "settings" ]
                [ label [ for "wpm" ] [ text "Hastighet (ord per minutt)" ]
                , input [ id "wpm", type_ "range", Attributes.min "5", Attributes.max "30", value (String.fromInt model.wpm), onInput ChangeSpeed ] []
                , span [ class "wpm-value" ] [ text (String.fromInt model.wpm ++ " WPM") ]
                ]
                :: gameView model
            )
        , historyView model.history
        ]


modeLink : Mode -> Mode -> Html Msg
modeLink selected mode =
    a
        ([ href ("/projects/morsekode/" ++ modeName mode), classList [ ( "active", selected == mode ) ] ]
            ++ (if selected == mode then
                    [ attribute "aria-current" "page" ]

                else
                    []
               )
        )
        [ text (modeName mode) ]


gameView : Model -> List (Html Msg)
gameView model =
    if model.mode == Overview then
        [ p [ class "hint" ] [ text "Trykk på en bokstav, eller trykk samme bokstav på tastaturet, for å høre og se koden." ]
        , div [ class "letter-grid" ] (List.map (letterView model.playback) alphabet)
        , div [ class "signal-preview" ] [ signalLight model.playback True NoOp "Forhåndsvisning av blink" ]
        ]

    else
        case model.game of
            NotStarted ->
                [ div [ class "start-area" ]
                    [ p [ class "hint" ] [ text "Trykk start for å få en bokstav eller et tall." ]
                    , button [ type_ "button", class "primary", onClick StartRound ] [ text "Start øving" ]
                    ]
                ]

            ChoosingTarget ->
                [ p [ class "hint", attribute "aria-live" "polite" ] [ text "Gjør klar neste runde…" ] ]

            Practicing round ->
                [ targetView model round ]
                    ++ (case round.result of
                            Answered feedback ->
                                [ div [ class "form-actions" ] [ button [ type_ "button", class "primary", onClick StartRound ] [ text "Neste runde" ] ]
                                , p [ class "feedback", attribute "aria-live" "polite" ] [ text feedback ]
                                ]

                            AwaitingAnswer ->
                                if model.mode == Receive then
                                    [ receiveForm round.answer ]

                                else
                                    sendControls model round
                       )
                    ++ [ statsView model ]


letterView : Playback -> ( String, String ) -> Html Msg
letterView playback ( letter, code ) =
    let
        active =
            case playback of
                Playing current ->
                    current.letter == letter

                Silent ->
                    False
    in
    button [ type_ "button", classList [ ( "letter-tile", True ), ( "playing", active ) ], onClick (PlayLetter letter), disabled (playback /= Silent), attribute "aria-label" (letter ++ ": " ++ formatMorse code) ]
        [ span [ class "letter-tile-char" ] [ text letter ]
        , span [ class "letter-tile-morse" ] [ text (formatMorse code) ]
        ]


signalLight : Playback -> Bool -> Msg -> String -> Html Msg
signalLight playback isDisabled action description =
    let
        lightOn =
            case playback of
                Playing current ->
                    current.lightOn

                Silent ->
                    False
    in
    button [ type_ "button", classList [ ( "signal-light", True ), ( "active", lightOn ) ], disabled isDisabled, onClick action, attribute "aria-label" description ]
        [ span [ class "light-core" ] [], span [ class "light-glow" ] [] ]


targetView : Model -> Round -> Html Msg
targetView model round =
    div [ class "target-area" ]
        [ span [ class "target-label" ]
            [ text
                (if model.mode == Receive then
                    "Hva hører du?"

                 else
                    "Send denne koden"
                )
            ]
        , div [ class "target-card" ]
            ((if model.mode == Send then
                [ span [ class "target-letter", attribute "aria-label" "Målbokstav" ] [ text round.target ] ]

              else
                [ signalLight model.playback (model.playback /= Silent) Replay "Spill av morsekode"
                , button [ type_ "button", class "small", onClick Replay, disabled (model.playback /= Silent) ]
                    [ text
                        (if model.playback /= Silent then
                            "spiller…"

                         else
                            "spill av igjen"
                        )
                    ]
                ]
             )
                ++ [ button [ type_ "button", class "small", onClick ToggleCode ]
                        [ text
                            (if model.showCode then
                                "skjul kode"

                             else
                                "vis kode"
                            )
                        ]
                   ]
                ++ (if model.showCode then
                        [ p [ class "morse-hint" ] [ text (formatMorse (morseCode round.target)) ] ]

                    else
                        []
                   )
            )
        ]


receiveForm : String -> Html Msg
receiveForm answer =
    form [ class "answer-form", onSubmit Submit ]
        [ label [ for "receive-answer" ] [ text "Bokstav eller tall" ]
        , input [ id "receive-answer", type_ "text", value answer, onInput ChangeAnswer, placeholder "f.eks. A", maxlength 1, autocomplete False, spellcheck False ] []
        , div [ class "form-actions" ] [ button [ type_ "submit" ] [ text "Sjekk svar" ] ]
        ]


sendControls : Model -> Round -> List (Html Msg)
sendControls model round =
    [ div
        [ classList [ ( "key-area", True ), ( "pressed", model.key /= Released ) ]
        , attribute "role" "button"
        , tabindex 0
        , attribute "aria-label" "Morsenøkkel. Hold for prikk eller strek."
        , on "pointerdown" (Decode.map PressKey timestampDecoder)
        , on "pointerup" (Decode.map ReleaseKey timestampDecoder)
        , on "pointerleave" (Decode.map ReleaseKey timestampDecoder)
        , on "pointercancel" (Decode.map ReleaseKey timestampDecoder)
        , on "blur" (Decode.map ReleaseKey timestampDecoder)
        , preventDefaultOn "keydown" keyDownDecoder
        , preventDefaultOn "keyup" keyUpDecoder
        ]
        [ span [ class "key-label" ] [ text "Trykk og hold" ]
        , span [ class "key-hint" ] [ text "kort = prikk, lang = strek" ]
        ]
    , div [ class "manual-controls" ]
        [ button [ type_ "button", onClick (AddSymbol "."), attribute "aria-label" "Legg til prikk" ] [ text "·" ]
        , button [ type_ "button", onClick (AddSymbol "-"), attribute "aria-label" "Legg til strek" ] [ text "—" ]
        , button [ type_ "button", class "ghost", onClick Backspace ] [ text "slett" ]
        , button [ type_ "button", class "ghost", onClick ClearBuffer ] [ text "tøm" ]
        ]
    , div [ class "send-buffer", attribute "aria-live" "polite" ]
        (if round.buffer == "" then
            [ span [ class "buffer-empty" ] [ text "trykk nøkkelen for å sende" ] ]

         else
            [ span [ class "buffer-chars" ] [ text (formatMorse round.buffer) ]
            , span [ class "buffer-guess" ] [ text (decodeMorse round.buffer |> Maybe.map ((++) "= ") |> Maybe.withDefault "…") ]
            ]
        )
    , div [ class "form-actions" ]
        [ button [ type_ "button", class "primary", onClick Submit, disabled (round.buffer == "") ] [ text "Sjekk sending" ] ]
    ]


timestampDecoder : Decode.Decoder Float
timestampDecoder =
    Decode.field "timeStamp" Decode.float


keyDownDecoder : Decode.Decoder ( Msg, Bool )
keyDownDecoder =
    Decode.map3
        (\code repeat timestamp ->
            if code == "Space" then
                ( if repeat then
                    NoOp

                  else
                    PressKey timestamp
                , True
                )

            else
                ( NoOp, False )
        )
        (Decode.field "code" Decode.string)
        (Decode.field "repeat" Decode.bool)
        timestampDecoder


keyUpDecoder : Decode.Decoder ( Msg, Bool )
keyUpDecoder =
    Decode.map2
        (\code timestamp ->
            if code == "Space" then
                ( ReleaseKey timestamp, True )

            else
                ( NoOp, False )
        )
        (Decode.field "code" Decode.string)
        timestampDecoder


statsView : Model -> Html Msg
statsView model =
    let
        total =
            List.length model.history

        correct =
            List.length (List.filter .correct model.history)

        accuracy =
            if total == 0 then
                0

            else
                round (toFloat correct / toFloat total * 100)
    in
    div [ class "stats" ]
        (List.map (\stat -> span [ class "stat" ] [ text stat ])
            [ "riktige: " ++ String.fromInt correct ++ "/" ++ String.fromInt total
            , "presisjon: " ++ String.fromInt accuracy ++ "%"
            , "streak: " ++ String.fromInt model.streak
            ]
        )


historyView : List HistoryEntry -> Html Msg
historyView history =
    section [ class "terminal-panel history", attribute "aria-label" "Rundehistorikk" ]
        [ p [ class "prompt" ] [ text "$ cat ./morse.log" ]
        , h2 [] [ text "Siste runder" ]
        , if List.isEmpty history then
            p [ class "empty" ] [ text "Ingen runder enda. Kom igjen!" ]

          else
            ul [ class "history-list" ]
                (List.map
                    (\entry ->
                        li
                            [ class
                                ("history-item "
                                    ++ (if entry.correct then
                                            "correct"

                                        else
                                            "wrong"
                                       )
                                )
                            ]
                            [ span [ class "history-subpage" ] [ text (modeName entry.mode) ]
                            , span [ class "history-target" ] [ text entry.target ]
                            , span [ class "history-answer" ] [ text entry.answer ]
                            , span [ class "history-result" ]
                                [ text
                                    (if entry.correct then
                                        "✓"

                                     else
                                        "✕"
                                    )
                                ]
                            ]
                    )
                    history
                )
        ]
