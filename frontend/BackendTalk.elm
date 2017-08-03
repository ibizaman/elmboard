module BackendTalk
    exposing
        ( send
        , subscription
        , messageDecoder
        )

import Dict exposing (Dict)
import Json.Decode as Json
import WebSocket


serverAddress : String
serverAddress =
    "ws://localhost:8080/socket"


send : String -> Cmd a
send message =
    WebSocket.send serverAddress message


subscription : Dict String (Json.Decoder msg) -> Sub (Result String msg)
subscription transform =
    WebSocket.listen serverAddress (webSocketJsonDecode transform)


webSocketJsonDecode : Dict String (Json.Decoder msg) -> String -> Result String msg
webSocketJsonDecode transform string =
    Json.decodeString (messageTypeDecoder transform) string


messageTypeDecoder : Dict String (Json.Decoder msg) -> Json.Decoder msg
messageTypeDecoder transform =
    let
        dispatch message =
            case Dict.get message transform of
                Just decoder ->
                    decoder

                Nothing ->
                    Json.fail ("No decoder found for message type " ++ message)
    in
        Json.field "message" Json.string
            |> Json.andThen dispatch


messageDecoder : Json.Decoder b -> (b -> msg) -> Json.Decoder msg
messageDecoder decoder msg =
    decoder |> Json.andThen (\x -> Json.succeed (msg x))
