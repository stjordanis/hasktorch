{-# LANGUAGE ForeignFunctionInterface #-}

module TestRandom (testsRandom) where

import Data.Maybe (fromJust)

import THDoubleTensor
import THDoubleTensorMath
import THDoubleTensorRandom

import THFloatTensor
import THFloatTensorMath
import THFloatTensorRandom

import THRandom
import Foreign.C.Types
import Test.Hspec

-- import TorchTensor
-- import Tensor
import TensorRaw
import TensorTypes
-- import TensorRandom

testsDouble = do
  gen <- c_THGenerator_new
  hspec $ do
    describe "random vectors" $ do
      it "uniform random is < bound" $ do
        t <- tensorRaw (D1 1000) 0.0
        c_THDoubleTensor_uniform t gen (-1.0) (1.0)
        (c_THDoubleTensor_maxall t) `shouldSatisfy` (< 1.001)
        c_THDoubleTensor_free t
      it "uniform random is > bound" $ do
        t <- tensorRaw (D1 1000) 0.0
        c_THDoubleTensor_uniform t gen (-1.0) (1.0)
        (c_THDoubleTensor_maxall t) `shouldSatisfy` (> (-1.001))
        c_THDoubleTensor_free t
      it "normal mean follows law of large numbers" $ do
        t <- tensorRaw (D1 10000) 0.0
        c_THDoubleTensor_normal t gen 1.55 0.25
        (c_THDoubleTensor_meanall t) `shouldSatisfy` (\x -> and [(x < 1.6), (x > 1.5)])
        c_THDoubleTensor_free t
      it "normal std follows law of large numbers" $ do
        t <- tensorRaw (D1 10000) 0.0
        c_THDoubleTensor_normal t gen 1.55 0.25
        (c_THDoubleTensor_stdall t biased) `shouldSatisfy` (\x -> and [(x < 0.3), (x > 0.2)])
        c_THDoubleTensor_free t
  where
    biased = 0

testsRandom :: IO ()
testsRandom = do
  testsDouble
  -- testsFloat
