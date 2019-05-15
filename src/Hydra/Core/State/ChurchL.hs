{-# LANGUAGE GADTs           #-}
{-# LANGUAGE TemplateHaskell #-}

module Hydra.Core.State.ChurchL where

import           Hydra.Prelude

import qualified Hydra.Core.Domain               as D
import qualified Hydra.Core.Logger.ChurchL       as CL
import qualified Hydra.Core.Logger.Class         as L
import qualified Hydra.Core.State.Class          as L

import           Language.Haskell.TH.MakeFunctor

-- | State language. It reflects STM and its behavior.
data StateF next where
  -- | Create variable.
  NewVar :: a -> (D.StateVar a -> next) -> StateF next
  -- | Read variable.
  ReadVar :: D.StateVar a -> (a -> next) -> StateF next
  -- | Write variable.
  WriteVar :: D.StateVar a -> a -> (() -> next) -> StateF next
  -- | Retry until some variable is changed in this atomic block.
  Retry :: (a -> next) -> StateF next
  -- | Eval "delayed" logger: it will be written after successfull state operation.
  EvalStmLogger :: CL.LoggerL () -> (() -> next) -> StateF next

makeFunctorInstance ''StateF

type StateL = F StateF

instance L.State' StateL where
  newVar   val     = liftFC $ NewVar val id
  readVar  var     = liftFC $ ReadVar var id
  writeVar var val = liftFC $ WriteVar var val id
  retry            = liftFC $ Retry id

instance L.Logger StateL where
  logMessage level msg = liftFC $ EvalStmLogger (L.logMessage level msg) id
