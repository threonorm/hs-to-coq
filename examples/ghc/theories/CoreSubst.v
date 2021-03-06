Require Import GHC.Base.
Import GHC.Base.Notations.
Import GHC.Base.ManualNotations.

Require Import Core.
Require Import CoreSubst.
Require Import Coq.Lists.List.

Require Import Proofs.GHC.Base.
Require Import Proofs.GHC.List.
Require Import Proofs.Data.Foldable.
Require Import Proofs.Data.Traversable. 

Require Import Proofs.GhcTactics.
Require Import Proofs.CoreInduct.
Require Import Proofs.Core.
Require Import Proofs.VarSet.
Require Import Proofs.VarEnv.
Require Import Proofs.Var.
Require Import Proofs.ScopeInvariant.

Require Import Coq.omega.Omega.

Opaque Base.hs_string__.
Opaque GHC.Err.default.

Open Scope nat_scope.
Set Bullet Behavior "Strict Subproofs".


(** [VarSet] *)
Axiom ValidVarSet_invariant: forall vs, ValidVarSet vs.

(* ---------------------------- *)


Lemma Forall_app : forall {A} {p} {l1 l2 : list A}, 
      Forall p l1 -> Forall p l2 -> Forall p (l1 ++ l2).
Proof.
  intros.
  induction l1; simpl; auto.
  inversion H. subst.  eapply Forall_cons; eauto.
Qed.

(* SCW: this one seems a bit specialized. replace with the more 
   general analogue to the above? *)
Lemma map_snd_zip' : 
  forall {a}{b}{c} (f:b -> c) (xs : list a) ys , 
    length xs = length ys ->
    (map (fun ps => f (snd ps)) (List.zip xs ys)) =
    (map f ys).
Proof.
  intros.
  pose (M := @map_map (a * b) _ _ snd f).
  simpl in M.
  rewrite <- M.
  rewrite map_snd_zip. auto. auto.
Qed.

   
(* ---------------------------------------------------------------- *)

(** [subst_expr] simplification lemmas *)

Lemma subst_expr_App : forall s subst e1 e2, 
    subst_expr s subst (App e1 e2) = 
    App (subst_expr s subst e1) (subst_expr s subst e2).
    Proof. 
      intros. unfold subst_expr. simpl. 
      f_equal.
      destruct e1; simpl; auto.
      destruct e2; simpl; auto.
Qed.

Lemma subst_expr_Tick : forall doc subst tic e, 
        subst_expr doc subst (Tick tic e) = 
        CoreUtils.mkTick (substTickish subst tic) (subst_expr doc subst e).
Proof.
  intros. 
  unfold subst_expr, CoreUtils.mkTick, substTickish. simpl.
  destruct e; simpl; auto.
Qed.

Lemma subst_expr_Lam : forall s subst bndr body,
        subst_expr s subst (Lam bndr body) = 
        let (subst', bndr') := substBndr subst bndr in
        Lam bndr' (subst_expr s subst' body).
Proof.
  intros.
  unfold subst_expr. simpl.
  destruct (substBndr subst bndr) as [subst' bndr']. 
  f_equal.
Qed.

Lemma subst_expr_LetNonRec : forall s subst c e0 body,
  subst_expr s subst (Let (NonRec c e0) body) = 
    let (subst', bndr') := substBndr subst c in 
    Let (NonRec bndr' (subst_expr &"substBind" subst e0)) (subst_expr s subst' body).
Proof.      
  intros.
  unfold subst_expr. simpl.
  destruct substBndr as [subst' bndr'].
  f_equal.
Qed.


Lemma subst_expr_Let : forall s subst bind body,
  subst_expr s subst (Let bind body) = 
   let '(subst', bind') := substBind subst bind in Let bind' (subst_expr s subst' body). 
Proof.
  intros.
  unfold subst_expr. fold subst_expr. 
  destruct substBind.
  auto.
Qed.

Lemma substBind_NonRec : forall subst c e0, 
    substBind subst (NonRec c e0) = 
    let '(subst', bndr') := substBndr subst c in 
    (subst', NonRec bndr' (subst_expr &"substBind" subst e0)).
Proof.
  intros.
  unfold substBind. 
  simpl.
  destruct substBndr.
  f_equal.
Qed.

Lemma substBind_Rec : forall subst pairs,
    substBind subst (Rec pairs) = 
    let '(bndrs, x)        := List.unzip pairs in 
    let '(subst'0, bndrs') := substRecBndrs subst bndrs in
    (subst'0 , Rec (List.zip bndrs' (map (fun ps : Var * CoreExpr => subst_expr &"substBind" subst'0 (snd ps)) pairs))).
Proof.
  intros.
  unfold substBind.
  simpl.
  destruct (List.unzip pairs).
  destruct (substRecBndrs subst l).
  f_equal.
Qed.


Definition substAlt str subst (alt:AltCon * list Core.Var * CoreExpr) := 
  let '((con,bndrs), rhs) := alt in
  let '(subst', bndrs') := substBndrs subst bndrs in
  (con, bndrs', subst_expr str subst' rhs).

Lemma subst_expr_Case : forall str s e b u l, 
    subst_expr str s (Case e b u l) = 
    let '(subst', bndr') := substBndr s b in 
    Case (subst_expr str s e) bndr' tt (map (substAlt str subst') l).
Proof. intros.  simpl.
destruct (substBndr s b) as [subst' bndr'].       
f_equal. destruct e; reflexivity.
Qed.

Lemma subst_expr_Cast : forall doc subst e co, 
   subst_expr doc subst (Cast e co) = 
   Cast (subst_expr doc subst e) tt.
Proof.
  intros. 
  unfold subst_expr. simpl.
  f_equal.
  destruct e; simpl; auto.
Qed.


Hint Rewrite subst_expr_App subst_expr_Case subst_expr_Cast 
     substBind_NonRec substBind_Rec subst_expr_Let subst_expr_Lam
     subst_expr_Tick : subst.


Tactic Notation "simp" "subst" "in" hyp(H) :=
  autorewrite with subst in H.

Tactic Notation "simp" "subst" "in" "*" :=
  autorewrite with subst in *.

Tactic Notation "simp" "subst" :=
  autorewrite with subst.



(* ---------------------------------------------------------------- *)


Definition getSubstInScopeVars (s : Subst) : VarSet :=
  match s with 
  | Mk_Subst i e _ _ => getInScopeVars i
  end.


(* When calling (subst subst tm) it should be the case that
   the in_scope_set in the substitution describes the scope after 
   the substituition has been applied.

  That means that it should be a superset of both:

  (SIa) The free vars of the range of the substitution
  (SIb) The free vars of ty minus the domain of the substitution

  We enforce this by requiring

    - the current scope minus the domain is a strongSubset of in_scope_set
    - the range of the subst_env is wellscoped according to the in_scope_set

  We should to enforce that 

    - the domain of the substitution only contains good local *identifiers*
      (i.e. not global ids, type vars or coercion vars.) 

  However, we cannot access the domain of VarEnvs directly. So we do not 
  capture this invariant here. Instead, we should only lookup localIds in this 
  subst_env.

*)


Definition WellScoped_Subst  (s : Subst) (vs:VarSet) :=
  match s with 
  | Mk_Subst in_scope_set subst_env _ _ => 

    (minusDom vs subst_env) {<=} (getInScopeVars in_scope_set) /\

    (forall var, 

      (match lookupVarEnv subst_env var with

        | Some expr => 
          
             WellScoped expr (getInScopeVars in_scope_set)

        | None => True

        end))  

  end.

Ltac destruct_WellScoped_Subst := 
    match goal with
      | [H0 : WellScoped_Subst ?s ?vs |- _ ] => 
         unfold WellScoped_Subst in H0;
         try (is_var s ; destruct s);
         destruct H0 as [? ? ]
  end.


Lemma WellScoped_Subst_StrongSubset : forall vs1 s vs2,
  vs2 {<=} vs1 -> 
  WellScoped_Subst s vs1 ->
  WellScoped_Subst s vs2.
Proof.
  intros.
  destruct_WellScoped_Subst.
  repeat split; auto.
  eapply (StrongSubset_trans (minusDom vs2 i0)); eauto.
  eapply StrongSubset_minusDom; eauto.
Qed.



(* ---------------------------------------- *)


Definition Disjoint {a}`{Eq_ a} (l1 l2 : list a) :=
  Forall (fun x => ~ (In x l2)) l1. 

Hint Constructors NoDup.

Lemma NoDup_app : forall (l1 l2 : list Var), 
    NoDup (map varUnique l1) ->
    NoDup (map varUnique l2) ->
    Disjoint (map varUnique l1) (map varUnique l2) ->
    NoDup (map varUnique l1 ++ map varUnique l2).
Proof.
  induction l1.
  intros. simpl. auto.
  intros. simpl.
  inversion H. inversion  H1.
  subst.
  econstructor.
  - intro x.
    apply in_app_or in x.
    destruct x; eauto. 
  - eapply IHl1; eauto.
Qed. 

(* ---------------------------------------- *)


(* Actually from Coq.Program.Tactics. *)
Ltac destruct_one_pair :=
 match goal with
   | [H : (_ /\ _) |- _] => destruct H
   | [H : prod _ _ |- _] => destruct H
 end.

(* Variants for CoreSubst. *)
Ltac destruct_one_id var2 :=
  match goal with [ H : exists var2:Id, _ |- _ ] =>
    destruct H as [var2 ?]; 
    repeat destruct_one_pair 
  end.
Ltac destruct_one_expr val1 :=
  match goal with 
    [ H : exists v : CoreExpr, _ |- _ ] =>
    destruct H as [val1 ?];
    repeat destruct_one_pair 
  end.



(* This property describes the invariants we need about the freshened
   binder list and new VarEnv after a use of substIdBndrs.
  
  - [e2] is a subst env extended from [e1], where the binders in [vars]
    have been freshened to [vars']. 

*)


Definition VarEnvExtends
           (e1  : IdSubstEnv) (vars  : list Var) 
           (e2  : IdSubstEnv) (vars' : list Var) : Prop :=
  forall var, 
    match lookupVarEnv e2 var with
    | Some val2 => 
      (* If a variable is in the dom of the new substitution, then 
         either, it is a renaming of a binding variable... *)
      (exists var2, val2 = Mk_Var var2 
                /\ In var2 vars'
                /\ Foldable.elem var vars = true) \/
     (* or it was also in the old substitution, with 
         the same definition ... *)
      (exists val1, lookupVarEnv e1 var = Some val1 /\
               val1 = val2 )

    | None =>
      (* If a variable is NOT in the dom of the new substitution, then 
         either .... *) 
      match lookupVarEnv e1 var with 
      | None  =>  True 
        (* ... it wasn't in the dom of the old substitution
           (and isn't a binder) 
        not (In var vars) /\ not (In var vars') *)
      | Some val1 => 
        (* .. or it was in the old substitution, 
           but it is a "sufficiently fresh" binder that 
           we dropped. *)
          (Foldable.elem var vars && Foldable.elem var vars') = true
      end
    end.

Lemma VarEnvExtends_trans : forall beg mid end_env vars1 vars2 vars1' vars2', 
  Disjoint (map varUnique vars1') (map varUnique vars2') -> 
  VarEnvExtends beg vars1 mid vars1' ->
  VarEnvExtends mid vars2 end_env vars2' ->
  VarEnvExtends beg (vars1 ++ vars2) end_env (vars1' ++ vars2').
Proof.
  intros.
  unfold VarEnvExtends in *. 
  intros var. specialize_all var.
  destruct (lookupVarEnv end_env var) eqn:LU2;
    destruct (lookupVarEnv mid var) eqn:LU0; 
    destruct (lookupVarEnv beg var) eqn:LU4; auto.
  all: repeat try match goal with 
                    [H : (?A \/ ?B) |- _] => destruct H end.
  all: repeat destruct_one_pair.
  all: try destruct_one_id var2.
  all: try destruct_one_id var3.
  all: try destruct_one_expr val1.
  all: try destruct_one_expr val2.
  all: try inversion H0.
  all: try inversion H1.
  all: subst.
  all: try solve [left; eexists;
    repeat split; auto;
      try (apply in_or_app; tauto);
        rewrite Foldable_elem_app;
        rewrite orb_true_iff; tauto].
  - right; eexists; repeat split; eauto.
  - left.  eexists. repeat split.
    apply in_or_app. tauto.
    rewrite H5.
    rewrite Foldable_elem_app.
    rewrite orb_true_iff.
    tauto.
  - rewrite H6.
    rewrite Foldable_elem_app.
    rewrite Foldable_elem_app.
    rewrite H3. simpl.
    rewrite andb_true_iff in *.
    rewrite orb_true_iff in *.
    tauto.
  - rewrite H1.
    rewrite Foldable_elem_app.
    rewrite Foldable_elem_app.
    rewrite andb_true_iff in *.
    rewrite orb_true_iff in *.
    rewrite orb_true_iff in *.
    tauto.
  - rewrite H3.    
    repeat rewrite Foldable_elem_app.
    repeat rewrite andb_true_iff in *.
    repeat rewrite orb_true_iff in *.
    tauto.
Qed.


(* This property describes the invariants we need about the freshened
   binder list and new subst after a use of substIdBndrs.
  
  - [s2] is a subst extended from [s1], where the binders in [vars]
    have been freshened to [vars']

*)


Definition SubstExtends (s1 : Subst) (vars  : list Var) 
                        (s2 : Subst) (vars' : list Var) : Prop :=

  length vars = length vars' /\

  NoDup (map varUnique vars') /\

  Forall GoodLocalVar vars' /\

  match (s1, s2) with 
    | (Mk_Subst i1 e1 _ _ , Mk_Subst i2 e2 _ _) => 

      (* The new variables are fresh for the original substitution. *)
      freshList vars' (getInScopeVars i1) /\

      (* For the in_scope_set:  new = old + vars' *) 
      (getInScopeVars i2) {=} (extendVarSetList (getInScopeVars i1) vars') /\

      (* ... and we can subtract out the old binders. *)      
      (minusDom (extendVarSetList (getInScopeVars i1) vars) e2 {<=} 
                getInScopeVars i2) /\ 

      (* Anything in the new substitution is either a renamed variable from
         the old substitution or was already in the old substitution *)
      VarEnvExtends e1 vars e2 vars'

  end.


Ltac destruct_SubstExtends := 
  repeat 
    match goal with 
    | [ H : SubstExtends ?s1 ?vs ?s2 ?vs1 |- _ ] => 
      try (is_var s1 ; destruct s1);
      try (is_var s2 ; destruct s2);
      unfold SubstExtends in H; repeat (destruct_one_pair)
    end.


(* Prove goals about lookupVarSet, given StrongSubset assumptions *)
Ltac lookup_StrongSubset :=
    match goal with 
      [ h1 : StrongSubset (extendVarSetList ?i3 ?vars1) ?i,
        h2 : forall v:Var, Foldable.elem v ?vars1 = true -> lookupVarSet ?i3 v = None,
        m  : lookupVarSet ?i ?v  = ?r |- 
             lookupVarSet ?i3 ?v = ?r ] =>
      let k := fresh in
      assert (k : StrongSubset i3 i); 
        [ eapply StrongSubset_trans with (vs2 := (extendVarSetList i3 vars1)); 
          eauto;
          eapply StrongSubset_extendVarSetList_fresh; eauto |
          unfold StrongSubset in k;
          specialize (k v);
          rewrite m in k;
          destruct (lookupVarSet i3 v) eqn:LY;
          [contradiction| auto]]
    end.


Lemma SubstExtends_refl : forall s, 
    SubstExtends s nil s nil.
Proof.
  intros.
  destruct s.
  repeat split; simpl; try rewrite extendVarSetList_nil; auto.  
  apply freshList_nil.
  eapply StrongSubset_refl.
  eapply StrongSubset_refl.
  eapply StrongSubset_minusDom_left.
  intros var.
  destruct lookupVarEnv eqn:LU; try tauto.
  right. eexists. 
  repeat split; eauto.
Qed.



  


Lemma SubstExtends_trans : forall s2 s1 s3 vars1 vars2 vars1' vars2', 
    Disjoint (map varUnique vars1') (map varUnique vars2') ->
    SubstExtends s1 vars1 s2 vars1' -> SubstExtends s2 vars2 s3 vars2'-> 
    SubstExtends s1 (vars1 ++ vars2) s3 (vars1' ++ vars2').
Proof.
  intros.
  destruct_SubstExtends.

  assert (k : VarEnvExtends i4 (vars1 ++ vars2) i2 (vars1' ++ vars2')).
  eapply VarEnvExtends_trans; eauto.

  repeat split; auto.
  - rewrite app_length. rewrite app_length. auto.
  - rewrite map_app.
    apply NoDup_app; auto.
  - eauto using Forall_app.
  - rewrite freshList_app.
    split; auto.
    unfold freshList in *.
    intros v IN.
    match goal with [ f2 : forall v:Var, Foldable.elem v vars2' = true -> _ |- _ ] =>
                    pose (m := f2 _ IN); clearbody m end.
    lookup_StrongSubset.
   - rewrite extendVarSetList_append.
     eapply StrongSubset_trans; eauto. 
     eapply StrongSubset_extendVarSetList.
     eauto.
   - rewrite extendVarSetList_append.
     eapply StrongSubset_trans with 
         (vs2 := extendVarSetList (getInScopeVars i) vars2'); eauto. 
     eapply StrongSubset_extendVarSetList; eauto.
   - (* This is the hard case. *)
     rename i3 into init_scope.
     rename i  into mid_scope.
     rename i1 into fin_scope.
     rename i0 into mid_env.
     rename i2 into fin_env.
     rename i4 into init_env.

     (* i3 == initial scope_set
        i  == after extension with vars1'
        i1 == after extension with vars2'
        
        i2 == initial env
        i0 == mid env
        i4 == final env
      *)

     unfold StrongSubset in *. 
     intros var. 
     specialize_all var.
     destruct (elemVarEnv var fin_env) eqn:ELEM.

     rewrite_minusDom_true.
     rewrite_minusDom_false.
     rewrite_minusDom_false.

     destruct (elemVarEnv var mid_env) eqn: ELEM2.
     + rewrite_minusDom_true.
       (* var is a binder in mid env that is NOT present in 
          the final env. *)
       unfold VarEnvExtends in *.
       specialize_all var.
       rewrite lookupVarEnv_elemVarEnv_true in ELEM2.
       destruct ELEM2 as [c k0].
       rewrite k0 in H7.
       rewrite lookupVarEnv_elemVarEnv_false in ELEM.
       rewrite ELEM in *.
       rewrite andb_true_iff in *.
       destruct_one_pair.
       rewrite lookupVarSet_extendVarSetList_self.
       rewrite lookupVarSet_extendVarSetList_self in H8.
       destruct ( lookupVarSet (getInScopeVars fin_scope) var ); try contradiction.
       auto.
       auto.
       rewrite Foldable_elem_app.
       rewrite orb_true_iff.
       tauto.
     + rewrite_minusDom_false.
       (* var is not in mid or final env, so cannot be in vars1 or vars2 *)
       unfold VarEnvExtends in k. specialize (k var). 
       rewrite lookupVarEnv_elemVarEnv_false in ELEM.
       rewrite ELEM in *.
       (* H7 has no information content. *) clear H7.
       
       destruct (Foldable.elem var (vars1 ++ vars2)) eqn:BNDR.
       ++ rewrite lookupVarSet_extendVarSetList_self; auto.          
          rewrite Foldable_elem_app in BNDR.
          rewrite orb_true_iff in BNDR.
          destruct BNDR.
          +++ destruct (Foldable.elem var vars2) eqn:VARS2.
              rewrite lookupVarSet_extendVarSetList_self in H6; auto.          
              rewrite lookupVarSet_extendVarSetList_false in H6; auto.
              rewrite lookupVarSet_extendVarSetList_self in H13; auto.          
              destruct (lookupVarSet (getInScopeVars mid_scope) var) eqn:MID;
                try contradiction.
              destruct (lookupVarSet (getInScopeVars fin_scope) var) eqn:FIN;
                try contradiction.
              eapply almostEqual_trans; eauto.
              intro h. rewrite h in VARS2. discriminate.
          +++ rewrite lookupVarSet_extendVarSetList_self in H6; auto.          
       ++ rewrite lookupVarSet_extendVarSetList_false; auto.
       rewrite lookupVarSet_extendVarSetList_false in H6; auto.
       rewrite lookupVarSet_extendVarSetList_false in H13; auto.
       destruct (lookupVarSet (getInScopeVars init_scope) var) eqn:INIT; auto;
       destruct (lookupVarSet (getInScopeVars mid_scope) var) eqn:MID;
       try contradiction.
       destruct (lookupVarSet (getInScopeVars fin_scope) var) eqn:FIN.
       eapply almostEqual_trans; eauto.
       contradiction.
       rewrite Foldable_elem_app in BNDR.
       rewrite orb_false_iff in BNDR.
       destruct BNDR.
       intro h. rewrite h in H7. discriminate.
       rewrite Foldable_elem_app in BNDR.
       rewrite orb_false_iff in BNDR.
       destruct BNDR.
       intro h. rewrite h in H16. discriminate.
       intro h. rewrite h in BNDR. discriminate.
Qed.
        
Lemma StrongSubset_VarEnvExtends : forall old_env vars new_env vars' vs1 vs2,
    VarEnvExtends old_env vars new_env vars' ->
    minusDom vs1 old_env {<=} vs2 ->
    minusDom (extendVarSetList vs1 vars) new_env
     {<=} minusDom (extendVarSetList vs2 vars) new_env.
Proof.
  intros.
  unfold VarEnvExtends in *.
  unfold StrongSubset in *.
  intros var. specialize_all var.
  destruct (lookupVarEnv new_env var) eqn:LU.
  - rewrite lookup_minusDom_inDom; auto.
    rewrite lookupVarEnv_elemVarEnv_true.
    eauto.
  - rewrite lookupVarSet_minusDom_1; auto.
    rewrite lookupVarSet_minusDom_1; auto.
    destruct (lookupVarEnv old_env var) eqn:LU2.
    -- rewrite lookup_minusDom_inDom in *.
       rewrite andb_true_iff in *.
       destruct_one_pair.
       rewrite lookupVarSet_extendVarSetList_self; auto.
       rewrite lookupVarSet_extendVarSetList_self; auto.
       apply almostEqual_refl; auto.
       rewrite lookupVarEnv_elemVarEnv_true.
       eauto.
    -- rewrite lookupVarSet_minusDom_1 in *; auto.
       destruct (Foldable.elem var vars) eqn:ELEM.
       rewrite lookupVarSet_extendVarSetList_self; auto.
       rewrite lookupVarSet_extendVarSetList_self; auto.
       apply almostEqual_refl; auto.
       rewrite lookupVarSet_extendVarSetList_false; auto.
       rewrite lookupVarSet_extendVarSetList_false; auto.
       intro h. rewrite h in ELEM. discriminate.
       intro h. rewrite h in ELEM. discriminate.
Qed.




(* To be usable with the induction hypothesis inside a renamed scope, 
   we need to know that the new substitution is well-scoped with respect 
   to the *old* list of binders. *)

Lemma SubstExtends_WellScoped_Subst : forall s1 s2 vs vars vars', 
    Forall GoodLocalVar vars ->
    SubstExtends s1 vars s2 vars' ->
    WellScoped_Subst s1 vs ->
    WellScoped_Subst s2 (extendVarSetList vs vars).
Proof.
  intros.
  rewrite Forall_forall in H.
  destruct_WellScoped_Subst.
  destruct_SubstExtends.
  rename i0 into old_env.
  rename i2 into new_env.
  simpl in *.
  repeat split. 
  + eapply StrongSubset_trans with 
        (vs2 := minusDom (extendVarSetList (getInScopeVars i) vars) new_env).
       eapply StrongSubset_VarEnvExtends; eauto.
       auto.
  + unfold VarEnvExtends in *. 
    intros var. specialize_all var.
    destruct (lookupVarEnv new_env var) eqn:LU; auto.
(*    destruct (lookupVarEnv old_env var) eqn:OL. *)
    destruct H8.
    ++ destruct_one_id var2.
       subst.
       eapply WellScoped_StrongSubset with 
       (vs1 := extendVarSetList (getInScopeVars i) vars'); eauto.
       unfold WellScoped.
       unfold WellScopedVar.
       replace (isLocalVar var2) with true; swap 1 2. {
        symmetry.
        rewrite Forall_forall in H4.
        specialize (H4 _ H10).
        unfold GoodLocalVar in H4. intuition.
       }
       rewrite lookupVarSet_extendVarSetList_self.
       eapply almostEqual_refl; auto.
       rewrite <- In_varUnique_elem.
       apply in_map.
       auto.
    ++ destruct_one_expr val1. 
       rewrite H8 in H2. subst.
       eapply WellScoped_StrongSubset with 
       (vs1 := extendVarSetList (getInScopeVars i) vars'); eauto.
       eapply WellScoped_StrongSubset; eauto.
       eapply StrongSubset_extendVarSetList_fresh.
       auto.       
Qed.


Lemma WellScoped_substBody : forall doc vs vars vars' body s1 s2,
   forall (IH : forall subst,  
      WellScoped_Subst subst (extendVarSetList vs vars) ->
      WellScoped (subst_expr doc subst body) (getSubstInScopeVars subst)),
   Forall GoodLocalVar vars ->
   SubstExtends s1 vars s2 vars' ->     
   WellScoped_Subst s1 vs ->      
   WellScoped (subst_expr doc s2 body) 
              (extendVarSetList (getSubstInScopeVars s1) vars').
Proof.
  intros.
  destruct s1.
  simpl.
  rewrite <- getInScopeVars_extendInScopeSetList.
  eapply WellScoped_StrongSubset.
  eapply IH.
  eapply SubstExtends_WellScoped_Subst; eauto.
  destruct s2.
  simpl.
  rewrite getInScopeVars_extendInScopeSetList.
  destruct_SubstExtends. auto.
Qed.  


(* For multiple binders, we need to package up the reasoning above into a form that 
   we can use directly with the IH. *)

Lemma WellScoped_Subst_substIdBndr : forall s1 s2 subst subst' bndr' v vs,
  forall (SB : substIdBndr s1 s2 subst v = (subst', bndr')),
  GoodLocalVar v ->
  WellScoped_Subst subst vs ->
  SubstExtends subst (cons v nil) subst' (cons bndr' nil) /\
  WellScoped_Subst subst' (extendVarSet vs v).
Proof. 
  intros.
  unfold substIdBndr in SB.
  destruct subst as [in_scope_set env u u0].
  match goal with [ H0 : WellScoped_Subst ?ss ?vs |- _ ] => 
                  destruct H0 as [SS LVi] end.
  inversion SB; subst; clear SB.
  (* Case analysis on whether we freshen the binder v. *)
  destruct (uniqAway in_scope_set v == v) eqn:NC.
  + (* Binder [v] is already fresh enough. *)
    apply uniqAway_eq_same in NC.
    unfold WellScoped_Subst.
    repeat split.
    -- econstructor.
       intro h; inversion h.
       econstructor.
    -- econstructor; eauto using GoodLocalVar_uniqAway.
(*       uniqAway_isLocalVar. *)
    -- unfold freshList.
       intros v1 InV.
       rewrite elem_cons, orb_true_iff in InV.
       destruct InV.
       rewrite lookupVarSet_eq with (v2 := v);
       rewrite <- NC; auto.
       apply uniqAway_lookupVarSet_fresh. 
       rewrite elem_nil in H0. discriminate.
    -- rewrite <- getInScopeVars_extendInScopeSetList.
       rewrite extendInScopeSetList_cons.
       rewrite extendInScopeSetList_nil.
       eapply StrongSubset_refl.
    -- rewrite <- getInScopeVars_extendInScopeSetList.
       rewrite extendInScopeSetList_cons.
       rewrite extendInScopeSetList_nil.
       eapply StrongSubset_refl.
    -- rewrite <- getInScopeVars_extendInScopeSetList.
       rewrite extendInScopeSetList_cons.
       rewrite extendInScopeSetList_nil.
       rewrite getInScopeVars_extendInScopeSet.
       eapply StrongSubset_trans.
       eapply minusDom_extend.
       rewrite getInScopeVars_extendInScopeSet.
       rewrite NC.
       eapply StrongSubset_extend.
       eapply StrongSubset_minusDom_left.
    -- unfold VarEnvExtends.
       intro var. specialize_all var.
       destruct (v == var) eqn:EQv.
       ++ (* The arbitrary var is the same as the binder
             which was sufficiently fresh. *)
         pose (k := uniqAway_lookupVarSet_fresh v in_scope_set). clearbody k.
         rewrite lookupVarEnv_delVarEnv_eq; auto.
         destruct (lookupVarEnv env var) eqn:INSUBST; auto.
         rewrite andb_true_iff. split.
         rewrite elem_cons.
         rewrite Base.Eq_sym.
         rewrite orb_true_iff.
         tauto.
         rewrite elem_cons.
         rewrite orb_true_iff.
         left.
         rewrite NC.
         rewrite Base.Eq_sym.
         auto.
       ++ rewrite lookupVarEnv_delVarEnv_neq; auto.
          destruct (lookupVarEnv env var).
          right. eexists. 
          split; eauto.
          split; auto.
          intros h. rewrite h in EQv. discriminate.
    -- simpl.
       rewrite getInScopeVars_extendInScopeSet.
       eapply StrongSubset_trans with (vs2 := extendVarSet (minusDom vs env) v).
       eapply minusDom_extend.
       rewrite NC.
       eapply StrongSubset_extend. 
       auto.
    -- intro var.
       destruct (v == var) eqn:Evvar.
       rewrite lookupVarEnv_delVarEnv_eq; auto.
       rewrite lookupVarEnv_delVarEnv_neq.
       specialize (LVi var).
       destruct (lookupVarEnv env var); auto.
       rewrite getInScopeVars_extendInScopeSet.
       eapply WellScoped_StrongSubset; eauto.       
       eapply StrongSubset_extend_fresh.
       rewrite <- NC.
       eapply uniqAway_lookupVarSet_fresh.
       unfold CoreBndr in *. intro h. rewrite h in Evvar. discriminate.

  + (* Binder needs to be freshened. *)
    unfold WellScoped_Subst.
    unfold SubstExtends.
    repeat split.
    -- simpl. eauto.
    -- rewrite Forall.Forall_cons_iff.
       split. eapply GoodLocalVar_uniqAway; auto.
       eauto.
    -- unfold freshList.
       intros v0 InV.
       rewrite elem_cons, orb_true_iff in InV.
       destruct InV.
       erewrite lookupVarSet_eq; eauto.
       apply uniqAway_lookupVarSet_fresh. 
       rewrite elem_nil in H0.
       discriminate.
    -- rewrite <- getInScopeVars_extendInScopeSetList.
       rewrite extendInScopeSetList_cons.
       rewrite extendInScopeSetList_nil.
       eapply StrongSubset_refl.
    -- rewrite <- getInScopeVars_extendInScopeSetList.
       rewrite extendInScopeSetList_cons.
       rewrite extendInScopeSetList_nil.
       eapply StrongSubset_refl.
    -- (* We have freshened binder v. *)
       rewrite <- getInScopeVars_extendInScopeSetList.
       rewrite extendInScopeSetList_cons.
       rewrite extendInScopeSetList_nil.
       rewrite getInScopeVars_extendInScopeSet.
       rewrite getInScopeVars_extendInScopeSet.
       pose (k := uniqAway_lookupVarSet_fresh v in_scope_set).
       clearbody k.
       set (v' := uniqAway in_scope_set v) in *.

       eapply StrongSubset_trans.
       eapply StrongSubset_minusDom_extend_extend.
       eapply StrongSubset_trans.
       eapply StrongSubset_minusDom_left.
       eapply StrongSubset_extendVarSet_fresh. 
       auto.
    -- unfold VarEnvExtends.
       intro var. specialize_all var.
       destruct (v == var) eqn:EQ.
       ++ rewrite lookupVarEnv_extendVarEnv_eq; auto.
       left. exists (uniqAway in_scope_set v).
       repeat split. econstructor; eauto.
       rewrite elem_cons.
       rewrite Base.Eq_sym.
       rewrite orb_true_iff.
       left. auto.
       ++ rewrite lookupVarEnv_extendVarEnv_neq; auto.
       destruct (lookupVarEnv env var) eqn:LU.
       right. exists c. repeat split; auto.
       auto.
       intro h. rewrite h in EQ. auto.
    -- eapply StrongSubset_trans; eauto.
       eapply StrongSubset_minusDom_extend_extend.
       eapply StrongSubset_trans; eauto.
       rewrite getInScopeVars_extendInScopeSet.
       eapply StrongSubset_extendVarSet_fresh.
       eapply uniqAway_lookupVarSet_fresh.
    -- intros var.
       destruct (v == var) eqn:Eq_vvar.
       - rewrite lookupVarEnv_extendVarEnv_eq; auto.
         unfold WellScoped, WellScopedVar.
         destruct_match; only 2: apply I.
         rewrite getInScopeVars_extendInScopeSet.
         rewrite lookupVarSet_extendVarSet_self.
         eapply almostEqual_refl.
       - rewrite lookupVarEnv_extendVarEnv_neq; auto.
         specialize (LVi var).
         destruct lookupVarEnv eqn:LU.
         rewrite getInScopeVars_extendInScopeSet.
         eapply WellScoped_StrongSubset; eauto.
         eapply StrongSubset_extendVarSet_fresh.
         eapply uniqAway_lookupVarSet_fresh.
         auto.
         intro h. rewrite h in Eq_vvar. discriminate.
Qed.


Lemma WellScoped_Subst_substBndr : forall subst subst' bndr' v vs,
  forall (SB : substBndr subst v = (subst', bndr')),
  GoodLocalVar v ->
  WellScoped_Subst subst vs ->
  SubstExtends subst (cons v nil) subst' (cons bndr' nil) /\
  WellScoped_Subst subst' (extendVarSet vs v).
Proof. 
  intros.
  unfold substBndr in SB.
  (* !!!!! TODO !!!!! *)
  (* When v is a tyvar or covar then the definition of substBndr is bogus
     and the invariants don't hold. *)
  destruct (isTyVar v) eqn:IsTyVar. 
  { inversion SB; subst; clear SB. admit. }
  destruct (isCoVar v) eqn:IsCoVar.
  { inversion SB; subst; clear SB. admit. }
  assert (ISL : isLocalId v = true).
  { unfold isLocalId, isTyVar, isCoVar, GoodLocalVar, isLocalVar in *.
    destruct v; try discriminate.
    destruct_one_pair.
    destruct i. simpl in *. discriminate. auto. }
  eapply WellScoped_Subst_substIdBndr; eauto.
Admitted.

Lemma WellScoped_substBndr : forall s in_scope_set env subst' bndr' body v vs u u0,
  forall (IH : forall (in_scope_set : InScopeSet) (env : IdSubstEnv) u u0,
      WellScoped_Subst (Mk_Subst in_scope_set env u u0) (extendVarSet vs v) ->
      WellScoped (subst_expr s (Mk_Subst in_scope_set env u u0) body) 
                 (getInScopeVars in_scope_set)),
  forall (SB : substBndr (Mk_Subst in_scope_set env u u0) v = (subst', bndr')),
  GoodLocalVar v ->
  WellScoped_Subst (Mk_Subst in_scope_set env u u0) vs ->
  WellScoped (subst_expr s subst' body) 
             (extendVarSet (getInScopeVars in_scope_set) bndr').

Proof. 
  intros.
  edestruct WellScoped_Subst_substBndr; eauto.
  destruct_SubstExtends.
  rewrite <- getInScopeVars_extendInScopeSet.
  eapply WellScoped_StrongSubset.
  eapply IH; eauto. clear IH. 
  rewrite extendVarSetList_cons in *.
  rewrite extendVarSetList_nil in *.
  rewrite getInScopeVars_extendInScopeSet.
  eauto.
Qed.


Ltac lift_let_in_eq H :=
   match goal with 
      | [ SB : (let '(x,y) := ?sb in ?e1) = ?e2 |- _ ] => 
         destruct sb as [ x y ] eqn:H
      | [ SB : ?e2 = (let '(x,y) := ?sb in ?e1) |- _ ] => 
         destruct sb as [ x y ] eqn:H
    end.


Lemma GoodLocalVar_substIdBndr : forall s1 s2 bndr bndr' subst subst',
  GoodLocalVar bndr ->
  substIdBndr s1 s2 subst bndr = (subst', bndr') ->
  GoodLocalVar bndr'.
Proof. intros.
  unfold substIdBndr in *.
  destruct subst.
  inversion H0. clear H0. 
  subst.
  eapply GoodLocalVar_uniqAway. 
  assumption.
Qed.

Lemma GoodLocalVar_substBndr : forall bndr bndr' subst subst',
  GoodLocalVar bndr ->
  substBndr subst bndr = (subst', bndr') ->
  GoodLocalVar bndr'.
Proof.
  intros.
  unfold substBndr in *.
  destruct (isTyVar bndr). inversion H0. subst. auto.
  destruct (isCoVar bndr). inversion H0. subst. auto.
  eapply GoodLocalVar_substIdBndr; eauto.
Qed.

Lemma SubstExtends_step : forall a s' y bndrs subst subst' ys, 
  SubstExtends subst (a :: nil) s' (y :: nil) ->
  SubstExtends s' bndrs subst' ys ->
  SubstExtends subst ((a :: nil) ++ bndrs) subst' (y :: ys).
Proof. 
  intros.
  replace (y :: ys) with (cons y nil ++ ys); try reflexivity.
  eapply SubstExtends_trans with (s2 := s'); auto.
       { 
         simpl.
         destruct_SubstExtends.
         unfold Disjoint.
         rewrite Forall_forall.
         intros x I.
         inversion I. subst. clear I.
         + (* at this point, we know that y is in i but that
              and that ys are fresh for i *)
           match goal with 
             [ h1 : freshList ys (getInScopeVars ?i) , 
               h2 : extendVarSetList (getInScopeVars ?i3) (y :: nil) {<=} 
                                     getInScopeVars ?i |- _ ] =>
               rename h1 into FrYs; rename h2 into InY
               end.
           (* derive a contradiction. *)
           intros not.           
           rewrite In_varUnique_elem in not.

           (* Make these two facts more clear *)
           specialize (InY y).
           rewrite lookupVarSet_extendVarSetList_self in InY; 
             [| rewrite elem_cons; rewrite orb_true_iff; left;
                eapply Base.Eq_refl ].
           destruct (lookupVarSet (getInScopeVars i) y) eqn:InScope; 
             try contradiction.

           specialize (FrYs y not).
           rewrite FrYs in InScope.
           discriminate.

         + inversion H15.
       }
Qed.



Lemma SubstExtends_mapAccumL_substBndr :
  forall (bndrs : list Var) (subst subst' : Subst) (bndrs' : list Var) (vs : VarSet)
    (SB: Traversable.mapAccumL substBndr subst bndrs = (subst', bndrs')),
    Forall GoodLocalVar bndrs ->
    WellScoped_Subst subst vs ->
    SubstExtends subst bndrs subst' bndrs' /\
    WellScoped_Subst subst' (extendVarSetList vs bndrs).
Proof.
  induction bndrs; intros.
  + rewrite mapAccumL_nil in SB.
    inversion SB; subst; clear SB.
    split. eapply SubstExtends_refl; eauto.
    rewrite extendVarSetList_nil. auto.
  + rewrite mapAccumL_cons in SB.
    lift_let_in_eq Hsb1.
    lift_let_in_eq Hsb2.
    inversion SB. subst; clear SB.
    inversion H.
    destruct (WellScoped_Subst_substBndr _ _ y _ _  Hsb1 ltac:(auto) H0) as [h0 h1].
    destruct (IHbndrs s' subst' ys _ Hsb2 ltac:(auto) h1) as [h2 h3].

    replace (a :: bndrs) with (cons a nil ++ bndrs); try reflexivity.
    subst. 
    split.
    ++ eapply SubstExtends_step; eauto.
    ++ simpl. rewrite extendVarSetList_cons.
       auto.
Qed.


Lemma SubstExtends_substBndrs : forall bndrs subst subst' bndrs' vs,
  forall (SB : substBndrs subst bndrs = (subst', bndrs')),
    Forall GoodLocalVar bndrs ->
    WellScoped_Subst subst vs ->
    SubstExtends subst bndrs subst' bndrs' /\
    WellScoped_Subst subst' (extendVarSetList vs bndrs).
Proof.
  unfold substBndrs. 
  eapply SubstExtends_mapAccumL_substBndr.
Qed.

Lemma SubstExtends_substRecBndrs : forall bndrs subst subst' bndrs' vs,
  forall (SB : substRecBndrs subst bndrs = (subst', bndrs')),
  Forall GoodLocalVar bndrs ->
  WellScoped_Subst subst vs ->
  SubstExtends subst bndrs subst' bndrs'  /\
  WellScoped_Subst subst' (extendVarSetList vs bndrs).
Proof.
  unfold substRecBndrs.
  intros.
  destruct ( Traversable.mapAccumL
           (substIdBndr (Datatypes.id &"rec-bndr") (Err.error Panic.someSDoc)) subst
           bndrs) eqn:EQ.
  inversion SB; subst; clear SB.
  revert bndrs subst subst' bndrs' vs EQ H H0.
  induction bndrs; intros.
  + rewrite mapAccumL_nil in EQ.
    inversion EQ; subst.
    split. eapply SubstExtends_refl; eauto.
    rewrite extendVarSetList_nil. auto.
  + rewrite mapAccumL_cons in EQ.
    lift_let_in_eq Hsb1.
    lift_let_in_eq Hsb2.
    inversion EQ; subst; clear EQ.
    rewrite Forall.Forall_cons_iff in H.
    destruct H.
    eapply WellScoped_Subst_substIdBndr in Hsb1; eauto.
    destruct Hsb1 as [? ?].

    destruct (IHbndrs s' subst' _ (extendVarSet vs a) Hsb2) as [h2 h3]; auto.
    replace (a :: bndrs) with (cons a nil ++ bndrs); try reflexivity.
    split.
    ++ eapply SubstExtends_step; eauto.
    ++ simpl. rewrite extendVarSetList_cons.
       auto.
Qed.

Lemma substExpr_ok : forall e s vs in_scope_set env u0 u1, 
    WellScoped_Subst (Mk_Subst in_scope_set env u0 u1) vs -> 
    WellScoped e vs -> 
    WellScoped (substExpr s (Mk_Subst in_scope_set env u0 u1) e) 
               (getInScopeVars in_scope_set).
Proof.
  intros e.
  apply (core_induct e); unfold substExpr.
  - unfold subst_expr. intros v s vs in_scope_set env u0 u1 WSsubst WSvar.
    unfold lookupIdSubst. 
    simpl in WSsubst. 
    destruct WSsubst as [ss vv] . specialize (vv v).         
    destruct (isLocalId v) eqn:HLocal; simpl.
    -- destruct (lookupVarEnv env v) eqn:HLookup. 
        + tauto.
        + destruct (lookupInScope in_scope_set v) eqn:HIS.
          ++ unfold WellScoped, WellScopedVar in *.
             rewrite isLocalVar_isLocalId in WSvar by assumption.
             destruct (isLocalVar v0) eqn:iLV; only 2: apply I.
             destruct (lookupVarSet vs v) eqn:LVS; try contradiction.
             unfold lookupInScope in HIS. destruct in_scope_set. simpl.
             pose (VV := ValidVarSet_invariant v2). clearbody VV.
             unfold ValidVarSet in VV.
             specialize (VV _ _ HIS).
             rewrite lookupVarSet_eq with (v2 := v).
             rewrite HIS.
             eapply Var.almostEqual_refl; auto.
             rewrite Base.Eq_sym. auto.
          ++ (* This case is impossible. *)
             unfold WellScoped, WellScopedVar in WSvar.
             unfold lookupInScope in HIS. destruct in_scope_set.
             unfold StrongSubset in ss.
             specialize (ss v). simpl in ss.
             rewrite HIS in ss.
             rewrite lookupVarSet_minusDom_1 in ss; eauto.
             rewrite isLocalVar_isLocalId in WSvar by assumption.
             destruct (lookupVarSet vs v); try contradiction.
             
    --



      unfold WellScoped, WellScopedVar in WSvar. 

      (* TODO *)
       (* !!!!! This is a global id, so we don't substitute for it !!!!! *)
       (* Need to add an assumption that v is either a localId or 
          a globalId to the scope invariant.  
          (And add a restriction that global id's are not in the dom 
          of the substitution.) *)

       
       admit.

  - unfold subst_expr. auto. 
  - intros. 
    rewrite subst_expr_App.
    unfold WellScoped; simpl; fold WellScoped.
    unfold WellScoped in H2; simpl; fold WellScoped in H2. destruct H2.
    split; eauto.
  - intros.
    rewrite subst_expr_Lam.
    destruct substBndr as [subst' bndr'] eqn:SB.
    unfold WellScoped in *; fold WellScoped in *.
    destruct H1 as [GLV H1].
    split.
    -- eapply GoodLocalVar_substBndr; eauto.
    -- eapply WellScoped_substBndr; eauto.
  - destruct binds.
    + intros body He0 Hbody s vs in_scope_set env u u0 WSS WSL.
      rewrite subst_expr_Let.
      rewrite substBind_NonRec.
      destruct substBndr as [subst' bndr'] eqn:SB.
     
      unfold WellScoped in *. fold WellScoped in *.
      destruct WSL as [[GLV WSe] WSb].

      split; only 1: split; eauto.
      -- eapply GoodLocalVar_substBndr; eauto.
      -- unfold bindersOf in *.
         rewrite extendVarSetList_cons in *.
         rewrite extendVarSetList_nil  in *.
         eapply WellScoped_substBndr; eauto.

    + intros body IHrhs IHbody s vs in_scope_set env u u0 WSvs WSe.
      rewrite subst_expr_Let.
      rewrite substBind_Rec. 
      destruct WSe as [[GLV [ND FF]] WSB].
      
      unfold bindersOf in WSB.
      rewrite bindersOf_Rec_cleanup in WSB.

      destruct (List.unzip l) as [vars rhss] eqn:UZ.      

      assert (EQL : length vars = length rhss).
      { eapply unzip_equal_length; eauto. }
      apply unzip_zip in UZ.
      subst l.

      rewrite map_fst_zip in *; auto.

      assert (NDV: NoDup vars). eapply NoDup_map_inv; eauto.

      destruct substRecBndrs as [subst' bndrs'] eqn:SRB.
      eapply SubstExtends_substRecBndrs in SRB; eauto.
      destruct_one_pair.
      rewrite Forall.Forall'_Forall in FF.
      rewrite Forall_forall in FF.     
      unfold WellScoped in *. fold WellScoped in *.
      repeat split.
      ++ destruct_SubstExtends.
         rewrite <- Forall.Forall_map with (f := fst) in *; auto.
         rewrite map_fst_zip in *; auto.
         rewrite map_snd_zip'; auto.
         rewrite map_length.
         rewrite <- H. eapply EQL.
     ++ destruct_SubstExtends.
        unfold CoreBndr,CoreExpr in *.
        rewrite map_fst_zip in *; auto. 

(*
        rewrite <- map_map with (g := fun p => subst_expr & "substBind" subst' p)
                               (f := snd).
*)
        rewrite map_snd_zip'.
        rewrite map_length.
        unfold CoreBndr,CoreExpr in *.
        congruence.
        unfold CoreBndr,CoreExpr in *.
        congruence.

      ++ rewrite Forall.Forall'_Forall.
         rewrite Forall_forall.
         intros.
         destruct x as [bndr' rhs'].
         simpl.

         rewrite map_snd_zip' in H1; auto.
         set (rhss' := map (subst_expr &"substBind" subst') rhss) in *.
         unfold CoreBndr in *.
         assert (L: length rhss = length rhss').
         { unfold rhss'. rewrite map_length. auto. }

         assert (L1 : length bndrs' = length rhss' ).
         { 
           destruct_SubstExtends. congruence.  
         } 
         
         (* At this point we have 

            (bndr',rhs') in (bndrs',rhss')
            
            and we need to get 
            
            (bndr,rhs) in (vars, rhss)

          *)

         destruct (In_zip_snd rhss H1) as [rhs InR]; try congruence.
         destruct (In_zip_fst vars InR) as [bndr InB]; try congruence.
         apply In_zip_swap in InB.

         specialize (IHrhs bndr rhs InB). 
         assert (rhs' = subst_expr &"substBind" subst' rhs).
         {
           unfold rhss' in InR.
           
           apply In_zip_map in InR. auto. }
         
         specialize (FF (bndr,rhs) InB).

         subst rhs'.
         replace (getInScopeVars in_scope_set) with 
             (getSubstInScopeVars (Mk_Subst in_scope_set env u u0)); auto.

         rewrite map_fst_zip.

         eapply WellScoped_substBody with (vars := vars); eauto.
         intros subst0 WS0.
         destruct subst0.
         eapply IHrhs; eauto.
         rewrite <- Forall.Forall_map with (f := fst) in GLV.
         rewrite map_fst_zip in GLV.
         auto.
         auto.
         rewrite map_snd_zip'.
         rewrite map_length.
         rewrite L1. rewrite <- L.
        auto.
        auto.
      ++ unfold bindersOf.
         rewrite bindersOf_Rec_cleanup.
         destruct_SubstExtends.
         rewrite map_fst_zip.
         rewrite <- getInScopeVars_extendInScopeSetList.
         eapply WellScoped_StrongSubset.
         eapply IHbody;eauto.
         rewrite getInScopeVars_extendInScopeSetList.
         eauto.
         unfold CoreBndr, CoreExpr in *.
         rewrite map_snd_zip'.
         rewrite map_length.
         rewrite <- H.
         eauto.
         eauto.
      ++ rewrite <- Forall.Forall_map in GLV.
         rewrite map_fst_zip in GLV.
         auto.
         auto.
  - intros.
    rewrite subst_expr_Case.
    destruct substBndr as [subst' bndr'] eqn:SB.
    unfold WellScoped in *. fold WellScoped in *.
    repeat destruct_one_pair.
    rewrite Forall.Forall'_Forall in *.
    rewrite Forall_forall in *.
    split; [|split].
    + (* recursive case for the scrut *)
      eauto.
    + eapply GoodLocalVar_substBndr; eauto. 
    + 
    intros alt IA.
    unfold substAlt in IA.
    rewrite in_map_iff in IA.
    destruct IA as [[[dc pats] rhs] [IAA IN]].
    destruct (substBndrs subst' pats) as [subst'' bndr''] eqn:SB2.
    destruct alt as [[dc0 bdnr''0] ss0]. inversion IAA. subst. clear IAA.
    pose (wf := H4 _ IN). clearbody wf. simpl in wf.
    simpl.
    destruct_one_pair.

    destruct (WellScoped_Subst_substBndr _ _ _ _ vs SB) as [h0 h1]; auto.

    destruct (SubstExtends_substBndrs _ _ _ _ (extendVarSet vs bndr)
                                      SB2) as [h2 h3]; auto.
    split.
    { destruct_SubstExtends. auto. }
    destruct subst'' as [i0'' i1'' u0'' u1''].

    eapply WellScoped_StrongSubset.
    eapply H0. eapply IN.
    eauto.
    rewrite extendVarSetList_cons in *.
    auto.
    destruct_SubstExtends.
    eapply StrongSubset_trans; eauto. 
    rewrite extendVarSetList_cons in *.
    rewrite extendVarSetList_nil in *.
    eapply StrongSubset_extendVarSetList.
    eauto.
  - intros.
    rewrite subst_expr_Cast.
    unfold WellScoped in *. fold WellScoped in *.
    eauto.

  - intros.
    rewrite subst_expr_Tick.
    unfold WellScoped in *. fold WellScoped in *.
    eapply H; eauto.

  - intros.
    unfold subst_expr.
    unfold WellScoped in *. fold WellScoped in *.
    auto.

  - intros.
    unfold subst_expr.
    unfold WellScoped in *. fold WellScoped in *.
    auto.
Admitted.
