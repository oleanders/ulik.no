module ExperimentsTest exposing (tests)

import Expect
import Json.Encode as Encode
import Pages.Falling as Falling
import Pages.Flow as Flow
import Pages.Robot as Robot
import Test exposing (Test, describe, test)


flow : String -> Flow.Model
flow query =
    Flow.init ("https://ulik.no/projects/flyt-felt" ++ query) |> Tuple.first


step : Flow.Msg -> Flow.Model -> Flow.Model
step message =
    Flow.update message >> Tuple.first


event : String -> String -> Encode.Value -> Encode.Value
event domain action data =
    Encode.object [ ( "domain", Encode.string domain ), ( "action", Encode.string action ), ( "data", data ) ]


tests : Test
tests =
    describe "Interactive experiments in Elm"
        [ describe "Flow URL configuration"
            [ test "preset defaults and full-width unsigned seeds survive shared URLs" <|
                \_ ->
                    let
                        model =
                            flow "?v=1&preset=glod&seed=4294967295"
                    in
                    Expect.equal
                        { preset = Flow.Glod, seed = 4294967295, speed = 1.5, density = 600, attraction = -0.5, hue = 5 }
                        model.config
            , test "bounds and snaps all numeric controls" <|
                \_ ->
                    let
                        bounded =
                            (flow "?speed=999&density=-100&attraction=-90&hue=1000").config

                        snapped =
                            (flow "?speed=0.321&density=849&attraction=0.32&hue=12.2").config
                    in
                    Expect.equal
                        [ ( 2, 300, -2 ), ( 0.3, 800, 0.3 ) ]
                        [ ( bounded.speed, bounded.density, bounded.attraction ), ( snapped.speed, snapped.density, snapped.attraction ) ]
            , test "rejects malformed numbers without accepting exponents or partial values" <|
                \_ ->
                    [ "NaN", "Infinity", "-Infinity", "1e9", "%3Cscript%3E", "+", "", "1.12345", "1=2" ]
                        |> List.map (\raw -> (flow ("?speed=" ++ raw ++ "&density=" ++ raw ++ "&attraction=" ++ raw ++ "&hue=" ++ raw)).config)
                        |> Expect.equal (List.repeat 9 (flow "").config)
            , test "invalid seeds fall back to the default" <|
                \_ ->
                    [ "0", "-1", "4294967296", "1.5", "Infinity", "1e2", "" ]
                        |> List.map (\raw -> (flow ("?seed=" ++ raw)).config.seed)
                        |> Expect.equal (List.repeat 7 20261002)
            , test "unknown versions, empty versions, malformed versions, and oversized URLs reset everything" <|
                \_ ->
                    [ "?v=2&preset=glod&seed=10", "?v&preset=glod", "?v=%zz&preset=glod", "?seed=1&extra=" ++ String.repeat 1000 "x" ]
                        |> List.map (flow >> .config)
                        |> Expect.equal (List.repeat 4 (flow "").config)
            , test "share strips unrelated parameters and fragments and restores the current controls" <|
                \_ ->
                    let
                        model =
                            flow "?preset=virvel&seed=17&speed=1.25&private=discard#discard" |> step Flow.Share

                        reopened =
                            Flow.init model.shareUrl |> Tuple.first
                    in
                    Expect.all
                        [ \_ -> Expect.equal False (String.contains "discard" model.shareUrl)
                        , \_ -> Expect.equal model.config reopened.config
                        ]
                        ()
            , test "all presets round-trip with custom controls and maximum seed" <|
                \_ ->
                    [ Flow.Nordlys, Flow.Virvel, Flow.Glod ]
                        |> List.map
                            (\preset ->
                                let
                                    model =
                                        flow "?seed=4294967295" |> step (Flow.SelectPreset preset) |> step (Flow.ChangeControl Flow.Speed "0.3") |> step (Flow.ChangeControl Flow.Attraction "-1.8") |> step Flow.Share
                                in
                                model.config == (Flow.init model.shareUrl |> Tuple.first).config
                            )
                        |> Expect.equal [ True, True, True ]
            ]
        , describe "Flow controls"
            [ test "reduced motion starts paused but can be explicitly played" <|
                \_ ->
                    let
                        paused =
                            flow "" |> step (Flow.Received (event "flow" "ready" (Encode.bool True)))

                        playing =
                            paused |> step Flow.TogglePlayback
                    in
                    Expect.equal ( True, Flow.Paused, Flow.Playing ) ( paused.reducedMotion, paused.playback, playing.playback )
            , test "keyboard pointer is bounded and restart releases it" <|
                \_ ->
                    let
                        moved =
                            List.foldl (\_ model -> step (Flow.Key "ArrowRight") model) (flow "") (List.range 1 30)

                        reset =
                            step Flow.Restart moved
                    in
                    Expect.equal ( 1, True, False ) ( moved.pointer.x, moved.keyboardActive, reset.keyboardActive )
            , test "configuration changes clear stale share URLs" <|
                \_ ->
                    flow "" |> step Flow.Share |> step (Flow.ChangeControl Flow.Density "1500") |> .shareUrl |> Expect.equal ""
            , test "events from other pages cannot change playback" <|
                \_ ->
                    flow "" |> step (Flow.Received (event "robot" "ready" (Encode.bool False))) |> .playback |> Expect.equal Flow.Starting
            ]
        , describe "Robot controls"
            [ test "repeated keydowns do not duplicate keys and blur releases them" <|
                \_ ->
                    let
                        initial =
                            Tuple.first Robot.init

                        pressed =
                            initial |> Robot.update (Robot.KeyDown "w") |> Tuple.first |> Robot.update (Robot.KeyDown "w") |> Tuple.first

                        released =
                            Robot.update (Robot.Received (event "robot" "clearKeys" Encode.null)) pressed |> Tuple.first
                    in
                    Expect.equal ( [ "w" ], [] ) ( pressed.keys, released.keys )
            , test "reduced motion starts robot paused" <|
                \_ ->
                    Robot.update (Robot.Received (event "robot" "ready" (Encode.bool True))) (Tuple.first Robot.init)
                        |> Tuple.first
                        |> .running
                        |> Expect.equal False
            ]
        , describe "Falling page"
            [ test "Escape from browser restores Elm state" <|
                \_ ->
                    Falling.update (Falling.Received (event "falling" "reset" (Encode.int 0))) (Tuple.first Falling.init)
                        |> Tuple.first
                        |> .phase
                        |> Expect.equal Falling.Restored
            , test "settled animation reports its phase and count" <|
                \_ ->
                    Tuple.first Falling.init
                        |> Falling.update (Falling.Received (event "falling" "count" (Encode.int 8)))
                        |> Tuple.first
                        |> Falling.update (Falling.Received (event "falling" "settled" (Encode.int 0)))
                        |> Tuple.first
                        |> (\model -> Expect.equal ( Falling.Settled, 8 ) ( model.phase, model.cloneCount ))
            ]
        ]
