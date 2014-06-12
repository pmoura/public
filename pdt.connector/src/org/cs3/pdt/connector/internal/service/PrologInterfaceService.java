/*****************************************************************************
 * This file is part of the Prolog Development Tool (PDT)
 * 
 * WWW: http://sewiki.iai.uni-bonn.de/research/pdt/start
 * Mail: pdt@lists.iai.uni-bonn.de
 * Copyright (C): 2004-2012, CS Dept. III, University of Bonn
 * 
 * All rights reserved. This program is  made available under the terms
 * of the Eclipse Public License v1.0 which accompanies this distribution,
 * and is available at http://www.eclipse.org/legal/epl-v10.html
 * 
 ****************************************************************************/

package org.cs3.pdt.connector.internal.service;

import static org.cs3.prolog.connector.common.QueryUtils.bT;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;

import org.cs3.pdt.connector.PrologConnectorPredicates;
import org.cs3.pdt.connector.PDTConnectorPlugin;
import org.cs3.pdt.connector.internal.service.ext.IPrologInterfaceServiceExtension;
import org.cs3.pdt.connector.registry.PrologInterfaceRegistry;
import org.cs3.pdt.connector.service.ActivePrologInterfaceListener;
import org.cs3.pdt.connector.service.ConsultListener;
import org.cs3.pdt.connector.service.IPrologInterfaceService;
import org.cs3.pdt.connector.service.PDTReloadExecutor;
import org.cs3.pdt.connector.subscription.DefaultSubscription;
import org.cs3.pdt.connector.subscription.Subscription;
import org.cs3.pdt.connector.util.FileUtils;
import org.cs3.prolog.connector.common.logging.Debug;
import org.cs3.prolog.connector.process.PrologProcess;
import org.cs3.prolog.connector.process.PrologProcessException;
import org.eclipse.core.resources.IFile;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.core.runtime.IStatus;
import org.eclipse.core.runtime.Status;
import org.eclipse.core.runtime.SubProgressMonitor;
import org.eclipse.core.runtime.jobs.ISchedulingRule;
import org.eclipse.core.runtime.jobs.Job;
import org.eclipse.core.runtime.jobs.MultiRule;

public class PrologInterfaceService implements IPrologInterfaceService, IPrologInterfaceServiceExtension {
	
	private DefaultReloadExecutor defaultReloadExecutor;
	
	public PrologInterfaceService() {
		defaultReloadExecutor = new DefaultReloadExecutor();
		registerPDTReloadExecutor(defaultReloadExecutor);
	}
	
	private PrologProcess activePrologProcess = getDefaultPrologProcess();
	
	private static final ISchedulingRule activePifChangedRule = new ISchedulingRule() {
		@Override
		public boolean isConflicting(ISchedulingRule rule) {
			return this == rule;
		}
		
		@Override
		public boolean contains(ISchedulingRule rule) {
			return this == rule;
		}
	};
	
	@Override
	public PrologProcess getActivePrologProcess() {
		if (activePrologProcess == null) {
			setActivePrologProcess(null);
		}
		return activePrologProcess;
	}
	
	@Override
	public synchronized void setActivePrologProcess(PrologProcess pif) {
		if (pif == null) {
			activePrologProcess = getDefaultPrologProcess();
		} else {
			if (activePrologProcess == pif) {
				return;
			} else {
				activePrologProcess = pif;
			}
		}
		fireActivePrologProcessChanged(activePrologProcess);
	}
	
	@SuppressWarnings("unchecked")
	private synchronized void fireActivePrologProcessChanged(final PrologProcess pif) {
		Job job = new Job("Active PrologProcess changed: notify listeners") {
			
			@Override
			protected IStatus run(IProgressMonitor monitor) {
				ArrayList<ActivePrologInterfaceListener> listenersClone;
				synchronized (activePrologInterfaceListeners) {
					listenersClone = (ArrayList<ActivePrologInterfaceListener>) activePrologInterfaceListeners.clone();
				}
				
				monitor.beginTask("Active PrologProcess changed: notify listeners", listenersClone.size());
				
				for (ActivePrologInterfaceListener listener : listenersClone) {
					listener.activePrologProcessChanged(pif);
					monitor.worked(1);
				}
				monitor.done();
				return Status.OK_STATUS;
			}
		};
		job.setRule(activePifChangedRule);
		job.schedule();
	}
	
	private ArrayList<ActivePrologInterfaceListener> activePrologInterfaceListeners = new ArrayList<ActivePrologInterfaceListener>();
	
	@Override
	public void registerActivePrologInterfaceListener(ActivePrologInterfaceListener listener) {
		synchronized (activePrologInterfaceListeners) {
			activePrologInterfaceListeners.add(listener);
		}
	}
	
	@Override
	public void unRegisterActivePrologInterfaceListener(ActivePrologInterfaceListener listener) {
		synchronized (activePrologInterfaceListeners) {
			activePrologInterfaceListeners.remove(listener);
		}
	}
	
	private static final String DEFAULT_PROCESS = "Default Process";
	
	private PrologProcess getDefaultPrologProcess() {
		PrologInterfaceRegistry registry = PDTConnectorPlugin.getDefault().getPrologInterfaceRegistry();
		Subscription subscription = registry.getSubscription(DEFAULT_PROCESS);
		if (subscription == null) {
			subscription = new DefaultSubscription(DEFAULT_PROCESS + "_indepent", DEFAULT_PROCESS, "Independent prolog process", "Prolog");
			registry.addSubscription(subscription);
		}
		PrologProcess pif = PDTConnectorPlugin.getDefault().getPrologProcess(subscription);
		return pif;
	}
	
	private TreeSet<PDTReloadExecutor> pdtReloadExecutors = new TreeSet<PDTReloadExecutor>(new Comparator<PDTReloadExecutor>() {
		@Override
		public int compare(PDTReloadExecutor o1, PDTReloadExecutor o2) {
			return o2.getPriority() - o1.getPriority();
		}
	});
	
	@Override
	public void registerPDTReloadExecutor(PDTReloadExecutor executor) {
		synchronized (pdtReloadExecutors) {
			pdtReloadExecutors.add(executor);
		}
	}
	
	@Override
	public void unRegisterPDTReloadExecutor(PDTReloadExecutor executor) {
		synchronized (pdtReloadExecutors) {
			pdtReloadExecutors.remove(executor);
		}
	}
	
	private HashSet<ConsultListener> consultListeners = new HashSet<ConsultListener>();

	@Override
	public void registerConsultListener(ConsultListener listener) {
		synchronized (consultListeners) {
			consultListeners.add(listener);
		}
	}
	
	@Override
	public void unRegisterConsultListener(ConsultListener listener) {
		synchronized (consultListeners) {
			consultListeners.remove(listener);
		}
	}
	
	@Override
	public void consultFile(String file) {
		consultFile(file, getActivePrologProcess());
	}

	@Override
	public void consultFile(String file, PrologProcess pif) {
		try {
			consultFile(FileUtils.findFileForLocation(file), pif);
		} catch (IOException e) {
			Debug.report(e);
			return;
		}
	}

	@Override
	public void consultFile(final IFile file) {
		consultFile(file, getActivePrologProcess());
	}
	
	@Override
	public void consultFile(IFile file, PrologProcess pif) {
		ArrayList<IFile> fileList = new ArrayList<IFile>();
		fileList.add(file);
		consultFiles(fileList, pif);
	}
	
	@Override
	public void consultFiles(List<IFile> files) {
		consultFiles(files, getActivePrologProcess());
	}
	
	@Override
	public void consultFiles(final List<IFile> files, final PrologProcess pif) {
		consultFilesInJob(files, pif, false);
	}
	
	@Override
	public void consultFilesSilent(List<IFile> files, PrologProcess pif) {
		consultFilesInJob(files, pif, true);
	}
	
	private void consultFilesInJob(final List<IFile> files, final PrologProcess pif, final boolean silent) {
		Job job = new Job("Consult " + files.size() + " file(s)") {
			@Override
			protected IStatus run(IProgressMonitor monitor) {
				try {
					consultFilesImpl(files, pif, silent, monitor);
				} catch (PrologProcessException e) {
					Debug.report(e);
					return Status.CANCEL_STATUS;
				} finally {
					monitor.done();
				}
				return Status.OK_STATUS;
			}
		};
		job.setRule(new MultiRule(files.toArray(new IFile[files.size()])));
		job.schedule();
	}
	
	@SuppressWarnings("unchecked")
	private void consultFilesImpl(List<IFile> files, PrologProcess pif, boolean silent, IProgressMonitor monitor) throws PrologProcessException {
		HashSet<ConsultListener> consultListenersClone;
		synchronized (consultListeners) {
			consultListenersClone = (HashSet<ConsultListener>) consultListeners.clone();
		}
		
		monitor.beginTask("Consult " +  files.size() + " file(s)", consultListenersClone.size() * 4);
		
		for (ConsultListener listener : consultListenersClone) {
			monitor.subTask("Notify Listener");
			listener.beforeConsult(pif, files, new SubProgressMonitor(monitor, 1));
		}
		
		monitor.subTask("Execute reload");
		boolean success = executeReload(pif, files, silent, new SubProgressMonitor(monitor, consultListenersClone.size()));
		
		if (success) {
			monitor.subTask("Collect all consulted files");
			List<String> allConsultedFiles = collectConsultedFiles(pif, new SubProgressMonitor(monitor, consultListenersClone.size()));
			
			for (ConsultListener listener : consultListenersClone) {
				monitor.subTask("Notify Listener");
				listener.afterConsult(pif, files, allConsultedFiles, new SubProgressMonitor(monitor, 1));
			}
		}
		monitor.done();
	}
	
	private List<String> collectConsultedFiles(PrologProcess pif, IProgressMonitor monitor) throws PrologProcessException {
		monitor.beginTask("", 1);
		
		List<String> result = new ArrayList<String>();
		
		List<Map<String, Object>> reloadedFiles = pif.queryAll(bT(PrologConnectorPredicates.RELOADED_FILE, "File"));
		for (Map<String, Object> reloadedFile : reloadedFiles) {
			result.add(reloadedFile.get("File").toString());
		}
		
		monitor.done();
		
		return result;
	}

	@SuppressWarnings("unchecked")
	private boolean executeReload(PrologProcess pif, List<IFile> files, boolean silent, IProgressMonitor monitor) throws PrologProcessException {
		TreeSet<PDTReloadExecutor> executorsClone;
		synchronized (pdtReloadExecutors) {
			executorsClone = (TreeSet<PDTReloadExecutor>) pdtReloadExecutors.clone();
		}
		monitor.beginTask("Execute reload", executorsClone.size());
		if (silent) {
			boolean success = defaultReloadExecutor.executePDTReload(pif, files, new SubProgressMonitor(monitor, executorsClone.size()));
			monitor.done();
			return success;
		} else {
			for (PDTReloadExecutor executor : executorsClone) {
				monitor.subTask("Execute reload");
				boolean success = executor.executePDTReload(pif, files, new SubProgressMonitor(monitor, 1));
				if (success) {
					monitor.done();
					return true;
				}
			}
		}
		monitor.done();
		return false;
	}

}


