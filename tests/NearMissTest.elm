module NearMissTest exposing (tests)

import Expect
import Pages.NearMiss as Game exposing (Msg(..), Phase(..))
import Test exposing (Test, describe, test)


finish model =
    List.foldl (\_ current -> Game.update (Tick 40) current |> Tuple.first) model (List.range 1 200)


fire model =
    Game.update Act model |> Tuple.first |> finish


tests : Test
tests =
    describe "Near miss geometry and game state"
        [ test "reduced motion resolves without a flight animation" <|
            \_ ->
                let
                    initial =
                        Tuple.first Game.init

                    result =
                        Game.update Act { initial | reducedMotion = True } |> Tuple.first
                in
                Expect.equal True
                    (case result.phase of
                        Crashed _ ->
                            True

                        _ ->
                            False
                    )
        , test "direct aim intersects target" <| \_ -> Expect.within (Expect.Absolute 0.0001) -35 (Game.gap (atan2 -120 250))
        , test "horizontal shot clears by 85" <| \_ -> Expect.within (Expect.Absolute 0.0001) 85 (Game.gap 0)
        , test "closer positive clearance earns more; a hit earns zero" <| \_ -> Expect.equal ( True, 0 ) ( Game.points 0.2 > Game.points 20, Game.points -1 )
        , test "difficulty increases but is capped" <| \_ -> Expect.equal ( True, 2.3 ) ( Game.speed 4 > Game.speed 1, Game.speed 100 )
        , test "initial shot hits and restart resets score and round" <|
            \_ ->
                let
                    initial =
                        Tuple.first Game.init

                    result =
                        fire initial

                    reset =
                        Game.update Act result |> Tuple.first
                in
                Expect.equal ( True, 0, 1 )
                    ( case result.phase of
                        Crashed _ ->
                            True

                        _ ->
                            False
                    , reset.score
                    , reset.round
                    )
        , test "clear shot scores once and next shot increases difficulty" <|
            \_ ->
                let
                    initial =
                        Tuple.first Game.init

                    result =
                        fire { initial | clock = pi / (2 * Game.speed 1) }

                    later =
                        finish result

                    next =
                        Game.update Act result |> Tuple.first
                in
                Expect.equal ( True, True, 2 ) ( result.score > 0, result.score == later.score, next.round )
        , test "input while flying cannot fire twice" <|
            \_ ->
                let
                    flying =
                        Game.update Act (Tuple.first Game.init) |> Tuple.first
                in
                Expect.equal flying (Game.update Act flying |> Tuple.first)
        , test "large background delta is bounded" <|
            \_ ->
                let
                    initial =
                        Tuple.first Game.init
                in
                Expect.equal (Game.update (Tick 40) initial) (Game.update (Tick 30000) initial)
        ]
