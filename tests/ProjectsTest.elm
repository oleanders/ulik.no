module ProjectsTest exposing (tests)

import Expect
import Projects exposing (Id(..), Status(..))
import Set
import Test exposing (Test, describe, test)


tests : Test
tests =
    describe "Project discovery"
        [ test "all ten projects have unique routable identifiers" <|
            \_ ->
                Expect.equal 10 (Projects.all |> List.map (.id >> Projects.slug) |> Set.fromList |> Set.size)
        , test "slugs round-trip through routing" <|
            \_ ->
                Projects.all |> List.all (\project -> Projects.fromSlug (Projects.slug project.id) == Just project.id) |> Expect.equal True
        , test "every card has meaningful metadata" <|
            \_ ->
                Projects.all |> List.all (\project -> not (List.isEmpty project.tags) && String.length project.hook > 5 && String.length project.interaction > 5 && String.length (Projects.categoryLabel project.category) > 0) |> Expect.equal True
        , test "surprise excludes placeholders and the current project" <|
            \_ ->
                Projects.all |> List.all (\current -> Projects.surpriseCandidates (Just current.id) |> List.all (\project -> project.status == Active && project.id /= current.id)) |> Expect.equal True
        , test "onward routes are active and distinct" <|
            \_ ->
                Projects.all
                    |> List.all
                        (\current ->
                            let
                                ( related, different ) =
                                    Projects.onward current.id

                                valid next =
                                    next.id /= current.id && next.status == Active
                            in
                            Maybe.map valid related == Just True && Maybe.map (\next -> valid next && next.category /= current.category && Just next.id /= Maybe.map .id related) different == Just True
                        )
                    |> Expect.equal True
        , test "unknown routes are not invented" <| \_ -> Expect.equal Nothing (Projects.fromSlug "unknown")
        ]
