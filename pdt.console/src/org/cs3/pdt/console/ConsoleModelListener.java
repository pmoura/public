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

package org.cs3.pdt.console;
import java.util.EventListener;

public interface ConsoleModelListener extends EventListener {
	
	abstract public void onOutput(ConsoleModelEvent e);
	abstract public void onEditBufferChanged(ConsoleModelEvent e);
	abstract public void onCommit(ConsoleModelEvent e);
	abstract public void onModeChange(ConsoleModelEvent e);
	abstract public void afterConnect(ConsoleModelEvent e);
	abstract public void beforeDisconnect(ConsoleModelEvent e);
}


