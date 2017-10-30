{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards #-}


module StaticTensorDouble (
  tds_new,
  tds_init,
  tds_cloneDim,
  dispS,
  TensorDoubleStatic(..),
  TDS(..),
  Nat -- re-export for kind signature readability
  ) where

import Foreign (Ptr)
import Foreign.C.Types (CLong)
import Foreign.ForeignPtr ( ForeignPtr, withForeignPtr, newForeignPtr )

import TensorRaw
import TensorDouble
import TensorTypes
import THTypes
import THDoubleTensor
import THDoubleTensorMath

import System.IO.Unsafe (unsafePerformIO)

import Data.Proxy (Proxy(..))
import Data.Proxy (Proxy)

import Data.Singletons
-- import Data.Singletons.Prelude
import Data.Singletons.TypeLits

class StaticTensor t where
  -- |create tensor
  tds_new :: t
  -- |create tensor of the same dimensions
  tds_cloneDim :: t -> t -- takes unused argument, gets dimensions by matching types
  -- |create and initialize tensor
  tds_init :: Double -> t
  -- |Display tensor
  dispS :: t -> IO ()

-- |Convert word to CLong
w2cl :: Word -> CLong
w2cl = fromIntegral

-- |Runtime type-level check of # dimensions
dimCheck :: Monad m => TensorDim Word -> Integer -> m ()
dimCheck dims n = case dims of
  D0 -> if n == 0 then pure () else fail "Incorrect Dimensions"
  D1 _ -> if n == 1 then pure () else fail "Incorrect Dimensions"
  D2 _ _ -> if n == 2 then pure () else fail "Incorrect Dimensions"
  D3 _ _ _ -> if n == 3 then pure () else fail "Incorrect Dimensions"
  D4 _ _ _ _ -> if n == 4 then pure () else fail "Incorrect Dimensions"

list2dim :: (Num a2, Integral a1) => [a1] -> TensorDim a2
list2dim lst  = case (length lst) of
  0 -> D0
  1 -> D1 (d !! 0)
  2 -> D2 (d !! 0) (d !! 1)
  3 -> D3 (d !! 0) (d !! 1) (d !! 2)
  4 -> D4 (d !! 0) (d !! 1) (d !! 2) (d !! 3)
  _ -> error "Tensor type signature has invalid dimensions"
  where
    d = fromIntegral <$> lst -- cast as needed for tensordim

data TensorDoubleStatic (d :: [Nat]) = TDS {
  tdsTensor :: !(ForeignPtr CTHDoubleTensor)
  } deriving (Show)

type TDS = TensorDoubleStatic

instance Eq (TensorDoubleStatic d) where
  (==) t1 t2 = unsafePerformIO $ withForeignPtr (tdsTensor t1)
    (\t1c -> withForeignPtr (tdsTensor t2)
             (\t2c -> pure $ (c_THDoubleTensor_equal t1c t2c) == 1)
    )

-- |Make a low level pointer according to dimensions
mkTHelper dims makeStatic value = unsafePerformIO $ do
  newPtr <- mkPtr dims value
  fPtr <- newForeignPtr p_THDoubleTensor_free newPtr
  pure $ makeStatic dims fPtr
  where
    mkPtr dim value = tensorRaw dim value

instance SingI d => StaticTensor (TensorDoubleStatic d)  where
  tds_init initVal = mkTHelper dims makeStatic initVal
    where
      dims = list2dim $ fromSing (sing :: Sing d)
      makeStatic dims fptr = (TDS fptr) :: TDS d
  tds_new = tds_init 0.0
  tds_cloneDim _ = tds_new :: TDS d
  dispS tensor = (withForeignPtr(tdsTensor tensor) dispRaw)

{- Sanity checks -}

testStatic = do
  print("1")
  let t1 = tds_new :: TDS '[2, 2]
  dispS t1 -- passes
  print("2")
  let t2 = tds_new :: TDS '[2, 4]
  dispS t2
  print("3")
  let t3 = tds_new :: TDS '[2, 2, 2]
  dispS t3
  print("4")
  let t4 = tds_new :: TDS '[8, 4]
  dispS t4
  pure ()

testEq = do
  print "Should be True:"
  print $ (tds_init 4.0 :: TDS '[2,3]) ==  (tds_init 4.0 :: TDS '[2,3])
  print "Should be False:"
  print $ (tds_init 3.0 :: TDS '[2,3]) ==  (tds_init 1.0 :: TDS '[2,3])

test = do
  testStatic
  testEq