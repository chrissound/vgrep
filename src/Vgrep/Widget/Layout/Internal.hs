{-# LANGUAGE TemplateHaskell #-}
module Vgrep.Widget.Layout.Internal where

import Control.Lens

-- $setup
-- >>> :set -fno-warn-missing-fields

data Ratio
    = Dynamic Rational
    | FixedPrimary Int
    | FixedSecondary Int
    deriving (Eq)

data Orientation = Horizontal | Vertical deriving (Eq)

data Focus = PrimaryOnly | FocusPrimary | FocusSecondary | SecondaryOnly
    deriving (Eq)

data Layout s t = Layout
    { _splitRatio  :: Ratio
    , _orientation :: Orientation
    , _primary     :: s
    , _secondary   :: t
    , _focus       :: Focus }

makeLenses ''Layout


-- | The currently focused child widget
--
-- >>> view focusedWidget $ Layout { _primary = "foo", _focus = PrimaryOnly }
-- Left "foo"
--
-- >>> view focusedWidget $ Layout { _primary = "foo", _focus = FocusPrimary }
-- Left "foo"
--
-- >>> view focusedWidget $ Layout { _secondary = "bar", _focus = FocusSecondary }
-- Right "bar"
focusedWidget :: Getter (Layout s t) (Either s t)
focusedWidget = to getCurrentWidget
  where
    getCurrentWidget state = case view focus state of
        PrimaryOnly    -> Left  (view primary state)
        FocusPrimary   -> Left  (view primary state)
        FocusSecondary -> Right (view secondary state)
        SecondaryOnly  -> Right (view secondary state)