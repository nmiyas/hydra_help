module Hydra.Framework.Tea.Interpreter where

import           Hydra.Prelude

import qualified Data.Map as Map

import qualified Hydra.Core.Language as L
import qualified Hydra.Framework.Tea.Language as L

type Handlers a = IORef (Map.Map String (L.LangL a))

interpretTeaHandlerL :: Handlers a -> L.TeaHandlerF a b -> IO b

interpretTeaHandlerL handlersRef (L.Cmd cmdStr method next) = do
  modifyIORef' handlersRef (Map.insert cmdStr method)
  pure $ next ()

runTeaHandlerL :: Handlers a -> L.TeaHandlerL a () -> IO ()
runTeaHandlerL handlersRef = foldFree (interpretTeaHandlerL handlersRef)
