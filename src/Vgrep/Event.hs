{-# LANGUAGE DeriveFunctor #-}
module Vgrep.Event
    ( EventHandler ()
    , runEventHandler
    , mkEventHandler
    , mkEventHandlerIO
    , liftEventHandler

    , Next (..)

    , handle

    , keyEvent
    , keyCharEvent
    , resizeEvent
    , continueIO
    , continue
    , suspend
    , halt
    ) where

import Control.Applicative
import Control.Monad.State.Extended ( State, StateT
                                    , execStateT, liftState )
import qualified Graphics.Vty as Vty
import Graphics.Vty.Prelude

import Vgrep.Type


newtype EventHandler e s = EventHandler
    { runEventHandler :: e -> s -> VgrepT IO (Next s) }

mkEventHandler :: (e -> s -> Next s) -> EventHandler e s
mkEventHandler f = EventHandler $ \e s -> pure (f e s)

mkEventHandlerIO :: (e -> s -> VgrepT IO (Next s)) -> EventHandler e s
mkEventHandlerIO = EventHandler

liftEventHandler :: (e -> Maybe e') -> EventHandler e' s -> EventHandler e s
liftEventHandler f (EventHandler h) = EventHandler $ \e -> case f e of
    Just e' -> h e'
    Nothing -> const (pure Unchanged)


instance Monoid (EventHandler e s) where
    mempty = EventHandler $ \_ _ -> pure Unchanged
    h1 `mappend` h2 = EventHandler $ \ev s ->
        liftA2 mappend (runEventHandler h1 ev s) (runEventHandler h2 ev s)

data Next s = Continue s
            | Resume (VgrepT IO s)
            | Halt s
            | Unchanged
            deriving (Functor)

instance Monoid (Next s) where
    mempty = Unchanged
    Unchanged `mappend` next = next
    next      `mappend` _    = next


handle :: (e -> Maybe e')
       -> (e' -> s -> VgrepT IO (Next s))
       -> EventHandler e s
handle select action = mkEventHandlerIO $ \event state ->
    case select event of
        Just event' -> action event' state
        Nothing     -> pure Unchanged

keyEvent :: Vty.Key -> [Vty.Modifier] -> Vty.Event -> Maybe ()
keyEvent k ms = \case
    Vty.EvKey k' ms' | (k', ms') == (k, ms) -> Just ()
    _otherwise                              -> Nothing

keyCharEvent :: Char -> [Vty.Modifier] -> Vty.Event -> Maybe ()
keyCharEvent c = keyEvent (Vty.KChar c)

resizeEvent :: Vty.Event -> Maybe DisplayRegion
resizeEvent = \case
    Vty.EvResize w h -> Just (w, h)
    _otherwise       -> Nothing


continueIO :: StateT s (VgrepT IO) () -> s -> VgrepT IO (Next s)
continueIO action state = (fmap Continue . execStateT action) state

continue :: Monad m => StateT s (VgrepT m) () -> s -> VgrepT IO (Next s)
continue action = undefined --continueIO (liftState action)

suspend :: StateT s (VgrepT IO) () -> s -> VgrepT IO (Next s)
suspend action = pure . Resume . execStateT action

halt :: s -> VgrepT IO (Next s)
halt state = pure (Halt state)
