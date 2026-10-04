port module Ports exposing (receive, send)

import Json.Decode as Decode
import Json.Encode as Encode


port send : Encode.Value -> Cmd msg


port receive : (Decode.Value -> msg) -> Sub msg
