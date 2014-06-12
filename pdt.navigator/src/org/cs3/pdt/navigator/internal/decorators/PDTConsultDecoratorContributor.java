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

package org.cs3.pdt.navigator.internal.decorators;

import static org.cs3.prolog.connector.common.QueryUtils.bT;

import java.util.HashSet;
import java.util.List;
import java.util.Map;

import org.cs3.pdt.common.PDTCommonPlugin;
import org.cs3.pdt.common.PDTCommonPredicates;
import org.cs3.pdt.common.PDTCommonUtil;
import org.cs3.pdt.common.PDTDecorator;
import org.cs3.pdt.common.PrologInterfaceStartListener;
import org.cs3.pdt.connector.PDTConnectorPlugin;
import org.cs3.pdt.connector.service.ActivePrologInterfaceListener;
import org.cs3.pdt.connector.service.ConsultListener;
import org.cs3.pdt.connector.util.UIUtils;
import org.cs3.pdt.navigator.internal.ImageRepository;
import org.cs3.prolog.connector.common.QueryUtils;
import org.cs3.prolog.connector.common.Util;
import org.cs3.prolog.connector.common.logging.Debug;
import org.cs3.prolog.connector.process.PrologProcess;
import org.cs3.prolog.connector.process.PrologProcessException;
import org.eclipse.core.resources.IFile;
import org.eclipse.core.resources.IFolder;
import org.eclipse.core.runtime.IPath;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.core.runtime.Path;
import org.eclipse.jface.viewers.BaseLabelProvider;
import org.eclipse.jface.viewers.IDecoration;
import org.eclipse.jface.viewers.ILightweightLabelDecorator;
import org.eclipse.jface.viewers.LabelProviderChangedEvent;

public class PDTConsultDecoratorContributor extends BaseLabelProvider implements PDTDecorator, ILightweightLabelDecorator, ConsultListener, ActivePrologInterfaceListener, PrologInterfaceStartListener {

	public PDTConsultDecoratorContributor() {
		PDTConnectorPlugin.getDefault().getPrologInterfaceService().registerActivePrologInterfaceListener(this);
		PDTConnectorPlugin.getDefault().getPrologInterfaceService().registerConsultListener(this);
		PDTCommonPlugin.getDefault().registerPifStartListener(this);
		PDTCommonPlugin.getDefault().addDecorator(this);
	}
	
	@Override
	public void decorate(Object element, IDecoration decoration) {
		if(!(element instanceof IFile) && !(element instanceof IFolder)){
			return;
		}

		try {
			// get active pif from console
			PrologProcess currentPif = PDTCommonUtil.getActivePrologProcess();
			
			if (currentPif == null) {
				if (element instanceof IFile) {
					decoration.addOverlay(ImageRepository.getImageDescriptor(ImageRepository.PROLOG_FILE_UNCONSULTED), IDecoration.UNDERLAY);
				}
				return;
			}
			
			if (element instanceof IFile) {
				IFile file = (IFile) element;
				
//			final DecorationContext decorationContext = (DecorationContext) decoration.getDecorationContext();
//			decorationContext.putProperty(IDecoration.ENABLE_REPLACE, Boolean.TRUE);
				
				// check if file is in consulted files list (important for qlf files)
				String prologFileName = getPrologFileName(file);
				
				// XXX: don't mark qlf file if only the pl file is consulted 
				if(prologFileName.endsWith(".qlf")){
					prologFileName = prologFileName.substring(0, prologFileName.length()-3)+"pl";
				}
				// check if file is source_file
				if (isCurrent(prologFileName)) {
					decoration.addSuffix(" [consulted]");
					if (file.getFileExtension().equalsIgnoreCase("QLF")) {
						decoration.addOverlay(ImageRepository.getImageDescriptor(ImageRepository.QLF_FILE_CONSULTED), IDecoration.BOTTOM_LEFT);
					} else {
						decoration.addOverlay(ImageRepository.getImageDescriptor(ImageRepository.PROLOG_FILE_CONSULTED), IDecoration.UNDERLAY);
					}
				} else if (isOld(prologFileName)) {
					decoration.addSuffix(" [consulted]");
					if (file.getFileExtension().equalsIgnoreCase("QLF")) {
						decoration.addOverlay(ImageRepository.getImageDescriptor(ImageRepository.QLF_FILE_CONSULTED_OLD), IDecoration.BOTTOM_LEFT);
					} else {
						decoration.addOverlay(ImageRepository.getImageDescriptor(ImageRepository.PROLOG_FILE_CONSULTED_OLD), IDecoration.UNDERLAY);
					}
				} else {
					decoration.addOverlay(ImageRepository.getImageDescriptor(ImageRepository.PROLOG_FILE_UNCONSULTED), IDecoration.UNDERLAY);
				}
			} else {
				IFolder folder = (IFolder) element;
				String dirName = QueryUtils.prologFileName(folder.getRawLocation().toFile());
				
				if (isContainingFolder(dirName)) {
					decoration.addOverlay(ImageRepository.getImageDescriptor(ImageRepository.PROLOG_FOLDER_CONSULTED), IDecoration.TOP_LEFT);
				}
			}
		} catch (Exception e) {
			Debug.error("Error during decoration of " + (element == null ? null : element.toString()));
			Debug.report(e);
		}
		
	}
	
	private String getPrologFileName(IFile file) {
		String enclFile = file.getRawLocation().toPortableString();
		if (Util.isWindows()) {
			enclFile = enclFile.toLowerCase();
		}

		IPath filepath = new Path(enclFile);
		return QueryUtils.prologFileName(filepath.toFile());
	}

    @Override
    public void updateDecorator() {
    	fireLabelProviderChanged();
    }
    
    private void fireLabelProviderChanged() {
    	final LabelProviderChangedEvent e = new LabelProviderChangedEvent(this);
        UIUtils.getDisplay().asyncExec(new Runnable() {
            @Override
            public void run() {
                fireLabelProviderChanged(e);
            }
        });
    }

	private HashSet<String> filesInCurrentState;
	private HashSet<String> filesInOldState;
	private HashSet<String> directories;
	private long lastFill = 0;
	
	private static final int MILLIS_BETWEEN_FILE_STATE_CHECK = 1000;

	private boolean isCurrent(String fileName) {
		fillSetsIfNeeded();
		return filesInCurrentState.contains(fileName);
	}
	
	private boolean isOld(String fileName) {
		fillSetsIfNeeded();
		return filesInOldState.contains(fileName);
	}
	
	private boolean isContainingFolder(String folderName) {
		fillSetsIfNeeded();
		return directories.contains(folderName);
	}
	
	private void fillSetsIfNeeded() {
		long now = System.currentTimeMillis();
		if (filesInCurrentState == null || filesInOldState == null || now - MILLIS_BETWEEN_FILE_STATE_CHECK > lastFill) {
			filesInCurrentState = new HashSet<String>();
			filesInOldState = new HashSet<String>();
			directories = new HashSet<String>();
			PrologProcess pif = PDTCommonUtil.getActivePrologProcess();
			List<Map<String, Object>> results;
			try {
				results = pif.queryAll(bT(PDTCommonPredicates.PDT_SOURCE_FILE, "File", "State"));
				for (Map<String, Object> result: results) {
					String fileName = result.get("File").toString();
					String fileState = result.get("State").toString();
					if ("current".equals(fileState)) {
						filesInCurrentState.add(fileName);
					} else {
						filesInOldState.add(fileName);
					}
					String parentDir = fileName.substring(0, fileName.lastIndexOf('/'));
					while (directories.add(parentDir)) {
						int parentDirEndPos = parentDir.lastIndexOf('/');
						if (parentDirEndPos < 0) {
							break;
						}
						parentDir = parentDir.substring(0, parentDirEndPos);
					}
				}
			} catch (PrologProcessException e) {
				Debug.report(e);
			}
			lastFill = System.currentTimeMillis();
		}
	}

	@Override
	public void prologProcessStarted(PrologProcess pif) {
    	if (pif.equals(PDTCommonUtil.getActivePrologProcess())) {
    		fireLabelProviderChanged();
    	}
	}

	@Override
	public void activePrologProcessChanged(PrologProcess pif) {
    	fireLabelProviderChanged();
	}

	@Override
	public void beforeConsult(PrologProcess pif, List<IFile> files, IProgressMonitor monitor) throws PrologProcessException {
	}

	@Override
	public void afterConsult(PrologProcess pif, List<IFile> files, List<String> allConsultedFiles, IProgressMonitor monitor) throws PrologProcessException {
    	if (pif.equals(PDTCommonUtil.getActivePrologProcess())) {
    		fireLabelProviderChanged();
    	}
	}
	
	@Override
	public void dispose() {
		PDTConnectorPlugin.getDefault().getPrologInterfaceService().unRegisterActivePrologInterfaceListener(this);
		PDTConnectorPlugin.getDefault().getPrologInterfaceService().unRegisterConsultListener(this);
		PDTCommonPlugin.getDefault().unregisterPifStartListener(this);
		PDTCommonPlugin.getDefault().removeDecorator(this);
		super.dispose();
	}

}


