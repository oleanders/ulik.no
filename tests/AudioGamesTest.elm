module AudioGamesTest exposing (tests)

import Expect
import Json.Encode as Encode
import Pages.Morse as Morse
import Pages.Nato as Nato
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


morseStep : Morse.Msg -> Morse.Model -> Morse.Model
morseStep msg =
    Morse.update msg >> Tuple.first


natoStep : Nato.Msg -> Nato.Model -> Nato.Model
natoStep msg =
    Nato.update msg >> Tuple.first


tests : Test
tests =
    describe "Audio games"
        [ describe "Morse"
            [ test "overview includes all 26 letters and 10 digits" <|
                \_ ->
                    Tuple.first (Morse.init "oversikt")
                        |> Morse.view
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.class "letter-tile" ]
                        |> Query.count (Expect.equal 36)
            , test "speed stays within 5–30 words per minute" <|
                \_ ->
                    let
                        initial =
                            Tuple.first (Morse.init "oversikt")
                    in
                    Expect.equal [ 15, 5, 30 ]
                        [ initial.wpm, (morseStep (Morse.ChangeSpeed "0") initial).wpm, (morseStep (Morse.ChangeSpeed "100") initial).wpm ]
            , test "receive answers are trimmed and uppercased" <|
                \_ ->
                    Tuple.first (Morse.init "motta")
                        |> morseStep (Morse.TargetChosen "A")
                        |> morseStep (Morse.ChangeAnswer " a ")
                        |> morseStep Morse.Submit
                        |> .history
                        |> List.map (\entry -> ( entry.answer, entry.correct ))
                        |> Expect.equal [ ( "A", True ) ]
            , test "presses under 40ms are ignored, 250ms begins a dash" <|
                \_ ->
                    Tuple.first (Morse.init "sende")
                        |> morseStep (Morse.TargetChosen "A")
                        |> morseStep (Morse.PressKey 100)
                        |> morseStep (Morse.ReleaseKey 139)
                        |> morseStep (Morse.PressKey 200)
                        |> morseStep (Morse.ReleaseKey 449)
                        |> morseStep (Morse.PressKey 500)
                        |> morseStep (Morse.ReleaseKey 750)
                        |> morseStep Morse.Submit
                        |> .history
                        |> List.map (\entry -> ( entry.answer, entry.correct ))
                        |> Expect.equal [ ( "A", True ) ]
            , test "a repeated keydown does not restart the held key" <|
                \_ ->
                    Tuple.first (Morse.init "sende")
                        |> morseStep (Morse.TargetChosen "T")
                        |> morseStep (Morse.PressKey 100)
                        |> morseStep (Morse.PressKey 340)
                        |> morseStep (Morse.ReleaseKey 350)
                        |> morseStep Morse.Submit
                        |> .streak
                        |> Expect.equal 1
            , test "manual editing and duplicate submission preserve one scored round" <|
                \_ ->
                    Tuple.first (Morse.init "sende")
                        |> morseStep (Morse.TargetChosen "A")
                        |> morseStep (Morse.AddSymbol "-")
                        |> morseStep Morse.ClearBuffer
                        |> morseStep (Morse.AddSymbol ".")
                        |> morseStep (Morse.AddSymbol ".")
                        |> morseStep Morse.Backspace
                        |> morseStep (Morse.AddSymbol "-")
                        |> morseStep Morse.Submit
                        |> morseStep Morse.Submit
                        |> (\model -> ( model.streak, List.length model.history ))
                        |> Expect.equal ( 1, 1 )
            , test "an incorrect round resets the streak without losing history" <|
                \_ ->
                    Tuple.first (Morse.init "sende")
                        |> morseStep (Morse.TargetChosen "E")
                        |> morseStep (Morse.AddSymbol ".")
                        |> morseStep Morse.Submit
                        |> morseStep (Morse.TargetChosen "T")
                        |> morseStep (Morse.AddSymbol ".")
                        |> morseStep Morse.Submit
                        |> (\model -> ( model.streak, List.map .correct model.history ))
                        |> Expect.equal ( 0, [ False, True ] )
            , test "stale playback events cannot light the current letter" <|
                \_ ->
                    Tuple.first (Morse.init "oversikt")
                        |> morseStep (Morse.PlayLetter "A")
                        |> morseStep
                            (Morse.AudioEvent
                                (Encode.object
                                    [ ( "domain", Encode.string "morse" )
                                    , ( "action", Encode.string "signal" )
                                    , ( "request", Encode.int 99 )
                                    , ( "lightOn", Encode.bool True )
                                    ]
                                )
                            )
                        |> Morse.view
                        |> Query.fromHtml
                        |> Query.find [ Selector.class "signal-light" ]
                        |> Query.hasNot [ Selector.class "active" ]
            ]
        , describe "NATO"
            [ test "round length settings stay in range and ordered" <|
                \_ ->
                    Tuple.first Nato.init
                        |> natoStep (Nato.ChangeMinimum "99")
                        |> natoStep (Nato.ChangeMaximum "-3")
                        |> (\model -> ( model.minWords, model.maxWords ))
                        |> Expect.equal ( 5, 5 )
            , test "answers normalize punctuation and case, matching each spoken word" <|
                \_ ->
                    Tuple.first Nato.init
                        |> natoStep (Nato.RoundChosen 1 [ { letter = "A", word = "Alfa" }, { letter = "B", word = "Bravo" } ])
                        |> natoStep (Nato.ChangeAnswer "a- b!")
                        |> natoStep Nato.Submit
                        |> (\model -> ( model.feedback, List.concatMap .letters model.history |> List.map .correct ))
                        |> Expect.equal ( "Riktig! Alfa Bravo = AB.", [ True, True ] )
            , test "missing letters are recorded as empty and scored wrong" <|
                \_ ->
                    Tuple.first Nato.init
                        |> natoStep (Nato.RoundChosen 1 [ { letter = "A", word = "Alfa" }, { letter = "B", word = "Bravo" } ])
                        |> natoStep (Nato.ChangeAnswer "A")
                        |> natoStep Nato.Submit
                        |> .history
                        |> List.concatMap .letters
                        |> List.map (\letter -> ( letter.user, letter.correct ))
                        |> Expect.equal [ ( "A", True ), ( "∅", False ) ]
            , test "duplicate submission does not add a second score" <|
                \_ ->
                    Tuple.first Nato.init
                        |> natoStep (Nato.RoundChosen 1 [ { letter = "A", word = "Alfa" } ])
                        |> natoStep Nato.Submit
                        |> natoStep Nato.Submit
                        |> .history
                        |> List.length
                        |> Expect.equal 1
            , test "history keeps the most recent round first" <|
                \_ ->
                    Tuple.first Nato.init
                        |> natoStep (Nato.RoundChosen 1 [ { letter = "A", word = "Alfa" } ])
                        |> natoStep Nato.Submit
                        |> natoStep (Nato.RoundChosen 2 [ { letter = "B", word = "Bravo" } ])
                        |> natoStep Nato.Submit
                        |> .history
                        |> List.map .number
                        |> Expect.equal [ 2, 1 ]
            , test "unsupported speech has a useful browser capability message" <|
                \_ ->
                    Tuple.first Nato.init
                        |> natoStep (Nato.BrowserEvent (Encode.object [ ( "domain", Encode.string "nato" ), ( "action", Encode.string "unavailable" ) ]))
                        |> .feedback
                        |> Expect.equal "Nettleseren din støtter ikke taleavspilling via Speech Synthesis."
            , test "unrelated browser messages are ignored" <|
                \_ ->
                    let
                        initial =
                            Tuple.first Nato.init
                    in
                    natoStep (Nato.BrowserEvent (Encode.object [ ( "domain", Encode.string "morse" ), ( "action", Encode.string "unavailable" ) ])) initial
                        |> Expect.equal initial
            ]
        ]
