module ToolsTest exposing (tests)

import Expect
import Json.Encode as Encode
import Pages.Diff as Diff
import Pages.Illusions as Illusions
import Pages.Screen as Screen
import Test exposing (Test, describe, test)


tests : Test
tests =
    describe "Small tools and optical illusions"
        [ describe "Diff"
            [ test "line statistics count lines and word statistics count characters" <|
                \_ ->
                    let
                        changes =
                            [ { value = "same", count = 1, added = False, removed = False }
                            , { value = "new\nline\n", count = 2, added = True, removed = False }
                            , { value = "old\n", count = 1, added = False, removed = True }
                            ]
                    in
                    Expect.equal
                        ( { added = 2, removed = 1 }, { added = 9, removed = 4 } )
                        ( Diff.statistics Diff.Lines changes, Diff.statistics Diff.Words changes )
            , test "swap and clear keep comparison state in Elm" <|
                \_ ->
                    let
                        initial =
                            Tuple.first Diff.init

                        swapped =
                            Tuple.first (Diff.update Diff.Swap initial)

                        cleared =
                            Tuple.first (Diff.update Diff.Clear swapped)
                    in
                    Expect.equal
                        [ initial.right, initial.left, "", "" ]
                        [ swapped.left, swapped.right, cleared.left, cleared.right ]
            , test "ignores stale browser results after a newer edit" <|
                \_ ->
                    let
                        initial =
                            Tuple.first Diff.init

                        edited =
                            Tuple.first (Diff.update (Diff.EditLeft "changed") initial)

                        received =
                            Tuple.first
                                (Diff.update
                                    (Diff.Received
                                        (Encode.object
                                            [ ( "domain", Encode.string "diff" )
                                            , ( "revision", Encode.int initial.revision )
                                            , ( "changes"
                                              , Encode.list identity
                                                    [ Encode.object
                                                        [ ( "value", Encode.string "stale" )
                                                        , ( "count", Encode.int 1 )
                                                        , ( "added", Encode.bool True )
                                                        , ( "removed", Encode.bool False )
                                                        ]
                                                    ]
                                              )
                                            ]
                                        )
                                    )
                                    edited
                                )
                    in
                    Expect.equal [] received.changes
            ]
        , describe "Screen sharing"
            [ test "a browser start event updates the label and enables sharing controls" <|
                \_ ->
                    let
                        initial =
                            Tuple.first Screen.init

                        started =
                            Tuple.first
                                (Screen.update
                                    (screenEvent "started" [ ( "sourceLabel", Encode.string "Test window" ) ])
                                    initial
                                )
                    in
                    Expect.equal
                        ( Screen.Sharing, "Test window", "Skjermdeling er aktiv." )
                        ( started.shareState, started.sourceLabel, started.statusText )
            , test "external stop clears the source and announces the browser stop" <|
                \_ ->
                    let
                        initial =
                            Tuple.first Screen.init

                        stopped =
                            Tuple.first (Screen.update (screenEvent "stopped" []) initial)
                    in
                    Expect.equal
                        ( Screen.Idle, "Ingen aktiv kilde", "Skjermdeling ble stoppet fra nettleseren." )
                        ( stopped.shareState, stopped.sourceLabel, stopped.statusText )
            , test "an API failure retains its useful error message" <|
                \_ ->
                    let
                        failed =
                            Tuple.first
                                (Screen.update
                                    (screenEvent "error" [ ( "message", Encode.string "Fant ingen skjermkilder å dele." ) ])
                                    (Tuple.first Screen.init)
                                )
                    in
                    Expect.equal
                        ( Screen.Error, "Fant ingen skjermkilder å dele." )
                        ( failed.shareState, failed.statusText )
            ]
        , describe "Illusion invariants"
            [ test "three distinct curated scenes retain their reference sources" <|
                \_ ->
                    Expect.equal
                        ( [ Illusions.Color, Illusions.Circles, Illusions.Lines ], True )
                        ( List.map .id Illusions.illusions
                        , List.all (\scene -> String.startsWith "https://" scene.source) Illusions.illusions
                        )
            , test "only context opacity changes, and reveal removes it entirely" <|
                \_ ->
                    Expect.equal
                        [ [ 0, 0.25, 0.5, 0.75, 1 ], [ 0, 0, 0, 0, 0 ], [ 0, 1 ] ]
                        [ List.map (\strength -> Illusions.contextOpacity strength False) [ 0, 25, 50, 75, 100 ]
                        , List.map (\strength -> Illusions.contextOpacity strength True) [ 0, 25, 50, 75, 100 ]
                        , [ Illusions.contextOpacity -20 False, Illusions.contextOpacity 120 False ]
                        ]
            , test "target color, radius and line length remain fixed" <|
                \_ ->
                    Expect.equal
                        ( "#82978b", [ 28, 280, 280 ] )
                        ( Illusions.targetColor
                        , [ Illusions.targetRadius
                          , Illusions.targetLength
                          , Illusions.lineEndpoints.x2 - Illusions.lineEndpoints.x1
                          ]
                        )
            , test "each ring contains six circles at the intended distance" <|
                \_ ->
                    let
                        validRing center radius distance =
                            let
                                ring =
                                    Illusions.surroundingCircles center radius distance
                            in
                            List.length ring
                                == 6
                                && List.all
                                    (\circle ->
                                        circle.radius
                                            == radius
                                            && abs (sqrt ((circle.x - center) ^ 2 + (circle.y - 135) ^ 2) - distance)
                                            < 0.00001
                                            && distance
                                            - radius
                                            > toFloat Illusions.targetRadius
                                    )
                                    ring
                    in
                    Expect.equal True (validRing 180 43 89 && validRing 540 13 48)
            , test "switching scenes resets reveal and surrounding strength" <|
                \_ ->
                    let
                        initial =
                            Tuple.first Illusions.init

                        changed =
                            initial
                                |> Illusions.update (Illusions.SetStrength "25")
                                |> Tuple.first
                                |> Illusions.update Illusions.ToggleReveal
                                |> Tuple.first
                                |> Illusions.update (Illusions.Select Illusions.Circles)
                                |> Tuple.first
                    in
                    Expect.equal ( Illusions.Circles, False, 100 ) ( changed.selected, changed.revealed, changed.strength )
            , test "reveal restores the previous slider value, while reset restores 100" <|
                \_ ->
                    let
                        changed =
                            Tuple.first Illusions.init
                                |> Illusions.update (Illusions.SetStrength "37")
                                |> Tuple.first
                                |> Illusions.update Illusions.ToggleReveal
                                |> Tuple.first
                                |> Illusions.update Illusions.ToggleReveal
                                |> Tuple.first

                        reset =
                            Tuple.first (Illusions.update Illusions.Reset changed)
                    in
                    Expect.equal ( ( False, 37 ), ( False, 100 ) ) ( ( changed.revealed, changed.strength ), ( reset.revealed, reset.strength ) )
            ]
        ]


screenEvent : String -> List ( String, Encode.Value ) -> Screen.Msg
screenEvent action fields =
    Screen.Received
        (Encode.object
            (( "domain", Encode.string "screen" )
                :: ( "action", Encode.string action )
                :: fields
            )
        )
