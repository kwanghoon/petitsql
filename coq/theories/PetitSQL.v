Require Import Arith.
Require Import Ascii.
Require Import Bool.
Require Import Coq.Arith.PeanoNat.
Require Import Coq.Lists.List.
Require Import Coq.micromega.Lia.
Require Import Coq.Program.Program.
Require Import Coq.Strings.Byte.
Require Import Coq.Strings.String.

Module Utils.

  Import ListNotations.

  Class Monad (M : Type -> Type) : Type :=
    { pure {A : Type} : A -> M A
    ; bind {A : Type} {B : Type} : M A -> (A -> M B) -> M B
    }.

  Global Infix " >>= " := bind (left associativity, at level 90).

  Global Instance option_isMonad : Monad option :=
    { pure {A} (x : A) := Some x
    ; bind {A} {B} (m : option A) (k : A -> option B) :=
      match m with
      | Some x => k x
      | None => None
      end
    }.

  Global Instance list_isMonad : Monad list :=
    { pure {A} (x : A) := [x]
    ; bind {A} {B} (m : list A) (k : A -> list B) := List.concat (List.map k m)
    }.

  Class Alternative (F : Type -> Type) : Type :=
    { empty {A : Type} : F A
    ; alt {A : Type} : F A -> F A -> F A
    }.

  Global Infix " <|> " := alt (left associativity, at level 50).

  Global Instance option_isAlternative : Alternative option :=
    { empty {A} := None
    ; alt {A} (m1 : option A) (m2 : option A) :=
      match m1 with
      | Some x1 => Some x1
      | None => m2
      end
    }.

  Global Instance list_isAlternative : Alternative list :=
    { empty {A} := []
    ; alt {A} (xs1 : list A) (xs2 : list A) := xs1 ++ xs2
    }.

  Lemma lt_strongInd (P : nat -> Prop)
    (IND : forall n : nat, forall IH : forall m : nat, m < n -> P m, P n)
    : forall n : nat, P n.
  Proof.
    intros n. eapply IND. induction n as [ | n IH].
    - intros m H_lt. inversion H_lt.
    - intros m H_lt. eapply IND.
      intros i i_lt_m. eapply IH. lia.
  Defined.

  Lemma acc_lt
    : forall x : nat, Acc Nat.lt x.
  Proof. exact (lt_strongInd (@Acc nat Nat.lt) (@Acc_intro nat Nat.lt)). Defined.

  Lemma acc_rel {A : Type} {B : Type} (f : A -> B) (R : B -> B -> Prop)
    (R_wf : forall y : B, Acc R y)
    : forall x : A, Acc (fun lhs : A => fun rhs : A => R (f lhs) (f rhs)) x.
  Proof.
    intros x. remember (f x) as y eqn: y_eq_f_x.
    revert x y_eq_f_x. induction (R_wf y) as [y' hyp_wf IH].
    intros x' hyp_eq. econstructor. intros x f_x_R_f_x'.
    subst y'. eapply IH; [exact (f_x_R_f_x') | reflexivity].
  Defined.

End Utils.

Export Utils.

Module P.

  Import ListNotations.

  Definition parserT (M : Type -> Type) (A : Type) : Type := string -> M (prod A string).

  Global Instance parserT_isMonad {M : Type -> Type} (M_isMonad : Monad M) : Monad (parserT M) :=
    { pure {A} := curry pure
    ; bind {A} {B} (m : parserT M A) (k : A -> parserT M B) := fun s : string => m s >>= uncurry k
    }.

  Global Instance parserT_isAlternative {M : Type -> Type} (M_isAlternative : Alternative M) : Alternative (parserT M) :=
    { empty {A} := fun s : string => empty
    ; alt {A} (p1 : parserT M A) (p2 : parserT M A) := fun s : string => p1 s <|> p2 s
    }.

  Definition parser : Type -> Type := parserT option.

  Definition isLt {A : Type} (p : parser A) : Prop :=
    forall s : string,
    match p s with
    | Some (x, s') => length s' < length s
    | None => True
    end.

  Definition isLe {A : Type} (p : parser A) : Prop :=
    forall s : string,
    match p s with
    | Some (x, s') => length s' <= length s
    | None => True
    end.

  Definition satisfy (p : ascii -> bool) : parser ascii :=
    fun s : string =>
    match s with
    | EmptyString => None
    | String ch s' => if p ch then Some (ch, s') else None
    end.

  Lemma satisfy_isLt (p : ascii -> bool)
    : isLt (satisfy p).
  Proof.
    intros s. unfold satisfy. destruct s as [ | ch s']; trivial.
    destruct (p ch); trivial. simpl. red. reflexivity.
  Qed.

  #[program]
  Fixpoint some {A : Type} (p : parser A) (p_isLt : isLt p) (s : string) {measure (length s)} : option (list A * string) :=
    match p s with
    | None => None
    | Some (x, s') =>
      match some p p_isLt s' with
      | None => Some ([x], s')
      | Some (xs, s'') => Some (x :: xs, s'')
      end
    end.
  Next Obligation. pose proof (p_isLt s) as H. rewrite <- Heq_anonymous in H. assumption. Defined.

  Example some_example1
    : (some (satisfy (fun ch : ascii => true)) (satisfy_isLt _) "abc"%string)
    = Some (["a"%char; "b"%char; "c"%char], ""%string).
  Proof. reflexivity. Qed.

  Example some_example2
    : (some (satisfy (fun ch : ascii => Ascii.eqb ch "a"%char)) (satisfy_isLt _) "abc"%string)
    = Some (["a"%char], "bc"%string).
  Proof. reflexivity. Qed.

  Example some_example3
    : (some (satisfy (fun ch : ascii => Ascii.eqb ch "b"%char)) (satisfy_isLt _) "abc"%string)
    = None.
  Proof. reflexivity. Qed. 

  Lemma some_unfold {A : Type} (p : parser A) (p_isLt : isLt p) (s : string) :
    some p p_isLt s =
    match p s with
    | None => None
    | Some (x, s') =>
      match some p p_isLt s' with
      | None => Some ([x], s')
      | Some (xs, s'') => Some (x :: xs, s'')
      end
    end.
  Admitted.

(**
  Inductive some_SPEC {A : Type} (p : parser A) (s : string) : option (list A * string) -> Prop :=
  | some_SPEC_intro1 (x : A) (s' : string) (xs : list A) (s'' : string)
    (OBS_p_s : p s = Some (x, s'))
    (OBS_some_p_s' : many_SPEC p s' (Some (xs, s'')))
    : some_SPEC p s (Some (x :: xs, s''))
  | some_SPEC_intro2 (x : A) (s' : string)
    (OBS_p_s : p s = None)
    (OBS_some_p_s' : many_SPEC p s' None)
    : some_SPEC p s None
  with many_SPEC {A : Type} (p : parser A) (s : string) : option (list A * string) -> Prop :=
  | many_SPEC_intro1 (xs : list A) (s' : string)
    (OBS_p_s : some_SPEC p s (Some (xs, s')))
    : many_SPEC p s (Some (xs, s'))
  | many_SPEC_intro2
    (OBS_p_s : p s = None)
    : many_SPEC p s (Some ([], s)).

  Inductive someSpecStmt {A : Type} (p : parser A) (s : string) : option (list A * string) -> Prop :=
  | someSpecStmt_intro1
    (OBS_p_s : p s = None)
    : someSpecStmt p s None
  | someSpecStmt_intro2 (x : A) (s' : string)
    (OBS_p_s : p s = Some (x, s'))
    (OBS_some_p_s' : someSpecStmt p s' None)
    : someSpecStmt p s (Some ([x], s'))
  | someSpecStmt_intro3 (x : A) (s' : string) (xs : list A) (s'' : string)
    (OBS_p_s : p s = Some (x, s'))
    (OBS_some_p_s' : someSpecStmt p s' (Some (xs, s'')))
    : someSpecStmt p s (Some (x :: xs, s'')).

  Definition some {A : Type}
    (p : parser A)
    (p_isLt : isLt p)
    : {some_p : parser (list A) | isLt some_p /\ (forall s : string, someSpecStmt p s (some_p s))}.
  Proof.
    enough (to_show : forall s : string, {res : option (list A * string) | (match res with Some (x, s') => length s' < length s | None => True end) /\ someSpecStmt p s res}).
    { exists (fun s : string => proj1_sig (to_show s)). split; intros s; destruct (to_show s) as [? [? ?]]; eauto. }
    enough (MAIN : forall s : string, Acc (fun s1 : string => fun s2 : string => length s1 < length s2) s -> {res : option (list A * string) | (match res with Some (x, s') => length s' < length s | None => True end) /\ someSpecStmt p s res}).
    { exact (fun s : string => MAIN s (Utils.acc_rel length Nat.lt Utils.acc_lt s)). }
    eapply Acc_rect. intros s _ IH. destruct (p s) as [[x s'] | ] eqn: OBS_p1_s.
    - pose proof (p_isLt s) as s_isLongerThan_s'. rewrite OBS_p1_s in s_isLongerThan_s'.
      pose proof (IH s' s_isLongerThan_s') as [[[xs s''] | ] [H1_ps H2_ps]].
      { exists (Some ((x :: xs), s'')). split; [etransitivity | econstructor 3]; eauto. }
      { exists (Some ([x], s')). split; [assumption | econstructor 2]; eauto. }
    - { exists (None). split; [trivial | econstructor 1]; eauto. }
  Defined.

*)

End P.

Module Hs.

  Inductive strSQLElem : Set :=
  | Text : string -> strSQLElem
  | Hole : string -> strSQLElem.

  Inductive value : Set :=
  | ColName : string -> value
  | StrVal  : string -> value
  | Var     : string -> value.

  Inductive term : Set := 
  | equalTerm : value -> value -> term.

  Inductive pred : Set := 
  | orPred : pred -> pred -> pred
  | termPred : term -> pred.

  Inductive cols : Set :=
  | star : cols
  | colNames : list string -> cols.

  Inductive sql : Set :=
  | sqlSFW : cols -> string -> option pred -> sql.

  Fixpoint normPred_measure (p : pred) {struct p} : nat :=
    match p with
    | termPred t => 0
    | orPred p1 p2 => 1 + (2 * normPred_measure p1 + normPred_measure p2)
    end.

  #[program]
  Fixpoint normPred (p : pred) {measure (normPred_measure p)} : pred :=
    match p with
    | termPred t => termPred t
    | orPred (termPred t1) p2 => orPred (termPred t1) (normPred p2)
    | orPred (orPred p11 p12) p2 => normPred (orPred p11 (orPred p12 p2))
    end.
  Next Obligation. simpl. lia. Defined.

  Example normPred_example1
    : (normPred (orPred (orPred (termPred (equalTerm (ColName "A") (ColName "B"))) (termPred (equalTerm (ColName "C") (ColName "D")))) (termPred (equalTerm (ColName "E") (ColName "F")))))
    = orPred (termPred (equalTerm (ColName "A") (ColName "B"))) (orPred (termPred (equalTerm (ColName "C") (ColName "D"))) (termPred (equalTerm (ColName "E") (ColName "F")))).
  Proof. reflexivity. Qed.

  Lemma normPred_unfold (p : pred) :
    normPred p =
    match p with
    | termPred t => termPred t
    | orPred (termPred t1) p2 => orPred (termPred t1) (normPred p2)
    | orPred (orPred p11 p12) p2 => normPred (orPred p11 (orPred p12 p2))
    end.
  Proof with eauto.
    unfold normPred at 1. rewrite fix_sub_eq.
    - destruct p as [[? ? | ?] | ?]...
    - intros. destruct x as [[? ? | ?] | ?]; simpl... rewrite H...
  Qed.

End Hs.
