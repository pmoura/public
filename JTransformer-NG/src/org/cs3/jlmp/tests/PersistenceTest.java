/*
 */
package org.cs3.jlmp.tests;

import java.io.File;
import java.io.FileInputStream;

import org.cs3.jlmp.JLMPPlugin;
import org.cs3.pl.common.ResourceFileLocator;
import org.cs3.pl.common.Util;
import org.cs3.pl.prolog.PrologInterface;
import org.cs3.pl.prolog.PrologSession;

/**
 */
public class PersistenceTest extends FactGenerationTest {
    /**
     * @param name
     */
    public PersistenceTest(String name) {
        super(name);
    }
    /* (non-Javadoc)
     * @see org.cs3.jlmp.tests.FactGenerationTest#setUpOnce()
     */
    public void setUpOnce() throws Exception {
        setAutoBuilding(false);
        super.setUpOnce();
    }
    //XXX:which issue was exposed by this test?
    public void testIt() throws Throwable{
        clean();
         PrologInterface pif = getTestJLMPProject().getPrologInterface();
         PrologSession s = pif.getSession();
         File file = File.createTempFile("persistencetest","pl");
         s.queryOnce("assert(toplevelT(la,le,lu,lo))");
         //this caused problems in the past:
         //there was a forgotten deleteSourceFacts in the builder        
         build();
         s.queryOnce("writeTreeFacts('"+Util.prologFileName(file)+"')");
         FileInputStream fis = new FileInputStream(file);
         String data = Util.toString(fis);
         fis.close();
         
         String line = "toplevelT(la, le, lu, lo)";
        assertTrue(data.indexOf(line)>-1);
    }
    
    public void test_JT_145() throws Throwable{
        clean();
        ResourceFileLocator l = JLMPPlugin.getDefault().getResourceLocator("");
		File r = l.resolve("testdata-facts.zip");
		Util.unzip(r);
		setTestDataLocator(JLMPPlugin.getDefault().getResourceLocator(
				"testdata-facts"));
		//actualy, any java code will do
		install("rumpel");

		build();
		PrologInterface pif = getTestJLMPProject().getPrologInterface();
        pif.stop();
		/*
		 * the shut down, as well as the build should trigger a pef dump
		 * via write_tree_facts/1
		 * In presence of JT_145, the dump will create a corrupt file.
		 *  (a detail test could easily be written, but i'm a bit lazy right now)
		 *  
		 *  The important thing is that upon reload, there will be no globalID facts
		 *  for general things (like java.lang.Object), which causes subsequent 
		 *  builds to fail eventualy. 
		 *  We only check the existence of a globalId fact for java.lang.Object
		 */ 
		pif.start();
		PrologSession s = pif.getSession();
		try{
		    assertNotNull(s.queryOnce("globalIds('java.lang.Object',_)"));
		}finally{
		    s.dispose();
		}
    }
}
