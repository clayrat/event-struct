From RelationAlgebra Require Import lattice monoid rel kat_tac kleene.
From mathcomp Require Import ssreflect ssrfun ssrbool eqtype choice seq path.
From mathcomp Require Import order finmap fintype ssrnat finfun.
From eventstruct Require Import utils ident porf_eventstruct.
From eventstruct Require Import rewriting_system inhtype.

(******************************************************************************)
(* Here we want to make function that by event and event structure creates a  *)
(* new event structure with added event. Then we want to describe behavior of *)
(* ca, cf, ... on new structure in terms of ca, cf, ... on old one. Finally   *)
(* we want to prove that if our structure is consistent, and we are adding    *)
(* the element that is not conflicting with his predecessors, then our new    *)
(* structure is going to be consistent, too.                                  *)
(*                                                                            *)
(* This file contains the definitions of:                                     *)
(*         add_label == special record with all necessary information about   *)
(*                   event that we want to add to a porf_eventstruct          *)
(*         add_event es al == function that takes porf_eventstruct            *)
(*                   and record add_label with event we want to add and       *)
(*                   returns new porf_eventstruct with added element          *)
(*         'function'_add_eventE == lemma that determines behavior of         *)
(*                   'function' on the new event structure with added element *)
(*                    in terms of 'function' on event structure without one   *)
(*         consist_add_event == statement about consistence of our new        *)
(*                    structure                                               *)
(*         tr_add_event e1 e2 == we can add some event to e1 and obtain e2    *)
(*         ltr_add_event e1 al e2 == we can add al to e1 and obtain e2        *)
(*         add_label_of_nread == takes non-read label and predecessor and     *)
(*                    returns corresponding add_label structure               *)
(*         rf_ncf_nread == lemma that ensures event structures obtained by    *)
(*                         add_label_of_nread is prime                        *)
(*         contain al es == checks if event that we want to add (al) is       *)
(*                    already in es                                           *)
(*         add_new_event == adding a new event to the event structure if it   *)
(*                    is not contained there                                  *)
(******************************************************************************)

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Import Order.LTheory.
Local Open Scope order_scope.
Local Open Scope fset_scope.
Local Open Scope ident_scope.

Import Label.Syntax.

Arguments dom0 {_ _ _}.

Section TransitionSystem.

Context (E : identType) (Lab : labType).

Notation porf_eventstruct := (@porf_eventstruct E Lab).
Notation prime_porf_eventstruct := (@prime_porf_eventstruct E Lab).

Notation label := (Lab).

Implicit Types (x : Loc) (es : porf_eventstruct).

(* Section with definitions for execution graph with added event *)
Section AddEvent.

(* execution graph in which we want to add l *)
Context (es : porf_eventstruct).

Notation dom  := (dom es).
Notation ffed := (fed es).
Notation flab := (lab es).
Notation ffpo := (fpo es).
Notation ffrf := (frf es).

Notation fresh_id := (fresh_seq dom).

Structure add_label := Add {
  add_lb         : Lab;
  add_po         : E;
  add_rf         : E;

  add_po_in_dom  : add_po \in dom;
  add_rf_in_dom  : add_rf \in dom;
  add_po_consist : flab add_po (po)>> add_lb;
  add_rf_consist : flab add_rf (rf)>> add_lb;
}.

Coercion of_add_label := fun
  '(Add l p w _ _ _ _) => mk_edescr l p w.

Lemma of_add_label_inj : injective of_add_label.
Proof.
  case=> ??? ++++ [??? ++++ [le pe we]].
  move: le pe we; (do ? case :_ /)=> *; congr Add; exact/eq_irrelevance.
Qed.

Variable al : add_label.

(* label of an event to add *)
Notation lb := (add_lb al).

(* predecessor of the new event (if it exists) *)
Notation pred := (add_po al).

(* if our event is `Read` then we should provide the corresponding `Write`
   event *)
Notation write := (add_rf al).

Lemma po_fresh_id : pred <^i fresh_id.
Proof. by move/add_po_in_dom/fresh_seq_mem: al. Qed.

Lemma rf_fresh_id : write <^i fresh_id.
Proof. by move/add_rf_in_dom/fresh_seq_mem: al. Qed.

Definition contain :=
  has (fun e => (flab e == lb) && (ffrf e == write) && (ffpo e == pred)) dom.

Definition add_fed :=
  [ fsfun ffed with fresh_id |->
                    {| lab_prj := lb; fpo_prj := pred; frf_prj := write |} ].

Definition add_lab := fun e : E => lab_prj (add_fed e).
Definition add_fpo := fun e : E => fpo_prj (add_fed e).
Definition add_frf := fun e : E => frf_prj (add_fed e).

Lemma add_fedE e :
  add_fed e = if e == fresh_id then mk_edescr lb pred write else fed es e.
Proof. by rewrite /= fsfun_withE /=; case: ifP. Qed.

Lemma add_labE e :
  add_lab e = if e == fresh_id then lb else lab es e.
Proof. by rewrite /add_lab /add_fed /= fsfun_withE /=; case: ifP. Qed.

Lemma add_fpoE e :
  add_fpo e = if e == fresh_id then pred else fpo es e.
Proof. by rewrite /add_fpo /add_fed /= fsfun_withE /=; case: ifP. Qed.

Lemma add_frfE e :
  add_frf e = if e == fresh_id then write else frf es e.
Proof. by rewrite /add_frf /add_fed /= fsfun_withE; case: ifP. Qed.

Fact add_fed_finsupp : finsupp add_fed == (seq_fset tt (fresh_id :: dom)).
Proof.
  apply/fset_eqP=> x; rewrite ?inE seq_fsetE finsupp_with.
  case: ifP; rewrite ?inE fed_supp //.
  move: po_fresh_id=> /[swap]/eqP[?->]; by rewrite ltxx.
Qed.

Lemma add_fed0 :
  add_fed ident0 = {| lab_prj := \init; fpo_prj := ident0; frf_prj := ident0 |}.
Proof.
  rewrite add_fedE lt_eqF; first exact/fed0.
  exact/fresh_seq_mem/dom0.
Qed.

Fact add_fpo_dom :
  [forall e : finsupp add_fed, add_fpo (val e) \in fresh_id :: dom].
Proof.
  apply/forallP=> [[/= x]].
  rewrite (eqP add_fed_finsupp) ?inE seq_fsetE ?inE /add_fpo fsfun_withE.
  case: (x =P fresh_id) => /=; first by rewrite (add_po_in_dom al).
  by move=> ? /fpo_dom->.
Qed.

Fact add_frf_dom :
  [forall e : finsupp add_fed, add_frf (val e) \in fresh_id :: dom].
Proof.
  apply/forallP=> [[/= x]].
  rewrite (eqP add_fed_finsupp) ?inE seq_fsetE ?inE /add_frf fsfun_withE.
  case: (x =P fresh_id)=> /=; first by rewrite (add_rf_in_dom al).
  by move=> ? /frf_dom->.
Qed.

Fact add_fpo_le :
  [forall e : finsupp add_fed, (val e != \i0) ==> (add_fpo (val e) <^i val e)].
Proof.
  apply/forallP=> [[/=]] e.
  rewrite (eqP add_fed_finsupp) ?inE seq_fsetE ?inE.
  rewrite add_fpoE; case: ifP=> /= [/eqP-> _|?].
  - by rewrite po_fresh_id implybT.
  by move/fpo_n0/implyP.
Qed.

Fact add_frf_le :
  [forall e : finsupp add_fed, (val e != \i0) ==> (add_frf (val e) <^i val e)].
Proof.
  apply/forallP=> [[/=]] e.
  rewrite (eqP add_fed_finsupp) ?inE seq_fsetE ?inE.
  rewrite add_frfE; case: ifP=> /= [/eqP-> _|?].
  - by rewrite rf_fresh_id implybT.
  by move/frf_n0/implyP.
Qed.

Fact add_frf_sync :
  [forall e : finsupp add_fed, add_lab (add_frf (val e)) (rf)>> add_lab (val e)].
Proof.
  apply/forallP=> [[/=]] e.
  rewrite (eqP add_fed_finsupp) ?inE seq_fsetE ?inE.
  rewrite !add_labE !add_frfE.
  case: (e =P fresh_id)=> /= [|? /frf_dom /fresh_seq_mem /lt_eqF->].
  - by rewrite (lt_eqF rf_fresh_id) (add_rf_consist al).
  exact/frf_sync.
Qed.

Fact add_fpo_sync :
  [forall e : finsupp add_fed, add_lab (add_fpo (val e)) (po)>> add_lab (val e)].
Proof.
  apply/forallP=> [[/=]] e.
  rewrite (eqP add_fed_finsupp) ?inE seq_fsetE ?inE.
  rewrite !add_labE !add_fpoE.
  case: (e =P fresh_id)=> /= [|? /fpo_dom /fresh_seq_mem /lt_eqF->].
  - by rewrite (lt_eqF po_fresh_id) (add_po_consist al).
  exact/fpo_sync.
Qed.

Lemma nfresh_dom0 :
  \i0 \in fresh_id :: dom.
Proof. by rewrite ?inE dom0. Qed.

Definition add_event :=
  @Pack _ _
        (fresh_id :: dom)
        add_fed
        add_fed_finsupp
        nfresh_dom0
        add_fed0
        add_fpo_dom
        add_frf_dom
        add_fpo_le
        add_frf_le
        add_fpo_sync
        add_frf_sync.

Definition add_new_event := if contain then es else add_event.

Hypothesis rf_ncf_dom_  : rf_ncf_dom es.
(* Hypothesis rf_ncf_fresh : ~~ (cf add_event fresh_id write). *)

Import Relation_Operators.

(* TODO: remove duplicate lemmas `add_fedE`, `add_labE`, etc *)

Lemma fed_add_eventE e :
  fed add_event e = if e == fresh_id then mk_edescr lb pred write else fed es e.
Proof. exact: add_fedE. Qed.

Lemma lab_add_eventE e :
  lab add_event e = if e == fresh_id then lb else lab es e.
Proof. exact: add_labE. Qed.

Lemma fpo_add_eventE e :
  fpo add_event e = if e == fresh_id then pred else fpo es e.
Proof. exact: add_fpoE. Qed.

Lemma frf_add_eventE e :
  frf add_event e = if e == fresh_id then write else frf es e.
Proof. exact: add_frfE. Qed.

Lemma ica_add_eventE e1 e2 :
  ica add_event e1 e2 =
  if e2 == fresh_id then
    (pred == e1) || (write == e1)
  else ica es e1 e2.
Proof.
  rewrite icaE /= /fca frf_add_eventE fpo_add_eventE.
  case: ifP=> ?; rewrite ?(andTb, andFb) ?orbF // ?inE.
  by rewrite eq_sym orbC eq_sym orbC.
Qed.

Lemma ca_add_eventE e1 e2 :
  e2 != fresh_id -> ca es e1 e2 = ca add_event e1 e2.
Proof.
  move=> N.
  apply/closure_n1P/closure_n1P; move: N=> /[swap]; elim; try constructor.
  all: move=> y ? I ? H /negbTE Z; apply: (@rtn1_trans _ _ _ y).
  2,4: apply/H/negP; move: I.
  - by rewrite ica_add_eventE Z.
  - move/[swap]/eqP=>->/ica_fresh Ez.
    by move/eqP: Z Ez.
  - rewrite ica_add_eventE Z=> /[swap]/eqP->/ica_fresh.
    by move/eqP: Z.
  move: I; by rewrite ica_add_eventE Z.
Qed.

Lemma icf_add_eventE e1 e2 :
  e1 != fresh_id -> e2 != fresh_id ->
  icf es e1 e2 = icf add_event e1 e2.
Proof.
  rewrite /icf !fpo_add_eventE lab_add_eventE=> /[dup] N /negbTE->/negbTE->.
  case: ifP=> //; case: (boolP (e1 \in dom))=> [|/fpo_ndom-> /(negP N)//].
  by move/fpo_dom/fresh_seq_mem/lt_eqF->.
Qed.

Lemma cf_add_eventE e1 e2 :
  e1 != fresh_id -> e2 != fresh_id ->
  cf es e1 e2 = cf add_event e1 e2.
Proof.
  move=> /[dup] /ca_fresh_contra Cnf1 Nf1 /[dup] /ca_fresh_contra Cnf2 Nf2.
  apply/cfP/cfP=> -[x [y C]]; exists x, y; move: C; rewrite -?ca_add_eventE //.
  - move=> [] ??; rewrite -icf_add_eventE //;
      [by rewrite Cnf1 | by rewrite Cnf2].
  move=> [] ??; rewrite icf_add_eventE //; first by rewrite Cnf1 ?C.
  by rewrite Cnf2 ?C.
Qed.

Lemma rf_ncf_add_event :
  ~~ (cf add_event fresh_id write) <-> rf_ncf_dom add_event.
Proof.
  split=> [? |].
  - rewrite /rf_ncf_dom; apply /allP=> e1.
    rewrite /frf /= fsfun_withE ?inE.
    case: ifP=> /= [/eqP-> _|/negbT N /(allP rf_ncf_dom_)] //; first exact/implyP.
    rewrite -cf_add_eventE //.
    apply/negP=> /eqP Ef.
    have /ica_fresh /eqP /(negP N) //: ica es fresh_id e1.
    by rewrite icaE /= ?inE -Ef eq_refl.
  case: (boolP (write == fresh_id))=> [/eqP<- /cf_irrelf/(_ write)->|?] //.
  move/allP/(_ fresh_id)=> /=; rewrite frf_add_eventE inE eq_refl /=.
  move/(_ erefl)/implyP; exact.
Qed.

(* Lemma rf_ncf_add_new_event :
  ~~ (cf add_event fresh_id write) -> rf_ncf_dom add_new_event.
Proof. rewrite /add_new_event; case: ifP=>// _; exact/rf_ncf_add_event. Qed. *)

End AddEvent.

(*Section NreadPrime.

Context (pes : prime_porf_eventstruct) (pr : E) (l : label).

Notation domain := (dom pes).
Notation fresh_id := (fresh_seq domain).

Hypothesis pr_mem : pr \in domain.
Hypothesis nr     : ~~ Label.is_read l.

Fact add_nread_synch : lab pes ident0 \>> l.
Proof.
  rewrite lab0 /Label.synch.
  case H: l=> //; symmetry; apply/contraPF.
  - move=> x; apply/negP; exact/nr.
  by rewrite /Label.is_read H.
Qed.

Let add_label_nread := Add pr_mem dom0 add_nread_synch.

Lemma rf_ncf_nread :
   rf_ncf_dom (add_event add_label_nread).
Proof. apply/rf_ncf_add_event=> //=; first (by case: pes); exact/cf0. Qed.

Lemma rf_ncf_new_nread :
  rf_ncf_dom (add_new_event add_label_nread).
Proof.
  rewrite /add_new_event; case: ifP=> // _.
  - by case pes.
  by rewrite ?rf_ncf_nread //.
Qed.

End NreadPrime.*)

End TransitionSystem.

Module AddEvent.

Section Confluence.

Context (E : identType) (Lab : labType).

Notation porf_eventstruct := (@porf_eventstruct E Lab).
Notation prime_porf_eventstruct := (@prime_porf_eventstruct E Lab).

Notation label := Lab.

Implicit Types (x : Loc) (es : porf_eventstruct).

Definition tr es1 es2 := exists al, es2 = @add_event _ Lab es1 al.

Notation "es1 '~>' es2" := (tr es1 es2) (at level 0).

Definition ltr (ed : edescr E label) es1 es2 :=
  exists2 al, es2 = @add_event _ Lab es1 al & ed = al.

Notation "es1 '~(' l ')~>' es2" := (ltr l es1 es2) (at level 0).

Section Equivalence.

Section IsoDef.

Context (f : E -> E) (es1 es2 : porf_eventstruct).

Definition is_morph := fed es2 \o f =1 (edescr_map f) \o fed es1.

Section Morphism.

Hypothesis morph: is_morph.

Lemma is_morph_lab e :
   lab es1 e = lab es2 (f e).
Proof.
  move/(congr1 (@lab_prj _ _)): (morph e).
  by rewrite /lab /=; case: (fed es1 e).
Qed.

Lemma is_morph_po e :
  f (fpo es1 e) = fpo es2 (f e).
Proof.
  move/(congr1 (@fpo_prj _ _)): (morph e).
  by rewrite fpo_prj_edescr_map.
Qed.

Lemma is_morph_rf e :
  f (frf es1 e) = frf es2 (f e).
Proof.
  move/(congr1 (@frf_prj _ _)): (morph e).
  by rewrite frf_prj_edescr_map.
Qed.

Lemma is_morph_ica e1 e2 :
  ica es1 e1 e2 -> ica es2 (f e1) (f e2).
Proof.
  rewrite ?icaE /fca /= ?inE -is_morph_po -is_morph_rf=> /orP[]/eqP->;
  by rewrite eq_refl.
Qed.

Lemma is_morph_ca e1 e2 :
  ca es1 e1 e2 -> ca es2 (f e1) (f e2).
Proof.
  move/closure_n1P; elim=> [|??/is_morph_ica I ?]; first exact/ca_refl.
  move/closure_n1P=> ?; apply/closure_n1P.
  by apply/Relation_Operators.rtn1_trans; first by exact/I.
Qed.

End Morphism.


Definition is_iso := is_morph /\ bijective f.

Section IsoMorphism.

Hypothesis iso : is_iso.

Lemma iso_dom : map f (dom es1) =i dom es2.
Proof.
  case: iso=> l /[dup] B [g /[dup] c1 /can_inj I c2 x].
  rewrite -[x]c2 (mem_map I) -?fed_supp_mem !mem_finsupp.
  move: (l (g x))=> /= ->.
  rewrite -[_ _ (f _) _]/(edescr_map f (mk_edescr _ _ _)).
  by rewrite (bij_eq (@edescr_map_bij label E E _ B)).
Qed.

Lemma f_icf e1 e2 :
  icf es1 e1 e2 -> icf es2 (f e1) (f e2).
Proof.
  case: iso=> ??.
  rewrite/icf ?lt_neqAle ?fpo_le ?andbT.
  by rewrite ?is_morph_lab -?is_morph_po ?(bij_eq (f := f)).
Qed.

Lemma f_cf e1 e2 :
  es1 |- e1 # e2 -> es2 |- (f e1) # (f e2).
Proof.
  case: iso=> ?? /cfP [x [y [*]]]; apply/cfP; exists (f x), (f y).
  by rewrite ?is_morph_ca ?f_icf.
Qed.

End IsoMorphism.

End IsoDef.

Lemma is_iso_can es1 es2 f g :
  is_iso f es1 es2 -> cancel f g -> cancel g f ->
  is_iso g es2 es1.
Proof.
  move=> [l b c1 c2].
  have B: bijective g by apply/(bij_can_bij b).
  split=> //; do ? split; try move=> x /=.
  apply/(bij_inj (@edescr_map_bij label _ _ _ b)).
  move: (l (g x))=> /= <-.
  by rewrite ?(edescr_map_can c2) c2.
Qed.

Lemma isoE f e1 e2 es1 es2: is_iso f es1 es2 ->
  (
    (lab es1 e1 = lab es2 (f e1)) *
    ((f (fpo es1 e1) = fpo es2 (f e1)) *
    (f (frf es1 e1) = frf es2 (f e1))) *
    ((ca es1 e1 e2 = ca es2 (f e1) (f e2)) *
    (cf es1 e1 e2 = cf es2 (f e1) (f e2)))
  )%type.
Proof.
  move=> /[dup] If [M []? /[dup] c /(is_iso_can If) /[apply] Ig].
  do ? split; rewrite ?(is_morph_po M) ?(is_morph_lab M) ?(is_morph_rf M) //.
  - apply/(sameP idP)/(equivP idP).
    split=> [/(is_morph_ca Ig.1)|/(is_morph_ca M)//]; by rewrite ?c.
  apply/(sameP idP)/(equivP idP).
  split=> [/(f_cf Ig)|/(f_cf If)//]; by rewrite ?c.
Qed.

Lemma eq_is_iso f g es1 es2 : f =1 g ->
  is_iso f es1 es2 <-> is_iso g es1 es2.
Proof.
  move=> /[dup] /fsym H1 H2; rewrite /is_iso /is_morph.
  have->: bijective f <-> bijective g.
  - by split=> [/eq_bij/(_ _ H2) |/eq_bij/(_ _ H1)].
  apply/(and_iff_compat_r (bijective g)).
  split=> H x; move: (H x)=> /=; rewrite (H1, H2)=>->;
    by under edescr_map_eqfun=> ? do rewrite (H1, H2) over //.
Qed.

Definition eqv := exlab is_iso.

Lemma eqv_refl : 1 ≦ eqv.
Proof.
  move=> ??->. exists id; do ? split=> //; last exact/inv_bij;
  rewrite ?map_id // => ? /=; by rewrite edescr_map_id.
Qed.

Lemma is_iso_comp es1 es2 es3 f g :
  is_iso f es1 es2 -> is_iso g es2 es3 ->
  is_iso (g \o f) es1 es3 .
Proof.
  case=> [] l1 ?[] l2 /[dup] [[?? c1 ?]] .
  (do ? split)=>[x|]; last exact/bij_comp.
  by move: (l1 x) (l2 (f x))=> /=; rewrite edescr_map_comp /= => <-.
Qed.

Lemma eqv_trans : Transitive eqv.
Proof. move=> ???[f i [g ?]]; exists (g \o f); exact/(is_iso_comp i). Qed.

Lemma eqv_symm : Symmetric eqv.
Proof. move=>> [? /[dup] I [_ [f *]]]; exists f; exact/(is_iso_can I).  Qed.

End Equivalence.

Notation "e1 ~~ e2" := (eqv e1 e2) (at level 20).

Notation fresh_id1  es := (fresh_seq (dom es)).
Notation fresh_id2 es := (fresh_seq (fresh_seq (dom es) :: dom es)).

Lemma is_iso_swap es1 es2 f e1 e2 :
  e1 \notin dom es1 ->
  e2 \notin dom es1 ->
  is_iso f es1 es2 ->
  is_iso (swap f e1 e2) es1 es2.
Proof.
  move=> N1 N2 /[dup] I [ l /[dup] /bij_inj ? b].
  case: (e1 =P e2)=> /= [->|/eqP/negbTE e12].
  - by under eq_is_iso=> ? do rewrite swapxx over //.
  (do ? split)=> [x/=|]; last exact/bij_swap.
  have H: forall e es, e \notin dom es -> fed es e = mk_edescr \eps e e.
  - by move=> ?? D; rewrite fsfun_dflt // fed_supp_mem D.
  rewrite /swap; case: ifP=> [/eqP->|].
  - rewrite ?H /= ?eq_refl // -?(iso_dom I) mem_map //.
  case: ifP=> [/eqP-> N|F1 F2].
  rewrite ?H //= ?N ?eq_refl // -?(iso_dom I) mem_map //.
  case: (boolP (x \in dom es1))=> [/[dup]/fpo_dom I1 /frf_dom I2|?].
  - apply/eqP; rewrite edescr_eq.
    rewrite lab_prj_edescr_map fpo_prj_edescr_map frf_prj_edescr_map.
    rewrite ?(negbTE (memPn _ _ I1)) ?(negbTE (memPn _ _ I2)) //.
    move: (l x)=> /=->.
    rewrite lab_prj_edescr_map fpo_prj_edescr_map frf_prj_edescr_map.
    by rewrite !eq_refl.
  by rewrite ?H //= ?F1 ?F2 //  -?(iso_dom I) mem_map.
Qed.

Arguments Add {_ _ _ _} _ _ _.

Lemma comm_eqv_tr :
  diamond_commute eqv tr.
Proof.
  move=> es es3 ? /[swap][][[al ap aw apd awd apc awc]]->.
  case=> f /[dup][[_ [g? c]]] I.
  have NI: g (fresh_id1 es3) \notin dom es.
  - by rewrite -(mem_map (bij_inj (proj2 I))) c (iso_dom I) fresh_seq_nmem //.
  move/(is_iso_swap (fresh_seq_nmem (dom es)) NI): I.
  set h := (swap f (fresh_id1 es) (g (fresh_id1 es3))).
  move=> /[dup] I [ l /[dup] /bij_inj ? b].
  have H: forall e, e \in dom es -> h e \in dom es3=> [e|].
  by rewrite -(iso_dom I) mem_map.
  have [: a1 a2 a3 a4] @s4: add_label es3 := @Add E Lab es3 al (h ap) (h aw) a1 a2 a3 a4.
  1,2: by apply/H; rewrite (apd, awd).
  - move: apc; move: (l ap)=> /=; rewrite /lab.
    by case L1: (fed _ ap)=> /=; case L2: (fed es3 (f ap))=> -> /=.
  - move: awc; move: (l aw)=> /=; rewrite /lab.
    by case L1: (fed _ aw)=> /=; case L2: (fed es3 (f aw))=> -> /=.
  exists (add_event s4); [by exists s4 | exists h].
  (do ? split)=> // x /=.
  rewrite ?fed_add_eventE /= -[fresh_id1 _]c -(swap1 f (fresh_id1 es)).
  rewrite -/h (bij_eq b); case: ifP=> // ?; exact/l.
Qed.

Lemma swap_dom es e : e \in dom es ->
  swap id (fresh_id1 es) (fresh_id2 es) e = e.
Proof.
  move=> H; rewrite -swap_not_eq=> //; rewrite lt_eqF //.
  - by apply /fresh_seq_mem.
  by apply /fresh_seq_mem; rewrite inE; apply /orP; right.
Qed.

Lemma add_add (es : porf_eventstruct)
  (al1 al2 : add_label es) :
  exists al : add_label (add_event al1),
  al = al2 :> edescr E label.
Proof.
  case: al2=> l p w ap aw ??.
  have [:a1 a2 a3 a4] @al : add_label (add_event al1) :=
    @Add E Lab (add_event al1) l p w a1 a2 a3 a4; try by rewrite ?inE (ap, aw) orbT.
    - by rewrite /= lab_add_eventE (lt_eqF (fresh_seq_mem ap)).
    - by rewrite /= lab_add_eventE (lt_eqF (fresh_seq_mem aw)).
    by exists al; rewrite ?(swap_dom (lexx _)).
Qed.

Lemma swap_add es
  (al1 al2 : add_label es)
  (al3 : add_label (add_event al1))
  (al4 : add_label (add_event al2)) :
  al1 = al4 :> edescr E label ->
  al2 = al3 :> edescr E label ->
  is_iso (swap id (fresh_id1 es) (fresh_id2 es))
    (add_event al3) (add_event al4) .
Proof.
  case: al1 al3 al2 al4=> ???????[/=???++++] [???????[/=???++++ E1 E2]].
  case: E1 E2; do 3? case:_/; case; (do 3? case:_/)=>*.
  do ? split; last exact/bij_swap/inv_bij.
  move=> x /=; rewrite /comp !fed_add_eventE /=.
  have: fresh_id1 es <> fresh_id2 es.
  - suff: fresh_id1 es < fresh_id2 es by rewrite lt_def eq_sym=> /andP[] /eqP.
    by apply/fresh_seq_mem/mem_head.
  move/eqP/negbTE=>F; case: (x =P fresh_id1 es)=> [->|/eqP/[dup] ? /negbTE N1].
  - rewrite swap1 eq_refl F /= !swap_dom //.
  rewrite ?inv_eq ?swap1 ?swap2 ?N1; try exact/swap_inv.
  case: ifP=> //=; first by rewrite !swap_dom=> //.
  move/negbT=> ?; rewrite -swap_not_eq //.
  case: (boolP (x \in dom es))=> [|I].
  - case L: (fed _ x)=> [l p r] I /=; apply/congr2; rewrite swap_dom //.
    - by rewrite -[p]/(fpo_prj (mk_edescr l p r)) -L fpo_dom.
    by rewrite -[r]/(frf_prj (mk_edescr l p r)) -L frf_dom.
  by rewrite fsfun_dflt /= -?swap_not_eq // fed_supp I.
Qed.

Lemma comm_ltr l1 l2 :
  eqv_diamond_commute (ltr l1) (ltr l2) eqv.
Proof.
  move=> es ?? [al1 -> /[swap][[al2->]]].
  case: (add_add al1 al2)=> al3 /[dup]? <-->.
  case: (add_add al2 al1)=> al4 /[dup]? <-->.
  exists (add_event al3), (add_event al4).
  split; [by exists al3| by exists al4|].
  exists (swap id (fresh_id1 es) (fresh_id2 es)); exact/swap_add.
Qed.

Lemma exlab_tr : tr ≡ exlab ltr.
Proof. by move=> ??; split=> [[l ->]|[?[l ->]]]; do ? exists l. Qed.

Arguments isoE {_ _ _ _ _}.

Lemma dom_consist_eqv es1 es2 :
  es1 ~~ es2 -> rf_ncf_dom es1 ->
  rf_ncf_dom es2.
Proof.
  rewrite /rf_ncf_dom=> [[f /[dup] If]] [L ? /allP H]; apply/allP.
  move=> x; rewrite -(iso_dom If)=> /mapP[y /H ?->].
  move/(congr1 (@frf_prj _ _)): (L y)=> /=; rewrite -frfE=>->.
  by rewrite frf_prj_edescr_map bij_eq // -(isoE If).
Qed.

Lemma dom_consist_add l1 l2
  (es1 es2 es3 es4 : porf_eventstruct) :
  rf_ncf_dom es1 ->
  es1 ~(l1)~> es2 -> rf_ncf_dom es2 ->
  es1 ~(l2)~> es3 -> rf_ncf_dom es3 ->
  es2 ~(l2)~> es4 -> rf_ncf_dom es4.
Proof.
  move=> ?; case=> [[la1 p1 w1 ap1 aw1 ad1 ac1 ->]].
  set al1 := @Add E Lab _ _ _ _ ap1 aw1 ad1 ac1=> e2; move=> C'.
  case=> [[l p w ap aw ad ac]]+->; set al2 := @Add E Lab _ _ _ _ ap aw ad ac=> -> C.
  case=> [[l' p' ap' ++++-> [le pe we]]].
  move: le pe we; (do ? case: _/).
  move=> ap2 aw2 ad2 ac2; set al2' := @Add E Lab _ _ _ _ ap2 aw2 ad2 ac2.
  apply/rf_ncf_add_event=> //=.
  set f := swap id (fresh_id1 es1) (fresh_id2 es1).
  have P : f p1 = p1 by rewrite /f (swap_dom ap1).
  have W : f w1 = w1 by rewrite /f (swap_dom aw1).
  have [: a1 a2 a3 a4] @al3 : add_label (add_event al2)
    := @Add E Lab _ la1 (f p1) (f w1) a1 a2 a3 a4=> /=.
  1,2: rewrite ?inE (P, W) (ap1, aw1); lattice.
  - by rewrite P lab_add_eventE (lt_eqF (po_fresh_id al1)).
  - by rewrite W lab_add_eventE (lt_eqF (rf_fresh_id al1)).
  have E1: al1 = al3 :> edescr _ _ by rewrite /= W P.
  have E2: al2 = al2' :> edescr _ _ by [].
  rewrite (isoE (swap_add E1 E2)) swap2 (swap_dom aw) //.
  rewrite -cf_add_eventE; first exact/rf_ncf_add_event.
  - suff: fresh_id1 es1 < fresh_id1 (add_event al2) by rewrite lt_def eq_sym=> /andP[].
    by apply /fresh_seq_mem=> /=; apply mem_head.
  by rewrite (lt_eqF (rf_fresh_id al2')).
Qed.

Lemma dup_free_eqv es1 es2 :
  es1 ~~ es2 -> dup_free es1 -> dup_free es2.
Proof.
  case=> f /[dup] If [M /[dup][[g c1 c2]] b /dup_freeP I].
  apply/dup_freeP=> x y.
  rewrite -?(iso_dom If) -[x]c2 -[y]c2 ?(mem_map (bij_inj b)).
  move: (M (g x)) (M (g y)).
  by move=> /=->-> /I/[apply] Eq /(bij_inj (edescr_map_bij b))/Eq->.
Qed.

Lemma fresh_id12 es :
  fresh_id1 es == fresh_id2 es = false.
Proof.
  apply /contra_neqF; first exact /eqP.
  suff: fresh_id1 es < fresh_id2 es by rewrite lt_def eq_sym=> /andP[].
  by apply/fresh_seq_mem/mem_head.
Qed.

Lemma dup_free_add l1 l2
  (es1 es2 es3 es4 : porf_eventstruct) :
  es2 != es3 ->
  dup_free es1 ->
  es1 ~(l1)~> es2 -> dup_free es2 ->
  es1 ~(l2)~> es3 -> dup_free es3 ->
  es2 ~(l2)~> es4 -> dup_free es4.
Proof.
  move=> + /dup_freeP I1 [al1] + ? => /[swap]->.
  move=> + /dup_freeP I2 [al2] + -> => /[swap]-> /negP N.
  have {N} ?: al1 <> al2 :> edescr _ _ by move: N=>/[swap]/of_add_label_inj->.
  move/dup_freeP=> I3 [al3] -> Eq.
  have N: al1 <> al3 :> edescr _ _ by rewrite -Eq=> /of_add_label_inj //.
  apply/dup_freeP=> x y /=.
  move: (I1 x y) (I2 x y)=> /=. rewrite ?add_fedE ?inE /=.
  case: ifP=> /= [/eqP->|].
  - rewrite fresh_id12 /=; case: ifP=> [/eqP->|].
    - by rewrite fresh_id12.
    case: ifP=> /= [/eqP->|???/[apply]/[apply]//].
    move=> ????? []; case: (al1) (al3) N=> /= ??????? [/=].
    by move=>> ???? /[swap]->/[swap]->/[swap]->.
  case: ifP=> /= [/eqP->|].
  - rewrite fresh_id12 /=; case: ifP=> /= // ?????? /esym.
    by case: (al1) (al3) N=> /= ??????? [].
  case: ifP=> /= [/eqP->|]; case: ifP=> [/eqP->|] //=.
  - move=> ? /[dup] EN + ???? D Ef; move: (I3 (fresh_id1 es1) y)=> /=.
    rewrite ?inE ?add_fedE {-3}EN -Ef ?eqxx D /==> /(_ erefl erefl) L.
    have->: fresh_id1 es1 = y by apply/L; case: (al2) (al3) Eq=> ??????? [].
    by rewrite eqxx.
  move=> ?? /[dup] EN + ?? D ? Ef; move: (I3 x (fresh_id1 es1))=> /=.
  rewrite ?inE ?add_fedE {-3}EN Ef ?eqxx D /==> /(_ erefl erefl) L.
  have->: x = fresh_id1 es1 by apply/L; case: (al2) (al3) Eq=> ??????? [].
  by rewrite eqxx.
Qed.

End Confluence.

End AddEvent.

