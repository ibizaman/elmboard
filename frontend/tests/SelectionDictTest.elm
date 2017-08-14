module SelectionDictTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, list, int, string)
import Test exposing (..)
import SelectionDict exposing (SelectionDict)


selectedDictSuite : Test
selectedDictSuite =
    describe "SelectionDict Module Test"
        [ describe "Update Functions"
            [ test ".updateAndSelect on existing unselected key" <|
                \_ ->
                    let
                        init =
                            SelectionDict.singleton 1 "a"

                        update x =
                            case x of
                                Just ( originalValue, False ) ->
                                    Just ( "ok", False )

                                _ ->
                                    Just ( "error", False )
                    in
                        SelectionDict.singleton 1 "a"
                            |> SelectionDict.updateAndSelect 1 update
                            |> SelectionDict.get 1
                            |> Expect.equal (Just ( "ok", False ))
            , test ".update on existing key" <|
                \_ ->
                    let
                        update x =
                            case x of
                                Just x ->
                                    Just (x ++ "b")

                                Nothing ->
                                    Just "error"
                    in
                        SelectionDict.singleton 1 "a"
                            |> SelectionDict.update 1 update
                            |> Expect.equal (SelectionDict.singleton 1 "ab")
            , describe ".updateSelected"
                [ test "without key selected" <|
                    \_ ->
                        let
                            update x =
                                x ++ "b"
                        in
                            SelectionDict.singleton 1 "a"
                                |> SelectionDict.updateSelected update
                                |> Expect.equal (SelectionDict.singleton 1 "a")
                , test "with key selected" <|
                    \_ ->
                        let
                            update x =
                                x ++ "b"
                        in
                            SelectionDict.singleton 1 "a"
                                |> SelectionDict.select 1
                                |> SelectionDict.updateSelected update
                                |> Expect.equal (SelectionDict.singleton 1 "ab" |> SelectionDict.select 1)
                ]
            ]
        ]
