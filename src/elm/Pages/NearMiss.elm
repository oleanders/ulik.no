module Pages.NearMiss exposing (Model, Msg(..), Phase(..), Shot, angle, gap, init, points, speed, subscriptions, update, view)

import Browser.Events
import Html exposing (Html, button, div, h1, p, span, strong, text)
import Html.Attributes exposing (attribute, class, disabled, type_)
import Html.Events exposing (onClick, preventDefaultOn)
import Json.Decode as Decode
import Svg
import Svg.Attributes as S


type Phase
    = Aiming
    | Flying Shot Float
    | Missed Shot
    | Crashed Shot


type alias Shot =
    { angle : Float, gap : Float, closest : Float }


type alias Model =
    { phase : Phase, clock : Float, score : Int, round : Int, best : Int }


type Msg
    = Tick Float
    | Act
    | Ignore


init : ( Model, Cmd Msg )
init =
    ( { phase = Aiming, clock = 0, score = 0, round = 1, best = 0 }, Cmd.none )


speed : Int -> Float
speed round =
    min 2.3 (0.85 + toFloat (round - 1) * 0.09)


angle : Model -> Float
angle model =
    -0.45 + 0.5 * sin (model.clock * speed model.round)



-- Distance between the edges of the marble (r=7) and target (r=28).
-- Projection onto the shot ray gives the actual closest approach, independent
-- of frame rate; contact, including tangency, ends the round.


gap : Float -> Float
gap direction =
    abs (250 * sin direction + 120 * cos direction) - 35


points : Float -> Int
points distance =
    if distance <= 0 then
        0

    else
        max 1 (round (100 * e ^ (-distance / 18)))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( case msg of
        Ignore ->
            model

        Act ->
            case model.phase of
                Aiming ->
                    let
                        direction =
                            angle model

                        shot =
                            { angle = direction, gap = gap direction, closest = 250 * cos direction - 120 * sin direction }
                    in
                    { model | phase = Flying shot 0 }

                Flying _ _ ->
                    model

                Missed _ ->
                    { model | phase = Aiming, round = model.round + 1, clock = model.clock + 1.7 }

                Crashed _ ->
                    { model | phase = Aiming, score = 0, round = 1, clock = 0 }

        Tick milliseconds ->
            let
                dt =
                    clamp 0 40 milliseconds / 1000
            in
            case model.phase of
                Aiming ->
                    { model | clock = model.clock + dt }

                Flying shot travel ->
                    let
                        -- Brief slow passage makes a narrow clearance readable.
                        velocity =
                            if abs (travel - shot.closest) < 48 then
                                110

                            else
                                430

                        next =
                            travel + velocity * dt

                        collision =
                            shot.closest - sqrt (max 0 (35 ^ 2 - (shot.gap + 35) ^ 2))

                        score =
                            model.score + points shot.gap
                    in
                    if shot.gap <= 0 && next >= collision then
                        { model | phase = Crashed shot }

                    else if next >= shot.closest + 85 then
                        { model | phase = Missed shot, score = score, best = max model.best score }

                    else
                        { model | phase = Flying shot next }

                _ ->
                    model
    , Cmd.none
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.phase of
        Aiming ->
            Browser.Events.onAnimationFrameDelta Tick

        Flying _ _ ->
            Browser.Events.onAnimationFrameDelta Tick

        _ ->
            Sub.none


view : Model -> Html Msg
view model =
    let
        ( ( direction, travel ), ( label, message, status ) ) =
            case model.phase of
                Aiming ->
                    ( ( angle model, 0 ), ( "Skyt", "Vent på vinkelen. Bom så vidt du kan.", "aiming" ) )

                Flying shot distance ->
                    ( ( shot.angle, distance ), ( "På vei …", "", "flying" ) )

                Missed shot ->
                    ( ( shot.angle, shot.closest ), ( "Neste skudd", clearance shot.gap ++ " klaring · +" ++ String.fromInt (points shot.gap) ++ " poeng", "missed" ) )

                Crashed shot ->
                    ( ( shot.angle, shot.closest - sqrt (max 0 (35 ^ 2 - (shot.gap + 35) ^ 2)) ), ( "Prøv igjen", "Treff. Runde over. En liten bom er bedre!", "crashed" ) )

        x =
            70 + travel * cos direction

        y =
            330 + travel * sin direction

        moving =
            case model.phase of
                Flying _ _ ->
                    True

                _ ->
                    False
    in
    div [ class "near-miss-page", attribute "data-phase" status ]
        [ div [ class "near-miss-heading" ]
            [ p [ class "near-miss-eyebrow" ] [ text "ET LITE SPILL OM Å BOMME" ]
            , h1 [] [ text "bom", span [] [ text "≠" ], text "feil" ]
            , p [] [ text "Nærmere gir mer. Treffer du, er det over." ]
            ]
        , div [ class "near-miss-stats" ]
            [ stat "POENG" (String.fromInt model.score)
            , stat "SKUDD" (String.fromInt model.round)
            , stat "BEST HER" (String.fromInt model.best)
            ]
        , div [ class "near-miss-arena" ]
            [ Svg.svg [ S.viewBox "0 0 440 400", attribute "role" "img", attribute "aria-label" "En kule nederst til venstre sikter mot en rund hindring. Trykk Skyt når siktelinjen akkurat går klar." ]
                [ Svg.defs [] [ Svg.radialGradient [ S.id "near-glow" ] [ Svg.stop [ S.offset "0%", S.stopColor "#d7ff91", S.stopOpacity "0.1" ] [], Svg.stop [ S.offset "100%", S.stopColor "#d7ff91", S.stopOpacity "0" ] [] ] ]
                , Svg.circle [ S.cx "320", S.cy "210", S.r "105", S.fill "url(#near-glow)" ] []
                , Svg.line [ S.x1 "70", S.y1 "330", S.x2 (String.fromFloat (70 + 450 * cos direction)), S.y2 (String.fromFloat (330 + 450 * sin direction)), S.stroke "#72857a", S.strokeWidth "1", S.strokeDasharray "3 8" ] []
                , Svg.circle [ S.cx "320", S.cy "210", S.r "35", S.fill "none", S.stroke "#64785e", S.strokeDasharray "2 5" ] []
                , Svg.circle [ S.cx "320", S.cy "210", S.r "28", S.fill "#d7ff91" ] []
                , Svg.circle [ S.cx "70", S.cy "330", S.r "16", S.fill "none", S.stroke "#52675d" ] []
                , Svg.circle
                    [ S.cx (String.fromFloat x)
                    , S.cy (String.fromFloat y)
                    , S.r "7"
                    , S.fill
                        (if status == "crashed" then
                            "#ff886f"

                         else
                            "#ffffff"
                        )
                    ]
                    []
                , Svg.text_ [ S.x "320", S.y "158", S.textAnchor "middle", S.fill "#a8b79d", S.fontSize "10", S.letterSpacing "2" ] [ Svg.text "IKKE TREFF" ]
                ]
            ]
        , p [ class "near-miss-result", attribute "aria-live" "polite", attribute "role" "status" ] [ text message ]
        , button
            [ class "near-miss-action"
            , type_ "button"
            , disabled moving
            , onClick Act
            , preventDefaultOn "keydown"
                (Decode.field "repeat" Decode.bool
                    |> Decode.andThen
                        (\repeating ->
                            if repeating then
                                Decode.succeed ( Ignore, True )

                            else
                                Decode.fail "native key activation"
                        )
                )
            ]
            [ text label, span [ attribute "aria-hidden" "true" ] [ text " ↗" ] ]
        , p [ class "near-miss-help" ] [ text "Trykk knappen · eller Tab og mellomrom / Enter" ]
        , p [ class "near-miss-rules" ] [ text "Den prikkede linjen er kulens bane. Poeng måles fra kant til kant ved nærmeste passering. Siktet blir litt raskere for hvert skudd. Ingen tidsfrist." ]
        ]


stat : String -> String -> Html Msg
stat label value =
    div [] [ span [] [ text label ], strong [] [ text value ] ]


clearance : Float -> String
clearance distance =
    (if distance < 0.1 then
        "< 0,1"

     else
        String.replace "." "," (String.fromFloat (toFloat (round (distance * 10)) / 10))
    )
        ++ " px"
