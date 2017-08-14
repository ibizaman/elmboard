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
import Dashboard
import Time
import Time.DateTime exposing (DateTime)


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


type alias Model =
    { dashboards : SelectionDict String Dashboard.Model
    , currentDatetime : DateTime
    , last_error : Maybe String
    }


init : ( Model, Cmd Msg )
init =
    ( { dashboards = Sel.fromList []
      , currentDatetime = Time.DateTime.epoch
      , last_error = Nothing
      }
    , Cmd.batch
        [ BackendTalk.send (jsonMessage GetDashboards) ]
    )



-- Update


type Msg
    = GoToDashboardList
    | UpdateDashboardList (Dict String Dashboard.Model)
    | DashboardSelected String
    | DashboardMsg String Dashboard.Msg
    | Tick DateTime
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

        DashboardMsg dashboardName msg ->
            case Sel.get dashboardName model.dashboards of
                Nothing ->
                    ( model, Cmd.none )

                Just ( dashboard, _ ) ->
                    let
                        ( newDashboard, dashboardCmd ) =
                            Dashboard.update msg dashboard

                        newDashboards =
                            Sel.updateExisting dashboardName (\_ -> newDashboard) model.dashboards
                    in
                        ( { model | dashboards = newDashboards }, dashboardCmd |> Cmd.map (DashboardMsg dashboardName) )

        Tick datetime ->
            let
                newDashboardModel =
                    Sel.updateSelected (Dashboard.tick datetime) model.dashboards
            in
                ( { model
                    | currentDatetime = datetime
                    , dashboards = newDashboardModel
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
            JsonD.map2 (\x y -> ( x, y ))
                (JsonD.field "title" JsonD.string)
                (JsonD.field "type" JsonD.string
                    |> JsonD.andThen
                        (\type_ ->
                            case type_ of
                                "builds" ->
                                    JsonD.succeed Dashboard.GraphTypeBuilds

                                errorType ->
                                    JsonD.fail ("Invalid graph type " ++ errorType)
                        )
                )

        dashboardDecoder =
            JsonD.map3 Dashboard.init
                (JsonD.field "title" JsonD.string)
                (JsonD.succeed model.currentDatetime)
                (JsonD.field "graphs"
                    (JsonD.list graphDecoder)
                )

        dashboardsDecoder =
            JsonD.map UpdateDashboardList
                (JsonD.field "dashboards"
                    (JsonD.dict dashboardDecoder)
                )

        fieldAndThen key decoder andThen =
            JsonD.field key decoder
                |> JsonD.andThen andThen

        dashboardDispatchDecoder =
            fieldAndThen "dashboard"
                JsonD.string
                (\dashboardName ->
                    case Sel.get dashboardName model.dashboards of
                        Just ( dashboard, True ) ->
                            JsonD.map2 DashboardMsg
                                (JsonD.succeed dashboardName)
                                (Dashboard.messageDecoder dashboardName dashboard)

                        _ ->
                            JsonD.fail ("Received message for unselected " ++ dashboardName)
                )

        messageDecoders =
            [ ( "dashboards", dashboardsDecoder )
            , ( "graph", dashboardDispatchDecoder )
            ]
                |> Dict.fromList

        toResult msg =
            case msg of
                Err string ->
                    BackendError string

                Ok msg ->
                    msg
    in
        Sub.batch
            [ BackendTalk.subscription messageDecoders |> Sub.map toResult
            , Time.every Time.second (\x -> Tick (Time.DateTime.fromTimestamp x))
            ]



-- View


view : Model -> Html Msg
view model =
    let
        dashboardButton dashboard =
            Html.button [ HE.onClick (DashboardSelected dashboard) ] [ Html.text dashboard ]

        viewGraph graph =
            [ Html.h2 [] [ Html.text graph.title ]
            , Html.p []
                [ Html.text ("type = " ++ graph.type_) ]
            ]
    in
        case Sel.getSelected model.dashboards of
            Nothing ->
                Elements.viewMenu DashboardSelected "Dashboards" (Sel.keys model.dashboards)
                    |> viewErrorOnTop model.last_error

            Just ( dashboardName, dashboard ) ->
                Html.div []
                    [ Html.button [ HE.onClick GoToDashboardList ] [ Html.text "back" ]
                    , (Html.map (DashboardMsg dashboardName) (Dashboard.view dashboard))
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



-- Utils


jsonDecoderTo : (a -> b) -> JsonD.Decoder a -> JsonD.Decoder b
jsonDecoderTo transformer decoder =
    decoder |> JsonD.andThen (\val -> JsonD.succeed (transformer val))
