{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TemplateHaskell       #-}

module Hydra.Core.Lang.Language where

import           Hydra.Prelude

import qualified Hydra.Core.ControlFlow.Class    as L
import qualified Hydra.Core.ControlFlow.Language as L
import qualified Hydra.Core.Logger.Class         as L
import qualified Hydra.Core.Logger.Language      as L
import qualified Hydra.Core.Random.Class         as L
import qualified Hydra.Core.Random.Language      as L
import qualified Hydra.Core.State.Class          as L
import qualified Hydra.Core.State.Language       as L
import qualified Hydra.Core.KVDB.Language        as L
import qualified Hydra.Core.Lang.Class           as C
import qualified Hydra.Core.Domain               as D

import           Language.Haskell.TH.MakeFunctor (makeFunctorInstance)

-- | Core effects container language.
data LangF next where
  -- | Eval stateful action atomically.
  EvalStateAtomically :: L.StateL a -> (a -> next) -> LangF next
  -- | Logger effect
  EvalLogger      :: L.LoggerL ()     -> (() -> next) -> LangF next
  -- | Random effect
  EvalRandom      :: L.RandomL a     -> (a  -> next) -> LangF next
  -- | ControlFlow effect
  EvalControlFlow :: L.ControlFlowL a -> (a  -> next) -> LangF next
  -- | Impure effect. Avoid using it in production code (it's not testable).
  EvalIO          :: IO a           -> (a  -> next) -> LangF next
  -- | Init KV DB
  InitKVDB :: D.KVDBConfig db -> (D.DBResult (D.KVDBStorage db) -> next) -> LangF next
  -- | Eval KV DB action
  EvalKVDB :: D.KVDBStorage db -> L.KVDBL db a -> (a -> next) -> LangF next


makeFunctorInstance ''LangF

type LangL = Free LangF

class IOL m where
  evalIO :: IO a -> m a

instance IOL LangL where
  evalIO io = liftF $ EvalIO io id

evalStateAtomically' :: L.StateL a -> LangL a
evalStateAtomically' action = liftF $ EvalStateAtomically action id

evalLogger' :: L.LoggerL () -> LangL ()
evalLogger' logger = liftF $ EvalLogger logger id

evalRandom' :: L.RandomL a -> LangL a
evalRandom' g = liftF $ EvalRandom g id

evalControlFlow' :: L.ControlFlowL a -> LangL a
evalControlFlow' a = liftF $ EvalControlFlow a id

instance C.Lang L.LoggerL L.RandomL L.ControlFlowL L.StateL LangL where
  evalStateAtomically = evalStateAtomically'
  evalLogger          = evalLogger'
  evalRandom          = evalRandom'
  evalControlFlow     = evalControlFlow'

instance L.StateIO LangL where
  newVarIO       = evalStateAtomically' . L.newVar
  readVarIO      = evalStateAtomically' . L.readVar
  writeVarIO var = evalStateAtomically' . L.writeVar var
  retryIO        = evalStateAtomically' L.retry

instance L.Atomically L.StateL LangL where
  atomically = evalStateAtomically'

instance L.Logger LangL where
  logMessage level msg = evalLogger' $ L.logMessage level msg

instance L.Random LangL where
  getRandomInt = evalRandom' . L.getRandomInt

instance L.ControlFlow LangL where
  delay i = evalControlFlow' $ L.delay i





initKVDB :: D.KVDBConfig db -> LangL (D.DBResult (D.KVDBStorage db))
initKVDB config = liftF $ InitKVDB config id

evalKVDB :: D.KVDBStorage db -> L.KVDBL db a -> LangL a
evalKVDB conn script = liftF $ EvalKVDB conn script id

withKVDB :: D.KVDBStorage db -> L.KVDBL db a -> LangL a
withKVDB = evalKVDB
