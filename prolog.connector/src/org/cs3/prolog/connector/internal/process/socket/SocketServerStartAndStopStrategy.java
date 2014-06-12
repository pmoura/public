/*****************************************************************************
 * This file is part of the Prolog Development Tool (PDT)
 * 
 * Author: Lukas Degener (among others)
 * WWW: http://sewiki.iai.uni-bonn.de/research/pdt/start
 * Mail: pdt@lists.iai.uni-bonn.de
 * Copyright (C): 2004-2012, CS Dept. III, University of Bonn
 * 
 * All rights reserved. This program is  made available under the terms
 * of the Eclipse Public License v1.0 which accompanies this distribution,
 * and is available at http://www.eclipse.org/legal/epl-v10.html
 * 
 ****************************************************************************/

/*
 */
package org.cs3.prolog.connector.internal.process.socket;

import java.io.BufferedOutputStream;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.cs3.prolog.connector.common.InputStreamPump;
import org.cs3.prolog.connector.common.ProcessUtils;
import org.cs3.prolog.connector.common.QueryUtils;
import org.cs3.prolog.connector.common.Util;
import org.cs3.prolog.connector.common.logging.Debug;
import org.cs3.prolog.connector.internal.process.ServerStartAndStopStrategy;
import org.cs3.prolog.connector.process.PrologProcess;
import org.cs3.prolog.connector.process.StartupStrategy;

public class SocketServerStartAndStopStrategy implements ServerStartAndStopStrategy {
private static JackTheProcessRipper processRipper;
	
	private static final String STARTUP_ERROR_LOG_PROLOG_CODE = 
			":- multifile message_hook/3.\n" +
			":- dynamic message_hook/3.\n" +
			":- dynamic pdt_startup_error_message/1.\n" +
			":- dynamic collect_pdt_startup_error_messages/0.\n" +
			"collect_pdt_startup_error_messages.\n" +
			"message_hook(_,Level,Lines):-\n" +
			"    collect_pdt_startup_error_messages,\n" +
			"    (Level == error; Level == warning),\n" + 
			"    prolog_load_context(term_position, '$stream_position'(_,Line,_,_,_)),\n" +
			"    prolog_load_context(source, File),\n" +
			"    with_output_to(atom(Msg0), (current_output(O), print_message_lines(O, '', Lines))),\n" +
			"    format(atom(Msg), 'Location: ~w:~w~nMessage: ~w', [File, Line, Msg0]),\n" +
			"    assertz(pdt_startup_error_message(Msg)),\n" +
			"    fail.\n" +
			"write_pdt_startup_error_messages_to_file(_File) :-\n" +
			"    retractall(collect_pdt_startup_error_messages),\n" + 
			"    \\+ pdt_startup_error_message(_),\n" +
			"    !.\n" +
			"write_pdt_startup_error_messages_to_file(File) :-\n" +
			"    open(File, write, Stream),\n" +
			"    forall(pdt_startup_error_message(Msg),format(Stream, '~w~n', [Msg])),\n" +
			"    close(Stream).\n";
	private static final String STARTUP_ERROR_LOG_LOGTALK_CODE =
			":- multifile('$lgt_logtalk.message_hook'/5).\n" +
			":- dynamic('$lgt_logtalk.message_hook'/5).\n" +
			"'$lgt_logtalk.message_hook'(_, Kind, core, Tokens, _) :-\n" +
			"    collect_pdt_startup_error_messages,\n" +
			"    functor(Kind, Level, _),\n" +
			"    (Level == error; Level == warning),\n" + 
			"    with_output_to(atom(Msg), (current_output(S), logtalk::print_message_tokens(S, '', Tokens))),\n" +
			"    assertz(pdt_startup_error_message(Msg)),\n" +
			"    fail.\n";

	public SocketServerStartAndStopStrategy() {
		processRipper=JackTheProcessRipper.getInstance();
	}

	/*
	 * (non-Javadoc)
	 * 
	 * @see
	 * org.cs3.pl.prolog.ServerStartAndStopStrategy#startServer(org.cs3.pl.prolog
	 * .IPrologInterface)
	 */
	@Override
	public  Process startServer(PrologProcess pif) {
		if (pif.isStandAloneServer()) {
			Debug.warning("Will not start server; the standalone option is set.");
			return null;
		}
		if (!(pif instanceof SocketPrologProcess)) {
			throw new ClassCastException("SocketPrologProcess needed but got another PrologProcess");
		}
		SocketPrologProcess socketPif = (SocketPrologProcess) pif;
		return startSocketServer(socketPif);
	}

	private Process startSocketServer(SocketPrologProcess socketPif) {
		File lockFile = Util.getLockFile();
		socketPif.setLockFile(lockFile);
		Util.addTempFile(lockFile);
		File errorLogFile = Util.getLockFile();
		socketPif.setErrorLogFile(errorLogFile);
		Util.addTempFile(errorLogFile);
		int port = getFreePort(socketPif);
		Process process = getNewProcess(socketPif, port);
		try {			
			initializeBuffers(socketPif, process);
			waitForProcessToGetRunning(socketPif, process);
			String errorLogFileContent = getErrorLogFileContent(socketPif);
			if (errorLogFileContent != null && !errorLogFileContent.isEmpty()) {
				Debug.warning("Prolog warnings and errors during initialization:\n" + errorLogFileContent);
			}
			return process;
		} catch (IOException e) {
			e.printStackTrace();
			return null;
		}
	}

	private static Process getNewProcess(SocketPrologProcess socketPif, int port) {
		String[] commandArray = getCommandArray(socketPif, port);
		Map<String, String> env = getEnvironmentAsArray(socketPif);
		Process process = null;
		try {
			Debug.info("Starting server with " + Util.prettyPrint(commandArray));
			// Temporary safety code to ensure that the command array contains no empty strings:
			List<String> commands = new ArrayList<String>();
			// keep this until its clear why there is an empty string elements in the array
			for (String string : commandArray) {
				if(string != null && string.length()>0){
					commands.add(string);
				}
			}
			commandArray=commands.toArray(new String[0]);
			
			if (env.size() == 0) {
				Debug.info("inheriting system environment");
				ProcessBuilder processBuilder = new ProcessBuilder(commands);
				processBuilder.environment();
				process = processBuilder.start();
			} else {
				Debug.info("using environment: " + Util.prettyPrint(env));
				ProcessBuilder processBuilder = new ProcessBuilder(commands);
				Map<String, String> processEnvironment = processBuilder.environment();
				processEnvironment.putAll(env);
				process = processBuilder.start();
			}
		} catch (IOException e) {
			e.printStackTrace();
			return null;
		}
		return process;
	}

	private static void initializeBuffers(SocketPrologProcess socketPif,
			Process process) throws IOException {
		BufferedWriter writer = initializeCorrespondingLogFile(socketPif);
		new InputStreamPump(process.getErrorStream(), writer).start();
		new InputStreamPump(process.getInputStream(), writer).start();
	}

	private static BufferedWriter initializeCorrespondingLogFile(
			SocketPrologProcess socketPif) throws IOException {
		File logFile = Util.getLogFile(socketPif.getServerLogDir(),"pdt.server.log");
		BufferedWriter writer = new BufferedWriter(new FileWriter(logFile.getAbsolutePath(), true));
		writer.write("---------------------------------\n");
		writer.write(new Date().toString() + "\n");
		writer.write("---------------------------------\n");
		return writer;
	}
	
	private  void waitForProcessToGetRunning(SocketPrologProcess socketPif,
			Process process) {
		long timeout = socketPif.getTimeout();
		long startTime = System.currentTimeMillis();
		while (!isRunning(socketPif)) {
			try {
				long now = System.currentTimeMillis();
				if (now - startTime > timeout) {
					String errorLogFileContent = getErrorLogFileContent(socketPif);
					if (errorLogFileContent != null) {
						Debug.error("Prolog errors during initialization:\n" + errorLogFileContent);
					}
					throw new RuntimeException("Timeout exceeded while waiting for peer to come up.");
				}
				Thread.sleep(50);
			} catch (InterruptedException e1) {
				Debug.report(e1);
			}
			try {
				if (process.exitValue() != 0) {
					throw new RuntimeException("Failed to start server. Process exited with err code " + process.exitValue());
				}
			} catch (IllegalThreadStateException e) {
				; // nothing. the process is still coming up.
			}
		}
	}

	private String getErrorLogFileContent(SocketPrologProcess socketPif) {
		String errorLogFileContent = null;
		try {
			errorLogFileContent = Util.readInputStreamToString(new FileInputStream(socketPif.getErrorLogFile()));
		} catch (FileNotFoundException e) {
		} catch (IOException e) {
		}
		return errorLogFileContent;
	}



	private static Map<String, String> getEnvironmentAsArray(SocketPrologProcess socketPif) {
		String environment = socketPif.getEnvironment();
		Map<String, String> env = new HashMap<String, String>();
		String[] envarray = Util.split(environment, ",");
		for (int i = 0; i < envarray.length; i++) {
			String[] mapping = Util.split(envarray[i], "=");
			env.put(mapping[0], mapping[1]);
		}
		return env;
	}

	private static String[] getCommandArray(SocketPrologProcess socketPif, int port) {
		String[] command = getCommands(socketPif);
		String[] args = getArguments(socketPif, port);
		String[] commandArray = new String[command.length + args.length];
		System.arraycopy(command, 0, commandArray, 0, command.length);
		System.arraycopy(args, 0, commandArray, command.length, args.length);
		return commandArray;
	}

	private static String[] getArguments(SocketPrologProcess socketPif, int port) {
		File tmpFile = null;
		try {
			tmpFile = File.createTempFile("socketPif", null);
			Util.addTempFile(tmpFile);
			writeInitialisationToTempFile(socketPif, port, tmpFile);
		} catch (IOException e) {
			Debug.report(e);
			throw new RuntimeException(e.getMessage());
		}
		String[] args = buildArguments(socketPif, tmpFile);
		return args;
	}

	private static String[] getCommands(SocketPrologProcess socketPif) {
		String executable = ProcessUtils.createExecutable(
				socketPif.getOSInvocation(),
				socketPif.getExecutablePath(),
				socketPif.getCommandLineArguments(),
				socketPif.getAdditionalStartupFile());
		String[] command = Util.split(executable, " ");
		return command;
	}

	private static String[] buildArguments(SocketPrologProcess socketPif,
			File tmpFile) {
		String fileSearchPath = socketPif.getFileSearchPath();
		String[] args;
		if (fileSearchPath != null && !(fileSearchPath.trim().length() == 0)) {
			args = new String[] { "-p", fileSearchPath, "-g", "[" + QueryUtils.prologFileNameQuoted(tmpFile) + "]" };
		} else {
			args = new String[] { "-g", "[" + QueryUtils.prologFileNameQuoted(tmpFile) + "]" };
		}
		return args;
	}

	private static void writeInitialisationToTempFile(SocketPrologProcess socketPif,
			int port, File tmpFile) throws FileNotFoundException {
		PrintWriter tmpWriter = new PrintWriter(new BufferedOutputStream(new FileOutputStream(tmpFile)));
//      Don't set the encoding globally because it breaks something
//		tmpWriter.println(":- set_prolog_flag(encoding, utf8).");
		tmpWriter.println(STARTUP_ERROR_LOG_PROLOG_CODE);
		if (socketPif.getAdditionalStartupFile() != null && socketPif.getAdditionalStartupFile().contains("logtalk")) {
			tmpWriter.print(STARTUP_ERROR_LOG_LOGTALK_CODE);
		}
		tmpWriter.println(":- (current_prolog_flag(xpce_threaded, _) -> set_prolog_flag(xpce_threaded, true) ; true).");
		tmpWriter.println(":- (current_prolog_flag(dialect, swi) -> guitracer ; true).");
		if (socketPif.isHidePlwin()) {
			tmpWriter.println(":- (  (current_prolog_flag(dialect, swi), current_prolog_flag(windows, true))  -> win_window_pos([show(false)]) ; true).");
		}
		tmpWriter.println(":- (current_prolog_flag(windows,_T) -> set_prolog_flag(tty_control,false) ; true).");

		tmpWriter.println(":- ['" + socketPif.getConsultServerLocation() + "'].");
		StartupStrategy startupStrategy = socketPif.getStartupStrategy();
		for (String fspInit : startupStrategy.getFileSearchPathInitStatements()) {
			tmpWriter.println(":- " + fspInit + ".");
		}
		for (String lfInit : startupStrategy.getLoadFileInitStatements()) {
			tmpWriter.println(":- " + lfInit + ".");
		}
		tmpWriter.println(":- consult_server(" + port + "," + QueryUtils.prologFileNameQuoted(socketPif.getLockFile()) + ").");
		tmpWriter.println(":- write_pdt_startup_error_messages_to_file(" + QueryUtils.prologFileNameQuoted(socketPif.getErrorLogFile()) + ").");
		tmpWriter.close();
	}

	private static int getFreePort(SocketPrologProcess socketPif) {
		int port;
		try {
			port = Util.findFreePort();
			socketPif.setPort(port);
		} catch (IOException e) {
			Debug.report(e);
			throw new RuntimeException(e.getMessage());
		}
		return port;
	}

	/*
	 * (non-Javadoc)
	 * 
	 * @see
	 * org.cs3.pl.prolog.ServerStartAndStopStrategy#stopServer(org.cs3.pl.prolog
	 * .IPrologInterface, boolean)
	 */
	@Override
	public void stopServer(PrologProcess pif) {
		if (pif.isStandAloneServer()) {
			Debug.warning("Will not stop server; the standalone option is set.");
			return;
		}
		if (!(pif instanceof SocketPrologProcess)) {
			throw new ClassCastException("SocketPrologProcess needed but got another PrologProcess");
		}
		try {
			if (!isRunning(pif)) {
				Debug.info("There is no server running. I do not stop anything.");
				return;
			}
			SocketPrologProcess socketPif = (SocketPrologProcess) pif;
			stopSocketServer(socketPif);
		} catch (Throwable e) {
			Debug.report(e);
			throw new RuntimeException(e.getMessage());
		}
	}
	
	private static void stopSocketServer(SocketPrologProcess socketPif){
		try {
			SocketClient client = getSocketClient(socketPif);
			sendClientShutdownCommand(client);
			long pid = client.getServerPid();
			client.close();
			socketPif.getLockFile().delete();
			File errorLogFile = socketPif.getErrorLogFile();
			if (errorLogFile.exists()) {
				errorLogFile.delete();
			}
			Debug.info("server process will be killed in about a second.");
			processRipper.markForDeletion(pid);
		} catch (Exception e) {
			Debug.warning("There was a problem during server shutdown.");
			Debug.report(e);
		}
	}

	private static SocketClient getSocketClient(SocketPrologProcess socketPif)
			throws UnknownHostException, IOException {
		int port = socketPif.getPort();
		SocketClient client = new SocketClient(socketPif.getHost(), port);
		return client;
	}

	private static void sendClientShutdownCommand(SocketClient client) 
			throws UnknownHostException, IOException {
		client.readUntil(SocketCommunicationConstants.GIVE_COMMAND);
		client.writeln(SocketCommunicationConstants.SHUTDOWN);
		client.readUntil(SocketCommunicationConstants.BYE);
	}
	
	/*
	 * (non-Javadoc)
	 * 
	 * @see
	 * org.cs3.pl.prolog.ServerStartAndStopStrategy#isRunning(org.cs3.pl.prolog
	 * .IPrologInterface)
	 */
	@Override
	public  boolean isRunning(PrologProcess pif) {
		File lockFile = ((SocketPrologProcess) pif).getLockFile();
		return lockFile != null && lockFile.exists();
	}
}


