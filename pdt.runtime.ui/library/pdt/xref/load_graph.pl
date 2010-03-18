:- module(load_graph,[build_new_load_graph/0, build_load_graph/0]).
:- use_module(parse_util).


/**
 * build_new_load_graph/0
 *   retracts all load_edge/3 of a former load-graph and
 *   builds a new one with respect to all given
 *   load_dir/4 using build_load_graph/0.
 */
build_new_load_graph:-
    retractall(load_edge(_,_,_)),
    retractall(warning(_,'file not found in project',_)),
    retractall(warning(_,'guessed file reference',_)),
    retractall(warning(_,'link to external library',_)),
    build_load_graph.

/**
* build_load_graph/0
*   tries to build the corresponding load_edge/3 for each load_dir/4 it
*   can find.
*   If it cannot find the correct file that is loaded with the considered
*   directive it tries to guess the file: It compares the file name with each
*   file name it can find.
*   Only files that are parsed with the preparser are considered. If no such
*   file can be found a warning will be created, if it is not a reference 
*   to a library file. 
*   (Libraries will not be in the working context in most cases.) 
*
*	Finishes with retracting all load_dir/4.
**/

/* ToDo: inform the user about the guessing?
         use the given path for the guesseing? -> concat 
 */ 	 
build_load_graph:-
    load_dir(Directive,ToLoadFiles,Imports),
     	flatten(ToLoadFiles,ToLoadFilesFlatt),
		build_load_edges_for_list(ToLoadFilesFlatt,Imports,Directive),
    	fail.
build_load_graph.
%build_load_graph:-
%	retractall(load_dir(_,_,_,_)).

/**
 * build_load_edges_for_list(+ArgList,+LoadingFileId,+LoadingDirectiveId)
 *   builds the load edges for all Arguments inside of ArgList with the
 *   help of build_complex_load_edges/3. 
 **/
build_load_edges_for_list([File],Imports,Directive):-
    !,
    directiveT(Directive,LoadingId,_),
    lookup_complex_file_reference(File,LoadingId,FileId,Warning),
   	(	FileId = ''
   	->	true
	;	assert(load_edge(LoadingId,FileId,Imports,Directive))
    ),
    (	Warning = ''
    ->	true
    ;	assert(warning(Directive,Warning,File))
   	).
build_load_edges_for_list([A|B],LoadingId,Imports,Directive):-
    build_load_edges_for_list([A],LoadingId,Imports,Directive),
    build_load_edges_for_list(B,LoadingId,Imports,Directive).


lookup_complex_file_reference(Arg,LoadingId,FileId,''):-
    atom(Arg),
    !,
    lookup_direct_file_reference(Arg,LoadingId,FileId).
lookup_complex_file_reference(ToLoadConstruct,LoadingId,FileId,''):-
    ToLoadConstruct =.. [PathKey,File],
    compute_dir_with_file_search_path(PathKey,FlatDir,Directive),
    combine_two_path_elements(FlatDir,File,FileName,Directive),
	lookup_direct_file_reference(FileName,LoadingId,FileId),
	!.   
lookup_complex_file_reference(ToLoadConstruct,_LoadingId,FileId,'guessed file reference'):-
    ToLoadConstruct =.. [_,File],
    prolog_file_type(Pl,prolog),
    file_name_extension(File,Pl,FilePl),	
    fileT_ri(AFile,FileId),							% Eva: optimierbar?
	atom_concat(_,FilePl,AFile),
	!.    
lookup_complex_file_reference(library(_Name),_LoadingId,'','link to external library'):-
    				% if it is a reference to a library file 
 					% the library may not be inside the project we parse
    				% so there may be no fileT for it to find with build_direct_load_edge
    !.	
lookup_complex_file_reference(_Args,_LoadingId,'','file not found in project').


lookup_direct_file_reference(ToLoad,LoadingId,Id):-
    prolog_file_type(Pl,prolog),
    fileT(LoadingId,LoadingName,_),
    absolute_file_name(ToLoad,[extensions(Pl),relative_to(LoadingName)],FileName),
	fileT_ri(FileName,Id),
	!.   



/**
 * compute_dir_with_file_search_path(+Key, -FinalDir, +Directive)
 *   resolves the directory represented by Arg1
 *   with file_search_path/2.
 *   
 *   It does this recursivley, if the path given by
 *   file_search_path is not a plain path but a refernce
 *   with a key to another path stored in file_search_path/2.
 *  
 *   Arg3 is needed to compose some warnings if it stumbles
 *   over syntax errors.
 **/
compute_dir_with_file_search_path(Key,FinalDir,Directive):-
	file_search_path(Key,Dir),
    (	Dir =.. [InnerKey,DirPath]
    ->	compute_dir_with_file_search_path(InnerKey,InnerDir,Directive),
 		combine_two_path_elements(InnerDir,DirPath,FinalDir,Directive)
    ;	Dir = FinalDir
    ).    	
 
 
 
/**
 * combine_tow_path_elements(+First,+Second,-Combination,+Directive)
 *    Arg3 is the atom that begins with Arg1, is followed
 *    with a '/' and ends with Arg2. If Arg1 and Arg2 are
 *    terms their atom representation is used.
 *
 *    Arg4 is needed to compose some warnings if it stumbles
 *    over syntax errors.
 **/ 
combine_two_path_elements(First,Second,Combination,Directive):-
    (	not(atomic(First)), assert(warning(Directive,'is not atomic',[First]))
    ;	not(atomic(Second)), assert(warning(Directive,'is not atomic',[Second]))
    ;	atomic(First), atomic(Second),
    	atomic_list_concat([First,'/',Second],Combination)
    ).