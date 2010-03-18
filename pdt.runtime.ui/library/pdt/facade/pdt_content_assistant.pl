:- module(pdt_content_assistant,
	[	pdt_simple_completion/4,
		pdt_simple_completion/5,
		pdt_completion/5,
		pdt_var_completion/4
	]
).

:-use_module(library('pef/pef_base')).
:-use_module(library('pef/pef_api')).
:-use_module(library('/org/cs3/pdt/util/pdt_util_comments')).
:-use_module(library('help')).


%% pdt_completion(+File,+Context,+Prefix,-Predicate,-Tags)
% Slightly more sophisticated version of pdt_simple_completion.
% Only succeeds for predicates that are visible in the given context.
%
% @param File the absolute path to the file in which completion should be applied.
% @param Context the name of the context module. If Context is a variable, the module
% 	defined by File will be assumed. If File does not define a module, 'user' will be assumed.
% @param Prefix the prefix to complete
% @param Predicate will be unified with a term of the form Module:Name/Arity.
% @param Tags a list of additional 'tags' the gui can use to decorate the completion proposal.
%	Currently supported are:
%	- public if the predicate is exported or defined in user or system.
%	- dynamic, multifile, etc if the respective properties where declared for the predicate
%	- head(Head) if a structured comment with a modes line was found.
%	- summary(Text) if a structured comment with a summary line was found.
%	- id(ID) where ID is the PEF identifier of the predicate. This can be used to query additional information
% 	  from the fact base.
%
pdt_completion(File,ContextName,Prefix,ModuleName:PredName/Arity,Tags):-
    get_pef_file(File,FID),
    
    pef_program_query([file=FID,id=PID]),
    (	var(ContextName)
    ->	guess_module(PID,FID,ContextMID)
    ;	resolve_module(PID,ContextName,ContextMID)
    ),
    pef_predicate_query([id=Id,name=PredName,arity=Arity,module=MID]),
	atom_prefix(PredName,Prefix),
	resolve_predicate(PID,ContextMID,PredName,Arity,Id),
	module_name(MID,ModuleName),
	findall(Tag,completion_tag(Id,MID,ModuleName,PredName,Arity,Tag),Tags).

% TRHO: very simplistic lookup built_in predicates
pdt_completion(_File,_ContextName,Prefix,user:PredName/Arity,Tags):-
%	user:predicate_property(Head, built_in),
%	functor(Head,PredName,Arity),
	predicate(PredName,Arity,_,_,_),
	atom_prefix(PredName,Prefix),
	manual_entry(PredName,Arity,Doc),
	Tags=[built_in,
	% head(is(get_defining_file('AbbaId','File'),det)), % TRHO NOT SUPPORTED
	documentation(Doc)]. % TODO, retrieve from documentation
	% id(40085) %TRHO not supported for built-ins

manual_entry(Pred,Arity,Content) :-
    predicate(Pred,Arity,_,FromLine,ToLine),
    !,
    online_help:line_start(FromLine, From),
    online_help:line_start(ToLine, To),
    online_help:online_manual_stream(Manual),
    %set_stream(Manual, encoding(octet)),
    new_memory_file(Handle),open_memory_file(Handle, write, MemStream),
%    stream_property(Manual, position(OldPos)),
 %   set_stream_position(Manual, OldPos),
    seek(Manual,From,bof,_NewOffset),
%    stream_position(Manual, _, OLD),
		    %'$stream_position'(From, 0, 0)),
    Range is To - From,
%   current_output(Out),
    online_help:copy_chars(Range, Manual, MemStream),
    close(MemStream),
%    set_output(Out),
    memory_file_to_atom(Handle,Content),
    free_memory_file(Handle).
spyme(_).


pdt_var_completion(Path,Offset,Prefix,Name):-
	pdt_request_target(parse(file(Path))),
	pef_file_query([path=Path,id=File]),
	(	toplevel_at(File,Offset,Offset,Toplevel)
	->	pef_toplevel_query([id=Toplevel,varnames=VarNames])
	;	between_toplevels(File,Offset,_Before,EndBefore,_After,StartAfter),
		very_slow_hand_made_heuristic_parser(File,Offset,EndBefore,StartAfter,VarNames)

	%	once(
	%		(	pef_toplevel_query([id=Toplevel
	),
	member(Name = _,VarNames),
		atom_prefix(Name,Prefix).

very_slow_hand_made_heuristic_parser(_File,_Offset,_Begin,_End,VarNames):-
	VarNames = "Test".

guess_module(_PID,FID,ContextMID):-
    pef_module_definition_query([id=ContextMID,file=FID]),
    !.
guess_module(PID,_FID,ContextMID):-
	resolve_module(PID,user,ContextMID).

completion_tag(_Id,_MID,user,_Name,_Arity,public).
completion_tag(_Id,_MID,system,_Name,_Arity,public).
completion_tag(_Id,MID,_ModuleName,Name,Arity,public):-
    module_exports(MID,Name/Arity).
completion_tag(ID,_MID,_ModuleName,_Name,_Arity,Prop):-
    pef_predicate_property_definition_query([predicate=ID,property=Prop]).
completion_tag(ID,_MID,_ModuleName,_Name,_Arity,Prop):-
	predicate_summary(ID,Head,Summary),
	(	Prop=head(Head)
	; 	Prop=summary(Summary)
	).
completion_tag(ID,_MID,_ModuleName,_Name,_Arity,id(ID)).
%%
% pdt_simple_completion(+Prefix,-Label,-Summary,-Completion).
% find predicates starting with a given prefix.
% This is the simplest version I can think of. More elaborated version will follow.
pdt_simple_completion(Prefix,Name/Arity,Summary,Name):-
	pef_predicate_query([id=Id,name=Name,arity=Arity]),
	atom_prefix(Name,Prefix),
	predicate_summary(Id,_Head,Summary).
%%
% pdt_simple_completion(+Prefix,-Id,-Label,-Summary,-Completion).
% unifies Id with the predicate Id, same as pdt_completion/4.
pdt_simple_completion(Prefix,Id,Name/Arity,Summary,Name):-
	pef_predicate_query([id=Id,name=Name,arity=Arity]),
	atom_prefix(Name,Prefix),
	predicate_summary(Id,_Head,Summary).


predicate_summary(Id,Head,Summary):-
	predicate_summary_nondet(Id,Head,Summary),
	!.

predicate_summary_nondet(Id,Head,Summary):-
	pef_clause_query([predicate=Id,toplevel=Toplevel]),
	pef_comment_query([id=Comment,toplevel=Toplevel,file=File,text=Text]),
	pef_property_query([pef=Comment,key=position,value=StreamPos]),
	get_pef_file(FileName,File),
	pdt_comment_summary(FileName,StreamPos,Text,Head,Summary).

predicate_summary_nondet(Id,Head,''):-
	pef_predicate_query([id=Id,name=Name,arity=Arity]),
	functor(Head,Name,Arity).