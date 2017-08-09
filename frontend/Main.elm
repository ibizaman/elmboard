module Main exposing (main)

import Dict
import Json.Decode as JsonD
import Json.Encode as JsonE
import Html.Attributes as HA
import Html.Events as HE
import Html exposing (Html)
import BackendTalk
import Elements
import List.Selection as Sel exposing (Selection)


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
    String


type alias Model =
    { dashboards : Selection Dashboard
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
    | DashboardSelected String
    | UpdateDashboardList (List String)
    | BackendError String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GoToDashboardList ->
            ( { model
                | dashboards = Sel.deselect model.dashboards
                , last_error = Nothing
              }
            , Cmd.none
            )

        DashboardSelected wanted ->
            ( { model
                | dashboards = Sel.select wanted model.dashboards
                , last_error = Nothing
              }
            , Cmd.none
            )

        UpdateDashboardList newDashboards ->
            case transferSelection model.dashboards (Sel.fromList newDashboards) of
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


transferSelection : Selection a -> Selection a -> ( Selection a, Bool )
transferSelection old new =
    case Sel.selected old of
        Nothing ->
            ( new |> Sel.deselect, True )

        Just selected ->
            let
                newSelected =
                    new |> Sel.select selected
            in
                case Sel.selected newSelected of
                    Just _ ->
                        ( newSelected, True )

                    Nothing ->
                        ( newSelected, False )


type JsonMessage
    = GetDashboards


jsonMessage : JsonMessage -> String
jsonMessage msg =
    let
        object =
            case msg of
                GetDashboards ->
                    [ ( "type", JsonE.string "dashboards" ) ]
    in
        object |> JsonE.object |> JsonE.encode 0



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        dashboardListDecoder =
            (JsonD.field "dashboards" (JsonD.list JsonD.string))

        messageDecoders =
            [ ( "dashboards", BackendTalk.messageDecoder dashboardListDecoder UpdateDashboardList )
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
    in
        case Sel.selected model.dashboards of
            Nothing ->
                Elements.viewMenu DashboardSelected "Dashboards" (Sel.toList model.dashboards)
                    |> viewErrorOnTop model.last_error

            Just dashboard ->
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
