module Main exposing (main)

import Html.Events as HE
import Html.Attributes as HA
import Html exposing (Html)
import List
import BackendTalk


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , subscriptions = subscriptions
        , view = view
        , update = update
        }


type alias Dashboard =
    String


type alias Model =
    { dashboards : Maybe (List Dashboard)
    , current_dashboard : Maybe Dashboard
    , last_error : Maybe String
    }


init : ( Model, Cmd Msg )
init =
    ( Model Nothing Nothing Nothing
    , Cmd.batch
        [ BackendTalk.sendRequestDashboardList Backend ]
    )


type Msg
    = GoToDashboardList
    | DashboardSelected String
    | Backend BackendTalk.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GoToDashboardList ->
            ( { model | current_dashboard = Nothing }, Cmd.none )

        DashboardSelected selected ->
            ( { model | current_dashboard = Just selected }, Cmd.none )

        Backend message ->
            updateBackend message model


updateBackend : BackendTalk.Msg -> Model -> ( Model, Cmd Msg )
updateBackend msg model =
    case msg of
        BackendTalk.RequestDashboardList ->
            ( model, BackendTalk.sendRequestDashboardList Backend )

        BackendTalk.DashboardList new_dashboards ->
            ( { model | dashboards = Just new_dashboards, last_error = Nothing }, Cmd.none )

        BackendTalk.Error error ->
            ( { model | last_error = Just error }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    BackendTalk.subscription Backend


view : Model -> Html Msg
view model =
    let
        dashboardButton dashboard =
            Html.button [ HE.onClick (DashboardSelected dashboard) ] [ Html.text dashboard ]
    in
        case ( model.dashboards, model.current_dashboard ) of
            ( Nothing, Nothing ) ->
                Html.div []
                    [ Html.p []
                        [ Html.text "Loading dashboard list..."
                        ]
                    ]
                    |> viewErrorOnTop model.last_error

            ( Just dashboards, Nothing ) ->
                Html.div []
                    [ Html.p []
                        [ Html.text "Pick a dashboard:"
                        ]
                    , Html.ul [] (List.map dashboardButton dashboards)
                    ]
                    |> viewErrorOnTop model.last_error

            ( _, Just dashboard ) ->
                Html.div []
                    [ Html.button [ HE.onClick GoToDashboardList ] [ Html.text "back" ]
                    , Html.p []
                        [ Html.text ("Dashboard: " ++ dashboard)
                        ]
                    ]
                    |> viewErrorOnTop model.last_error


viewErrorOnTop : Maybe String -> Html Msg -> Html Msg
viewErrorOnTop string html =
    case string of
        Nothing ->
            html

        Just error ->
            Html.div [ HA.class "error" ]
                [ Html.text ("Error: " ++ error)
                , html
                ]
