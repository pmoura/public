%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This file is part of the Prolog Development Tool (PDT) for Eclipse
% http://roots.iai.uni-bonn.de/research/pdt
%
% Authors: G�nter Kniesel, Paulo Moura (May 2011)
%          partly based on PDT code by Tobias Rho
%
% All rights reserved. This program is  made available under the terms
% of the Eclipse Public License v1.0 which accompanies this distribution,
% and is available at http://www.eclipse.org/legal/epl-v10.html
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

:- object(logtalk_editor_adapter).

:- uses(list, [
	length/2, member/2, memberchk/2, selectchk/3
]).
:- uses(numberlist, [
	sum/2
]).
:- uses(utils4entities, [
	source_file_entity/3, entity/1, entity_property/3
]).

:- public(predicates_with_property/3).

%% predicates_with_property(+Property,+FileName,-Predicates) is det.

%predicates_with_property(Property, FileName, Predicates) :-
predicates_with_property(Property, FileName, Predicates) :-
	setof(
		Name,
		Property^predicate_with_property(Property, FileName, Name),
		Predicates
	).

:- private(predicate_with_property/3).

%predicate_with_property(built_in, _FileName, Name) :-
%	user::current_predicate(Name/Arity),
%	functor(Head, Name, Arity),
%	user::predicate_property(Head, iso).
%
predicate_with_property(built_in, _FileName, Name) :-
	help::completion('', Name/_Arity-_HelpFile).

predicate_with_property(Property, _FileName, Name) :-
	(	Property = (dynamic)
	;	Property = meta_predicate(_)
	),
	help::completion('', Name/Arity-_HelpFile),
	functor(Head, Name, Arity),
	catch(logtalk<<predicate_property(Head, Property),_,fail).

:- end_object.
