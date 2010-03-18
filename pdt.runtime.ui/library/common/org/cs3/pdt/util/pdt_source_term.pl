%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This file is part of the Prolog Development Tool (PDT)
% 
% Author: Lukas Degener (among others) 
% E-mail: degenerl@cs.uni-bonn.de
% WWW: http://roots.iai.uni-bonn.de/research/pdt 
% Copyright (C): 2004-2006, CS Dept. III, University of Bonn
% 
% All rights reserved. This program is  made available under the terms 
% of the Eclipse Public License v1.0 which accompanies this distribution, 
% and is available at http://www.eclipse.org/legal/epl-v10.html
% 
% In addition, you may at your option use, modify and redistribute any
% part of this program under the terms of the GNU Lesser General Public
% License (LGPL), version 2.1 or, at your option, any later version of the
% same license, as long as
% 
% 1) The program part in question does not depend, either directly or
%   indirectly, on parts of the Eclipse framework and
%   
% 2) the program part in question does not include files that contain or
%   are derived from third-party work and are therefor covered by special
%   license agreements.
%   
% You should have received a copy of the GNU Lesser General Public License
% along with this program; if not, write to the Free Software Foundation,
% Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
%   
% ad 1: A program part is said to "depend, either directly or indirectly,
%   on parts of the Eclipse framework", if it cannot be compiled or cannot
%   be run without the help or presence of some part of the Eclipse
%   framework. All java classes in packages containing the "pdt" package
%   fragment in their name fall into this category.
%   
% ad 2: "Third-party code" means any code that was originaly written as
%   part of a project other than the PDT. Files that contain or are based on
%   such code contain a notice telling you so, and telling you the
%   particular conditions under which they may be used, modified and/or
%   distributed.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

/*********
it is assumed that
 - a source term represents a piece of source code that would be parsed into a prolog term. 
   It typically has a well-defined location (e.g. given as character 
   offsets) within a source file. 
 - Arbitrary application data can be attached to subterms.
 - source terms are datastructures representing a "working copy" of the actual information stored somewhere on heap.
 - source terms carry enough information to identify the source file to which they belong aswell as their position
   relative to the other terms in this file.
 - source terms live on the stack. All operations on source terms are non-destructive.
 - source terms can be stored or "commited" on the heap and associated with a given source file.
 - it is possible to iterate all source terms that were stored for a given file.
 - it is possible to compare two source terms within a file by order of occurance in the containing file. 
   this order is expected to be transitive. Both of the following conditions hold:
   + a parent term preceeds all its subterms. (pre-fix ordering of subterms)
   + a term is preceeded by all subterms of its left sibblings (order by occurance)

A typical life cycle of a source term would look like this:
 - the term is checked out from some heap data structure. 
 - the term is modified, i.e properties are added, the structure is modified, ...
 - the term is commited back to the heap.



*********/
:- module(pdt_source_term,[
	source_term/2,
	source_term_var/1,
	source_term_arg/3,
	source_term_expand/2,
	source_term_functor/3,
	source_term_property/3,
	source_term_set_property/4,
	source_term_copy_properties/3,
	source_term_create/3,
	source_term_unifiable/3,
	implements_source_term/0,
	source_term_subterm/3,
	source_term_all_properties/2,
	source_term_member/3
/*	source_term_update/2,
	source_term_commit/2,
	source_term_checkout/2*/
]).


:- dynamic source_term_hook/2.
:- multifile source_term_hook/2.


:-module_transparent implements_source_term/0.
:-multifile implements_source_term/0.

implements_source_term:-
	dynamic 	
		source_term_var_hook/1,
		source_term_arg_hook/3,
		source_term_expand_hook/2,
		source_term_functor_hook/3,
		source_term_property_hook/3,
		source_term_set_property_hook/4,
		source_term_copy_properties_hook/3,
		source_term_create_hook/2,
		source_term_all_properties_hook/2.
:-implements_source_term.

%% source_term(+SourceTerm,-Module)  
% Check if there is an Implementation for the given source term.
%
% This calls souce_term_hook/2 to find a module that contains the necessary hook clauses
% to handle this source term. It should NOT be used to create source terms. See source_term_create/3.
source_term(SourceTerm,Module):-
    source_term_hook(SourceTerm,Module),
    !.
source_term(_,pdt_source_term).


%% source_term_var(?Sourceterm)
% succeeds if SourceTerm is a source term that represents a variable.
source_term_var(SourceTerm):-
    source_term(SourceTerm,Module),    
    Module:source_term_var_hook(SourceTerm),
    !.
source_term_var(SourceTerm):-
    var(SourceTerm).
%% source_term_create(+Module,?Term,-SourceTerm)  
% creates a new source term.
% Uses the implementation in Module to create a new SourceTerm. 
% Whether or not any annotations are initially added to the (sub-) term(s) is 
% completely up to the implementation.

source_term_create(Module,Term,SourceTerm):-
    Module:source_term_create_hook(Term,SourceTerm),
    !.
source_term_create(_,Term,Term).



%% source_term_expand(+SourceTerm, -Term) 
% Expand source term
%
% unify the second argument with the plain prolog term represented by this source term.
source_term_expand(SourceTerm,Term):-
    source_term(SourceTerm,Module),    
    Module:source_term_expand_hook(SourceTerm,Term),
    !.
    
source_term_expand(Term,Term).



%% source_term_functor(+SourceTerm, ?Name,?Arity) 
% access the principal functor of a source term.
% This works much as functor/3. If SourceTerm is a source term representing a variable,
% and if Name and Arity are ground, SourceTerm will become a source term representing a term with
% the given name and arity. Note however that this source term is incomplete, as its arguments are not specified.
source_term_functor(SourceTerm,Name,Arity):-
    source_term(SourceTerm,Module),
    Module:source_term_functor_hook(SourceTerm,Name,Arity),
    !.
source_term_functor(SourceTerm,Name,Arity):-
    functor(SourceTerm,Name,Arity).

%% source_term_arg(?ArgNum, +SourceTerm, ?ArgValue) 
% like arg/3, only that second and third arguments are source terms.
% Similar to arg/3 this predicate can be used to construct source terms:
% If the ArgNum-th argument of SourceTerm was not yet specified, and ArgValue is bound to a
% source term, then ArgValue will in fact become the ArgNum-th argument of SourceTerm.

source_term_arg(ArgNum,SourceTerm,ArgVal):-
    source_term(SourceTerm,Module),
    Module:source_term_arg_hook(ArgNum,SourceTerm,ArgVal),
    !.
source_term_arg(ArgNum,SourceTerm,ArgVal):-
    arg(ArgNum,SourceTerm,ArgVal).
    

%% source_term_property(+SourceTerm, +Key, -Value) 
% access term annotation.
source_term_property(SourceTerm,Key,Property):-
    source_term(SourceTerm,Module),
    Module:source_term_property_hook(SourceTerm,Key,Property),
    !.



%% source_term_set_property(+SourceTerm, +Key, -Value, -NewSourceTerm) 
% modify term annotation.
source_term_set_property(SourceTerm,Key,Value,NewSourceTerm):-
    source_term(SourceTerm,Module),
    Module:source_term_set_property_hook(SourceTerm,Key,Value,NewSourceTerm),
    !.

%% source_term_copy_properties
% copy term annotations.
% this copies all properties of source term In to source term Out, overwriting any conflicting 
% properties in Out.
source_term_copy_properties(From,To,Out):-
    source_term(From,Module),
    source_term(To,Module),
    Module:source_term_copy_properties_hook(From,To,Out),
    !.
source_term_copy_properties(_From,To,To).

source_term_unifiable(A,B,Unifier):-
	source_term_expand(A,AA),
	source_term_expand(B,BB),
	unifiable(AA,BB,Unifier).


%% source_term_subterm(+Term,+Path,?Subterm).
%
%succeeds if Term is a term or an annotated term and Path is a list of integers
%such that if each element of Path is interpreted as an argument position, Path induces a
%path from Term to the (plain or annotated) sub term SubTerm.
source_term_subterm(Term,[], Term). %Do NOT cut this clause!!!
source_term_subterm(Term,[ArgNum|ArgNums],SubTerm):-
	source_term_compound(Term),
	source_term_arg(ArgNum,Term,ArgVal),
	source_term_subterm(ArgVal,ArgNums,SubTerm).


source_term_compound(Term):-
    \+ source_term_var(Term),
    source_term_functor(Term,_,Arity),
    Arity>0.

%% source_term_all_properties(+Term,-Props)
%
% unifies Props with Terms property list
% @deprecated only here to support legacy code. Will be removed until 0.2.
source_term_all_properties(SourceTerm,Props):-
    source_term(SourceTerm,Module),
    Module:source_term_all_properties_hook(SourceTerm,Props),
    !.
    
    
match_elms(List,[1],Elm):-
    source_term_subterm(List,[1],Elm).
%match_elms(List,[2],Elm):-
%    pdt_aterm_subterm(List,[2],Elm).
match_elms(List,[2|T],Elm):-
    source_term_subterm(List,[2],Elms),
    match_elms(Elms,T,Elm).
    	

match_operand(Operator,ATerm,[],ATerm):-
    \+ source_term_functor(ATerm,Operator),
    !.
match_operand(_Operator,ATerm,[1],Elm):-    
    source_term_subterm(ATerm,[1],Elm).
match_operand(Operator,ATerm,[2|T],Elm):-
    source_term_subterm(ATerm,[2],Elms),
    match_operand(Operator,Elms,T,Elm).

%% pdt_aterm_member(+List,?Path,?Elm)
% succeeds if Elm is a member of the annotated list List.
%
% @param List an annotated list term.
% @param Path subterm path. See pdt_aterm_subterm/3.
% @param Elm an annotated element of List.
%
source_term_member(List,Path, Elm):-
    match_elms(List,Path,Elm).


source_term_operand(Operator,List,Path, Elm):-
    match_operand(Operator,List,Path,Elm).

    