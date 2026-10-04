module Pages.Illusions exposing (Circle, IllusionId(..), Model, Msg(..), contextOpacity, illusions, init, lineEndpoints, subscriptions, surroundingCircles, targetColor, targetLength, targetRadius, update, view)

import Html exposing (Html, a, button, div, h1, h2, input, label, p, section, span, strong, text)
import Html.Attributes as Attr exposing (attribute, class, disabled, href, id, type_, value)
import Html.Events exposing (onClick, onInput)
import Svg exposing (Svg)
import Svg.Attributes as SvgAttr


type IllusionId
    = Color
    | Circles
    | Lines


type alias Illusion =
    { id : IllusionId
    , number : Int
    , title : String
    , question : String
    , description : String
    , measurement : String
    , explanation : String
    , source : String
    , sourceLabel : String
    }


type alias Model =
    { selected : IllusionId
    , revealed : Bool
    , strength : Int
    }


type Msg
    = Select IllusionId
    | ToggleReveal
    | SetStrength String
    | Reset


type alias Circle =
    { x : Float, y : Float, radius : Float }


targetColor : String
targetColor =
    "#82978b"


targetRadius : Int
targetRadius =
    28


targetLength : Int
targetLength =
    280


init : ( Model, Cmd Msg )
init =
    ( { selected = Color, revealed = False, strength = 100 }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( case msg of
        Select selected ->
            { selected = selected, revealed = False, strength = 100 }

        ToggleReveal ->
            { model | revealed = not model.revealed }

        SetStrength input ->
            { model | strength = clamp 0 100 (Maybe.withDefault model.strength (String.toInt input)) }

        Reset ->
            { model | revealed = False, strength = 100 }
    , Cmd.none
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


contextOpacity : Int -> Bool -> Float
contextOpacity strength revealed =
    if revealed then
        0

    else
        toFloat (clamp 0 100 strength) / 100


surroundingCircles : Float -> Float -> Float -> List Circle
surroundingCircles x radius distance =
    List.range 0 5
        |> List.map
            (\index ->
                let
                    angle =
                        toFloat index / 6 * pi * 2
                in
                { x = x + cos angle * distance
                , y = 135 + sin angle * distance
                , radius = radius
                }
            )


lineEndpoints : { x1 : Int, x2 : Int }
lineEndpoints =
    { x1 = 220, x2 = 220 + targetLength }


illusion : IllusionId -> Illusion
illusion selected =
    case selected of
        Color ->
            { id = Color
            , number = 1
            , title = "Samme farge"
            , question = "Ser A og B ut som samme farge?"
            , description = "To like fargefelt på ulik bakgrunn."
            , measurement = "Begge feltene: " ++ targetColor ++ "."
            , explanation = "Begge feltene har nøyaktig samme fargekode. En lys bakgrunn kan få et felt til å se mørkere ut, og en mørk bakgrunn kan få det til å se lysere ut. Dette kalles simultankontrast."
            , source = "https://annex.exploratorium.edu/exhibits/mix_n_match/"
            , sourceLabel = "Exploratorium om farge og kontrast"
            }

        Circles ->
            { id = Circles
            , number = 2
            , title = "Samme sirkel"
            , question = "Hvilken midtsirkel ser størst ut, A eller B?"
            , description = "To like midtsirkler, omgitt av store og små sirkler."
            , measurement = "Begge midtsirklene: radius " ++ String.fromInt targetRadius ++ " i tegningen."
            , explanation = "Midtsirklene har samme radius. Størrelsen og plasseringen på sirklene rundt kan påvirke hvor store de ser ut. Dette er Ebbinghaus-illusjonen. Fjern omgivelsene og sammenlign igjen."
            , source = "https://michaelbach.de/ot/cog-Ebbinghaus/index.html"
            , sourceLabel = "Michael Bach om Ebbinghaus-illusjonen"
            }

        Lines ->
            { id = Lines
            , number = 3
            , title = "Samme linje"
            , question = "Ser den vannrette linjen A eller B lengst ut?"
            , description = "To like vannrette linjer med vinkler i ulike retninger ved endene."
            , measurement = "Begge strekene: " ++ String.fromInt targetLength ++ " enheter i tegningen."
            , explanation = "De vannrette strekene har samme lengde. Vinklene ved endene kan påvirke hvordan vi bedømmer lengden. Dette er Müller-Lyer-illusjonen. Målelinjene viser hvor strekene begynner og slutter."
            , source = "https://michaelbach.de/ot/sze-muelue/index.html"
            , sourceLabel = "Michael Bach om Müller-Lyer-illusjonen"
            }


illusions : List Illusion
illusions =
    List.map illusion [ Color, Circles, Lines ]


view : Model -> Html Msg
view model =
    let
        current =
            illusion model.selected
    in
    section [ class "illusions-page terminal-panel experiment", attribute "aria-labelledby" "illusion-title" ]
        [ div [ class "heading" ]
            [ div []
                [ p [ class "prompt" ] [ text "$ ./lik --se-en-gang-til" ]
                , h1 [ id "illusion-title" ] [ text "lik≠lik" ]
                ]
            , p [] [ text "Det du ser ", span [ attribute "aria-hidden" "true" ] [ text "≠" ], text " det du måler." ]
            ]
        , div [ class "choices", attribute "role" "group", attribute "aria-label" "Velg illusjon" ]
            (List.map (choice model.selected) illusions)
        , div [ class "question" ]
            [ h2 [] [ text current.question ]
            , span [] [ text (String.fromInt current.number ++ " / 3") ]
            ]
        , div [ class "stage" ] [ scene model current ]
        , controlsView model
        , div [ class "answer", attribute "aria-live" "polite", attribute "aria-atomic" "true" ]
            (if model.revealed then
                [ strong [] [ text "A = B. Helt likt." ]
                , p [] [ text current.measurement ]
                , p [] [ text current.explanation ]
                ]

             else
                [ strong [] [ text "Stol på øynene. Så sjekker du." ]
                , p [] [ text "Trykk «Avslør likheten», eller dra ned omgivelsene. Selve feltene, sirklene og strekene endres ikke." ]
                ]
            )
        , div [ class "bottom" ]
            [ a [ href current.source, Attr.target "_blank", Attr.rel "noreferrer" ]
                [ text "Les om fenomenet ↗"
                , span [ class "sr-only" ] [ text (": " ++ current.sourceLabel ++ " (åpnes i ny fane)") ]
                ]
            , p [] [ text "Opplevelsen kan variere fra person til person. Ingen fasit på hva du ser." ]
            ]
        , Html.node "noscript"
            []
            [ p [] [ text ("Slå på JavaScript for å bruke kontrollene. I tegningen over er begge feltene " ++ targetColor ++ ".") ]
            ]
        ]


choice : IllusionId -> Illusion -> Html Msg
choice selected option =
    button [ type_ "button", pressed (selected == option.id), onClick (Select option.id) ]
        [ span [] [ text ("0" ++ String.fromInt option.number) ]
        , text (" " ++ option.title)
        ]


pressed : Bool -> Html.Attribute msg
pressed isPressed =
    attribute "aria-pressed"
        (if isPressed then
            "true"

         else
            "false"
        )


controlsView : Model -> Html Msg
controlsView model =
    let
        visibleStrength =
            if model.revealed then
                0

            else
                model.strength
    in
    div [ class "controls" ]
        [ button [ class "reveal", type_ "button", pressed model.revealed, onClick ToggleReveal ]
            [ text
                (if model.revealed then
                    "Vis illusjonen igjen"

                 else
                    "Avslør likheten"
                )
            ]
        , button [ type_ "button", onClick Reset ] [ text "Nullstill" ]
        , div [ class "slider" ]
            [ label [ Attr.for "context-strength" ]
                [ text "Omgivelser "
                , Html.output [ Attr.for "context-strength" ] [ text (String.fromInt visibleStrength ++ "%") ]
                ]
            , input
                [ id "context-strength"
                , type_ "range"
                , Attr.min "0"
                , Attr.max "100"
                , Attr.step "1"
                , value (String.fromInt visibleStrength)
                , onInput SetStrength
                , disabled model.revealed
                , attribute "aria-describedby" "slider-help"
                ]
                []
            , span [ id "slider-help" ] [ text "Dra mot 0 for å se uten omgivelsene." ]
            ]
        ]


scene : Model -> Illusion -> Svg Msg
scene model current =
    Svg.svg
        [ SvgAttr.viewBox "0 0 720 310"
        , attribute "role" "img"
        , attribute "aria-labelledby" "scene-title scene-description"
        ]
        (Svg.title [ SvgAttr.id "scene-title" ] [ Svg.text current.question ]
            :: Svg.desc [ SvgAttr.id "scene-description" ]
                [ Svg.text (current.description ++ " Bruk kontrollene under bildet for å fjerne omgivelsene og vise målene.") ]
            :: (case model.selected of
                    Color ->
                        colorScene model

                    Circles ->
                        circleScene model

                    Lines ->
                        lineScene model
               )
        )


contextAttributes : Model -> List (Svg.Attribute msg)
contextAttributes model =
    [ SvgAttr.opacity (String.fromFloat (contextOpacity model.strength model.revealed))
    , attribute "data-testid" "context"
    ]


colorScene : Model -> List (Svg Msg)
colorScene model =
    [ Svg.g (contextAttributes model)
        [ Svg.rect [ SvgAttr.width "360", SvgAttr.height "260", SvgAttr.fill "#101612" ] []
        , Svg.rect [ SvgAttr.x "360", SvgAttr.width "360", SvgAttr.height "260", SvgAttr.fill "#e2e8e4" ] []
        ]
    ]
        ++ List.map
            (\x ->
                Svg.rect
                    [ attribute "data-testid" "color-target"
                    , SvgAttr.x (String.fromInt (x - 48))
                    , SvgAttr.y "82"
                    , SvgAttr.width "96"
                    , SvgAttr.height "96"
                    , SvgAttr.fill targetColor
                    ]
                    []
            )
            [ 180, 540 ]
        ++ [ sceneLabel "180" "292" "A", sceneLabel "540" "292" "B" ]


circleScene : Model -> List (Svg Msg)
circleScene model =
    [ Svg.g (SvgAttr.fill "#427167" :: contextAttributes model)
        (List.map
            (\circle ->
                Svg.circle
                    [ SvgAttr.cx (String.fromFloat circle.x)
                    , SvgAttr.cy (String.fromFloat circle.y)
                    , SvgAttr.r (String.fromFloat circle.radius)
                    ]
                    []
            )
            (surroundingCircles 180 43 89 ++ surroundingCircles 540 13 48)
        )
    ]
        ++ List.map
            (\x ->
                Svg.circle
                    [ attribute "data-testid" "circle-target"
                    , SvgAttr.cx x
                    , SvgAttr.cy "135"
                    , SvgAttr.r (String.fromInt targetRadius)
                    , SvgAttr.fill "#ffc879"
                    ]
                    []
            )
            [ "180", "540" ]
        ++ (if model.revealed then
                [ measure "M152 175 H208 M152 167 V183 M208 167 V183 M512 175 H568 M512 167 V183 M568 167 V183" ]

            else
                []
           )
        ++ [ sceneLabel "180" "292" "A", sceneLabel "540" "292" "B" ]


lineScene : Model -> List (Svg Msg)
lineScene model =
    [ Svg.g
        (contextAttributes model
            ++ [ SvgAttr.stroke "#86c6b4", SvgAttr.strokeWidth "5", SvgAttr.fill "none", SvgAttr.strokeLinecap "butt" ]
        )
        [ Svg.path [ SvgAttr.d "M264 45 L220 90 L264 135 M456 45 L500 90 L456 135" ] []
        , Svg.path [ SvgAttr.d "M176 175 L220 220 L176 265 M544 175 L500 220 L544 265" ] []
        ]
    ]
        ++ List.map
            (\y ->
                Svg.line
                    [ attribute "data-testid" "line-target"
                    , SvgAttr.x1 (String.fromInt lineEndpoints.x1)
                    , SvgAttr.x2 (String.fromInt lineEndpoints.x2)
                    , SvgAttr.y1 y
                    , SvgAttr.y2 y
                    , SvgAttr.stroke "#ffc879"
                    , SvgAttr.strokeWidth "5"
                    ]
                    []
            )
            [ "90", "220" ]
        ++ [ sceneLabel "105" "98" "A", sceneLabel "105" "228" "B" ]
        ++ (if model.revealed then
                [ measure "M220 50 V260 M500 50 V260 M220 155 H500" ]

            else
                []
           )


sceneLabel : String -> String -> String -> Svg msg
sceneLabel x y caption =
    Svg.text_ [ SvgAttr.x x, SvgAttr.y y ] [ Svg.text caption ]


measure : String -> Svg msg
measure path =
    Svg.path [ SvgAttr.class "measure", SvgAttr.d path ] []
