module MarbleTest exposing (tests)

import Expect
import Json.Encode as Encode
import Pages.Marble as Marble
import Test exposing (Test, describe, test)


step : Marble.Msg -> Marble.Model -> Marble.Model
step message =
    Marble.update message >> Tuple.first


event : String -> String -> Marble.Msg
event domain action =
    Marble.Received (Encode.object [ ( "domain", Encode.string domain ), ( "action", Encode.string action ) ])


ready : Marble.Model
ready =
    Tuple.first Marble.init |> step (event "marble" "ready")


tests : Test
tests =
    describe "Easy marble track"
        [ test "a complete track starts still with an overview camera" <|
            \_ ->
                Expect.equal ( [ Marble.Sweep, Marble.Spiral, Marble.Jump ], Marble.Overview, Marble.Ready ) ( ready.segments, ready.camera, ready.phase )
        , test "launch is unavailable until the renderer is ready" <|
            \_ ->
                Tuple.first Marble.init |> step Marble.Launch |> .phase |> Expect.equal Marble.Loading
        , test "each slot cycles independently and returns after three taps" <|
            \_ ->
                let
                    once =
                        ready |> step (Marble.CycleSegment 1)

                    thrice =
                        once |> step (Marble.CycleSegment 1) |> step (Marble.CycleSegment 1)
                in
                Expect.equal ( [ Marble.Sweep, Marble.Jump, Marble.Jump ], ready.segments ) ( once.segments, thrice.segments )
        , test "invalid slots do not alter the track or interrupt a run" <|
            \_ ->
                let
                    running =
                        ready |> step Marble.Launch
                in
                Expect.equal running (running |> step (Marble.CycleSegment -1) |> step (Marble.CycleSegment 3))
        , test "changing a segment during a run returns the marble to start" <|
            \_ ->
                ready |> step Marble.Launch |> step (Marble.CycleSegment 0) |> .phase |> Expect.equal Marble.Ready
        , test "changing camera keeps the current run alive" <|
            \_ ->
                let
                    following =
                        ready |> step Marble.Launch |> step (Marble.ChooseCamera Marble.Follow)
                in
                Expect.equal ( Marble.Running, Marble.Follow ) ( following.phase, following.camera )
        , test "changing color resets the marble" <|
            \_ ->
                let
                    colored =
                        ready |> step Marble.Launch |> step (Marble.ChooseColor Marble.Mint)
                in
                Expect.equal ( Marble.Ready, Marble.Mint ) ( colored.phase, colored.color )
        , test "finish and replay can be repeated" <|
            \_ ->
                ready |> step Marble.Launch |> step (event "marble" "finished") |> step Marble.Launch |> .phase |> Expect.equal Marble.Running
        , test "reset ignores a late finished event" <|
            \_ ->
                ready |> step Marble.Launch |> step Marble.Reset |> step (event "marble" "finished") |> .phase |> Expect.equal Marble.Ready
        , test "other pages and malformed events cannot start the renderer" <|
            \_ ->
                Tuple.first Marble.init |> step (event "robot" "ready") |> step (Marble.Received Encode.null) |> .phase |> Expect.equal Marble.Loading
        , test "a failed renderer cannot be launched or customized" <|
            \_ ->
                let
                    failed =
                        ready |> step (event "marble" "error")
                in
                Expect.equal failed (failed |> step Marble.Launch |> step Marble.Reset |> step (Marble.CycleSegment 0))
        ]
