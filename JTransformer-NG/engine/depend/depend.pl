depend(_ct1, _ct2)  :- depend(_ct1,_ct2,_,_).
posDepend(_ct1,_ct2,_DepElem) :- depend(_ct1,_ct2,positive,_DepElem).
negDepend(_ct1,_ct2,_DepElem) :- depend(_ct1,_ct2,negative,_DepElem).

% Muss VOR der richtigen dependency definition stehen
% schliesst diese aus !!!!
% Dient zur Interaktiven Aufl�sung von Abh�ngigkeiten
depend(_ct1, _ct2, _type, _label) :-
    use_cache_results_only,
    !,
    ct_edge(_ct1, _ct2, _label, _type).
depend(_ct1, _ct2, _DepType, _DepElem) :-
    % 1) lade CT's
    ct(_ct1, _c1, _t1),
    ct(_ct2, _c2, _t2),
    % 2) pr�fe ob CT's verschieden sind
    _ct1 \= _ct2,
%    breakpoint,
%    _ct1 = decorator_adaptee_interf,
%    _ct2 = decorator_before,
    % 3) ersetze Anweisungen an die Analyse
    replaceDependencyInstructions(_c1, _c2,_c1r,_c2r),
    % 5) extrahiere \= und pattern, unifiziere bei =      %do not backtrack
    extractRestrictions(_c1, _c2, _restr),
    % 4) expandiere Abstractionen zu DNF Termen      %do not backtrack
    expandAbstractionsAndDNF(_c1r, _c2r, _t2, _c1e, _c2e, _t2e),
%    _c1r = _c1e,
%    _c2r = _c2e,
%    _t2  =_t2e,
    % 6) f�hre auf den expandierten Vorbedingungen und Actionen die Abh�ngigkeitsanalyse durch
    depend(_c1e, _t1, _c2e, _t2e, _restr, _DepType, _DepElem).

breakpoint.

% Ersetzt Anweisungen an die Analyse
replaceDependencyInstructions(_c1, _c2,_C1r,_C2r):-
    replaceDependencyInstructions(_c1,_C1r),
    replaceDependencyInstructions(_c2,_C2r).

replaceDependencyInstructions(_member, (_memberExp)) :-
    _member \= ','(_,_),
    _member \= ';'(_,_),
    replaceDependencyInstruction(_member, _memberExp).
replaceDependencyInstructions(','(_member,_t), ','(_memberExp,_T)) :-
    replaceDependencyInstruction(_member, _memberExp),
    replaceDependencyInstructions(_t, _T).
replaceDependencyInstructions(';'(_member,_t), (';'(_memberExp,_T))) :-
    replaceDependencyInstruction(_member, _memberExp),
    replaceDependencyInstructions(_t, _T).

replaceDependencyInstruction(dependency_analysis(_command),_command):- !.
%    term_to_atom(_command,_atom),
%    format('~n************~n~a~n',_atom).
replaceDependencyInstruction(_command,_command):- !.

bagofT(_a, _b, _c) :- bagof(_a, _b, _c), !.
bagofT(_, _, []).

depend(_sc1, _st1, _sc2, _st2, _restr, _DepType, _DepElem) :-
    % 5.1) w�hle aus der DNF-Formel von ct1 eine Konjunction     O(N)
    semicolon_member((_k1), _sc1),
    bagofT(_m1, (comma_member(_m1, _k1), tree(_m1)), _c1),
    % 5.2) w�hle aus der DNF-Formel von t1 eine Konjunction     O(N)
    semicolon_member((_a1), _st1),
    bagofT(_m3, (comma_member(_m3, _a1), tree_action(_m3)), _t1),
    % 5.3) Sammle alle gesharten Variablen in _c1 (wichtig f�r replace) und alle (variablen) ID's
    collectIDShared(_c1, _t1, _restr, _Ids, _Shared),
    % 5.4) w�hle aus der DNF-Formel von ct2 eine Konjunction     O(M)
    semicolon_member((_k2), _sc2),
    bagofT(_m2, (comma_member(_m2, _k2), tree(_m2)), _c2),
    % 5.5) w�hle aus der DNF-Formel von t2 eine Konjunction     O(N)
    semicolon_member((_a2), _st2),
    bagofT(_m4, (comma_member(_m4, _a2), tree_action(_m4)), _t2),
    % 5.6) Berechne die PostConditions von _c2
    postcond(_c2, _t2, _p2),
    % 5.7) w�hle eine elementare �nderung aus t_2     O(T)
    member(_elemChange, _t2),
    % 5.8) w�hle eine Existenzaussage aus _c1
    member(_DepElem, _c1),
%    debug_(_elemChange,_DepElem),
    % 5.9) Pr�fe ob �nderung Existenzaussage beeinflussen k�nnte
    effect(_elemChange, _DepElem, _DepType, _restr, _Shared,_c1,_p2),
    % 5.10) Pr�fe auf tiefe Gleichheit (Unifikation)
    deep_equal(_DepElem, _c1, _p2, _restr).
    % 5.11) Breche ab sobald die erste Abh�ngigkeit gefunden wurde (f�r ein CT-Paar)
%    !.


debug_(add(methodDefT(_A1,_B1,_C1,_D1,_E1,_F1,_G1)),methodDefT(_A,_B,_C,_D,_E,_F,_G)):-
    debugme.
debug_(_,_).
% Berechne den Effekt einer �nderung auf eine Existenzaussage
effect(add(_a),_x,positive,_restr,_,_l1,_l2)          :- flat_equal(_a,_x,_restr,_l1,_l2).
effect(add(_a),not(_x),negative,_restr,_,_l1,_l2)     :- flat_equal(_a,_x,_restr,_l1,_l2).
effect(delete(_a),not(_x),positive,_restr,_,_l1,_l2)  :- flat_equal(_a,_x,_restr,_l1,_l2).
effect(delete(_a),_x,negative,_restr,_,_l1,_l2)       :- flat_equal(_a,_x,_restr,_l1,_l2).
effect(replace(_a,_b),_x,_t,_restr,_shared,_l1,_l2) :-
    can_unify(_a, _x),
    not(change_doesnt_matter(_a, _b, _x, _shared)),
    effect(delete(_a),_x,_t,_restr,_,_l1,_l2).
effect(replace(_a,_b),_x,_t,_restr,_shared,_l1,_l2) :-
    can_unify(_b, _x),
    % FIX 030319_2: eine positive Abh�ngigkeit sollte in jedem Fall bestehen,
    % da _b ver�ndert wird und somit die durch _x gebundenen Elemente zu anderen
    % Transformationen f�hren (im wesentlichen f�r introduction Aufteilung in
    % interface / code transformer n�tig
    % fix wieder entfernt: eine Abh�ngigkeit soll nur zum execution Advice bestehen (explizit erzeugen)
    not(change_doesnt_matter(_a, _b, _x, _shared)),
    effect(add(_b),_x,_t,_restr,_,_l1,_l2).



change_doesnt_matter(_a, _b, not(_x), _s) :- !, change_doesnt_matter(_a,_b,_x,_s), !.
change_doesnt_matter(_a, _b, _x, _s) :-
    functor(_a, _f, _n),
    functor(_b, _f, _n),
    functor(_x, _f, _n),
    forall(changed_arg(_a,_b,_i), change_on_wildcard(_i, _x, _s)).

changed_arg(_a, _b, _i) :-
    arg(_i,_a,_arga),
    arg(_i,_b,_argb),
    _arga \== _argb.

change_on_wildcard(_i, _x, _s) :-
    arg(_i, _x, _argx),
    var(_argx),
    not(member_save(_argx, _s)).



/************* PostCondition ********************/

post_condition(_pre, _act, _Post) :-
    comma2list(_pre, _prel),
    comma2list(_act, _actl),
    postcond(_prel,_actl,_postl),
    maplist(removeActions,_postl, _postl2),
    flatten(_postl2, _postl3),
    comma2list(_Post,_postl3).

removeActions(add(_elem), _elem):-!.
removeActions(delete(_elem), not(_elem)):-!.
removeActions(replace(_e1,_e2), [not(_e1), _e2]):-!.
removeActions(_x,_x).

%postcond(-conditions:list, -actions:list, +postConditions:list)
postcond(_pre, _act, _Post) :-
    transd(_pre, _act, _preSimple),
    sublist(removeTrueFalse, _preSimple, _preSimple2),
    %maplist(effectl, _act, _actEffekt),
    %flatten(_actEffekt, _actEffekt2),
    append(_act, _preSimple2, _Post).

removeTrueFalse(not(_x)) :- !, removeTrueFalse(_x).
removeTrueFalse(true) :- !, fail.
removeTrueFalse(false) :- !, fail.
removeTrueFalse(_).

effect_tree(add(_a),_a) :- !.
effect_tree(delete(_a),_a) :- !.
effect_tree(replace(_a,_b),_a).
effect_tree(replace(_a,_b),_b) :- !.
effect_tree(_x, _x).


%transd(-conditions:list, -action:list, +simplifiedConditions:list)
transd(_kl, [], _kl) :- !.
transd(_kl, [replace(_a,_b)|_t],_T) :-
    !,
    maplist(transd_(delete(_a)), _kl, _kl2),
    maplist(transd_(add(_b)), _kl2, _kl3),
    transd(_kl3, _t, _T),
    !.
transd(_kl, [_h|_t],_T) :-
    maplist(transd_(_h), _kl, _kl2),
    transd(_kl2, _t, _T),
    !.

% transd(-action:{add(_),delete(_)}, -condition{tree, not(tree)}, +{true, false, tree, not(tree)}
transd_(_act, not(_c), not(_t)) :- !, transd_(_act, _c, _t).
transd_(add(_a), _c, true) :- same_tree(_a, _c), !.
transd_(delete(_a), _c, false) :- same_tree(_a, _c), !.
transd_(_, _c, _c) :- !.

same_tree(not(_tree1), _tree2) :- !,same_tree(_tree1, _tree2).
same_tree(_tree1, not(_tree2)) :- !,same_tree(_tree1, _tree2).
same_tree(_tree1, _tree2) :-
    can_unify(_tree1, _tree2),
    tree_id(_tree1, _id1),
    tree_id(_tree2, _id2),
    _id1 == _id2,
    !.

can_unify(not(_x), _y) :- !, can_unify(_x, _y).
can_unify(_x, not(_y)) :- !, can_unify(_x, _y).
can_unify(_x, _y) :-
    copy_term(_x, _z),
    copy_term(_y, _z).


/************* Gleichheit ********************/

% Flache Gleichheit entspricht Unifikation unter der Einschr�nkung
% dass alle Ungleichheits-Beziehungen / Pattern weiterhin gelten
%flat_equal(not(_tree1), _tree2,_restr) :- flat_equal(_tree1, _tree2,_restr), !.

% bei ge�nderten Elementen wird Negation ignoriert

flat_equal(not(_tree1), add(_tree2),_restr,_l1,_l2) :- flat_equal(_tree1, _tree2,_restr,_l1,_l2), !.
flat_equal(_tree1, add(_tree2),_restr,_l1,_l2) :- flat_equal(_tree1, _tree2,_restr,_l1,_l2), !.
flat_equal(not(_tree1), delete(_tree2),_restr,_l1,_l2) :- flat_equal(_tree1, _tree2,_restr,_l1,_l2), !.
flat_equal(_tree1, delete(_tree2),_restr,_l1,_l2) :- flat_equal(_tree1, _tree2,_restr,_l1,_l2), !.
flat_equal(not(_tree1), replace(_tree2,_),_restr,_l1,_l2) :- flat_equal(_tree1, _tree2,_restr,_l1,_l2), !.
flat_equal(_tree1, replace(_tree2,_),_restr,_l1,_l2) :- flat_equal(_tree1, _tree2,_restr,_l1,_l2), !.
flat_equal(not(_tree1), replace(_,_tree2),_restr,_l1,_l2) :- flat_equal(_tree1, _tree2,_restr,_l1,_l2), !.
flat_equal(_tree1, replace(_,_tree2),_restr,_l1,_l2) :- flat_equal(_tree1, _tree2,_restr,_l1,_l2), !.


%flat_equal(_tree1, _tree2,_restr,_,_) :-
%    flat_equal(_tree1, _tree2,_restr).
% ansonsten
flat_equal(_tree1, _tree2,_restr,_l1,_l2) :-
    tree(_tree1),
    tree(_tree2),
    !,
    _tree1 = _tree2,
    !,
    unification_restrictions(_restr,_l1,_l2).

:- dynamic cached_id/1.
:- dynamic nehypo/0.

% Tiefe Gleichheit entspricht flacher Gleichheit f�r alle erreichbaren Elemente
deep_equal(_startElem, _l1, _l2, _restr) :-
    % l�sche alte Cache Ergebnisse
    retractall(cached_id(_)),
    retractall(nehypo),
    tree_id(_startElem, _id), term_to_atom(_id, _a), assert(cached_id(_a)),
    !,
    % F�r alle ausgehenden Kanten muss die tiefe Gleichheit gelten
    forall(ast_edge(_, _startElem, _eid), deep_equal_(_eid, _l1, _l2, _restr)),
    !.

% Element wurde bereits gepr�ft
deep_equal_(_id, _, _, _) :- term_to_atom(_id,_a), cached_id(_a), !.

% Unifiziere �ber alle gleichen Kanten
deep_equal_(_id, _l1, _l2, _restr) :-
    % in beiden Konjunktionen ist das Element vorhanden
    term_to_atom(_id,_atom_for_debugging),
    exists_tree(_id, _l1, _m1),
    exists_tree(_id, _l2, _m2),
    !,
    % => es muss gleich sein
    flat_equal(_m1,_m2, _restr,_l1,_l2),
    % cache Ergebnis
    term_to_atom(_id,_a), assert(cached_id(_a)),
    % Pr�fe Rekrursiv f�r alle abgehenden Kanten
    forall(ast_edge(_, _m1, _eid), deep_equal_(_eid, _l1, _l2, _restr)).
% Element ist nur in Ungleichheit vorhanden
deep_equal_(_id, _l1, _l2, re(_ne1,_patt1,_parampatt1,_ne2,_patt2,_parampatt2)) :-
    (id_not_equals(_id, _ne1, _Ne1);id_not_equals(_id, _ne2, _Ne2)),
    exists_tree(_id, _l1, _m1),
    exists_tree(_id, _l2, _m2),
    flat_equal(_m1,_m2,re(_Ne1,_patt1,_parampatt1,_Ne2,_patt2,_parampatt2),_l1,_l2),
    !,
    fail.
% Element ist keiner der beiden AST's vorhanden
deep_equal_(_id, _, _,_) :- term_to_atom(_id,_a), assert(cached_id(_a)), !.

%:- dynamic ne_hypo/0.

id_not_equals(_, [], []) :- !, fail.
id_not_equals(_id, [_h|_t], _t) :-
    _h = '\\='(_idx, _idy),
%    member('\\='(_idx, _idy), _ne),
    ((_id == _idx);(_id == _idy)),
    _idx = _idy,
    !.
%    assert(ne_hypo),
%    id_not_equals(_id,_t,_T).
id_not_equals(_id, [_h|_t], [_h|_T]) :-
    id_not_equals(_id,_t,_T).


exists_tree(_id, _l, _Tree) :-
    member(_Tree, _l),
%    effect_tree(_tree, _Tree),
    tree_id(_Tree, _idx),
    _idx == _id.



/**************************************************************************
 * Einige Testdaten
 */
 
% Einige Tests f�r Deep Equal
% Direkt Match
test('de#0') :- deep_equal(fieldDefT(_v,C,_,_,_),(classDefT(C,_,x,_)),(classDefT(C,_,x,_)),_).
test('de#1') :- deep_equal(fieldDefT(_v,C,_,_,_),(not(classDefT(C,_,x,_))),(not(classDefT(C,_,x,_))),_).
% Direkt Non-Match

%FIXME:
%test('de#2') :- not(deep_equal(fieldDefT(_v,C,_,_,_),(classDefT(C,_,x,_)),(classDefT(C,_,y,_)),_)).
%test('de#3') :- not(deep_equal(fieldDefT(_v,C,_,_,_),(not(classDefT(C,_,x,_))),(classDefT(C,_,x,_)),_)).
%test('de#4') :- not(deep_equal(fieldDefT(_v,C,_,_,_),(classDefT(C,_,x,_)),(not(classDefT(C,_,x,_))),_)).
% Match against Empty AST
test('de#5') :- deep_equal(fieldDefT(_v,C,_,_,_),(classDefT(C,_,x,_)),(true),_).
test('de#6') :- deep_equal(fieldDefT(_v,C,_,_,_),(true),(classDefT(C,_,x,_)),_).
test('de#7') :- deep_equal(fieldDefT(_v,C,_,_,_),(classDefT(C,P1,x,_), packageT(P1,p1)),(classDefT(C,_,x,_)),_).
test('de#8') :- deep_equal(fieldDefT(_v,C,_,_,_),(classDefT(C,_,x,_)),(classDefT(C,P1,x,_), packageT(P1,p1)),_).
% Transitive Match
%FIXME
%test('de#9') :- not(deep_equal(fieldDefT(_v,C,_,_,_),(classDefT(C,P1,x,_), packageT(P1,p1)),(classDefT(C,P2,x,_), packageT(P2,p2)),_)).
% Match two edges (instead of one as above)
%test('de#10'):- not(deep_equal(fieldDefT(_v,C,_,_,I),(classDefT(C,_,x,_), identT(I,_,_,a,_v)),(classDefT(C,_,x,_), identT(I,_,_,b,_v)),_)).
% Cycle Match
test('de#11'):- deep_equal(fieldDefT(_v,C,_,_,_),(fieldDefT(_v,C,_,_,_), classDefT(C,_,x,[_v])),(fieldDefT(_v,C,_,_,_), classDefT(C,_,x,[_v])),_).


/*****************************************************************
 * Graph Sicht auf Programmelemente (unabh�ngig von Faktenbasis)
 *****************************************************************/

tree(_tree)                         :- ast_node(_,_tree,_).

%tree_edge(_type,_elem,_eid)         :- ast_edge(_type,_elem,_eid).

tree_id(not(_tree), _id)            :- ast_node(_,_tree,_id), !.
tree_id(add(_tree), _id)            :- ast_node(_,_tree,_id), !.
tree_id(delete(_tree), _id)         :- ast_node(_,_tree,_id), !.
tree_id(replace(_tree,_), _id)      :- ast_node(_,_tree,_id), !.
tree_id(replace(_,_tree), _id)      :- ast_node(_,_tree,_id), !.
tree_id(_tree, _id)                 :- ast_node(_,_tree,_id), !.

/******************************************************************************
 * Expandieren von Abstraktionen
 *****************************************************************************/
 

:- multifile abstraction/1.
:- multifile specialisation/2.
:- multifile tree/1.
:- multifile tree_id/2.
:- multifile test/1.


expandAbstractionsAndDNF(_c1, _c2, _t2, _c1dnf, _c2dnf, _t2) :-
    % 4.1) Filtern aller nicht-Programmelemente und Expandieren der Abstraktionen
    expandConditions(_c1, _c1e),
%    noch nicht implementiert:
%    _c1 = _cte,
    dnf(_c1e, _c1dnf),
    % 4.2) Filtern aller nicht-Programmelemente und Expandieren der Abstraktionen
    expandConditions(_c2, _c2e),
%    noch nicht implementiert:
%    _c2 = _c2e,
    dnf(_c2e, _c2dnf),
    % 4.3) _t2e ist automatisch in dnf, da _t2 eine reine Konjunktion sein muss
%    expandActions(_t2, _t2dnf),
    !.

% todo: formt eine Bedingung in DNF um
%dnf(_c,_c).

% CT kann (muss nicht) in DNF sein.
expandCT(_ct, _Cexp, _Texp) :-
    ct(_ct, _c, _t),
    expandConditions(_c, _Cexp),
    expandActions(_t, _Texp).

% Grundidee: Folge von Regeln, die eine Abstraktion beschreiben, wird umgefprmt in einen logischen Ausdruck mit Konjunktion und Disjunktion. Alles was nicht Teil des Alphabets (tree/1) und nicht als Abstraktion markiert ist (abstraktion/1) wird ignoriert.
expandConditions(_member, (_memberExp)) :-
    _member \= ','(_,_),
    _member \= ';'(_,_),
    expandCondition(_member, _memberExp).
expandConditions(','(_member,_t), _Expanded) :-
    expandCondition(_member, _memberExp),
    expandConditions(_t, _T),
    emptyCheck(_memberExp,_T,','(_memberExp,_T),_Expanded).
    

% _Expand umschlie�en mit ( ) ?
expandConditions(';'(_member,_t), _Expanded) :-
    expandCondition(_member, _memberExp),
    expandConditions(_t, _T),
    emptyCheck(_memberExp,_T,';'(_memberExp,_T),_Expanded).

expandCondition(_konjunction, (_Disjunction)) :-
    bagofT(_kexp, expandCondition_(_konjunction, _kexp), _l),
    semicolon2list(_Disjunction, _l).


%expandCondition_(not(_term), not(_T)) :-
%    not(tree(_term)),
%    abstraction(_term,_abstraction),
%    expandCondition_(_abstraction, _T).
    
expandCondition_(_term, _T) :-
%    not(tree(_term)),
    unfoldAbstraction(_term,_abstraction),
    !,
%    clause(_term,_abstraction),
    _abstraction \= not(_),
    % wenn es eine regel f�r diese abstraktion gibt
%    clause(_abstraction, _body),
    % ersetze die abstraktion durch ihren expandierten body
%    expandConditions(_body, _T).
    _abstraction = _T.
%   TODO: endless loop:
%    expandConditions(_abstraction, _T).

expandCondition_(_term,_term) :-
%    not(unfoldable(_term)),
    tree(_term),
    !.

expandCondition_(_term, empty) :- % l�sche elemente die weder abstraktion noch tree sind
%    not(tree(_term)),
%    not(unfoldable(_term)),
    _term \= not(_),
    !.

expandCondition_(not(_abstraction), _ExpandedAbstraction) :- % l�sche elemente die weder abstraktion noch tree sind
    expandCondition_(_abstraction, _expandedAbstraction),
    emptyCheck(_expandedAbstraction, _expandedAbstraction,not(_expandedAbstraction),_ExpandedAbstraction).
    

emptyCheck(empty,empty,_, empty):-!.
emptyCheck(empty,_2,_, _2):-!.
emptyCheck(_1,empty,_, _1):-!.
emptyCheck(_,_,_3, _3).



expandActions(_konjunction, _Konjunction) :-
    bagofT(_kexp, expandActions_(_konjunction, _kexp), _l),
    semicolon2list(_Konjunction, _l). % be carefull with multiple solutions

expandActions_(_member, _memberExp) :-
    _member \= ','(_,_),
    expandAction_(_member, _memberExp).
expandActions_(','(_member,_t), (_memberExp,_T)) :-
    expandAction_(_member, _memberExp),
    expandActions_(_t, _T).

expandAction_(_abstraction, _abstraction) :-
    tree_action(_abstraction).
expandAction_(_abstraction, _T) :-
    not(tree_action(_abstraction)),
    abstract_action(_abstraction),
    clause(_abstraction, _body),
    expandActions_(_body, _T).
expandAction_(_abstraction, empty) :-
    not(tree_action(_abstraction)),
    abstract_action(_abstraction),
    not(clause(_abstraction, _body)).
expandAction_(_abstraction, empty) :-
    not(tree_action(_abstraction)),
    not(abstract_action(_abstraction)).

abstract_action(add(_)).
abstract_action(delete(_)).
abstract_action(replace(_,_)).
abstract_action(empty).
tree_action(add(_tree)) :- tree(_tree).
tree_action(delete(_tree)) :- tree(_tree).
tree_action(replace(_tree1,_tree2)) :- tree_action(delete(_tree1)), tree_action(add(_tree2)).
tree_action(empty).


/*************************************************************
 * Einige Tests
 */

   /*
abstraction(s).
s :- b, not(u).
s :- a, c.
abstraction(c).
c :- d.
abstraction(u).
u :- b, d.

tree(a).
tree(b).
tree(c).
tree_id(a,a).
tree_id(b,b).
tree_id(c,c).

add(s) :- add(c), add(u).



test('exp#2') :- expandConditions( (b;s),(b;( (b, not((b, true)));(a, c)))).
test('exp#3') :- expandConditions( (a;u),(a;(b, true))).
%test('exp#1') :- expandCT(expand1, (a, (not((b, not((b, true))));not((a, c)))), (add(c), empty)).
     */

collectIDShared(_cl, _tl, re(_ne1,_p1,_pp1,_,_,_),_Ids, _Shared) :-
    append(_cl, _tl, _l),
    append(_l, _ne1, _l2),
    append(_l2, _p1, _l3),
    append(_l3, _pp1,_l4),
    !,
    collectIDShared_(_l4, [], _ids, _shared),
    list_to_set_save(_ids, _Ids),
    list_to_set_save(_shared, _Shared),
    !.

tree_arg(add(_tree), _arg) :- tree_arg(_tree, _arg).
tree_arg(delete(_tree), _arg) :- tree_arg(_tree, _arg).
tree_arg(replace(_tree1,_), _arg) :- tree_arg(_tree1, _arg).
tree_arg(replace(_,_tree2), _arg) :- tree_arg(_tree2, _arg).
tree_arg(not(_tree), _arg) :- tree_arg(_tree, _arg).
tree_arg(_tree, _arg) :-
    _tree \= not(_),
    _tree \= add(_),
    _tree \= delete(_),
    _tree \= replace(_,_),
% uwe : 28.01.03   %tree(_tree),
    arg(_i, _tree, _arg).

collectIDShared_([],_,[],[]).

collectIDShared_([_h|_t], _all, _T1, _T2) :-
    % if elem is no tree, continue
    bagofT(_arg, tree_arg(_h,_arg), _args),
    _args == [],
    !,
    collectIDShared_(_t, _all, _T1, _T2).
    
collectIDShared_([_h|_t], _all, [_id|_T1], _T2) :-
    % else, if tree first arg is id
    bagofT(_arg, tree_arg(_h,_arg), [_id|_args]),
    % mark as already
    append(_all, [_id|_args], _all2),
    % collect all new args, that are already seen
    bagofT(_s, (member(_s, [_id|_args]), member_save(_s, _all)), _shared),
    % continue with rest of list
    collectIDShared_(_t, _all2, _T1, _shared2),
    % collect shared variables
    append(_shared2, _shared,_T2).

% WICHTIG: Nach DND-Normalisierung
extractRestrictions(_c1, _c2, re(_ne1,_patt1,_parampatt1,_ne2,_patt2,_parampatt2) ) :-
    extrRest(_c1, _ne1x, _patt1x, _parampatt1x),
    extrRest(_c2, _ne2x, _patt2x, _parampatt2x),
    sublist(nonnull, _ne1x, _ne1),
    sublist(nonnull, _ne2x, _ne2),
    sublist(nonnull, _patt1x, _patt1),
    sublist(nonnull, _patt2x, _patt2),
    sublist(nonnull, _parampatt1x, _parampatt1),
    sublist(nonnull, _parampatt2x, _parampatt2),
    !.

nonnull(_x) :- _x \= null.

%:- [ct_filter].

%unification_restrictions(_) :- !.
unification_restrictions( re(_ne1,_patt1,_parampatt1,_ne2,_patt2,_parampatt2),_l1,_l2) :-
        checkInequalities(_ne1),
        checkInequalities(_ne2),
        checkPattern(_patt1, _patt2),
        checkParamPattern(_parampatt1, _parampatt2,_l1,_l2).

extrRest(_member, [_ne],[_patt],[_parampatt]) :-
    _member \= ','(_,_),
    _member \= ';'(_,_),
    mappatt(_member, _patt),
    mapparampatt(_member, _parampatt),
    mapne(_member, _ne).
extrRest(','(_member,_t), [_ne|_T1], [_patt|_T2],[_parampatt|_T3]) :-
    mapne(_member, _ne),
    mappatt(_member, _patt),
    mapparampatt(_member,_parampatt),
    extrRest(_t, _T1, _T2,_T3).
extrRest(';'(_member,_t), [_ne|_T1], [_patt|_T2],[_parampatt|_T3]) :-
    mapne(_member, _ne),
    mappatt(_member, _patt),
    mapparampatt(_member,_parampatt),
    extrRest(_t, _T1, _T2,_T3).

mappatt(not(pattern(A,B,C)),not(pattern(A,B,C))) :- !.
mappatt(pattern(A,B,C),pattern(A,B,C)) :- !.
mappatt(_m,null).

mapparampatt(matchParams(A,B),matchParams(A,B)):-!.
mapparampatt(not(matchParams(A,B)),not(matchParams(A,B))):-!.
mapparampatt(_m,null).


mapne('\\='(A,B), '\\='(A,B)) :- !.
mapne('='(A,B), null) :- A=B, !.
mapne(_m,null).

get_ct_order(_ct_order) :-
    ct_order(_ct_order),
    !.
get_ct_order([]).


test(mp1):-
    assert(ct(c1,
    (
        classDefT(_cid1,_,'classname',_),
        methodDefT(_elemId1, _, _elemName1, _params1, _, _, _),
        matchParams(_params1 , [
            type(class,_cid1,1),
             typePattern('oth*',0),
             typePattern('patter*',3),
             '..'
           ])
        ),(
            add(selectT(_1, _, _, _elemName1, _, _elemId1))
        ))
    ),
    assert(ct(c2,
        (
        classDefT(_cid2,_,'classname',_),
        classDefT(_cid3,_,'other',_),
        methodDefT(_elemId2, _, _elemName2, _params2, _, _, _),
        matchParams(_params2 , [
            type(class,_cid2,1),
            type(class,_cid3,0),
             typePattern('pat*',3),
             '..'
           ]),
           selectT(_2, _, _, _, _, _elemId2)
        ),(
            empty
        ))
    ),
    gen_dep_graph('ct_graph_test.pl',[c2,c1]),
    retractall(ct(c1,_,_)),
    retractall(ct(c2,_,_)),
    del_dep_graph.
/*
test(mp2):-
    assert(ct(c1,
    (
        classDefT(_cid1,_,'classname',_),
        new_ids([_elemId1,_p1,_p2])
        ),(
            add(methodDefT(_elemId1, _, _elemName1, [_p1,_p2], _, _, _)),
            add(paramDefT(_p1, _elemId1_, type(class, _cid1,_),'name1')),
            add(paramDefT(_p2, _elemId1_, type(class, _cid1,_),'name2')),
            add(selectT(_1, _, _, _elemName1, _, _elemId1))
        ))
    ),
    assert(ct(c2,
        (
        classDefT(_cid2,_,'classname',_),
        classDefT(_cid3,_,'other',_),
        methodDefT(_elemId2, _, _elemName2, _params2, _, _, _),
        matchParams(_params2 , [
            type(class,_cid2,1),
%            type(class,_cid3,0),
%             typePattern('pat*',3),
             '..'
           ]),
           selectT(_2, _, _, _, _, _elemId2)
        ),(
            empty
        ))
    ),
    gen_dep_graph('ct_graph_test.pl',[c2,c1]),
    retractall(ct(c1,_,_)),
    retractall(ct(c2,_,_)),
    del_dep_graph.
*/

% expand condition
test(ec1):-
    expandCondition_(methodCall(_1,_2,_3,_4,_5,_6,_7),_out),
    term_to_atom(_out,_a),
    write(_a).

ajdg :-
    aj_ct_list(_aj_ct_list),
    gen_dep_graph('ct_graph.pl', _aj_ct_list),
    del_dep_graph.

dg(_list) :-
    gen_dep_graph('ct_graph.pl', _list),
    del_dep_graph.


% specialisations are special abstractions,
% that have the same id as an contained element
% and cannot exist without this element
%abstraction(_x,_y) :- specialisation(_x,_y).

unfoldable(_x):-
    abstraction(_x),
    !.
unfoldable(_x):-
    specialisation(_x,_).


unfoldAbstraction(_term,_abstraction) :-
    specialisation(_term,_abstraction),
%    print(',special:  '),
%    term_to_atom(_term,_atom),
%    print(_atom),
%    print(' -> '),
%    term_to_atom(_abstraction,_atom2),
%    print(_atom2),
    !.

unfoldAbstraction(_term,_abstraction) :-
    abstraction(_term),
%    format('~nabstr: '),
%    term_to_atom(_term,_atom),
%    print(_atom),
%    print(' -> '),
    clause(_term,_abstraction).
%    term_to_atom(_abstraction,_atom2),
%    print(_atom2).



%abstraction(field(_ID, _PID, _Type, _Name, _Init),field(_ID, _PID, _Type, _Name, _Init)).
specialisation(methodCall(_id, _pid, _encl, _recv, Name, _method, _args),
        applyT(_id, _pid, _encl, _recv, Name, _args,_method)).

specialisation(getField(_id, _pid, _encl, _recv, _field),
        getFieldT(_id, _pid, _encl, _recv,_, _field)).

specialisation(setField(_id, _pid, _encl, Recv, _field, _value),
    (assignT(_id, _pid, _encl, _identSelect, _value),
     getFieldT(_identSelect,_id,_encl,Recv,_,_field))).

specialisation(resolve_field(_type, _name, _field), fieldDefT(_field,_,_,_name,_)).
specialisation(resolve_method(_type, _name, _,_method), methodDefT(_method,_,_name,_,_,_,_)).


