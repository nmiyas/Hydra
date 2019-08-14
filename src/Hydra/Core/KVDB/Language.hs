{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE TemplateHaskell       #-}

module Hydra.Core.KVDB.Language where

import           Hydra.Prelude

import qualified Hydra.Core.Domain.DB   as D
import qualified Hydra.Core.Domain.KVDB as D

import           Language.Haskell.TH.MakeFunctor (makeFunctorInstance)

data KVDBF next where
  Save :: D.KVDBKey -> D.KVDBValue -> (D.DBResult () -> next) -> KVDBF next
  Load :: D.KVDBKey -> (D.DBResult D.KVDBValue -> next) -> KVDBF next


makeFunctorInstance ''KVDBF

type KVDBL db = Free KVDBF

save'
  :: forall src entity db
   . D.DBEntity db entity
  => D.AsKeyEntity db entity src
  => D.AsValueEntity db entity src
  => D.RawDBEntity db entity
  => src
  -> KVDBL db (D.DBResult ())
save' src = liftF $ Save dbkey dbval id
  where
    k :: D.KeyEntity db entity
    k = D.toKeyEntity src
    v :: D.ValueEntity db entity
    v = D.toValueEntity src
    dbkey = D.toDBKey @db k
    dbval = D.toDBValue @db v

load'
  :: forall entity dst db
   . D.DBEntity db entity
  => D.AsValueEntity db entity dst
  => D.RawDBEntity db entity
  => Show (D.KeyEntity db entity)
  => D.KeyEntity db entity
  -> KVDBL db (D.DBResult dst)
load' key = do
  eRawVal <- liftF $ Load (D.toDBKey @db key) id
  pure $ case eRawVal of
    Left err  -> Left err
    Right val -> maybe (decodingErr val) (Right . D.fromValueEntity) $ mbE val
  where
    mbE :: D.KVDBValue -> Maybe (D.ValueEntity db entity)
    mbE = D.fromDBValue @db
    decodingErr val = Left
      $ D.DBError D.DecodingFailed
      $ "Failed to decode entity, k: "
          <> show key <> ", v: " <> show val

-- putEntity'
--     :: forall entity db src
--     .  D.RawDBEntity db entity
--     => D.ToDBKey   entity src
--     => D.ToDBValue entity src
--     => src
--     -> KVDBL db (D.DBResult ())
-- putEntity' src = let
--     rawKey = D.toRawDBKey   @db @entity $ D.toDBKey   src
--     rawVal = D.toRawDBValue @db @entity $ D.toDBValue src
--     in putValue rawKey rawVal
--
-- -- | Gets a typed entity from the corresponding DB.
-- getEntity
--     :: forall entity db
--     . (FromJSON (D.DBValue entity), D.RawDBEntity db entity, Typeable (D.DBValue entity))
--     => D.DBKey entity
--     -> KVDBL db (D.DBResult (D.DBE entity))
-- getEntity dbKey = do
--     let rawKey = D.toRawDBKey @db dbKey
--     let proxyVal = error "Don't call me, I'm Proxy" :: D.DBValue entity
--     eRawVal <- getValue rawKey
--     case eRawVal of
--         Left err       -> pure $ Left err
--         Right rawVal   -> case D.fromRawDBValue @db rawVal of
--             Nothing    -> pure $ Left $ D.DBError D.InvalidType ("Expected type: " <> show (typeOf proxyVal)
--                             <> ". Raw key: <" <> decodeUtf8 rawKey <>  ">. Raw data: <" <> decodeUtf8 rawVal <> ">")
--             Just dbVal -> pure $ Right (dbKey, dbVal)
--
-- -- | Gets a typed value from the corresponding DB.
-- getValue
--     :: (FromJSON (D.DBValue entity), D.RawDBEntity db entity, Typeable (D.DBValue entity))
--     => D.DBKey entity
--     -> KVDBL db (D.DBResult (D.DBValue entity))
-- getValue dbKey = do
--     eEntity <- getEntity dbKey
--     pure $ eEntity >>= Right . snd
--
-- -- | Gets a typed value from the corresponding DB.
-- getValue'
--     :: (FromJSON (D.DBValue entity), D.RawDBEntity db entity, Typeable (D.DBValue entity))
--     => D.ToDBKey entity src
--     => src
--     -> KVDBL db (D.DBResult (D.DBValue entity))
-- getValue' src = do
--     eEntity <- getEntity $ D.toDBKey src
--     pure $ eEntity >>= Right . snd
--
-- -- | Gets a typed value from the corresponding DB.
-- -- The difference from @getValue@ is that it forgets about DB errors.
-- findValue
--     :: (FromJSON (D.DBValue entity), D.RawDBEntity db entity, Typeable (D.DBValue entity))
--     => D.DBKey entity
--     -> KVDBL db (Maybe (D.DBValue entity))
-- findValue key = do
--     eVal <- getValue key
--     pure $ either (const Nothing) Just eVal
--
-- -- | Gets a typed value from the corresponding DB.
-- -- The difference from @getValue'@ is that it forgets about DB errors.
-- findValue'
--     :: (FromJSON (D.DBValue entity), D.RawDBEntity db entity, Typeable (D.DBValue entity))
--     => D.ToDBKey entity src
--     => src
--     -> KVDBL db (D.DBResult (Maybe (D.DBValue entity)))
-- findValue' src = do
--     eVal <- getValue' src
--     case eVal of
--         Left (D.DBError D.KeyNotFound _) -> pure $ Right Nothing
--         Left err                         -> pure $ Left err
--         Right val                        -> pure $ Right $ Just val
