module MyCss exposing (css, id, class, classList, CssClasses(..))

import Css exposing (..)
import Css.Elements exposing (body, ul, nav, h1, button)
import Css.Namespace exposing (namespace)
import Html.CssHelpers


myNamespace : String
myNamespace =
    "elmboards"


type CssClasses
    = Menu


{ id, class, classList } =
    Html.CssHelpers.withNamespace myNamespace


css : Stylesheet
css =
    (stylesheet << Css.Namespace.namespace myNamespace)
        [ body
            [ margin zero
            ]
        , nav
            [ withClass Menu
                [ borderStyle solid
                , borderRadius (px 15)
                , display inlineBlock
                , boxSizing borderBox
                , height (vh 100)
                , descendants
                    [ h1
                        [ paddingLeft (px 40)
                        , paddingRight (px 40)
                        ]
                    , ul
                        [ paddingLeft (px 40)
                        , paddingRight (px 40)
                        , display block
                        , listStyle none
                        , fontFamilies [ "Roboto", "sans-serif" ]
                        , descendants
                            [ button
                                materialButton
                            ]
                        ]
                    ]
                ]
            ]
        ]


materialButton : List Style
materialButton =
    [ width (pct 100)
    , display listItem
    , backgroundColor (hex "#4CAf50")
    , borderStyle none
    , borderRadius (px 2)
    , color (rgb 255 255 255)
    , marginLeft zero
    , marginRight zero
    , marginTop (px 15)
    , marginBottom (px 15)
    , paddingTop zero
    , paddingBottom zero
    , paddingLeft (Css.rem 2)
    , paddingRight (Css.rem 2)
    , textAlign left
    , textDecoration none
    , letterSpacing (px 0.5)
    , fontSize (Css.rem 1)
    , property "box-shadow" "0 2px 2px 0 rgba(0,0,0,0.14), 0 1px 5px 0 rgba(0,0,0,0.12), 0 3px 1px -2px rgba(0,0,0,0.2)"
    , height (px 54)
    , lineHeight (px 54)
    , cursor pointer
    ]


materialFloatButton : List Style
materialFloatButton =
    [ lineHeight (px 56)
    , fontSize (Css.rem 1.6)
    , textAlign center
    , color (rgb 255 255 255)
    , borderRadius (pct 50)
    ]
