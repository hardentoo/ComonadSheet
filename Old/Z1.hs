{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses #-}

module Z1
   ( module Generic , Z1
   , zipper , zipperOf , zipIterate
   , switch
   , insertL , insertR , deleteL , deleteR
   , insertListR , insertListL
   ) where

import Generic

data Z1 i a = Z1 !i [a] a [a]

instance Functor (Z1 i) where
   fmap f = Z1 <$> index
               <*> fmap f . viewL
               <*>      f . view
               <*> fmap f . viewR

instance (Enum i, Ord i) => Applicative (Z1 i) where
   fs <*> xs =
      Z1 (index fs)
         (zipWith ($) (viewL fs) (viewL xs))
         (view fs $ view xs)
         (zipWith ($) (viewR fs) (viewR xs))
   -- In the case of bounded types, the (toEnum 0) might be a problem; use zipperOf to specify a custom starting index for the zipper
   pure = zipperOf (toEnum 0)

instance (Enum i, Ord i) => ComonadApply (Z1 i) where
   (<@>) = (<*>)

instance (Ord i, Enum i) => Comonad (Z1 i) where
   extract   = view
   duplicate = widthWise
      where widthWise = zipIterate zipL zipR <$> col <*> id

instance AnyZipper (Z1 i a) i a where
   index (Z1 i _ _ _) = i
   view  (Z1 _ _ c _) = c
   write   c (Z1 i l _ r) = Z1 i l c r
   reindex i (Z1 _ l c r) = Z1 i l c r

instance (Enum i, Ord i) => Zipper1 (Z1 i a) i where
   zipL (Z1 i (l : ls) cursor rs) =
      Z1 (pred i) ls l (cursor : rs)
   zipL _ = error "zipL of non-infinite zipper; the impossible has occurred"

   zipR (Z1 i ls cursor (r : rs)) =
      Z1 (succ i) (cursor : ls) r rs
   zipR _ = error "zipR of non-infinite zipper; the impossible has occurred"

   col = index

instance (Ord c, Enum c) => RefOf (Ref c) (Z1 c a) [a] where
   go = genericDeref zipL zipR index
   insert = insertListR
   slice ref1 ref2 z =
      if dist >= 0
         then take     (dist + 1) . viewR $ go left  loc1
         else take ((- dist) + 1) . viewL $ go right loc1
      where loc1 = go ref1 z
            loc2 = go ref2 z
            dist = fromEnum (index loc2) - fromEnum (index loc1)

zipper :: i -> [a] -> a -> [a] -> Z1 i a
zipper i ls cursor rs = Z1 i (cycle ls) cursor (cycle rs)

zipperOf :: i -> a -> Z1 i a
zipperOf = zipIterate id id

zipIterate :: (a -> a) -> (a -> a) -> i -> a -> Z1 i a
zipIterate prev next i current =
   Z1 i <$> (tail . iterate prev)
        <*> id
        <*> (tail . iterate next) $ current

viewL :: Z1 i a -> [a]
viewL (Z1 _ ls _ _) = ls

viewR :: Z1 i a -> [a]
viewR (Z1 _ _ _ rs) = rs

switch :: Z1 i a -> Z1 i a
switch (Z1 i ls cursor rs) = Z1 i rs cursor ls

insertR, insertL :: a -> Z1 i a -> Z1 i a
insertR x (Z1 i ls cursor rs) = Z1 i ls x (cursor : rs)
insertL x (Z1 i ls cursor rs) = Z1 i (cursor : ls) x rs

insertListR, insertListL :: [a] -> Z1 i a -> Z1 i a

insertListR [] z = z
insertListR list (Z1 i ls cursor rs) =
   Z1 i ls (head list) (tail list ++ cursor : rs)

insertListL [] z = z
insertListL list (Z1 i ls cursor rs) =
   Z1 i (tail list ++ cursor : ls) (head list) rs

deleteL, deleteR :: Z1 i a -> Z1 i a
deleteL (Z1 i (l : ls) cursor rs) = Z1 i ls l rs
deleteL _                         = error "deleteL: empty zipper"
deleteR (Z1 i ls cursor (r : rs)) = Z1 i ls r rs
deleteR _                         = error "deleteR: empty zipper"
