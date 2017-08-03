module BackendTalk
    exposing
        ( send
        , sendRequestDashboardList
        , subscription
        , Msg(..)
        )

import WebSocket
import Json.Decode as Json


type Msg
    = DashboardList (List String)
    | Error String


serverAddress : String
serverAddress =
    "ws://localhost:8080/socket"


send : String -> (Msg -> a) -> Cmd a
send message transform =
    WebSocket.send serverAddress message |> Cmd.map transform


sendRequestDashboardList : (Msg -> a) -> Cmd a
sendRequestDashboardList transform =
    send "dashboards" transform


subscription : (Msg -> a) -> Sub a
subscription transform =
    WebSocket.listen serverAddress (webSocketJsonDecode) |> Sub.map transform


webSocketJsonDecode : String -> Msg
webSocketJsonDecode string =
    case Json.decodeString rootDecoder string of
        Err error ->
            Error error

        Ok msg ->
            msg


rootDecoder : Json.Decoder Msg
rootDecoder =
    let
        dispatch message =
            case message of
                "dashboards" ->
                    jsonDashboardsDecoder

                _ ->
                    Json.fail ("Unknown message type " ++ message)
    in
        Json.field "message" Json.string
            |> Json.andThen dispatch


messageDecoder : String -> Json.Decoder b -> (b -> msg) -> Json.Decoder msg
messageDecoder messageType decoder msg =
    Json.field messageType decoder
        |> Json.andThen (\x -> Json.succeed (msg x))


jsonDashboardsDecoder : Json.Decoder Msg
jsonDashboardsDecoder =
    messageDecoder "dashboards" (Json.list Json.string) DashboardList
