module Pages.Nato exposing (Model, Msg(..), init, subscriptions, update, view)

import Browser.Dom
import Html exposing (Html, aside, button, code, div, form, h1, h2, input, label, option, p, section, select, span, text)
import Html.Attributes exposing (attribute, autocomplete, class, classList, disabled, for, id, placeholder, selected, spellcheck, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports
import Random
import Task


type alias Entry =
    { letter : String, word : String }


type Game
    = Setup
    | Loading Int
    | Playing Round


type alias Round =
    { number : Int
    , entries : List Entry
    , answer : String
    , revealWords : Bool
    , outcome : Outcome
    }


type Outcome
    = AwaitingAnswer
    | Answered (List LetterResult)


type alias LetterResult =
    { word : String, expected : String, user : String, correct : Bool }


type alias HistoryEntry =
    { number : Int, letters : List LetterResult }


type Language
    = Bokmal
    | Nynorsk
    | AmericanEnglish
    | BritishEnglish


type Speech
    = CheckingSupport
    | Unavailable
    | Available (List Voice)


type alias Voice =
    { uri : String, language : String }


type Playback
    = Quiet
    | Speaking Int


type alias Model =
    { game : Game
    , minWords : Int
    , maxWords : Int
    , language : Language
    , speech : Speech
    , playback : Playback
    , nextRequest : Int
    , feedback : String
    , history : List HistoryEntry
    }


type Msg
    = ChangeMinimum String
    | ChangeMaximum String
    | ChangeLanguage String
    | StartGame
    | NextRound
    | RoundChosen Int (List Entry)
    | ChangeAnswer String
    | Submit
    | ToggleWords
    | SpeakRound
    | BrowserEvent Decode.Value
    | NoOp


type AudioEvent
    = VoicesLoaded (List Voice)
    | SpeechUnavailable
    | SpeechEnded Int
    | SpeechFailed Int


init : ( Model, Cmd Msg )
init =
    ( { game = Setup
      , minWords = 3
      , maxWords = 5
      , language = Bokmal
      , speech = CheckingSupport
      , playback = Quiet
      , nextRequest = 1
      , feedback = ""
      , history = []
      }
    , audioCommand "nato-init" []
    )


alphabet : List Entry
alphabet =
    List.map (\( letter, word ) -> { letter = letter, word = word })
        [ ( "A", "Alfa" )
        , ( "B", "Bravo" )
        , ( "C", "Charlie" )
        , ( "D", "Delta" )
        , ( "E", "Echo" )
        , ( "F", "Foxtrot" )
        , ( "G", "Golf" )
        , ( "H", "Hotel" )
        , ( "I", "India" )
        , ( "J", "Juliett" )
        , ( "K", "Kilo" )
        , ( "L", "Lima" )
        , ( "M", "Mike" )
        , ( "N", "November" )
        , ( "O", "Oscar" )
        , ( "P", "Papa" )
        , ( "Q", "Quebec" )
        , ( "R", "Romeo" )
        , ( "S", "Sierra" )
        , ( "T", "Tango" )
        , ( "U", "Uniform" )
        , ( "V", "Victor" )
        , ( "W", "Whiskey" )
        , ( "X", "X-ray" )
        , ( "Y", "Yankee" )
        , ( "Z", "Zulu" )
        ]


languages : List ( Language, String )
languages =
    [ ( Bokmal, "Norsk bokmål (nb-NO)" )
    , ( Nynorsk, "Norsk nynorsk (nn-NO)" )
    , ( AmericanEnglish, "Engelsk (USA) (en-US)" )
    , ( BritishEnglish, "Engelsk (Storbritannia) (en-GB)" )
    ]


languageCode : Language -> String
languageCode language =
    case language of
        Bokmal ->
            "nb-NO"

        Nynorsk ->
            "nn-NO"

        AmericanEnglish ->
            "en-US"

        BritishEnglish ->
            "en-GB"


languageFromString : String -> Language
languageFromString language =
    case language of
        "nn-NO" ->
            Nynorsk

        "en-US" ->
            AmericanEnglish

        "en-GB" ->
            BritishEnglish

        _ ->
            Bokmal


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChangeMinimum raw ->
            ( { model | minWords = raw |> String.toInt |> Maybe.withDefault model.minWords |> clamp 1 model.maxWords }, Cmd.none )

        ChangeMaximum raw ->
            ( { model | maxWords = raw |> String.toInt |> Maybe.withDefault model.maxWords |> clamp model.minWords 10 }, Cmd.none )

        ChangeLanguage raw ->
            ( { model | language = languageFromString raw }, Cmd.none )

        StartGame ->
            case model.game of
                Setup ->
                    beginRound 1 { model | history = [] }

                _ ->
                    ( model, Cmd.none )

        NextRound ->
            case model.game of
                Playing current ->
                    case current.outcome of
                        Answered _ ->
                            beginRound (current.number + 1) model

                        AwaitingAnswer ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        RoundChosen number entries ->
            let
                next =
                    { model
                        | game = Playing { number = number, entries = entries, answer = "", revealWords = False, outcome = AwaitingAnswer }
                        , feedback = ""
                    }

                ( speakingModel, speechCommand ) =
                    speakRound next
            in
            ( speakingModel, Cmd.batch [ speechCommand, focus "answer" ] )

        ChangeAnswer answer ->
            ( mapRound (\current -> { current | answer = answer }) model, Cmd.none )

        Submit ->
            submit model

        ToggleWords ->
            ( mapRound (\current -> { current | revealWords = not current.revealWords }) model, Cmd.none )

        SpeakRound ->
            speakRound model

        BrowserEvent raw ->
            case Decode.decodeValue audioDecoder raw of
                Ok (VoicesLoaded voices) ->
                    ( { model | speech = Available voices }, Cmd.none )

                Ok SpeechUnavailable ->
                    ( { model | speech = Unavailable, feedback = "Nettleseren din støtter ikke taleavspilling via Speech Synthesis." }, Cmd.none )

                Ok (SpeechEnded request) ->
                    if model.playback == Speaking request then
                        ( { model | playback = Quiet }, Cmd.none )

                    else
                        ( model, Cmd.none )

                Ok (SpeechFailed request) ->
                    if model.playback == Speaking request then
                        ( { model | playback = Quiet, feedback = "Klarte ikke å spille av tale i nettleseren." }, Cmd.none )

                    else
                        ( model, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


beginRound : Int -> Model -> ( Model, Cmd Msg )
beginRound number model =
    let
        entryGenerator =
            Random.uniform { letter = "A", word = "Alfa" } (List.drop 1 alphabet)

        roundGenerator =
            Random.int model.minWords model.maxWords
                |> Random.andThen (\count -> Random.list count entryGenerator)
    in
    ( { model | game = Loading number, playback = Quiet, feedback = "" }
    , Cmd.batch [ audioCommand "nato-stop" [], Random.generate (RoundChosen number) roundGenerator ]
    )


mapRound : (Round -> Round) -> Model -> Model
mapRound transform model =
    case model.game of
        Playing current ->
            { model | game = Playing (transform current) }

        _ ->
            model


roundWords : Round -> String
roundWords current =
    current.entries |> List.map .word |> String.join " "


expectedAnswer : Round -> String
expectedAnswer current =
    current.entries |> List.map .letter |> String.concat


submit : Model -> ( Model, Cmd Msg )
submit model =
    case model.game of
        Playing current ->
            case current.outcome of
                Answered _ ->
                    ( model, Cmd.none )

                AwaitingAnswer ->
                    let
                        normalized =
                            current.answer |> String.toUpper |> String.filter (\character -> character >= 'A' && character <= 'Z')

                        results =
                            List.indexedMap
                                (\index entry ->
                                    let
                                        letter =
                                            String.slice index (index + 1) normalized

                                        user =
                                            if letter == "" then
                                                "∅"

                                            else
                                                letter
                                    in
                                    { word = entry.word, expected = entry.letter, user = user, correct = user == entry.letter }
                                )
                                current.entries

                        correct =
                            countCorrect results

                        feedback =
                            if correct == List.length current.entries then
                                "Riktig! " ++ roundWords current ++ " = " ++ expectedAnswer current ++ "."

                            else
                                String.fromInt correct ++ "/" ++ String.fromInt (List.length current.entries) ++ " riktige. Riktig svar er " ++ expectedAnswer current ++ " (" ++ roundWords current ++ ")."
                    in
                    ( { model
                        | game = Playing { current | revealWords = True, outcome = Answered results }
                        , history = { number = current.number, letters = results } :: model.history
                        , feedback = feedback
                      }
                    , focus "next-round"
                    )

        _ ->
            ( model, Cmd.none )


countCorrect : List LetterResult -> Int
countCorrect =
    List.filter .correct >> List.length


isAnswered : Round -> Bool
isAnswered current =
    case current.outcome of
        AwaitingAnswer ->
            False

        Answered _ ->
            True


speechSupported : Speech -> Bool
speechSupported speech =
    case speech of
        Available _ ->
            True

        _ ->
            False


matchingVoice : Language -> List Voice -> Maybe Voice
matchingVoice language voices =
    let
        requested =
            String.toLower (languageCode language)

        prefix =
            requested |> String.split "-" |> List.head |> Maybe.withDefault ""

        matches predicate =
            voices |> List.filter (\voice -> predicate (String.toLower voice.language)) |> List.head
    in
    [ matches ((==) requested)
    , matches (String.startsWith (prefix ++ "-"))
    , matches (String.startsWith "nb")
    , matches (String.startsWith "no")
    , matches (String.startsWith "en")
    ]
        |> List.filterMap identity
        |> List.head


speakRound : Model -> ( Model, Cmd Msg )
speakRound model =
    case ( model.game, model.speech ) of
        ( Playing current, Available voices ) ->
            let
                voiceUri =
                    matchingVoice model.language voices |> Maybe.map (.uri >> Encode.string) |> Maybe.withDefault Encode.null
            in
            ( { model | playback = Speaking model.nextRequest, nextRequest = model.nextRequest + 1 }
            , audioCommand "nato-speak"
                [ ( "request", Encode.int model.nextRequest )
                , ( "text", Encode.string (roundWords current) )
                , ( "language", Encode.string (languageCode model.language) )
                , ( "voiceUri", voiceUri )
                , ( "rate", Encode.float 0.85 )
                , ( "pitch", Encode.float 1 )
                ]
            )

        _ ->
            ( model, Cmd.none )


focus : String -> Cmd Msg
focus elementId =
    Task.attempt (\_ -> NoOp) (Browser.Dom.focus elementId)


audioCommand : String -> List ( String, Encode.Value ) -> Cmd msg
audioCommand action data =
    Ports.send (Encode.object [ ( "domain", Encode.string "audio" ), ( "action", Encode.string action ), ( "data", Encode.object data ) ])


audioDecoder : Decode.Decoder AudioEvent
audioDecoder =
    Decode.field "domain" Decode.string
        |> Decode.andThen
            (\domain ->
                if domain == "nato" then
                    Decode.field "action" Decode.string |> Decode.andThen audioActionDecoder

                else
                    Decode.fail "Unrelated browser event"
            )


audioActionDecoder : String -> Decode.Decoder AudioEvent
audioActionDecoder action =
    case action of
        "voices" ->
            Decode.map VoicesLoaded
                (Decode.field "voices"
                    (Decode.list (Decode.map2 Voice (Decode.field "uri" Decode.string) (Decode.field "language" Decode.string)))
                )

        "unavailable" ->
            Decode.succeed SpeechUnavailable

        "ended" ->
            Decode.map SpeechEnded (Decode.field "request" Decode.int)

        "error" ->
            Decode.map SpeechFailed (Decode.field "request" Decode.int)

        _ ->
            Decode.fail "Unknown speech event"


subscriptions : Model -> Sub Msg
subscriptions _ =
    Ports.receive BrowserEvent


view : Model -> Html Msg
view model =
    div [ class "nato-page" ]
        [ section [ class "terminal-panel head" ]
            [ p [ class "prompt" ] [ text "$ ./fonetisk-spill --start" ]
            , div [ class "head-row" ] [ h1 [] [ text "fonetisk≠spill" ], span [ class "status active" ] [ text "aktiv" ] ]
            , p [ class "description" ]
                [ text "Øv deg på det fonetiske alfabetet ved å høre ord (for eksempel "
                , code [] [ text "alfa" ]
                , text " og "
                , code [] [ text "bravo" ]
                , text ") og skriv riktige bokstaver."
                ]
            ]
        , section [ class "terminal-panel game" ]
            ((case model.game of
                Setup ->
                    setupView model

                Loading number ->
                    [ p [ class "prompt", attribute "aria-live" "polite" ] [ text ("$ play --round " ++ String.fromInt number) ] ]

                Playing current ->
                    [ div [ class "game-layout" ] [ roundView model current, historyView model.history ] ]
             )
                ++ (if model.feedback == "" then
                        []

                    else
                        [ p [ class "feedback", attribute "aria-live" "polite" ] [ text model.feedback ] ]
                   )
            )
        ]


setupView : Model -> List (Html Msg)
setupView model =
    [ p [ class "prompt" ] [ text "$ play --start" ]
    , p [ class "description" ] [ text "Trykk start for å begynne. Ordene leses opp automatisk i hver runde." ]
    , div [ class "round-settings" ]
        [ p [ class "settings-title" ] [ text "Antall ord per oppgave" ]
        , div [ class "settings-grid" ]
            [ label [ for "min-words" ]
                [ text "Min"
                , select [ id "min-words", value (String.fromInt model.minWords), onInput ChangeMinimum ]
                    (List.map (wordOption model.minWords) (List.range 1 model.maxWords))
                ]
            , label [ for "max-words" ]
                [ text "Maks"
                , select [ id "max-words", value (String.fromInt model.maxWords), onInput ChangeMaximum ]
                    (List.map (wordOption model.maxWords) (List.range model.minWords 10))
                ]
            ]
        , p [ class "settings-hint" ] [ text "Velg mellom 1 og 10. Standard er 3–5." ]
        ]
    , div [ class "actions" ] [ button [ type_ "button", onClick StartGame ] [ text "Start spill" ] ]
    ]


wordOption : Int -> Int -> Html Msg
wordOption current number =
    option [ value (String.fromInt number), selected (current == number) ] [ text (String.fromInt number) ]


roundView : Model -> Round -> Html Msg
roundView model current =
    div [ class "game-main" ]
        ([ p [ class "prompt" ] [ text ("$ play --round " ++ String.fromInt current.number) ]
         , div [ class "voice-settings" ]
            [ label [ for "speech-language" ] [ text "Språk for opplesning" ]
            , select [ id "speech-language", value (languageCode model.language), onInput ChangeLanguage, disabled (not (speechSupported model.speech) || model.playback /= Quiet) ]
                (List.map
                    (\( language, description ) -> option [ value (languageCode language), selected (model.language == language) ] [ text description ])
                    languages
                )
            ]
         , div [ class "actions" ]
            [ button [ type_ "button", onClick SpeakRound, disabled (not (speechSupported model.speech) || model.playback /= Quiet) ]
                [ text
                    (if model.playback /= Quiet then
                        "Spiller av…"

                     else
                        "Spill av ord igjen"
                    )
                ]
            , button [ id "next-round", type_ "button", classList [ ( "ghost", True ), ( "ready", isAnswered current ) ], onClick NextRound, disabled (not (isAnswered current)) ] [ text "Neste runde" ]
            , button [ type_ "button", class "ghost", onClick ToggleWords ]
                [ text
                    (if current.revealWords then
                        "Skjul ord"

                     else
                        "Vis ord"
                    )
                ]
            ]
         ]
            ++ (if current.revealWords then
                    [ wordsView current ]

                else
                    []
               )
            ++ [ form [ class "answer-form", onSubmit Submit ]
                    [ label [ for "answer" ] [ text "Hvilke bokstaver hørte du?" ]
                    , input [ id "answer", type_ "text", value current.answer, onInput ChangeAnswer, placeholder "f.eks. AB", autocomplete False, spellcheck False, disabled (isAnswered current) ] []
                    , button [ type_ "submit", disabled (isAnswered current) ] [ text "Sjekk svar" ]
                    ]
               ]
        )


wordsView : Round -> Html Msg
wordsView current =
    p [ class "round-words", attribute "aria-label" "Ord i runden" ]
        (case current.outcome of
            AwaitingAnswer ->
                List.map (\entry -> span [ class "round-word" ] [ text entry.word ]) current.entries

            Answered results ->
                List.map (\result -> span [ class ("round-word " ++ resultClass result.correct) ] [ text result.word ]) results
        )


resultClass : Bool -> String
resultClass correct =
    if correct then
        "correct"

    else
        "wrong"


historyView : List HistoryEntry -> Html Msg
historyView history =
    let
        results =
            List.concatMap .letters history

        total =
            List.length results

        correct =
            countCorrect results

        percent =
            if total == 0 then
                0

            else
                round (toFloat correct / toFloat total * 100)
    in
    aside [ class "history-panel", attribute "aria-label" "Rundehistorikk" ]
        [ h2 [] [ text "Runder" ]
        , p [ class "history-summary" ]
            [ text ("Oppsummering: " ++ String.fromInt correct ++ "/" ++ String.fromInt total ++ " riktige bokstaver (" ++ String.fromInt percent ++ "%)") ]
        , if List.isEmpty history then
            p [ class "history-empty" ] [ text "Ingen runder enda." ]

          else
            div [ class "history-list" ] (List.map historyEntryView history)
        ]


historyEntryView : HistoryEntry -> Html Msg
historyEntryView entry =
    div [ class "history-item" ]
        [ p [ class "history-round" ] [ text ("Runde " ++ String.fromInt entry.number ++ " — " ++ String.fromInt (countCorrect entry.letters) ++ "/" ++ String.fromInt (List.length entry.letters)) ]
        , div [ class "history-letters" ]
            (List.map (\letter -> span [ class ("submitted-letter " ++ resultClass letter.correct) ] [ text letter.user ]) entry.letters)
        ]
