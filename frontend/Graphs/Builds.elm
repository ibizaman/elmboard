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
import Html exposing (Html)
import Svg exposing (Svg)
import Svg.Attributes
import Set
import Css.Colors
import NotEmptyList exposing (NotEmptyList)


-- Model


type Model
    = Model
        { id : String
        , title : String
        , builds : SelectionDict ( String, Int ) Build
        , datetime : DateTime
        , duration : Int
        , viewportDatetime : DateTime
        , viewportDuration : Float
        , viewportFollow : Bool
        , margin : Margin
        , jobLaneHeight : Float
        , jobLanePadding : Float
        , jobColors : NotEmptyList String
        }


type alias Margin =
    { top : Float
    , bottom : Float
    , left : Float
    , right : Float
    }


init : String -> String -> DateTime -> Model
init id title currentDate =
    Model
        { id = id
        , title = title
        , builds = SelectionDict.empty
        , datetime = currentDate
        , duration = 3600
        , viewportDatetime = currentDate
        , viewportDuration = 3600
        , viewportFollow = True
        , margin = Margin 10 10 10 10
        , jobLaneHeight = 20
        , jobLanePadding = 2
        , jobColors =
            NotEmptyList.notEmptyList Css.Colors.blue
                [ Css.Colors.olive
                , Css.Colors.orange
                , Css.Colors.maroon
                , Css.Colors.teal
                ]
                |> NotEmptyList.map (\color -> "rgb(" ++ (toString color.red) ++ "," ++ (toString color.green) ++ "," ++ (toString color.blue) ++ ")")
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
            if model.viewportFollow then
                currentDatetime |> DateTime.addSeconds -model.duration
            else
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
        jobNames =
            model.builds
                |> SelectionDict.foldr (\( name, buildNumber ) build isSelected acc -> Set.insert name acc) Set.empty
                |> Set.toList
                |> List.indexedMap (\i v -> ( v, i ))
                |> Dict.fromList

        jobIndex name =
            Dict.get name jobNames |> Maybe.withDefault 0

        jobAxis name =
            jobIndex name |> toFloat

        jobColor name =
            NotEmptyList.moduloIndex (jobIndex name) model.jobColors

        maxTimestamp =
            model.builds
                |> SelectionDict.values
                |> List.map (getEndDate model.datetime)
                |> List.map (\datetime -> (DateTime.toTimestamp datetime) / 1000)
                |> List.maximum
                |> Maybe.withDefault 0

        minTimestamp =
            model.builds
                |> SelectionDict.values
                |> List.map (getStartDate model.datetime)
                |> List.map (\datetime -> (DateTime.toTimestamp datetime) / 1000)
                |> List.minimum
                |> Maybe.withDefault 0

        xAxis datetime =
            (DateTime.toTimestamp datetime) / 1000 - minTimestamp

        viewBuild ( job, buildNumber ) build isSelected =
            let
                jobLane =
                    (jobAxis job) * (model.jobLaneHeight + model.jobLanePadding)

                buildRect status start end url =
                    rect ( xAxis start, xAxis end ) ( jobLane, jobLane + model.jobLaneHeight ) (toString buildNumber) (jobColor job)
            in
                case build of
                    SuccessfulBuild start end url ->
                        buildRect "S" start end url

                    FailedBuild start end url ->
                        buildRect "F" start end url

                    AbortedBuild start end url ->
                        buildRect "A" start end url

                    RunningBuild start url ->
                        buildRect "R" start model.datetime url

                    ScheduledBuild ->
                        buildRect "S" model.datetime model.datetime ""

        getStartDate default build =
            case build of
                SuccessfulBuild start end url ->
                    start

                FailedBuild start end url ->
                    start

                AbortedBuild start end url ->
                    start

                RunningBuild start url ->
                    start

                ScheduledBuild ->
                    default

        getEndDate default build =
            case build of
                SuccessfulBuild start end url ->
                    end

                FailedBuild start end url ->
                    end

                AbortedBuild start end url ->
                    end

                RunningBuild start url ->
                    default

                ScheduledBuild ->
                    default
    in
        Svg.svg
            [ Svg.Attributes.id model.id
            , Svg.Attributes.width "800"
            , Svg.Attributes.height "500"
            , Svg.Attributes.preserveAspectRatio "none"
            , viewBox ( xAxis model.viewportDatetime, xAxis model.viewportDatetime + model.viewportDuration ) ( 0, 200 )
            ]
            (SelectionDict.map viewBuild model.builds |> SelectionDict.values)


viewBox : ( Float, Float ) -> ( Float, Float ) -> Svg.Attribute msg
viewBox ( minX, maxX ) ( minY, maxY ) =
    Svg.Attributes.viewBox
        ((toString minX)
            ++ " "
            ++ (toString minY)
            ++ " "
            ++ (toString (maxX - minX))
            ++ " "
            ++ (toString (maxY - minY))
        )


rect : ( Float, Float ) -> ( Float, Float ) -> String -> String -> Svg msg
rect ( minX, maxX ) ( minY, maxY ) text color =
    let
        width =
            max (maxX - minX) 10

        height =
            max (maxY - minY) 10
    in
        Svg.g
            [ Svg.Attributes.transform ("translate (" ++ (toString minX) ++ ", " ++ (toString minY) ++ ")")
            ]
            [ Svg.rect
                [ Svg.Attributes.width (toString width)
                , Svg.Attributes.height (toString height)
                , Svg.Attributes.rx "0"
                , Svg.Attributes.ry "0"
                , Svg.Attributes.fill color
                ]
                []
            , Svg.svg
                [ Svg.Attributes.width (toString width)
                , Svg.Attributes.height (toString height)
                ]
                [ Svg.text_
                    [ Svg.Attributes.x "50%"
                    , Svg.Attributes.y "50%"
                    , Svg.Attributes.textAnchor "middle"
                    , Svg.Attributes.alignmentBaseline "middle"
                    ]
                    [ Svg.text text
                    ]
                ]
            ]
