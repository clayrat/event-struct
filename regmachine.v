From mathcomp Require Import ssreflect ssrfun ssrbool ssrnat seq fintype order.
From mathcomp Require Import eqtype fingraph path finmap choice finfun. 
From event_struct Require Import utilities eventstructure inhtype.
From event_struct Require Import transitionsystem ident rfsfun.

(******************************************************************************)
(* Here we want to obrain big-step semaintics of simple register machine in   *)
(* terms of fin_exec_event_structures                                         *)
(* This file contains definition of:                                          *)
(*       instr == regmachine instructions                                     *)
(*     seqprog == sequence on instructions ie. one thread of program          *)
(*     parprog == consurent program (contains several threads)                *)
(*  thrd_state == state of one thread: pair of our place in program (ie. line *)
(*            numder) and map from registers to values                        *)
(*  init_state == initial state of one thred : pair of 0 default map that     *)
(*     maps all registers to default value                                    *)
(*      config == configuration of program: pair of fin_exec_event_strucure   *)
(*           corresponding to our program in current state and map form       *)
(*           elements of this event structure to corresponding thread states  *)
(*  thrd_sem == if we are in some thread state we can make one step in program*)
(*     and obtain side effect (action on shared locals) and a new thread state*)
(*     But if we want to read from shared memory, in general we can do it in  *)
(*     defferent ways. So as a read-from-shared-memory-side effect we return  *)
(*     Read x __  ie. read with hole instead of read value. And as a mapping  *)
(*     from registers to values we return somehow codded function hole        *)
(*  ltr_thrd_sem == version of thrd_sem as labeled relation                   *)
(*    writes_seq == function that takes local variable x and some event       *)
(*          structure and returns all events in this event structure that are *)
(*          writing in x                                                      *)
(*        es_seq == takes event structure `es`, location `x`, predsessor event*)
(*          `pr` and returns sequence of `es + Read x v`, where v runs on all *)
(*           values  `v` that we can read in location `x`                     *)
(*      add_hole == takes `es`, label with hole `l` (look thrd_sem),          *)
(*    predsessor event `pr` and return seq `es + l` where l runs on all labels*)
(*     that can be obtained by filling the hole in `l`                        *)
(*     eval_step == takes config `c`, event `pr` and retunrs seq of           *)
(*        configurations `c'` that can be reach form `c` making a step        *)
(*        in thread state corresponding to `pr` in `c`                        *)
(******************************************************************************)

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Arguments Read {_ _}.
Arguments Write {_ _}.

Section RegMachine.

Open Scope fmap.
Context {val : inhType} {disp} {E : identType disp}.

(*Notation n := (@n val).*)
Notation exec_event_struct := (@fin_exec_event_struct val _ E).

(*Notation lab := (@lab val).*)
Notation __ := (tt).

(* Registers --- thread local variables *)
Definition reg := nat. 

(* Instruction *)
Inductive instr :=
| WriteReg : val -> reg -> instr
| ReadLoc  : reg -> loc -> instr
| WriteLoc : val -> loc -> instr
| CJmp     : reg -> nat -> instr.

Definition seqprog := seq instr.

Definition parprog := seq seqprog.

Record thrd_state := Thrd_state {
  ip     : nat;
  regmap : {fsfun reg -> val with inh}
}.

Definition eq_thrd_state st st' := 
  (ip st == ip st') && (regmap st == regmap st').

Lemma eqthrd_stateP : Equality.axiom eq_thrd_state.
Proof.
  case=> ?? [?? /=]; rewrite /eq_thrd_state /=.
  by apply/(equivP andP); split=> [[/eqP->/eqP->]|[->->]]. 
Qed.

Canonical thrd_state_eqMixin := EqMixin eqthrd_stateP.
Canonical thrd_state_eqType := Eval hnf in EqType thrd_state thrd_state_eqMixin.

Definition init_state : thrd_state := {| ip := 0; regmap := [fsfun with inh] |}.

Record config := Config {
  evstr    : exec_event_struct;
  trhdmap  :> {fsfun E -> thrd_state with init_state}
}.

Variable p : seqprog.

Notation nth := (nth (CJmp 0 0)).

Definition thrd_sem (st : thrd_state) :
  (option (@label unit val) * (val -> thrd_state))%type :=
  let: {| ip := i; regmap := map |} := st in
  match nth p i with
  | WriteReg v r => (none,
                     fun _ => {| ip     := i.+1;
                                 regmap := [fsfun map with r |-> v] |})
  | ReadLoc  r x => (some (Read x __), 
                     fun v => {| ip     := i.+1;
                                 regmap := [fsfun map with r |-> v] |})
  | WriteLoc v x => (some (Write x v), 
                     fun _ => {| ip     := i.+1;
                                 regmap := map |})
  | CJmp     r n => (none,             
                     fun _ => {| ip     := if map r != inh then n else i.+1;
                                 regmap := map |} )
  end.

Definition ltr_thrd_sem (l : option (@label val val)) st1 st2 : bool :=
  match thrd_sem st1, l with
  | (some (Write x v), st), some (Write y u) => [&& x == y, v == u & st inh == st2]
  | (some (Read  x _), st), some (Read  y u) => (x == y) && (st u == st2)
  | (none            , st), none             => st inh == st2
  | _, _                                     => false
  end.

Variable (es : exec_event_struct).
Notation dom      := (dom es).
Notation lab      := (lab es).
Notation ffpred   := (ffpred es).
Notation ffrf     := (ffrf es).
Notation fresh_id := (fresh_seq dom).

Arguments add_label_of_Nread {_ _ _ _} _ {_}.

Definition wval (l : @label val val) : val := 
  if l is Write _ v then v else inh.

(* label location *)
Definition lloc (l : @label val val) := 
  match l with
  | Write x _ => some x
  | Read  x _ => some x
  | _         => none
  end.

Definition is_write (l : @label val val) := 
  if l is Write _ _ then true else false.

Definition wpred (x : loc) (w : E) :=
   (lloc (lab w) == some x) && (is_write (lab w)).

Arguments wpred /.

Definition writes_seq x : seq {y | (wpred x y) && (y \in dom)} :=
  pmap insub dom.

Lemma ws_mem x (w : {y | (wpred x y) && (y \in dom)}) :
   (sval w) \in fresh_id :: dom .
Proof.
  rewrite ?inE.
  by case: w=> /= ? /andP[?->]. 
Qed.

Lemma ws_wpred x (w : {y | (wpred x y) && (y \in dom)}) :
  let: wr := sval w in
  let: read_lab := Read x (wval (lab wr)) in
    add_wr wr fresh_id lab read_lab.
Proof. 
  case: w=> /= e /andP[].
  case: (lab e)=> //= [?? /andP[]|?? /andP[/eqP[->]]] //; by rewrite ?eq_refl.
Qed.

(* TODO: filter by consistentcy *)
Definition es_seq x {pr} (pr_mem : pr \in fresh_id :: dom) :
 (seq (exec_event_struct * val)) := 
  [seq
    let: wr := sval w in
    let: read_lab := Read x (wval (lab wr)) in
    (
      add_event
        {| add_lb            := read_lab;
           add_pred_in_dom   := pr_mem;
           add_write_in_dom  := @ws_mem x w;
           add_write_consist := ws_wpred w; |},
      wval (lab (eqtype.val w))
    ) | w <- (writes_seq x)].

Definition add_hole  
  (l : @label unit val) {pr} (pr_mem : pr \in fresh_id :: dom) :
  seq (exec_event_struct * val) :=
  match l with
  | Write x v => 
    [:: (add_event (add_label_of_Nread (Write x v) pr_mem erefl), v)]
  | Read x __ => es_seq x pr_mem
  | _ => [::]
  end.

Definition eval_step (c : config) {pr} (pr_mem : pr \in fresh_id :: dom) 
  : seq config :=
  let: (l, cont_st) := thrd_sem (c pr) in
  if l is some l then
    [seq let: (e, v) := x in 
          (Config e [fsfun c with fresh_id |-> cont_st v]) |
          x <- (add_hole l pr_mem)]
  else 
    [:: Config (evstr c) [fsfun c with pr |-> cont_st inh]].

End RegMachine.
