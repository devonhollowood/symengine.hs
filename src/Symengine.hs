{-# LANGUAGE RecordWildCards #-}

module Symengine
    (
     ascii_art_str,
     basic_str,
     basic_const_zero,
     basic_const_one,
     basic_const_I,
     basic_const_pi,
     basic_const_EulerGamma,
     basic_const_minus_one,
     basic_int_signed,
     BasicPtr,
    ) where

import Foreign.C.Types
import Foreign.Ptr
import Foreign.C.String
import Foreign.Storable
import Foreign.Marshal.Array
import Foreign.ForeignPtr
import Control.Applicative
import System.IO.Unsafe
import Control.Monad
import GHC.Real

data BasicStruct = BasicStruct {
    data_ptr :: Ptr ()
}

instance Storable BasicStruct where
    alignment _ = 8
    sizeOf _ = sizeOf nullPtr
    peek basic_ptr = BasicStruct <$> peekByteOff basic_ptr 0
    poke basic_ptr BasicStruct{..} = pokeByteOff basic_ptr 0 data_ptr

data BasicPtr = BasicPtr { fptr :: ForeignPtr BasicStruct }

withBasicPtr :: BasicPtr -> (Ptr BasicStruct -> IO a) -> IO a
withBasicPtr p f = withForeignPtr (fptr p ) f

withBasicPtr2 :: BasicPtr -> BasicPtr -> (Ptr BasicStruct -> Ptr BasicStruct -> IO a) -> IO a
withBasicPtr2 p1 p2 f = withBasicPtr p1 (\p1 -> withBasicPtr p2 (\p2 -> f p1 p2))

withBasicPtr3 :: BasicPtr -> BasicPtr -> BasicPtr -> (Ptr BasicStruct -> Ptr BasicStruct -> Ptr BasicStruct -> IO a) -> IO a
withBasicPtr3 p1 p2 p3 f = withBasicPtr p1 (\p1 -> withBasicPtr p2 (\p2 -> withBasicPtr p3 (\p3 -> f p1 p2 p3)))

instance Show BasicPtr where
    show = basic_str 


basic_const_zero :: BasicPtr
basic_const_zero = basic_obj_constructor basic_const_zero_ffi


basic_const_one :: BasicPtr
basic_const_one = basic_obj_constructor basic_const_one_ffi

basic_const_minus_one :: BasicPtr
basic_const_minus_one = basic_obj_constructor basic_const_minus_one_ffi

basic_const_I :: BasicPtr
basic_const_I = basic_obj_constructor basic_const_I_ffi

basic_const_pi :: BasicPtr
basic_const_pi = basic_obj_constructor basic_const_pi_ffi

basic_const_E :: BasicPtr
basic_const_E = basic_obj_constructor basic_const_E_ffi

basic_const_EulerGamma :: BasicPtr
basic_const_EulerGamma = basic_obj_constructor basic_const_EulerGamma_ffi

basic_obj_constructor :: (Ptr BasicStruct -> IO ()) -> BasicPtr
basic_obj_constructor init_fn = unsafePerformIO $ do
    basic_ptr <- create_basic_ptr
    withBasicPtr basic_ptr init_fn
    return basic_ptr

basic_str :: BasicPtr -> String
basic_str basic_ptr = unsafePerformIO $ withBasicPtr basic_ptr (basic_str_ffi >=> peekCString)

integerToCLong :: Integer -> CLong
integerToCLong i = CLong (fromInteger i)


intToCLong :: Int -> CLong
intToCLong i = integerToCLong (toInteger i)

basic_int_signed :: Int -> BasicPtr
basic_int_signed i = unsafePerformIO $ do
    iptr <- create_basic_ptr
    withBasicPtr iptr (\iptr -> integer_set_si_ffi iptr (intToCLong i) )
    return iptr


basic_from_integer :: Integer -> BasicPtr
basic_from_integer i = unsafePerformIO $ do
    iptr <- create_basic_ptr
    withBasicPtr iptr (\iptr -> integer_set_si_ffi iptr (fromInteger i))
    return iptr

-- |The `ascii_art_str` function prints SymEngine in ASCII art.
-- this is useful as a sanity check
ascii_art_str :: IO String
ascii_art_str = ascii_art_str_ffi >>= peekCString

-- Unexported ffi functions------------------------

-- |Create a basic object that represents all other objects through
-- the FFI
create_basic_ptr :: IO BasicPtr
create_basic_ptr = do
    basic_ptr <- newArray [BasicStruct { data_ptr = nullPtr }]
    basic_new_heap_ffi basic_ptr
    finalized_ptr <- newForeignPtr ptr_basic_free_heap_ffi basic_ptr
    return $ BasicPtr { fptr = finalized_ptr }

basic_binaryop :: (Ptr BasicStruct -> Ptr BasicStruct -> Ptr BasicStruct -> IO ()) -> BasicPtr -> BasicPtr -> BasicPtr
basic_binaryop f a b = unsafePerformIO $ do
    s <- create_basic_ptr
    withBasicPtr3 s a b f
    return s 

basic_unaryop :: (Ptr BasicStruct -> Ptr BasicStruct -> IO ()) -> BasicPtr -> BasicPtr
basic_unaryop f a = unsafePerformIO $ do
    s <- create_basic_ptr
    withBasicPtr2 s a f
    return s 


basic_add :: BasicPtr -> BasicPtr -> BasicPtr
basic_add = basic_binaryop basic_add_ffi
 
basic_sub :: BasicPtr -> BasicPtr -> BasicPtr
basic_sub = basic_binaryop basic_sub_ffi

basic_mul :: BasicPtr -> BasicPtr -> BasicPtr
basic_mul = basic_binaryop basic_mul_ffi

basic_div :: BasicPtr -> BasicPtr -> BasicPtr
basic_div = basic_binaryop basic_div_ffi

basic_pow :: BasicPtr -> BasicPtr -> BasicPtr
basic_pow = basic_binaryop basic_pow_ffi

basic_neg :: BasicPtr -> BasicPtr
basic_neg = basic_unaryop basic_neg_ffi

basic_abs :: BasicPtr -> BasicPtr
basic_abs = basic_unaryop basic_abs_ffi

basic_rational_set :: BasicPtr -> BasicPtr -> BasicPtr
basic_rational_set = basic_binaryop rational_set_ffi

basic_rational_set_signed :: Integer -> Integer -> BasicPtr
basic_rational_set_signed i j = unsafePerformIO $ do
    s <- create_basic_ptr
    withBasicPtr s (\s -> rational_set_si_ffi s (integerToCLong i) (integerToCLong j))
    return s 



instance Num BasicPtr where
    (+) = basic_add
    (-) = basic_sub
    (*) = basic_mul
    negate = basic_neg
    abs = basic_abs
    signum = undefined
    fromInteger = basic_from_integer

instance Fractional BasicPtr where
    (/) = basic_div
    fromRational (num :% denom) = basic_rational_set_signed num denom
    recip r = basic_const_one / r

foreign import ccall "symengine/cwrapper.h ascii_art_str" ascii_art_str_ffi :: IO CString
foreign import ccall "symengine/cwrapper.h basic_new_heap" basic_new_heap_ffi :: Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h &basic_free_heap" ptr_basic_free_heap_ffi :: FunPtr(Ptr BasicStruct -> IO ())

-- constants
foreign import ccall "symengine/cwrapper.h basic_const_zero" basic_const_zero_ffi :: Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h basic_const_one" basic_const_one_ffi :: Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h basic_const_minus_one" basic_const_minus_one_ffi :: Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h basic_const_I" basic_const_I_ffi :: Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h basic_const_pi" basic_const_pi_ffi :: Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h basic_const_E" basic_const_E_ffi :: Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h basic_const_EulerGamma" basic_const_EulerGamma_ffi :: Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h basic_str" basic_str_ffi :: Ptr BasicStruct -> IO CString

foreign import ccall "symengine/cwrapper.h integer_set_si" integer_set_si_ffi :: Ptr BasicStruct -> CLong -> IO ()

foreign import ccall "symengine/cwrapper.h rational_set" rational_set_ffi :: Ptr BasicStruct -> Ptr BasicStruct -> Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h rational_set_si" rational_set_si_ffi :: Ptr BasicStruct -> CLong -> CLong -> IO ()

foreign import ccall "symengine/cwrapper.h basic_add" basic_add_ffi :: Ptr BasicStruct -> Ptr BasicStruct -> Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h basic_sub" basic_sub_ffi :: Ptr BasicStruct -> Ptr BasicStruct -> Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h basic_mul" basic_mul_ffi :: Ptr BasicStruct -> Ptr BasicStruct -> Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h basic_div" basic_div_ffi :: Ptr BasicStruct -> Ptr BasicStruct -> Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h basic_pow" basic_pow_ffi :: Ptr BasicStruct -> Ptr BasicStruct -> Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h basic_neg" basic_neg_ffi :: Ptr BasicStruct -> Ptr BasicStruct -> IO ()
foreign import ccall "symengine/cwrapper.h basic_abs" basic_abs_ffi :: Ptr BasicStruct -> Ptr BasicStruct -> IO ()


