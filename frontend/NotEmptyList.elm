module NotEmptyList
    exposing
        ( NotEmptyList
        , singleton
        , notEmptyList
        , moduloIndex
        , map
        )


type NotEmptyList e
    = NotEmptyList e (List e)


singleton : e -> NotEmptyList e
singleton elem =
    NotEmptyList elem []


notEmptyList : e -> List e -> NotEmptyList e
notEmptyList first rest =
    NotEmptyList first rest


moduloIndex : Int -> NotEmptyList e -> e
moduloIndex index (NotEmptyList first list) =
    let
        length =
            (List.length list) + 1

        normalizedIndex =
            Basics.rem index length

        at index list =
            case ( index, list ) of
                ( 0, x :: _ ) ->
                    x

                ( _, x :: [] ) ->
                    x

                ( index, _ :: rest ) ->
                    at (index - 1) rest

                _ ->
                    first
    in
        at normalizedIndex (first :: list)


map : (a -> b) -> NotEmptyList a -> NotEmptyList b
map transform (NotEmptyList first rest) =
    NotEmptyList (transform first) (List.map transform rest)
