module SelectionDict
    exposing
        ( SelectionDict
        , empty
        , singleton
        , insert
        , insertAndSelect
        , append
        , update
        , updateExisting
        , updateAndSelect
        , updateAndSelectExisting
        , updateSelected
        , transferSelection
        , selectWithStatus
        , select
        , deselectWithPrevious
        , deselect
        , SelectStatus
        , selected
        , isValueSelected
        , isSelected
        , isEmpty
        , member
        , get
        , getSelected
        , size
        , keys
        , values
        , toList
        , fromList
        , toDict
        , fromDict
        , map
        , foldl
        , foldr
        , filter
        , partition
        , union
        , intersect
        , diff
        , mergeToAnything
        )

import Dict exposing (Dict)


type SelectionDict k v
    = SelectionDict (Maybe k) (Dict k v)


empty : SelectionDict k v
empty =
    SelectionDict Nothing Dict.empty


singleton : comparable -> v -> SelectionDict comparable v
singleton k v =
    SelectionDict Nothing (Dict.singleton k v)


insert : comparable -> v -> SelectionDict comparable v -> SelectionDict comparable v
insert k v dict =
    insertAndSelect k v False dict


insertAndSelect : comparable -> v -> Bool -> SelectionDict comparable v -> SelectionDict comparable v
insertAndSelect k v selected (SelectionDict originalSelection originalDict) =
    let
        newDict =
            SelectionDict originalSelection (Dict.insert k v originalDict)
    in
        case selected of
            False ->
                newDict

            True ->
                newDict |> select k


append : Dict comparable v -> SelectionDict comparable v -> SelectionDict comparable v
append newDict originalDict =
    let
        existingAdder =
            insertAndSelect

        newAdder k v _ selectedDict =
            insertAndSelect k v False selectedDict

        bothMerger k _ isExistingSelected vNew _ selectedDict =
            insertAndSelect k vNew isExistingSelected selectedDict
    in
        mergeToAnything existingAdder bothMerger newAdder originalDict (fromDict newDict) empty


remove : comparable -> SelectionDict comparable v -> SelectionDict comparable v
remove k (SelectionDict originalSelection originalDict) =
    case originalSelection of
        Nothing ->
            SelectionDict originalSelection (Dict.remove k originalDict)

        Just selection ->
            let
                newSelection =
                    case selection == k of
                        False ->
                            originalSelection

                        True ->
                            Nothing
            in
                SelectionDict newSelection (Dict.remove k originalDict)


update : comparable -> (Maybe v -> Maybe v) -> SelectionDict comparable v -> SelectionDict comparable v
update k updateFunction dict =
    let
        updateSelected maybeValueSelected =
            case maybeValueSelected of
                Nothing ->
                    case updateFunction Nothing of
                        Nothing ->
                            Nothing

                        Just v ->
                            Just ( v, False )

                Just ( originalV, isSelected ) ->
                    case updateFunction (Just originalV) of
                        Nothing ->
                            Nothing

                        Just v ->
                            Just ( v, isSelected )
    in
        updateAndSelect k updateSelected dict


updateExisting : comparable -> (v -> v) -> SelectionDict comparable v -> SelectionDict comparable v
updateExisting k updateFunction dict =
    let
        updateAny maybeExisting =
            case maybeExisting of
                Nothing ->
                    Nothing

                Just value ->
                    Just (updateFunction value)
    in
        update k updateAny dict


updateAndSelect : comparable -> (Maybe ( v, Bool ) -> Maybe ( v, Bool )) -> SelectionDict comparable v -> SelectionDict comparable v
updateAndSelect k updateFunction (SelectionDict originalSelection originalDict) =
    let
        maybeMember =
            Dict.get k originalDict

        updatedValue =
            case maybeMember of
                Nothing ->
                    updateFunction Nothing

                Just v ->
                    updateFunction (Just ( v, (maybeEqual (Just k) originalSelection) ))
    in
        case ( maybeMember, updatedValue ) of
            ( Nothing, Nothing ) ->
                (SelectionDict originalSelection originalDict)

            ( Nothing, Just ( newValue, isSelected ) ) ->
                insertAndSelect k newValue isSelected (SelectionDict originalSelection originalDict)

            ( Just _, Nothing ) ->
                remove k (SelectionDict originalSelection originalDict)

            ( Just _, Just ( newValue, isSelected ) ) ->
                SelectionDict originalSelection (originalDict |> Dict.remove k |> Dict.insert k newValue)
                    |> (\dict ->
                            case isSelected of
                                True ->
                                    dict |> select k

                                False ->
                                    dict
                       )


updateAndSelectExisting : comparable -> (( v, Bool ) -> ( v, Bool )) -> SelectionDict comparable v -> SelectionDict comparable v
updateAndSelectExisting k update dict =
    let
        updateAny maybeExisting =
            case maybeExisting of
                Nothing ->
                    Nothing

                Just value ->
                    Just (update value)
    in
        updateAndSelect k updateAny dict


updateSelected : (v -> v) -> SelectionDict comparable v -> SelectionDict comparable v
updateSelected update dict =
    case selected dict of
        Just v ->
            updateExisting v update dict

        Nothing ->
            dict


transferSelection : SelectionDict comparable v -> SelectionDict comparable v -> ( SelectionDict comparable v, Bool )
transferSelection (SelectionDict originalSelection originalDict) new =
    case originalSelection of
        Nothing ->
            ( new |> deselect, True )

        Just selection ->
            let
                newSelected =
                    new |> select selection
            in
                case selected newSelected of
                    Just _ ->
                        ( newSelected, True )

                    Nothing ->
                        ( newSelected, False )


type SelectStatus
    = NewSelected
    | SameSelected
    | NoMatch


selectWithStatus : comparable -> SelectionDict comparable v -> ( SelectionDict comparable v, SelectStatus )
selectWithStatus k (SelectionDict originalSelection originalDict) =
    case Dict.member k originalDict of
        False ->
            ( (SelectionDict originalSelection originalDict), NoMatch )

        True ->
            case originalSelection of
                Nothing ->
                    ( (SelectionDict (Just k) originalDict), NewSelected )

                Just originalJustSelection ->
                    case k == originalJustSelection of
                        True ->
                            ( (SelectionDict originalSelection originalDict), SameSelected )

                        False ->
                            ( (SelectionDict (Just k) originalDict), NewSelected )


select : comparable -> SelectionDict comparable v -> SelectionDict comparable v
select k dict =
    case selectWithStatus k dict of
        ( newDict, _ ) ->
            newDict


deselectWithPrevious : SelectionDict comparable v -> ( SelectionDict comparable v, Maybe comparable )
deselectWithPrevious (SelectionDict originalSelection originalDict) =
    ( SelectionDict Nothing originalDict, originalSelection )


deselect : SelectionDict comparable v -> SelectionDict comparable v
deselect dict =
    case deselectWithPrevious dict of
        ( newDict, _ ) ->
            newDict


selected : SelectionDict k v -> Maybe k
selected (SelectionDict selected _) =
    selected


isValueSelected : comparable -> SelectionDict comparable v -> Bool
isValueSelected k (SelectionDict selected _) =
    case selected of
        Nothing ->
            False

        Just value ->
            k == value


isSelected : SelectionDict k v -> Bool
isSelected (SelectionDict selected _) =
    case selected of
        Just _ ->
            True

        Nothing ->
            False


isEmpty : SelectionDict k v -> Bool
isEmpty (SelectionDict _ dict) =
    Dict.isEmpty dict


member : comparable -> SelectionDict comparable v -> Bool
member k (SelectionDict _ dict) =
    Dict.member k dict


get : comparable -> SelectionDict comparable v -> Maybe ( v, Bool )
get k (SelectionDict selected dict) =
    case Dict.get k dict of
        Nothing ->
            Nothing

        Just val ->
            Just ( val, isValueSelected k (SelectionDict selected dict) )


getSelected : SelectionDict comparable v -> Maybe ( comparable, v )
getSelected dict =
    case selected dict of
        Nothing ->
            Nothing

        Just selection ->
            case get selection dict of
                Just ( value, _ ) ->
                    Just ( selection, value )

                Nothing ->
                    Nothing


size : SelectionDict comparable v -> Int
size (SelectionDict _ dict) =
    Dict.size dict


keys : SelectionDict comparable v -> List comparable
keys (SelectionDict _ dict) =
    Dict.keys dict


values : SelectionDict comparable v -> List v
values (SelectionDict _ dict) =
    Dict.values dict


toList : SelectionDict comparable v -> List ( comparable, v )
toList (SelectionDict _ dict) =
    Dict.toList dict


fromList : List ( comparable, v ) -> SelectionDict comparable v
fromList list =
    SelectionDict Nothing (Dict.fromList list)


toDict : SelectionDict comparable v -> Dict comparable v
toDict (SelectionDict _ dict) =
    dict


fromDict : Dict comparable v -> SelectionDict comparable v
fromDict dict =
    SelectionDict Nothing dict


map :
    (comparable -> a -> Bool -> b)
    -> SelectionDict comparable a
    -> SelectionDict comparable b
map transform (SelectionDict originalSelection originalDict) =
    SelectionDict
        originalSelection
        (Dict.map
            (\k v -> transform k v (maybeEqual (Just k) originalSelection))
            originalDict
        )


foldl :
    (comparable -> v -> Bool -> b -> b)
    -> b
    -> SelectionDict comparable v
    -> b
foldl transform init (SelectionDict originalSelection originalDict) =
    (Dict.foldl
        (\k v -> transform k v (maybeEqual (Just k) originalSelection))
        init
        originalDict
    )


foldr :
    (comparable -> v -> Bool -> b -> b)
    -> b
    -> SelectionDict comparable v
    -> b
foldr transform init (SelectionDict originalSelection originalDict) =
    (Dict.foldr
        (\k v -> transform k v (maybeEqual (Just k) originalSelection))
        init
        originalDict
    )


filter :
    (comparable -> v -> Bool -> Bool)
    -> SelectionDict comparable v
    -> SelectionDict comparable v
filter filterFunction (SelectionDict originalSelection originalDict) =
    let
        newDict =
            Dict.filter (\k v -> filterFunction k v (maybeEqual (Just k) originalSelection)) originalDict

        newSelection =
            case originalSelection of
                Nothing ->
                    Nothing

                Just selection ->
                    case Dict.member selection newDict of
                        True ->
                            Just selection

                        False ->
                            Nothing
    in
        SelectionDict newSelection newDict


partition :
    (comparable -> v -> Bool)
    -> SelectionDict comparable v
    -> ( SelectionDict comparable v, SelectionDict comparable v )
partition partitionFunction (SelectionDict originalSelection originalDict) =
    let
        ( leftDict, rightDict ) =
            Dict.partition partitionFunction originalDict

        ( leftSelection, rightSelection ) =
            case originalSelection of
                Nothing ->
                    ( Nothing, Nothing )

                Just selection ->
                    case Dict.member selection leftDict of
                        True ->
                            ( Just selection, Nothing )

                        False ->
                            ( Nothing, Just selection )
    in
        ( SelectionDict leftSelection leftDict, SelectionDict rightSelection rightDict )


union :
    (Maybe comparable -> Maybe comparable -> Maybe comparable)
    -> SelectionDict comparable v
    -> SelectionDict comparable v
    -> SelectionDict comparable v
union selectionMerger (SelectionDict leftSelection leftDict) (SelectionDict rightSelection rightDict) =
    SelectionDict (selectionMerger leftSelection rightSelection) (Dict.union leftDict rightDict)


intersect :
    (Maybe comparable -> Maybe comparable -> Maybe comparable)
    -> SelectionDict comparable v
    -> SelectionDict comparable v
    -> SelectionDict comparable v
intersect selectionMerger (SelectionDict leftSelection leftDict) (SelectionDict rightSelection rightDict) =
    let
        newDict =
            Dict.intersect leftDict rightDict

        newSideSelection selection =
            case selection of
                Nothing ->
                    Nothing

                Just sel ->
                    case Dict.member sel newDict of
                        False ->
                            Nothing

                        True ->
                            Just sel

        newSelection =
            selectionMerger (newSideSelection leftSelection) (newSideSelection rightSelection)
    in
        SelectionDict newSelection newDict


diff :
    (Maybe comparable -> Maybe comparable -> Maybe comparable)
    -> SelectionDict comparable v
    -> SelectionDict comparable v
    -> SelectionDict comparable v
diff selectionMerger (SelectionDict leftSelection leftDict) (SelectionDict rightSelection rightDict) =
    let
        newDict =
            Dict.diff leftDict rightDict

        newSideSelection selection =
            case selection of
                Nothing ->
                    Nothing

                Just sel ->
                    case Dict.member sel newDict of
                        False ->
                            Nothing

                        True ->
                            Just sel

        newSelection =
            selectionMerger (newSideSelection leftSelection) (newSideSelection rightSelection)
    in
        SelectionDict newSelection newDict


mergeToAnything :
    (comparable -> a -> Bool -> result -> result)
    -> (comparable -> a -> Bool -> b -> Bool -> result -> result)
    -> (comparable -> b -> Bool -> result -> result)
    -> SelectionDict comparable a
    -> SelectionDict comparable b
    -> result
    -> result
mergeToAnything leftNewAdder bothMerger rightNewAdder (SelectionDict leftSelection leftDict) (SelectionDict rightSelection rightDict) init =
    let
        selectedLeftNewAdder =
            (\comp a result -> leftNewAdder comp a (maybeEqual (Just comp) leftSelection) result)

        selectedRightNewAdder =
            (\comp a result -> rightNewAdder comp a (maybeEqual (Just comp) rightSelection) result)

        selectedBothMerger =
            (\comp a b result ->
                bothMerger comp
                    a
                    (maybeEqual (Just comp) leftSelection)
                    b
                    (maybeEqual (Just comp) rightSelection)
                    result
            )
    in
        (Dict.merge
            selectedLeftNewAdder
            selectedBothMerger
            selectedRightNewAdder
            leftDict
            rightDict
            init
        )


maybeEqual : Maybe a -> Maybe a -> Bool
maybeEqual maybeLeft maybeRight =
    case ( maybeLeft, maybeRight ) of
        ( Just left, Just right ) ->
            left == right

        _ ->
            False
