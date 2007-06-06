:- module(pef_base,[pef_reserve_id/2, pef_type/2]).

:- use_module(library('org/cs3/pdt/util/pdt_util_context')).	
:- dynamic pef_pred/2.
:- dynamic pef_type/2.

define_assert(Template):-
    functor(Template,Name,_),
    atom_concat(Name,'_assert',HeadName),
    functor(Head,HeadName,1),
    arg(1,Head,List),
    atom_concat(Name,'_get',GetterName),
    functor(Getter,GetterName,2),
    arg(1,Getter,Cx),
    arg(2,Getter,List),
    atom_concat(Name,'_new',ConstructorName),
    functor(Constructor,ConstructorName,1),
    arg(1,Constructor,Cx),
    assert((Head:-Constructor,Getter,assert(Cx)),Ref),
    assert(pef_pred(Name,Ref)),
    export(Head).

define_query(Template):-
    functor(Template,Name,_),
    atom_concat(Name,'_query',HeadName),
    functor(Head,HeadName,1),
    arg(1,Head,List),
    atom_concat(Name,'_get',GetterName),
    functor(Getter,GetterName,2),
    arg(1,Getter,Cx),
    arg(2,Getter,List),
    atom_concat(Name,'_new',ConstructorName),
    functor(Constructor,ConstructorName,1),
    arg(1,Constructor,Cx),
    assert((Head:-Constructor,Getter,call(Cx)),Ref),
    assert(pef_pred(Name,Ref)),
    export(Head).

define_query2(Template):-
    functor(Template,Name,_),
    atom_concat(Name,'_query',HeadName),
    functor(Head,HeadName,2),
    arg(1,Head,List),
    arg(2,Head,Cx),
    atom_concat(Name,'_get',GetterName),
    functor(Getter,GetterName,2),
    arg(1,Getter,Cx),
    arg(2,Getter,List),
    atom_concat(Name,'_new',ConstructorName),
    functor(Constructor,ConstructorName,1),
    arg(1,Constructor,Cx),
    assert((Head:-Constructor,Getter,call(Cx)),Ref),
    assert(pef_pred(Name,Ref)),
    export(Head).


define_retractall(Template):-
    functor(Template,Name,_),
    atom_concat(Name,'_retractall',HeadName),
    functor(Head,HeadName,1),
    arg(1,Head,List),
    atom_concat(Name,'_get',GetterName),
    functor(Getter,GetterName,2),
    arg(1,Getter,Cx),
    arg(2,Getter,List),
    atom_concat(Name,'_new',ConstructorName),
    functor(Constructor,ConstructorName,1),
    arg(1,Constructor,Cx),
    assert((Head:-Constructor,Getter,retractall(Cx)),Ref),
    assert(pef_pred(Name,Ref)),
    export(Head).

define_recorda(Template):-
    functor(Template,Name,_),
    atom_concat(Name,'_recorda',HeadName),
    functor(Head,HeadName,3),
    arg(1,Head,Key),
    arg(2,Head,List),
    arg(3,Head,Ref),    
    atom_concat(Name,'_get',GetterName),
    functor(Getter,GetterName,2),
    arg(1,Getter,Cx),
    arg(2,Getter,List),
    atom_concat(Name,'_new',ConstructorName),
    functor(Constructor,ConstructorName,1),
    arg(1,Constructor,Cx),
    assert((Head:-Constructor,Getter,recorda(Key,Cx,Ref)),PefRef),
    assert(pef_pred(Name,PefRef)),    
    export(Head).

define_recordz(Template):-
    functor(Template,Name,_),
    atom_concat(Name,'_recordz',HeadName),
    functor(Head,HeadName,3),
    arg(1,Head,Key),
    arg(2,Head,List),
    arg(3,Head,Ref),    
    atom_concat(Name,'_get',GetterName),
    functor(Getter,GetterName,2),
    arg(1,Getter,Cx),
    arg(2,Getter,List),
    atom_concat(Name,'_new',ConstructorName),
    functor(Constructor,ConstructorName,1),
    arg(1,Constructor,Cx),
    assert((Head:-Constructor,Getter,recordz(Key,Cx,Ref)),PefRef),
    assert(pef_pred(Name,PefRef)),
    export(Head).

define_recorded(Template):-
    functor(Template,Name,_),
    atom_concat(Name,'_recorded',HeadName),
    functor(Head,HeadName,3),
    arg(1,Head,Key),
    arg(2,Head,List),
    arg(3,Head,Ref),    
    atom_concat(Name,'_get',GetterName),
    functor(Getter,GetterName,2),
    arg(1,Getter,Cx),
    arg(2,Getter,List),
    atom_concat(Name,'_new',ConstructorName),
    functor(Constructor,ConstructorName,1),
    arg(1,Constructor,Cx),
    assert((Head:-Constructor,Getter,recorded(Key,Cx,Ref)),PefRef),
    assert(pef_pred(Name,PefRef)),
    export(Head).



%%
% define_pef(+Template).
%
% define a new PEF type.
% Suppose template is foo(bar,baz).
% Then this call will generate and export predicates foo_assert(+List), foo_retractall(+List)
% and foo_query(+List), where List is a list of key=Value pairs.
% E.g. you can use foo_query([bar=bang,baz=V]), for retreiveing the baz of all foos with 
% a bar of bang.
% @param Template should be a ground compound term like in pdt_define_context/1.

define_pef(Template):-
    functor(Template,Name,Arity),
    undefine_pef(Name),
    dynamic(Name/Arity),
	pdt_define_context(Template),	
	pdt_export_context(Name),
    define_assert(Template),
    define_retractall(Template),
    define_query(Template),
    define_query2(Template),
    define_recorded(Template),
    define_recorda(Template),
    define_recordz(Template).

undefine_pef(Name):-
    forall(pef_pred(Name,Ref),erase(Ref)),
    retractall(pef_pred(Name,_)).

pef_reserve_id(Type,Id):-
    flag(pef_next_id,Id,Id + 1),
    assert(pef_type(Id,Type)). 

% A module definition. Also represents the defined module.
:- define_pef(pef_module_definition(id,name,file_ref,toplevel_ref)).

% An operator definition. 
:- define_pef(pef_op_definition(id,priority,type,name,file_ref,toplevel_ref)).

% A file dependency definition. Also represents the defined dependency.
:- define_pef(pef_file_dependency(id,file_ref,dep_ref,toplevel_ref)).

% A named property of any pef. Id is the PEFs Id. The property itself is a weak entity,
% it does not have an Id of its own.
:- define_pef(pef_property(id,key,value)).

% TODO
:- define_pef(pef_problem(id,severity,file_ref,start,end,type,data)).

% A parsed toplevel term. 
:- define_pef(pef_toplevel(file_ref,term,expanded,positions,varnames,singletons)).

% An AST node representing a non-var program term.
:- define_pef(pef_term(id,name,arity)).

% An AST node representing a program variable occurence.
:- define_pef(pef_variable_occurance(id,variable_ref)).

% A program variable.
:- define_pef(pef_variable(id,toplevel_ref)).

% The relation between a compound term and its arguments.
:- define_pef(pef_arg(num,parent,child)).

% The relation between a toplevel record and the root of corresponding AST.
:- define_pef(pef_toplevel_root(root,toplevel_ref,file_ref)).

% A recorded file.
:- define_pef(pef_file(file_ref,toplevel_key)).

% The mapping of names to modules within a program
% there currently is no separate pef for programs.
% Instead, file references are used to identify the program that results from
% loading that file into a new runtime.
:- define_pef(pef_program_module(program,name,module)).

% A predicate
% note that module is a module identifier, not a module name.
:- define_pef(pef_predicate(id,module,name,arity)).

% The mapping of names to predicates within a module
:- define_pef(pef_imported_predicate(module,name,arity,predicate)).

% The relation between a predicate and its clauses
:- define_pef(pef_clause(predicate,number,toplevel_ref)).

% A special Module that results from extending an existing module definition,
% e.g. by adding clauses to multifile predicates.
:- define_pef(pef_module_extension(id,base,program)).

% A special Module that is defined "ad hoc", i.e. there is no file
% associated to it.
:- define_pef(pef_ad_hoc_module(id,name,program)).

% The relation between modules and the signatures they export
% signature may be either Name/Arity or op(Pr,Tp,Nm)
:- define_pef(pef_exports(module,signature)).


% The relation between programs and files
% force_reload is true if file was loaded using consult/1 rather than ensure_loaded/1 or use_module/1.
% otherwise it is false.
:- define_pef(pef_program_file(program,file_ref,module_name,force_reload)).

% The relation between predicates and their property definitions.
% Don't confuse this with normal pef_properties:
% pef_properties can be attached to any pef. In particular, they have no direct relation to source code.
% predicate property definitions are more like clauses - they are attached to toplevel terms.
% When predicates are merged or copied, so are the property definitions.
:- define_pef(pef_predicate_property_definition(predicate,toplevel_ref,property)).