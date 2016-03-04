module Lib
    (
     ascii_art_str
    ) where

import Foreign.C.Types
import Foreign.Ptr
import Foreign.C.String

-- exported functions
ascii_art_str :: IO String
ascii_art_str = ascii_art_str_raw >>= peekCString

-- Unexported raw functions

foreign import ccall "cwrapper.h ascii_art_str" ascii_art_str_raw :: IO CString
