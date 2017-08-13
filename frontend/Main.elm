module Main exposing (main)

import Dict
import Json.Decode as JsonD
import Json.Encode as JsonE
import Html.Attributes as HA
import Html.Events as HE
import Html exposing (Html)
import BackendTalk
import Elements
import Dict exposing (Dict)
import SelectionDict as Sel exposing (SelectionDict)


-- Main


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , subscriptions = subscriptions
        , view = view
        , update = update
        }



-- Model


type alias Dashboard =
    { title : String
    , graphs : List Graph
    }


type alias Graph =
    { id : String
    , title : String
    , type_ : String

    --, job_prefix_url: String
    }


type alias Model =
    { dashboards : SelectionDict String Dashboard
    , last_error : Maybe String
    }


init : ( Model, Cmd Msg )
init =
    ( { dashboards = Sel.fromList []
      , last_error = Nothing
      }
    , Cmd.batch
        [ BackendTalk.send (jsonMessage GetDashboards) ]
    )



-- Update


type Msg
    = GoToDashboardList
    | UpdateDashboardList (Dict String Dashboard)
    | DashboardSelected String
    | BackendError String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GoToDashboardList ->
            ( { model
                | dashboards = Sel.deselect model.dashboards
                , last_error = Nothing
              }
            , BackendTalk.send (jsonMessage UnselectDashboard)
            )

        DashboardSelected wanted ->
            ( { model
                | dashboards = Sel.select wanted model.dashboards
                , last_error = Nothing
              }
            , BackendTalk.send (jsonMessage (SelectDashboard wanted))
            )

        UpdateDashboardList newDashboards ->
            case Sel.transferSelection model.dashboards (Sel.fromDict newDashboards) of
                ( newSelectedDashboards, True ) ->
                    ( { model | dashboards = newSelectedDashboards }, Cmd.none )

                ( newSelectedDashboards, False ) ->
                    ( { model
                        | dashboards = newSelectedDashboards
                        , last_error = Just "The selected dashboard does not exist anymore"
                      }
                    , Cmd.none
                    )

        BackendError error ->
            ( { model | last_error = Just error }, Cmd.none )


type JsonMessage
    = GetDashboards
    | SelectDashboard String
    | UnselectDashboard


jsonMessage : JsonMessage -> String
jsonMessage msg =
    let
        object =
            case msg of
                GetDashboards ->
                    [ ( "type", JsonE.string "dashboards" ) ]

                SelectDashboard dashboard ->
                    [ ( "type", JsonE.string "select_dashboard" )
                    , ( "dashboard", JsonE.string dashboard )
                    ]

                UnselectDashboard ->
                    [ ( "type", JsonE.string "unselect_dashboard" ) ]
    in
        object |> JsonE.object |> JsonE.encode 0



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        graphDecoder =
            JsonD.map3 Graph
                (JsonD.field "id" JsonD.string)
                (JsonD.field "title" JsonD.string)
                (JsonD.field "type" JsonD.string)

        dashboardDecoder =
            JsonD.map2
                Dashboard
                (JsonD.field "title" JsonD.string)
                (JsonD.field "graphs"
                    (JsonD.list graphDecoder)
                )

        dashboardsDecoder =
            JsonD.map UpdateDashboardList
                (JsonD.field "dashboards"
                    (JsonD.dict dashboardDecoder)
                )

        messageDecoders =
            [ ( "dashboards", dashboardsDecoder )
            ]
                |> Dict.fromList

        toResult msg =
            case msg of
                Err string ->
                    BackendError string

                Ok msg ->
                    msg
    in
        BackendTalk.subscription messageDecoders |> Sub.map toResult



-- View


view : Model -> Html Msg
view model =
    let
        dashboardButton dashboard =
            Html.button [ HE.onClick (DashboardSelected dashboard) ] [ Html.text dashboard ]

        viewGraph graph =
            [ Html.h2 [] [ Html.text graph.title ] ]
    in
        case Sel.getSelected model.dashboards of
            Nothing ->
                Elements.viewMenu DashboardSelected "Dashboards" (Sel.keys model.dashboards)
                    |> viewErrorOnTop model.last_error

            Just dashboard ->
                Html.div []
                    [ Html.button [ HE.onClick GoToDashboardList ] [ Html.text "back" ]
                    , Html.p []
                        ([ Html.h1 [] [ Html.text ("Dashboard: " ++ dashboard.title) ]
                         ]
                            ++ List.concatMap viewGraph dashboard.graphs
                        )
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
