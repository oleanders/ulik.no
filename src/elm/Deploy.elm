module Deploy exposing (Model, Msg, init, subscriptions, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as Decode
import Time


type Status
    = Running
    | Success
    | Failure
    | Cancelled
    | Other String


type alias Run =
    { url : String, status : Status }


type Model
    = Loading
    | Unavailable
    | NoDeploy
    | Latest Run


type Msg
    = Fetched (Result Http.Error (List Run))
    | Refresh Time.Posix


init : ( Model, Cmd Msg )
init =
    ( Loading, fetch )


fetch : Cmd Msg
fetch =
    Http.get { url = "https://api.github.com/repos/oleanders/ulik.no/actions/runs?per_page=20", expect = Http.expectJson Fetched decoder }


decoder : Decode.Decoder (List Run)
decoder =
    Decode.field "workflow_runs"
        (Decode.list
            (Decode.map4
                (\name url status conclusion ->
                    ( name
                    , { url = url
                      , status =
                            if List.member status [ "in_progress", "queued", "pending", "waiting", "requested" ] then
                                Running

                            else
                                case conclusion of
                                    Just "success" ->
                                        Success

                                    Just "failure" ->
                                        Failure

                                    Just "cancelled" ->
                                        Cancelled

                                    _ ->
                                        Other (Maybe.withDefault status conclusion)
                      }
                    )
                )
                (Decode.field "name" Decode.string)
                (Decode.field "html_url" Decode.string)
                (Decode.field "status" Decode.string)
                (Decode.field "conclusion" (Decode.nullable Decode.string))
            )
        )
        |> Decode.map (List.filter (\( name, _ ) -> List.member name [ "Deploy to beta on push to main", "Deploy to production when release is published" ]) >> List.map Tuple.second)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Refresh _ ->
            ( model, fetch )

        Fetched (Err _) ->
            ( Unavailable, Cmd.none )

        Fetched (Ok []) ->
            ( NoDeploy, Cmd.none )

        Fetched (Ok (run :: _)) ->
            ( Latest run, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Time.every
        (case model of
            Latest { status } ->
                if status == Running then
                    15000

                else
                    60000

            _ ->
                60000
        )
        Refresh


view : Model -> Html Msg
view model =
    let
        ( label, dot ) =
            case model of
                Loading ->
                    ( "laster deploy-status…", "idle" )

                Unavailable ->
                    ( "status utilgjengelig", "idle" )

                NoDeploy ->
                    ( "ingen deploy registrert", "idle" )

                Latest run ->
                    case run.status of
                        Running ->
                            ( "deploy pågår", "live" )

                        Success ->
                            ( "siste deploy ok", "ok" )

                        Failure ->
                            ( "siste deploy feilet", "fail" )

                        Cancelled ->
                            ( "siste deploy avbrutt", "idle" )

                        Other state ->
                            ( "siste deploy: " ++ state, "idle" )

        content =
            [ span [ class ("dot " ++ dot), attribute "aria-hidden" "true" ] [], span [] [ text label ] ]
    in
    div [ class "deploy-status" ]
        [ case model of
            Latest run ->
                a [ class "status", href run.url, target "_blank", rel "noreferrer" ] content

            _ ->
                span [ class "status" ] content
        ]
