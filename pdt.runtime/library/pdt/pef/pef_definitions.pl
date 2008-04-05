
% Option "hooks".
%
% This will cause the pef base to call hook predicates for any fact it asserts or retracts.
% This facility is mainly intended for debugging. E.g. the PEF-graph uses it to update itself. 
% 
% NOTE: this will *noticably* slow down the build process!
% 	Only enable this option for debugging!
%
%'$option'(hooks).


% Option "index_foreign_keys" (enabled by default).
%
% If enabled, the tag "index" is implicitly assumed for all attributes 
% that are "typed", i.e. are references to pefs. The "type" tag causes the
% automatic generation/maintainance/use of reverse indices for that attribute.
%  
% You may not need all the indices, unless you intend to use the pef graph a lot.
% Nevertheless, a redundant index will not hurt performance as much as a missing one.
% If you are unsure, you should probably just enable this flag.
'$option'(index_foreign_keys).

% Option "implicit_ids" (enabled by default).
%
% If enabled, an implicit attribute "id @index" will be added to 
% each pef type that has no explicit id. Note that the <pef>_assert
% predicates will automatically generate an identifier if it is 
% not explicitly set.
%  
% The rational behind this is that refering to PEFs via their clause ref
% is dangerous if that clause may have been removed. 
% On the other hand there are several situations where we want to
% explicitly reference individual weak PEFs. So I decided that 
% ANY PEF should have a unique identifier. Just leave this enabled.
'$option'(implicit_ids).



:- op(600,xfy,@).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Types:
% Each pef attribute can be assigned (currently at most) one type using the
% : operator. In addition, A pef type can be assigend a super type using the same operator.
% 
% Note: There currently is no inheritance or anything. There is no type checking either.
% those "types" are really only interesting for debugging: The meta-model is used
% to create a graph which we can visualizie using Bashar's SVF plugin.
%
% Tags:
% An arbitrary number of tags can be attached to
% any pef type or attribute using the @ operator.
% you can "chain" several tags to one attribute or type.
%
% Example:
% :- define_pef(
% 	type( 
%		attr1 @foo @bar : attr_type1, 
%		attr2 @color(green) : attr_type2
% 	) @typetag1 @typetag2 : supertype
% ).

% A module definition. Also represents the defined module.
% generated by parse(file($file->$path))
:- define_pef(
	pef_module_definition(
		id,
		name @label,
		file:pef_file,
		toplevel:pef_toplevel
	):module
).

% An operator definition.
% generated by parse(file($file->$path)) 
:- define_pef(
	pef_op_definition(
		id,
		priority @label,
		type @label,
		name @label,
		file:pef_file,
		toplevel:pef_toplevel
	)
).

% A file dependency definition. Also represents the defined dependency.
% generated by parse(file($depending->$path))
:- define_pef(
	pef_file_dependency(
		id,
		depending:pef_file,
		dependency:pef_file,
		toplevel:pef_toplevel
	)
).

% A named property of any pef. Id is the PEFs Id. The property itself is a weak entity,
% it does not have an Id of its own.
% generated by ?
:- define_pef(
	pef_property(
		pef:any,
		key @label,
		value @label
	) @weak
).



% A parsed toplevel term.
% generated by parse(file($file->$path)) 
:- define_pef(
	pef_toplevel(
		id,
		file @index :pef_file,
		term,
		%expanded,
		positions,
		varnames,
		singletons
	)
).

% The relatione between source terms
% and the terms they are expanded to
% generated by parse(file($source->$file->$path))
:- define_pef(
	pef_term_expansion(		
		source:pef_toplevel,		
		expanded:pef_toplevel
	)
).


% generated by parse(file($file->$path))
:- define_pef(
	pef_comment(
		id,
		file @index :pef_file,
		toplevel @index :pef_toplevel,
		text
	)
).

% An AST node representing a non-var program term.
% generated by ast(file($toplevel($this)->$file->$path))
:- define_pef(
	pef_term(
		id,
		name @label,
		arity @label
	):ast_node
).

% An AST node representing a program variable occurence.
% generated by ast(file($toplevel($this)->$file->$path))
:- define_pef(
	pef_variable_occurance(
		id,
		variable @index :pef_variable
	):ast_node
).

% A program variable.
% generated by ast(file($ast->$toplevel->$file->$path))
:- define_pef(
	pef_variable(
		id,
		name @label,
		ast @index :ast
	)
).

% The relation between a compound term and its arguments.
% generated by ast(file($toplevel($parent)->$file->$path))
:- define_pef(
	pef_arg(
		num @label,
		parent:pef_term,
		child @cascade :ast_node
	) @edge @weak
).

% The relation between a toplevel record and the root of corresponding AST.
% generated by ast(file($toplevel->$file->$path))
:- define_pef(
	pef_ast(
		id,
		root @cascade :ast_node,
		toplevel:pef_toplevel
	):ast 
).

% A pseudo AST not connected to any toplevel. 
% generated during transformation, not stable yet
:- define_pef(
	pef_pseudo_ast(
		id,
		root @cascade :ast_node,
		file:pef_file		
	):ast 
).


% The mapping of names to modules within a program
% generated by inteprete(file($program->$file->$path))
:- define_pef(
	pef_program_module(
		program @cascade :pef_program,
		name @label,
		module:module
	)@weak @edge
).

% A predicate
% note that module is a module identifier, not a module name.
% generated by inteprete(file($owner($module)->$file->$path))
:- define_pef(
	pef_predicate(
		id,
		name @label @index,
		arity @label,
		module:module		
	)
).

% The mapping of a signature imported into a module to the name of the module
% they where imported from.
% generated by inteprete(file($owner($module)->$file->$path))
:- define_pef(
	pef_imported_predicate(
		name @label @index,
		arity @label,
		module:module, %importing module		
		from_name @label
	) @weak @edge @composite_index([name,module])
).

% The relation between a predicate and its clauses
% generated by inteprete(file($owner($predicate->$module)->$file->$path))
:- define_pef(
	pef_clause(
		predicate @cascade :pef_predicate,
		number @label,
		toplevel @index:pef_toplevel
	) @weak @edge
).

% A special Module that results from extending an existing module definition,
% e.g. by adding clauses to multifile predicates.
% generated by inteprete(file($program->$file->$path))
:- define_pef(
	pef_module_extension(
		id,
		base:pef_module_definition,
		program:pef_program
	):module
).
 

% A special Module that is defined "ad hoc", i.e. there is no file
% associated to it.
% generated by inteprete(file($program->$file->$path))
:- define_pef(
	pef_ad_hoc_module(
		id,
		name @label,
		program:pef_program
	):module
).

% The relation between modules and the signatures they export
% signature may be either Name/Arity or op(Pr,Tp,Nm)
% generated by parse(file($module->$file->$path)), interprete(file($owner($module)->$file->$path))
:- define_pef(
	pef_exports(
		module:module,
		signature @label
	) @weak
).


% The relation between programs and files
% force_reload is true if file was loaded using consult/1 rather than ensure_loaded/1 or use_module/1.
% otherwise it is false.
% generated by interprete(file($program->$file->$path))
:- define_pef(
	pef_program_file(
		program @cascade :pef_program,
		file:pef_file,
		module_name,
		force_reload
	) @weak @edge
).

% The relation between predicates and their property definitions.
% Don't confuse this with normal pef_properties:
% pef_properties can be attached to any pef. In particular, they have no direct relation to source code.
% predicate property definitions are more like clauses - they are attached to toplevel terms.
% When predicates are merged or copied, so are the property definitions.
% generated by interprete(file($owner($predicate->$module)->$file->$path))
:- define_pef(
	pef_predicate_property_definition(
		predicate:pef_predicate,
		toplevel:pef_toplevel,
		property @label
	) @weak
).

% The relation between a module and its import list
% The import list is a list of module NAMES.
% This fact only exists, if the module has an import list that differs from the default one:
% By default each module imports user and user imports system.
% Also, a module extension inherits the list of its base by default. 
% If it has a list of its own, the list of its base is ignored.
% generated by interprete(file($owner($module)->$file->$path))
:- define_pef(
	pef_import_list(
		module:module,
		list
	)
).

% various problem pefs produced by the interpreter
% generated by interprete(file($program->$file->$path))
:- define_pef(
	pef_module_name_clash(
		id,
		program:pef_program,
		toplevel:pef_toplevel,
		first:module,
		second:module
	)@expensive :problem
).

% generated by interprete(file($program->$file->$path))
% FIXME: in which situation is this needed? Is it needed at all?
:- define_pef(
	pef_predicate_name_clash(
		id,
		program:pef_program,
		toplevel:pef_toplevel,
		module:module,
		first:pef_predicate,
		second:pef_predicate
	)@expensive :problem
).

:- define_pef(
	pef_predicate_already_imported(
		id,
		program:pef_program,
		toplevel:pef_toplevel,
		module:module,
		predicate:pef_predicate		
	)@expensive :problem
).

% generated by interprete(file($program->$file->$path))
:- define_pef(
	pef_predicate_redefinition(
		id,
		program:pef_program,
		toplevel:pef_toplevel,
		first:pef_predicate,
		second:pef_predicate
	)@expensive :problem
).

% generated by interprete(file($program->$file->$path))
:- define_pef(
	pef_predicate_abolished(
		id,
		program:pef_program,
		toplevel:pef_toplevel,
		module:module,
		predicate:pef_predicate
	)@expensive :problem
).

% generated by interprete(file($program->$file->$path))
:- define_pef(
	pef_unresolved_export(
		id,
		program:pef_program,
		toplevel:pef_toplevel,
		module:module,
		name @label,
		arity @label,
		export:ast_node/*TODO*/
	)@expensive :problem
).

:- define_pef(
	pef_malformed_signature(
		id,
		toplevel:pef_toplevel,
		signature
	)@expensive :problem
).


% problem pefs generated by the singleton checker (TODO)
% generated by singletons(file($variable->$ast->$toplevel->$file->$path))
:- define_pef(
	pef_singleton(
		id,	
		variable:pef_variable
	)@cheap :problem
).

% generated by singletons(file($variable->$ast->$toplevel->$file->$path))
:- define_pef(
	pef_no_singleton(
		id,
		variable:pef_variable
	)@cheap :problem
).

% problem pefs generated by the parser
% generated by parse(file($file->$path))
:- define_pef(
	pef_syntax_error(
		id,
		file:pef_file,
		error @label
	)@cheap :problem
).
% generated by parse(file($toplevel->$file->$path))
:- define_pef(
	pef_file_not_found(
		id,
		toplevel:pef_toplevel,
		file_spec @label
	)@cheap :problem
).

:- define_pef(
	pef_parser_dependency_cycle(
		id,
		action,
		toplevel:pef_toplevel
	)@cheap :problem
).


% problem pefs generated by the cross referencer
% generated by literals(file($toplevel($goal)->$file->$path))
:- define_pef(
	pef_unresolved_predicate_symbol(
		id,
		goal:ast_node,
		cx
	)@expensive :problem
).

% generated by literals(file($toplevel($goal)->$file->$path))
:- define_pef(
	pef_cannot_infer_rule(
		id,
		goal:ast_node,
		cx
	)@expensive :problem
).




% pefs for describing the workspace
% generated by interpreter(file($file->$path))
:- define_pef(
	pef_program(
		id,
		file:pef_file
	)
).

% generated by file($path)
:- define_pef(
	pef_file(
		id,
		path @label @index
	) :fs_node
).

% generated by directory($path,$include_pattern,$exclude_pattern)
:- define_pef(
	pef_directory(
		id,
		include_pattern,
		exclude_pattern,
		path @label @index
	) :fs_node
).

% generated by directory($parent->$path,$parent->$include_pattern,$parent->$exclude_pattern)
:- define_pef(
	pef_directory_entry(		
		parent :pef_directory,		
		child :fs_node
	) 
).


% seeded in facade/pdt_workspace
:- define_pef(
	pef_source_path(
		project:pef_project,
		path,
		include_pattern,
		exclude_pattern
	) 
).

% seeded in facade/pdt_workspace
:- define_pef(
	pef_entry_point(
		project:pef_project,
		path @index
	) 
).

% seeded in facade/pdt_workspace
:- define_pef(
	pef_project(
		id,
		name @index
	)
).

%%
% The relation between formulars and their maximal sub-formulars
% generated by literals(?)
% the rule currently does not carry information about the clause that contributed it.
% could be added, if necessary. 

:- define_pef(
	pef_msf_rule(
		predicate :pef_predicate,
		pattern,
		context,
		program :pef_program,
		subformula,
		substitution,
		subcontext,
		bound
	)
).

% generated by literals(?)
% the call currently contains no "explicit" information that could be used to link it to 
% the target that created it. The (opaque!) cx field however probably contains enough information.
% This could probably be made explicit, if necessary. 
:- define_pef(
	pef_call(
		predicate :pef_predicate,
		goal :ast_node,
		cx
	)
).


% generated during transformation, not stable yet.
:- define_pef(
	pef_modified_file(
		file:pef_file
	)
).

% generated during transformation, not stable yet.
:- define_pef(
	pef_renamed_file(
		file:pef_file,
		old_path
	)
).

% generated during transformation, not stable yet.
:- define_pef(
	pef_modified_toplevel(
		toplevel:pef_toplevel
	)
).

:- define_pef(
	pef_transformation_problem(
		severity,
		message
	)
).

% generated by delta
:- define_pef(
	pef_resource_delta(
		old_path,
		new_path,
		type
		
	)
).


% generated by delta
:- define_pef(
	pef_text_delta(		
		file:pef_file,
		start,
		end,
		text
	)
).
