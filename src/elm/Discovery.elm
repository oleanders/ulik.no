module Discovery exposing (Filter(..), Model, Msg, init, onward, subscriptions, update, viewCatalog, viewHome)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports
import Projects exposing (Category(..), Id, Project, Status(..))
import Random


type Filter
    = All
    | Category Category


type Playback
    = Playing
    | Paused


type alias Model =
    { filter : Filter, playback : Playback, reducedMotion : Bool }


type Msg
    = FilterBy Filter
    | Toggle
    | NewPattern
    | Received Decode.Value
    | Surprise (Maybe Id)
    | Picked Id


init : Model
init =
    { filter = All, playback = Paused, reducedMotion = False }


update : Msg -> Model -> ( Model, Cmd Msg, Maybe Id )
update msg model =
    case msg of
        FilterBy filter ->
            ( { model | filter = filter }, Cmd.none, Nothing )

        Toggle ->
            let
                playing =
                    model.playback == Paused
            in
            ( { model
                | playback =
                    if playing then
                        Playing

                    else
                        Paused
              }
            , command "play" [ ( "playing", Encode.bool playing ) ]
            , Nothing
            )

        NewPattern ->
            ( model, command "pattern" [], Nothing )

        Surprise excluded ->
            case Projects.surpriseCandidates excluded of
                first :: rest ->
                    ( model, Random.generate (Picked << .id) (Random.uniform first rest), Nothing )

                [] ->
                    ( model, Cmd.none, Nothing )

        Picked id ->
            ( model, Cmd.none, Just id )

        Received value ->
            case Decode.decodeValue (Decode.map3 (\domain reduced playing -> ( domain, reduced, playing )) (Decode.field "domain" Decode.string) (Decode.field "reducedMotion" Decode.bool) (Decode.field "playing" Decode.bool)) value of
                Ok ( "preview", reduced, playing ) ->
                    ( { model
                        | reducedMotion = reduced
                        , playback =
                            if playing then
                                Playing

                            else
                                Paused
                      }
                    , Cmd.none
                    , Nothing
                    )

                _ ->
                    ( model, Cmd.none, Nothing )


command : String -> List ( String, Encode.Value ) -> Cmd msg
command action fields =
    Ports.send (Encode.object (( "domain", Encode.string "preview" ) :: ( "action", Encode.string action ) :: fields))


subscriptions : Model -> Sub Msg
subscriptions _ =
    Ports.receive Received


surprise : Maybe Id -> Html Msg
surprise excluded =
    button [ class "surprise", type_ "button", onClick (Surprise excluded) ] [ text "Overrask meg" ]


card : Project -> Html msg
card project =
    a [ class "project-card card", href (Projects.href project.id) ]
        [ img [ src ("/previews/" ++ Projects.slug project.id ++ ".svg"), width 360, height 160, alt "", attribute "aria-hidden" "true" ] []
        , div [ class "body" ]
            [ div [ class "meta" ]
                [ span [] [ text (Projects.categoryLabel project.category) ]
                , if project.status == Active then
                    text ""

                  else
                    span [ class "status" ] [ text "Under arbeid" ]
                ]
            , h2 [] [ text project.title ]
            , p [] [ text project.hook ]
            , div [ class "foot" ] [ span [] [ text project.interaction ], span [ class "arrow", attribute "aria-hidden" "true" ] [ text "↗" ] ]
            ]
        ]


viewHome : Model -> Html Msg
viewHome model =
    div [ class "home-page" ]
        [ section [ class "hero terminal-panel", attribute "aria-labelledby" "home-title" ]
            [ div [ class "intro" ]
                [ p [ class "prompt" ] [ text "$ ./ulik --utforsk" ]
                , h1 [ id "home-title" ] [ span [ attribute "aria-hidden" "true" ] [ text "≠" ], text " ulik.no" ]
                , p [ class "tagline" ] [ text "ulik alt annet." ]
                , p [ class "description" ] [ text "Små eksperimenter. Rare ideer.", br [] [], text "Ting du kan prøve, ikke bare lese om." ]
                , div [ class "actions" ] [ a [ class "primary", href "/projects/flyt-felt" ] [ text "Lek med flyt≠felt ", span [ attribute "aria-hidden" "true" ] [ text "→" ] ], surprise Nothing ]
                , a [ class "catalog", href "/projects" ] [ text ("Se alle " ++ String.fromInt (List.length Projects.all) ++ " prosjekter ↓") ]
                ]
            , div [ class "home-preview" ]
                [ div [ class "preview" ]
                    [ div [ class "preview-head" ] [ span [] [ text "01 / flyt≠felt" ], span [] [ text "prøv her ↓" ] ]
                    , div [ class "art" ] [ img [ class "fallback", src "/previews/flyt-felt.svg", alt "" ] [], canvas [ id "home-flow", class "ready", attribute "aria-label" "Forhåndsvisning av flyt≠felt: fargede spor som følger et strømningsfelt" ] [] ]
                    , div [ class "preview-foot" ]
                        [ p []
                            [ text
                                (if model.reducedMotion then
                                    "Et stille mønster. Start bevegelsen hvis du vil."

                                 else
                                    "Beveg pekeren eller berør bildet."
                                )
                            ]
                        , div [ class "controls" ]
                            [ button
                                [ type_ "button"
                                , onClick Toggle
                                , attribute "aria-pressed"
                                    (if model.playback == Playing then
                                        "true"

                                     else
                                        "false"
                                    )
                                ]
                                [ text
                                    (if model.playback == Playing then
                                        "Pause bevegelse"

                                     else
                                        "Start bevegelse"
                                    )
                                ]
                            , button [ type_ "button", onClick NewPattern ] [ text "Nytt mønster" ]
                            ]
                        ]
                    ]
                ]
            ]
        , section [ class "discovery", attribute "aria-labelledby" "discovery-title" ]
            [ div [ class "section-head" ] [ div [] [ p [ class "prompt" ] [ text "$ ls ./muligheter" ], h2 [ id "discovery-title" ] [ text "Hvor vil du begynne?" ] ], a [ href "/projects" ] [ text "Hele katalogen →" ] ]
            , div [ class "project-grid" ] (List.map (Projects.byId >> card) [ Projects.Marble, Projects.Morse, Projects.Diff ])
            , p [ class "note" ] [ text "Ingen konto. Bare nysgjerrighet." ]
            ]
        ]


viewCatalog : Model -> Html Msg
viewCatalog model =
    let
        visible =
            List.filter (\project -> model.filter == All || model.filter == Category project.category) Projects.all

        label filter =
            case filter of
                All ->
                    "Alle"

                Category category ->
                    Projects.categoryLabel category
    in
    div [ class "catalog-page" ]
        [ section [ class "terminal-panel page-head" ] [ p [ class "prompt" ] [ text "$ tree ./prosjekter -L 1" ], h1 [] [ text "Prosjekter" ], p [] [ text "Vil du leke, lage noe eller løse en liten floke? Velg et sidespor." ], div [] [ surprise Nothing ] ]
        , div [ class "filters", attribute "role" "group", attribute "aria-label" "Filtrer prosjekter" ]
            (List.map
                (\choice ->
                    button
                        [ type_ "button"
                        , attribute "aria-pressed"
                            (if choice == model.filter then
                                "true"

                             else
                                "false"
                            )
                        , onClick (FilterBy choice)
                        ]
                        [ text (label choice) ]
                )
                [ All, Category Play, Category Art, Category Tools ]
            )
        , p [ class "count", attribute "role" "status" ] [ text ("Viser " ++ String.fromInt (List.length visible) ++ " av " ++ String.fromInt (List.length Projects.all) ++ " prosjekter") ]
        , section [ class "project-grid", attribute "aria-label" "Prosjekter" ] (List.map card visible)
        ]


onward : Id -> Html Msg
onward current =
    let
        ( related, different ) =
            Projects.onward current

        suggestion label project =
            a [ class "suggestion", href (Projects.href project.id) ] [ span [] [ text label ], strong [] [ text (project.title ++ " ↗") ], span [] [ text project.hook ] ]
    in
    nav [ class "onward-wrapper onward terminal-panel", attribute "aria-label" "Utforsk videre" ]
        [ div [ class "head" ] [ div [] [ p [ class "prompt" ] [ text "$ cd ../neste" ], h2 [] [ text "Prøv noe mer" ] ], a [ class "catalog", href "/projects" ] [ text "Alle prosjekter →" ] ]
        , div [ class "choices" ] [ Maybe.map (suggestion "I samme spor") related |> Maybe.withDefault (text ""), Maybe.map (suggestion "Noe helt annet") different |> Maybe.withDefault (text "") ]
        , div [] [ surprise (Just current) ]
        ]
