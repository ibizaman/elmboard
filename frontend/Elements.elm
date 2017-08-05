module Elements exposing (..)

import Html exposing (Html)
import Html.Attributes as HA
import Html.Events as HE
import List
import String


viewMenu : (String -> msg) -> String -> List String -> Html msg
viewMenu msg title elements =
    let
        link name =
            Html.li []
                [ Html.button [ HE.onClick (msg name) ]
                    [ Html.text (String.toUpper name)
                    ]
                ]
    in
        Html.nav [ HA.class "menu" ]
            [ Html.h1 [] [ Html.text title ]
            , Html.ul [] (List.map link elements)
            ]
