module Astro.Catalogue where

import qualified Data.Map       as Map
import qualified Data.Set       as Set

import qualified Hydra.Domain   as D
import qualified Hydra.Language as L
import           Hydra.Prelude
import qualified Hydra.Runtime  as R

import           Astro.Types
import           Astro.KVDB.Model
import           Astro.Lens

-- withKBlocksDB
--     ::
--     -- forall s db a
--     -- .  Lens.HasKBlocksDB s (D.Storage db)
--     -- =>
--     D.KVDBStorage CatalogueDB
--     -> L.KVDBL db a
--     -> L.LangL a
-- withKBlocksDB kvDBModel = L.withDatabase (kvDBModel ^. Lens.meteorsTable)

loadMeteorsCount :: L.KVDBL CatalogueDB Int
loadMeteorsCount = do
  eTest <- L.getValue "test"

  pure 10

dynamicsMonitor :: AppState -> L.LangL ()
dynamicsMonitor st = do
  meteorsCount <- L.withKVDB (st ^. catalogueDB) loadMeteorsCount
  -- L.logInfo $ "Meteors count: " +|| meteorsCount ||+ ""

  pure ()


initState :: AppConfig -> L.AppL AppState
initState cfg = do
  eCatalogueDB <- L.scenario
    $ L.initKVDB
    $ D.KVDBConfig @CatalogueDB "catalogue"
    $ D.KVDBOptions True False

  catalogueDB <- case eCatalogueDB of
    Right db -> pure db
    Left err -> do
      L.logError $ "Failed to init KV DB catalogue: " +|| err ||+ ""
      error $ "Failed to init KV DB catalogue: " +|| err ||+ ""    -- TODO

  totalMeteors <- L.newVarIO 0

  pure $ AppState
    { _catalogueDB = catalogueDB
    , _totalMeteors = totalMeteors
    , _config = cfg
    }

astroCatalogue :: AppConfig -> L.AppL ()
astroCatalogue cfg = do
  appSt <- initState cfg

  L.process $ dynamicsMonitor appSt

  L.awaitAppForever
