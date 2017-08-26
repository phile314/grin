{-# LANGUAGE DeriveGeneric, DeriveAnyClass, DeriveFunctor, TypeFamilies #-}
{-# LANGUAGE DeriveFoldable, DeriveTraversable #-}
{-# LANGUAGE DataKinds, GADTs, KindSignatures, ConstraintKinds #-}
{-# LANGUAGE LambdaCase, RankNTypes #-}
module Grin where

import Data.Functor.Foldable as Foldable
import Control.DeepSeq
import Data.Map (Map)
import GHC.Generics (Generic)

type Name = String

type Prog = Map Name Def

data Def = Def Name [Name] Exp
  deriving Show


type SimpleExp = Exp
type Alt = Exp

data ExpKind = E | S | A
class ExpG (a :: ExpKind -> *) where
  bindG :: a S -> LPat -> a E -> a E    
  caseG :: Val -> [a A]          -> a E
  sExpG :: a S                   -> a E

  appG    :: Name -> [SimpleVal]    -> a S
  returnG :: Val                    -> a S
  storeG  :: Val                    -> a S
  fetchG  :: Name                   -> a S
  updateG :: Name -> Val            -> a S
  blockG  :: a E                 -> a S

  altG    :: CPat -> a E         -> a A

newtype ExpGT a = ExpGT Exp

data Exp
  = EBind    SimpleExp LPat Exp
  | ECase    Val [Alt]
  | ESExp    SimpleExp
  -- Simple Expr
  | SApp     Name [SimpleVal]
  | SReturn  Val
  | SStore   Val
  | SFetch   Name
  | SUpdate  Name Val
  | SBlock   Exp
  -- Alt
  | Alt CPat Exp
  deriving (Generic, NFData, Eq, Show)

fromExpG :: forall (e :: ExpKind) . ExpG e -> Exp
fromExpG = \case
  BindG simpleExp lpat exp -> EBind (fromExpG simpleExp) lpat (fromExpG exp)
  CaseG val alts           -> ECase val (fmap fromExpG alts)
  SExpG exp                -> ESExp (fromExpG exp)

  AppG    name simpleVals -> SApp name simpleVals
  ReturnG val             -> SReturn val
  StoreG  val             -> SStore val
  FetchG  name            -> SFetch name
  UpdateG name val        -> SUpdate name val
  BlockG  exp             -> SBlock (fromExpG exp)

  AltG cpat exp           -> Alt cpat (fromExpG exp)

toExpGE :: Exp -> ExpG E
toExpGE = \case
  EBind simpleExp lpat exp -> BindG (toExpGS simpleExp) lpat (toExpGE exp)
  ECase val alts           -> CaseG val (fmap toExpGA alts)
  ESExp simpleExp          -> SExpG (toExpGS simpleExp)

toExpGS :: Exp -> ExpG S
toExpGS = \case
  SApp name simpleVals     -> AppG name simpleVals
  SReturn val              -> ReturnG val
  SStore val               -> StoreG val
  SFetch name              -> FetchG name
  SUpdate name val         -> UpdateG name val

toExpGA :: Exp -> ExpG A
toExpGA = \case
  Alt cpat exp             -> AltG cpat (toExpGE exp)

type LPat = Val
type SimpleVal = Val
data Val
  = ConstTagNode  Tag  [SimpleVal] -- complete node (constant tag)
  | VarTagNode    Name [SimpleVal] -- complete node (variable tag)
  | ValTag        Tag
  | Unit
  -- simple val
  | Lit Lit
  | Var Name
  -- extra
  | Loc Int
  | Undefined
  deriving (Generic, NFData, Eq, Show)

data Lit = LFloat Float
  deriving (Generic, NFData, Eq, Show)

data CPat
  = NodePat Tag [Name]
  | TagPat  Tag
  | LitPat  Lit
  deriving (Generic, NFData, Eq, Show)

data TagType = C | F | P
  deriving (Generic, NFData, Eq, Show)

data Tag = Tag TagType Name Int -- is this arity?
  deriving (Generic, NFData, Eq, Show)

-- * shahe functors

data ExpF a
  = EBindF    a LPat a
  | ECaseF    Val [a]
  | ESExpF    a
  -- Simple Expr
  | SAppF     Name [SimpleVal]
  | SReturnF  Val
  | SStoreF   Val
  | SFetchF   Name
  | SUpdateF  Name Val
  | SBlockF   a
  -- Alt
  | AltF CPat a
  deriving (Generic, NFData, Eq, Show, Functor, Foldable, Traversable)

type instance Base Exp = ExpF
instance Recursive Exp where
  -- Expression
  project (EBind    simpleExp lpat exp) = EBindF simpleExp lpat exp
  project (ECase    val alts) = ECaseF val alts
  project (ESExp    simpleExp) = ESExpF simpleExp
  -- Simple Expr
  project (SApp     name simpleVals) = SAppF name simpleVals
  project (SReturn  val) = SReturnF val
  project (SStore   val) = SStoreF val
  project (SFetch   name) = SFetchF name
  project (SUpdate  name val) = SUpdateF name val
  project (SBlock   exp) = SBlockF exp
  -- Alt
  project (Alt cpat exp) = AltF cpat exp

instance Corecursive Exp where
  -- Expression
  embed (EBindF    simpleExp lpat exp) = EBind simpleExp lpat exp
  embed (ECaseF    val alts) = ECase val alts
  embed (ESExpF    simpleExp) = ESExp simpleExp
  -- Simple Expr
  embed (SAppF     name simpleVals) = SApp name simpleVals
  embed (SReturnF  val) = SReturn val
  embed (SStoreF   val) = SStore val
  embed (SFetchF   name) = SFetch name
  embed (SUpdateF  name val) = SUpdate name val
  embed (SBlockF   exp) = SBlock exp
  -- Alt
  embed (AltF cpat exp) = Alt cpat exp
