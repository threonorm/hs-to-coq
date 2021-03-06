Require Import Coq.Lists.List.

Require Import GHC.Base.
Require Import Proofs.Data.Foldable.

Require Import Id.
Require Import Core.

Require Import Proofs.Core.
Require Import Proofs.Var.
Require Import Proofs.Unique.
Require Import Proofs.VarSet.

Import GHC.Base.ManualNotations.

Set Bullet Behavior "Strict Subproofs".


(** ** [uniqAway] axiomatization *)

Axiom isJoinId_maybe_uniqAway:
  forall s v, 
  isJoinId_maybe (uniqAway s v) = isJoinId_maybe v.

(* See discussion of [isLocalUnique] in [Proofs.Unique] *)
Axiom isLocalUnique_uniqAway:
  forall iss v,
  isLocalUnique (varUnique (uniqAway iss v)) = true.

Axiom isLocalId_uniqAway:
  forall iss v,
  isLocalId (uniqAway iss v) = isLocalId v.

Axiom isLocalVar_uniqAway:
  forall iss v,
  isLocalVar (uniqAway iss v) = isLocalVar v.

Axiom nameUnique_varName_uniqAway:
  forall vss v,
  Name.nameUnique (varName v) = varUnique v ->
  Name.nameUnique (varName (uniqAway vss v)) = varUnique (uniqAway vss v).


(* If uniqAway returns a variable with the same unique, 
   it returns the same variable. *)      
Axiom uniqAway_eq_same : forall v in_scope_set,
    (uniqAway in_scope_set v == v) = true ->
    (uniqAway in_scope_set v = v).
  
(* The variable returned by uniqAway is fresh. *)
Axiom uniqAway_lookupVarSet_fresh : forall v in_scope_set,
    lookupVarSet (getInScopeVars in_scope_set) (uniqAway in_scope_set v) = None.

Lemma elemVarSet_uniqAway:
  forall v iss vs,
  subVarSet vs (getInScopeVars iss) = true ->
  elemVarSet (uniqAway iss v) vs = false.
Proof.
  intros.
  apply subVarSet_elemVarSet_false with (vs' := getInScopeVars iss). auto.
  rewrite <- lookupVarSet_None_elemVarSet.
  eapply uniqAway_lookupVarSet_fresh.  
Qed.



(** ** [VarEnv] axiomatization *)

(* Eventually replace these with container axioms. *)

Axiom lookupVarEnv_elemVarEnv_true :
  forall A v (vs : VarEnv A),
   elemVarEnv v vs = true <-> (exists a, lookupVarEnv vs v = Some a).

Axiom lookupVarEnv_elemVarEnv_false :
  forall A v (vs : VarEnv A),
   elemVarEnv v vs = false <-> (lookupVarEnv vs v = None).


Axiom lookupVarEnv_eq :
  forall A v1 v2 (vs : VarEnv A),
    (v1 == v2) = true ->
    lookupVarEnv vs v1 = lookupVarEnv vs v2.

Axiom elemVarEnv_eq :
  forall A v1 v2 (vs : VarEnv A),
    (v1 == v2) = true ->
    elemVarEnv v1 vs = elemVarEnv v2 vs.


Axiom lookupVarEnv_extendVarEnv_eq :
  forall A v1 v2 (vs : VarEnv A) val, 
    v1 == v2 = true ->
    lookupVarEnv (extendVarEnv vs v1 val) v2 = Some val.

Axiom lookupVarEnv_extendVarEnv_neq :
  forall A v1 v2 (vs : VarEnv A) val, 
    v1 == v2 <> true ->
    lookupVarEnv (extendVarEnv vs v1 val) v2 = lookupVarEnv vs v2.

Axiom elemVarEnv_extendVarEnv_eq :
  forall A v1 v2 (vs : VarEnv A) val, 
    v1 == v2 = true ->
    elemVarEnv v2 (extendVarEnv vs v1 val) = true.

Axiom elemVarEnv_extendVarEnv_neq :
  forall A v1 v2 (vs : VarEnv A) val, 
    v1 == v2 <> true ->
    elemVarEnv v2 (extendVarEnv vs v1 val) = elemVarEnv v2 vs.


Axiom elemVarEnv_delVarEnv_eq :
  forall A v1 v2 (vs : VarEnv A), 
    v1 == v2 = true ->
    elemVarEnv v2 (delVarEnv vs v1) = false.

Axiom elemVarEnv_delVarEnv_neq :
  forall A v1 v2 (env: VarEnv A), (v1 == v2) = false -> 
               elemVarEnv v2 (delVarEnv env v1) = elemVarEnv v2 env.


Axiom lookupVarEnv_delVarEnv_eq :
  forall A v1 v2 (vs : VarEnv A), 
    v1 == v2 = true ->
    lookupVarEnv (delVarEnv vs v1) v2 = None.

Axiom lookupVarEnv_delVarEnv_neq :
  forall A v1 v2 (vs : VarEnv A), 
    v1 == v2 <> true ->
    lookupVarEnv (delVarEnv vs v1) v2 = lookupVarEnv vs v2.


(** [minusDom] **)

(* To be able to specify the property of a wellformed substitution, 
   we need to define the operation of taking a variable set and 
   removing all of the vars that are part of the domain of the 
   substitution. *)


Definition minusDom {a} (vs : VarSet) (e : VarEnv a) : VarSet :=
  filterVarSet (fun v => negb (elemVarEnv v e)) vs.


Ltac specialize_all var := 
  repeat 
    match goal with 
    | [ H : forall var:Var, _ |- _ ] => specialize (H var)
    end.

(* After a case split on whether a var is present in a minusDom'ed env, 
   rewrite a use of minusDom appropriately. *)
Ltac rewrite_minusDom_true := 
  match goal with 
  | [ H : elemVarEnv ?var ?init_env = true |- 
      context [ lookupVarSet 
                  (minusDom ?s ?init_env) ?var ] ] =>  
    unfold minusDom;
    repeat rewrite lookupVarSet_filterVarSet_false with 
        (f := (fun v0 : Var => negb (elemVarEnv v0 init_env ))); try rewrite H; auto 
  | [ H : elemVarEnv ?var ?init_env = true, 
          H2: context [ lookupVarSet 
                          (minusDom ?s ?init_env) ?var ] |- _ ] =>  
    unfold minusDom in H2;
    rewrite lookupVarSet_filterVarSet_false with
        (f := (fun v0 : Var => negb (elemVarEnv v0 init_env ))) in H2; 
    try rewrite H; auto 
                                                                    
  end.

Ltac rewrite_minusDom_false := 
  match goal with 
  | [ H : elemVarEnv ?var ?init_env  = false |- 
      context [ lookupVarSet 
                  (minusDom ?s ?init_env) ?var ] ] =>  
    unfold minusDom;
    repeat rewrite lookupVarSet_filterVarSet_true
    with (f := (fun v0 : Var => negb (elemVarEnv v0 init_env ))); 
    try rewrite H; auto 
  | [ H : elemVarEnv ?var ?init_env = false, 
          H2: context [ lookupVarSet 
                          (minusDom ?s ?init_env) ?var ] |- _ ] =>  
    unfold minusDom in H2;
    rewrite lookupVarSet_filterVarSet_true with 
        (f := (fun v0 : Var => negb (elemVarEnv v0 init_env ))) in H2 ; 
    try rewrite H; auto  
  end.


Lemma StrongSubset_minusDom {a} : forall vs1 vs2 (e: VarEnv a), 
    vs1 {<=} vs2 ->
    minusDom vs1 e {<=} minusDom vs2 e.
Proof.
  intros. 
  unfold StrongSubset in *.
  intros var.
  destruct (elemVarEnv var e) eqn:IN_ENV.
  + rewrite_minusDom_true. 
  + rewrite_minusDom_false.
    eapply H.
Qed.


Lemma lookupVarSet_minusDom_1 :
  forall a (env : VarEnv a) vs v,
    lookupVarEnv env v = None -> 
    lookupVarSet (minusDom vs env) v = lookupVarSet vs v.
Proof.
  intros.
  rewrite <- lookupVarEnv_elemVarEnv_false in H.
  unfold minusDom.
  rewrite lookupVarSet_filterVarSet_true
    with (f := (fun v0 : Var => negb (elemVarEnv v0 env))).
  auto.
  rewrite H. simpl. auto.
Qed.



Lemma lookup_minusDom_inDom : forall a vs (env:VarEnv a) v',
    elemVarEnv v' env = true ->
    lookupVarSet (minusDom vs env) v' = None.
Proof.
  intros.
  rewrite_minusDom_true.
Qed. 


Lemma minusDom_extend : 
  forall a vs (env : VarEnv a) v,
    minusDom (extendVarSet vs v) (delVarEnv env v) {<=} 
    extendVarSet (minusDom vs env) v.
Proof.
  intros.
  unfold StrongSubset.
  intros var.
  destruct (elemVarEnv var (delVarEnv env v)) eqn:IN.
  rewrite_minusDom_true.
  rewrite_minusDom_false.
  destruct (v == var) eqn:EQ.
  rewrite lookupVarSet_extendVarSet_eq;auto.
  rewrite lookupVarSet_extendVarSet_eq; auto.
  eapply almostEqual_refl; auto.
  rewrite lookupVarSet_extendVarSet_neq; auto.
  destruct (lookupVarSet vs var) eqn:IN2; auto.
  rewrite lookupVarSet_extendVarSet_neq; auto.
  rewrite lookupVarSet_filterVarSet_true; try rewrite IN; auto.
  rewrite IN2.
  apply almostEqual_refl; auto.
  rewrite elemVarEnv_delVarEnv_neq in IN; auto.
  rewrite IN. auto.
  intro h. rewrite h in EQ. discriminate.
  intro h. rewrite h in EQ. discriminate.
Qed.


Lemma lookup_minusDom_extend : forall a vs (env:VarEnv a) v v' e,
    v ==  v' <> true ->
    lookupVarSet (minusDom (extendVarSet vs v) (extendVarEnv env v e)) v' =
    lookupVarSet (minusDom vs env) v'.
Proof.
  intros.
  destruct (elemVarEnv v' env) eqn:Eenv; auto.
  + (* v' is in dom of env. so cannot be looked up. *)
    unfold minusDom.
    rewrite 2 lookupVarSet_filterVarSet_false; auto.  
    rewrite Eenv. simpl. auto.
    rewrite elemVarEnv_extendVarEnv_neq.
    rewrite Eenv. simpl. auto.
    auto.
  + unfold minusDom.
    rewrite 2 lookupVarSet_filterVarSet_true; auto.  
    rewrite lookupVarSet_extendVarSet_neq; auto.
    auto.
    rewrite Eenv. simpl. auto.
    rewrite elemVarEnv_extendVarEnv_neq.
    rewrite Eenv. simpl. auto.
    auto.
Qed.

Lemma StrongSubset_minusDom_left {a} : forall vs (e: VarEnv a), 
    minusDom vs e {<=} vs.
Proof.
  intros.
  unfold StrongSubset. intro var.
  destruct (elemVarEnv var e) eqn:EL.
  rewrite_minusDom_true.
  rewrite_minusDom_false.
  destruct lookupVarSet.
  eapply almostEqual_refl.
  auto.
Qed.


Lemma StrongSubset_minusDom_extend_extend : forall vs v e (env: IdEnv CoreExpr),
           minusDom (extendVarSet vs v) (extendVarEnv env v e) {<=} minusDom vs env.
Proof.
  intros.
  intro var.
  destruct (var == v) eqn:EQ.
  rewrite lookupVarSet_eq with (v2 := v); auto.
  unfold minusDom.
  rewrite lookupVarSet_filterVarSet_false. 
  auto.
  rewrite elemVarEnv_extendVarEnv_eq.
  simpl. auto.
  rewrite Base.Eq_refl. auto.
  rewrite lookup_minusDom_extend.
  destruct (lookupVarSet (minusDom vs env) var).
  eapply almostEqual_refl. auto.
  intro h.
  rewrite Base.Eq_sym in h.
  rewrite h in EQ.
  discriminate.
Qed.


(** ** [InScopeSet] *)

Lemma getInScopeVars_extendInScopeSet:
  forall iss v,
  getInScopeVars (extendInScopeSet iss v) = extendVarSet (getInScopeVars iss) v.
Proof.
  intros.
  unfold getInScopeVars.
  unfold extendInScopeSet.
  destruct iss.
  reflexivity.
Qed.

Lemma getInScopeVars_extendInScopeSetList:
  forall iss vs,
  getInScopeVars (extendInScopeSetList iss vs) = extendVarSetList (getInScopeVars iss) vs.
Proof.
  intros.
  unfold getInScopeVars.
  unfold extendInScopeSetList.
  set_b_iff.
  destruct iss.
  unfold_Foldable_foldl'.
  unfold_Foldable_foldl.
  f_equal.
Qed.


Lemma extendInScopeSetList_cons : forall v vs in_scope_set,
           (extendInScopeSetList in_scope_set (v :: vs) = 
            (extendInScopeSetList (extendInScopeSet in_scope_set v) vs)).
Proof.
  unfold extendInScopeSetList.
  destruct in_scope_set.
  unfold_Foldable_foldl.
  simpl.
  f_equal.
  unfold Pos.to_nat.
  unfold Pos.iter_op.
  omega.
Qed.

Lemma extendInScopeSetList_nil : forall in_scope_set,
           extendInScopeSetList in_scope_set nil = in_scope_set.
Proof.
  unfold extendInScopeSetList.
  destruct in_scope_set.
  unfold_Foldable_foldl.
  simpl.
  f_equal.
  omega.
Qed.
