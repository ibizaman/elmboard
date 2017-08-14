module Dashboard
    exposing
        ( Model
        , GraphTypes(..)
        , init
        , Msg
        , tick
        , update
        , messageDecoder
        , view
        )

import Graphs.Builds
import Html exposing (Html)
import SelectionDict exposing (SelectionDict)
import Time.DateTime exposing (DateTime)
import Json.Decode as JsonD


-- Model


type Model
    = Model
        { title : String
        , graphs : SelectionDict Int Graph
        }


type Graph
    = BuildsGraph Graphs.Builds.Model


type GraphTypes
    = GraphTypeBuilds


init : String -> DateTime -> List ( String, GraphTypes ) -> Model
init title currentDate list =
    let
        toGraph ( title, elem ) =
            case elem of
                GraphTypeBuilds ->
                    BuildsGraph (Graphs.Builds.init title currentDate)

        listIndexTuple fun =
            List.indexedMap (\index v -> ( index, fun v ))
    in
        Model
            { title = title
            , graphs = SelectionDict.fromList (listIndexTuple toGraph list)
            }



-- Update


type Msg
    = BuildsMsg Int Graphs.Builds.Msg


tick : DateTime -> Model -> Model
tick currentDatetime (Model model) =
    let
        runTick graphId graph isSelected =
            case graph of
                BuildsGraph model ->
                    Graphs.Builds.tick currentDatetime model |> BuildsGraph
    in
        Model
            { model
                | graphs = SelectionDict.map runTick model.graphs
            }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg (Model model) =
    case msg of
        BuildsMsg graphId buildsMsg ->
            case SelectionDict.get graphId model.graphs of
                Just ( BuildsGraph buildsGraph, _ ) ->
                    let
                        ( newGraph, graphCmd ) =
                            Graphs.Builds.update buildsMsg buildsGraph
                    in
                        ( Model
                            { model
                                | graphs = (SelectionDict.updateExisting graphId (\_ -> BuildsGraph newGraph) model.graphs)
                            }
                        , graphCmd |> Cmd.map (BuildsMsg graphId)
                        )

                _ ->
                    ( Model model, Cmd.none )


messageDecoder : String -> Model -> JsonD.Decoder Msg
messageDecoder dashboardName (Model model) =
    let
        fieldAndThen key decoder andThen =
            JsonD.field key decoder
                |> JsonD.andThen andThen

        graphDispatchDecoder dashboardName dashboard =
            fieldAndThen "graph_id"
                JsonD.int
                (\graphId ->
                    case SelectionDict.get graphId dashboard.graphs of
                        Nothing ->
                            JsonD.fail ("No graph for dashboard " ++ dashboardName ++ " at id " ++ (toString graphId))

                        Just ( graph, _ ) ->
                            graphTypeDispatchDecoder dashboardName graphId graph
                )

        graphTypeDispatchDecoder dashboardName graphId graph =
            case graph of
                BuildsGraph buildsGraph ->
                    JsonD.map (BuildsMsg graphId) Graphs.Builds.messageDecoder
    in
        graphDispatchDecoder dashboardName model



-- View


view : Model -> Html Msg
view (Model model) =
    let
        viewGraph graphId graph isSelected acc =
            let
                newElem =
                    case graph of
                        BuildsGraph model ->
                            Graphs.Builds.view model
            in
                (Html.map (BuildsMsg graphId) newElem) :: acc
    in
        Html.p []
            ([ Html.h1 [] [ Html.text ("Dashboard: " ++ model.title) ]
             ]
                ++ (SelectionDict.foldr viewGraph [] model.graphs)
            )



-- Utils


listAt : Int -> List a -> Maybe a
listAt index list =
    list |> List.drop index |> List.head
