/*****************************************************************************
 * This file is part of the Prolog Development Tool (PDT)
 * 
 * Author: Lukas Degener (among others) 
 * E-mail: degenerl@cs.uni-bonn.de
 * WWW: http://roots.iai.uni-bonn.de/research/pdt 
 * Copyright (C): 2004-2006, CS Dept. III, University of Bonn
 * 
 * All rights reserved. This program is  made available under the terms 
 * of the Eclipse Public License v1.0 which accompanies this distribution, 
 * and is available at http://www.eclipse.org/legal/epl-v10.html
 * 
 * In addition, you may at your option use, modify and redistribute any
 * part of this program under the terms of the GNU Lesser General Public
 * License (LGPL), version 2.1 or, at your option, any later version of the
 * same license, as long as
 * 
 * 1) The program part in question does not depend, either directly or
 *   indirectly, on parts of the Eclipse framework and
 *   
 * 2) the program part in question does not include files that contain or
 *   are derived from third-party work and are therefor covered by special
 *   license agreements.
 *   
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 *   
 * ad 1: A program part is said to "depend, either directly or indirectly,
 *   on parts of the Eclipse framework", if it cannot be compiled or cannot
 *   be run without the help or presence of some part of the Eclipse
 *   framework. All java classes in packages containing the "pdt" package
 *   fragment in their name fall into this category.
 *   
 * ad 2: "Third-party code" means any code that was originaly written as
 *   part of a project other than the PDT. Files that contain or are based on
 *   such code contain a notice telling you so, and telling you the
 *   particular conditions under which they may be used, modified and/or
 *   distributed.
 ****************************************************************************/

package org.cs3.pdt.internal.editors;

import org.cs3.pdt.core.PDTCorePlugin;
import org.cs3.pdt.internal.ImageRepository;
import org.cs3.pl.metadata.IMetaInfoProvider;
import org.cs3.pl.metadata.Predicate;
import org.eclipse.jface.text.Assert;
import org.eclipse.jface.text.BadLocationException;
import org.eclipse.jface.text.IDocument;
import org.eclipse.jface.text.contentassist.ContextInformation;
import org.eclipse.jface.text.contentassist.ICompletionProposal;
import org.eclipse.jface.text.contentassist.IContextInformation;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.graphics.Point;


public class PrologCompletionProposal implements ICompletionProposal {
	
	/** The string to be displayed in the completion proposal popup */
	//private String fDisplayString;
	/** The replacement string */
	//private String fReplacementString;
	/** The replacement offset */
	private int fReplacementOffset;
	/** The replacement length */
	private int fReplacementLength;
	/** The cursor position after this proposal has been applied */
	private int fCursorPosition;
	/** The image to be displayed in the completion proposal popup */
	private Image image;
	private Predicate data;
	/** The additional info of this proposal */
	//private String fAdditionalProposalInfo;
    private static final Image publicImage = ImageRepository.getImage(ImageRepository.PE_PUBLIC);
    private static final Image hiddenImage = ImageRepository.getImage(ImageRepository.PE_HIDDEN);
    private String postfix;
    
    private IContextInformation context;
    private String help;
	private IMetaInfoProvider metaInfoProvider;

	/**
	 * Creates a new completion proposal based on the provided information.  The replacement string is
	 * considered being the display string too. All remaining fields are set to <code>null</code>.
	 * @param provider 
	 *
	 * @param replacementOffset the offset of the text to be replaced
	 * @param replacementLength the length of the text to be replaced
	 * @param cursorPosition the position of the cursor following the insert relative to replacementOffset
	 */
	public PrologCompletionProposal(IMetaInfoProvider provider, Predicate data, int replacementOffset, int replacementLength,String prefix) {
		Assert.isTrue(replacementOffset >= 0);
		Assert.isTrue(replacementLength >= 0);
		fReplacementOffset= replacementOffset;
		fReplacementLength= replacementLength;
		this.data=data;
		this.metaInfoProvider=provider;
		
		
			if(data.getName().regionMatches(true,0,prefix,0,prefix.length()) ) {
				
				postfix = "";
                int cursorPos = data.getName().length();
				if (data.getArity() > 0) {
					postfix = "()";
					cursorPos++;
				}
				else if (data.getArity() == -1) {
					postfix = ":";
					cursorPos++;
				}
				
				
				image = data.isPublic() ? publicImage : hiddenImage;
                fCursorPosition=cursorPos;
				
		
				
		}
	}

	
	/*
	 * @see ICompletionProposal#apply(IDocument)
	 */
	public void apply(IDocument document) {
		try {
			document.replace(fReplacementOffset, fReplacementLength, data.getName() + postfix);
		} catch (BadLocationException x) {
			// ignore
		}
	}
	
	/*
	 * @see ICompletionProposal#getSelection(IDocument)
	 */
	public Point getSelection(IDocument document) {
		return new Point(fReplacementOffset + fCursorPosition, 0);
	}

	/*
	 * @see ICompletionProposal#getContextInformation()
	 */
	public IContextInformation getContextInformation() {	    
        if (context==null && getHelp().length() > 0) {
			int predLen = data.getName().length();
			int firstLB = getHelp().indexOf('\n');
			if(firstLB > predLen) {
				String params = getHelp().substring(predLen,firstLB);
				context = new ContextInformation(null, "", params );
			}
		}
		return context;
	}

	/*
	 * @see ICompletionProposal#getImage()
	 */
	public Image getImage() {
		return image;
	}

	/*
	 * @see ICompletionProposal#getDisplayString()
	 */
	public String getDisplayString() {
		return data.getSignature();
	}

	/*
	 * @see ICompletionProposal#getAdditionalProposalInfo()
	 */
	public String getAdditionalProposalInfo() {
		return getHelp();
	}


    /**
     * @return
     */
    private String getHelp() {
        if(this.help==null){
            this.help=metaInfoProvider.getHelp(data);
            if(this.help==null){
                this.help="";
            }
        }
        return help;
    }

}
