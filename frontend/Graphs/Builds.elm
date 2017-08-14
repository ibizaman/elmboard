module Graphs.Builds
    exposing
        ( Model
        , init
        , Msg
        , tick
        , update
        , messageDecoder
        , view
        )

import Time.DateTime as DateTime exposing (DateTime)
import Dict exposing (Dict)
import Json.Decode as JsonD
import SelectionDict exposing (SelectionDict)
import Html.Attributes as HA
import Html exposing (Html)


-- Model


type Model
    = Model
        { title : String
        , builds : SelectionDict ( String, Int ) Build
        , datetime : DateTime
        , duration : Int
        , viewportDatetime : DateTime
        , viewportDuration : Int
        , viewportFollow : Bool
        }


init : String -> DateTime -> Model
init title currentDate =
    Model
        { title = title
        , builds = SelectionDict.empty
        , datetime = currentDate
        , duration = 3600
        , viewportDatetime = currentDate
        , viewportDuration = 3600
        , viewportFollow = True
        }


type Build
    = SuccessfulBuild DateTime DateTime String
    | FailedBuild DateTime DateTime String
    | AbortedBuild DateTime DateTime String
    | RunningBuild DateTime String
    | ScheduledBuild


messageDecoder : JsonD.Decoder Msg
messageDecoder =
    let
        statusBuild status =
            case status of
                "SUCCESSFUL" ->
                    JsonD.map3 SuccessfulBuild
                        (JsonD.field "start" timestampToDate)
                        (JsonD.field "end" timestampToDate)
                        (JsonD.field "url" JsonD.string)

                "FAILED" ->
                    JsonD.map3 FailedBuild
                        (JsonD.field "start" timestampToDate)
                        (JsonD.field "end" timestampToDate)
                        (JsonD.field "url" JsonD.string)

                "ABORTED" ->
                    JsonD.map3 AbortedBuild
                        (JsonD.field "start" timestampToDate)
                        (JsonD.field "end" timestampToDate)
                        (JsonD.field "url" JsonD.string)

                "RUNNING" ->
                    JsonD.map2 RunningBuild
                        (JsonD.field "start" timestampToDate)
                        (JsonD.field "url" JsonD.string)

                "SCHEDULED" ->
                    JsonD.succeed ScheduledBuild

                _ ->
                    JsonD.fail ("Could not parse build status " ++ status)

        decodeStatusBuild =
            JsonD.field "status" JsonD.string
                |> JsonD.andThen statusBuild

        decodeKey =
            JsonD.map2 (\job build -> ( job, build ))
                (JsonD.field "name" JsonD.string)
                (JsonD.field "build" JsonD.int)
    in
        JsonD.map2 (\key value -> UpdateBuilds (Dict.singleton key value))
            decodeKey
            decodeStatusBuild


timestampToDate : JsonD.Decoder DateTime
timestampToDate =
    JsonD.float
        |> JsonD.andThen
            (\timestamp ->
                JsonD.succeed (DateTime.fromTimestamp timestamp)
            )



--{"name": "pipeline1",
--"url": "http://localhost:8090/job/pipeline1/",
--"build": 1791,
--"status": "SUCCESSFUL",
--"start": 1502640778888.0,
--"end": 1502640779448.0,
--"message": "graph",
--"dashboard": "jenkins",
--"graph_id": "1"}
-- Update


type Msg
    = UpdateBuilds (Dict ( String, Int ) Build)
    | SelectBuild String Int



-- | UpdateViewport Date Date
-- | Scale Int
-- | Pan Int
-- |


update : Msg -> Model -> ( Model, Cmd Msg )
update msg (Model model) =
    case msg of
        UpdateBuilds newBuilds ->
            ( Model { model | builds = SelectionDict.append newBuilds model.builds }, Cmd.none )

        SelectBuild jobId buildId ->
            ( Model { model | builds = SelectionDict.select ( jobId, buildId ) model.builds }, Cmd.none )


tick : DateTime -> Model -> Model
tick currentDatetime (Model model) =
    let
        newViewportDatetime =
            case model.viewportFollow of
                True ->
                    currentDatetime |> DateTime.addSeconds -model.duration

                False ->
                    model.viewportDatetime
    in
        Model
            { model
                | datetime = currentDatetime
                , viewportDatetime = newViewportDatetime
            }



-- View


view : Model -> Html Msg
view (Model model) =
    let
        viewBuild ( job, buildNumber ) build isSelected acc =
            let
                liFull status start end url =
                    Html.li []
                        [ Html.text
                            (status
                                ++ " "
                                ++ job
                                ++ "#"
                                ++ (toString buildNumber)
                                ++ " ["
                                ++ (toString start)
                                ++ ", "
                                ++ (toString end)
                                ++ "]: "
                                ++ url
                            )
                        ]

                newElem =
                    case build of
                        SuccessfulBuild start end url ->
                            liFull "S" start end url

                        FailedBuild start end url ->
                            liFull "F" start end url

                        AbortedBuild start end url ->
                            liFull "A" start end url

                        RunningBuild start url ->
                            Html.li []
                                [ Html.text
                                    ("R "
                                        ++ job
                                        ++ "#"
                                        ++ (toString buildNumber)
                                        ++ " ["
                                        ++ (toString start)
                                        ++ ", X]: "
                                        ++ url
                                    )
                                ]

                        ScheduledBuild ->
                            Html.li []
                                [ Html.text
                                    (". "
                                        ++ job
                                        ++ "#"
                                        ++ (toString buildNumber)
                                    )
                                ]
            in
                newElem :: acc

        viewBuildList builds =
            Html.ul [ HA.class "Builds" ]
                (SelectionDict.foldr viewBuild [] builds)
    in
        Html.div [ HA.classList [ ( "graph", True ), ( "builds", True ) ] ]
            ([ Html.h2 [] [ Html.text model.title ]
             , Html.p []
                [ "span: [" ++ (model.datetime |> DateTime.addSeconds (-model.duration) |> DateTime.toISO8601) ++ ", " ++ (model.datetime |> DateTime.toISO8601) ++ "]" |> Html.text
                ]
             , viewBuildList model.builds
             ]
            )
