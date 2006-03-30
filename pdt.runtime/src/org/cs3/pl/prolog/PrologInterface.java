package org.cs3.pl.prolog;

import java.io.IOException;
import java.util.List;

public interface PrologInterface {
    /**
     * consult event subject constant
     * events of this subject will be fired whenver something was
     * consulted into the prolog system.
     * <br>NOT IMPLEMENTED YET
     */
    public final static String SUBJECT_CONSULTED = "consulted";

    
    /**
     * Returns a prolog session.<br>
     * Use sessions to interact with the prolog system.
     * Sessions can only be obtained while the PrologInterface is in
     * UP state. During startup, this call will block until the pif is up.
     * in state SHUTODWN or DOWN, this will raise an IllegalStateException.
     * 
     * @return a new Session Object
     */
    public abstract PrologSession getSession();

    /**
     * Stop the prolog system (if it is up).
     * This will terminate all running sessions and shut down the prolog process.
     * @throws IOException
     */
    public abstract void stop() throws IOException;

    /**
     * Starts the prolog system (if it is down).
     * @throws IOException
     */
    public abstract void start() throws IOException;

    /**
     * checks wether the prologInterface is up and running.
     * @return true if the prolog system is ready for battle.
     */
    public boolean isUp();

    /**
     * checks wether the prologInterface is down.
     * <br>this is not the same as <code>!isUp()</code>. During startup and shutdown
     * both methods return false.
     * @return
     */
    public boolean isDown();

    
    public void addLifeCycleHook(LifeCycleHook hook, String id,
            String[] dependencies);

    /**
     * set a configuration option of this prolog interface.
     * 
     * @see PrologInterfaceFactory.getOptions()
     */
    public void setOption(String opt, String value);

    /**
     * get the current value of a configuration option.
     * 
     * @see PrologInterfaceFactory.getOptions()
     */
    public String getOption(String opt);

    /**
     * register a listener for events generated by the prolog system.
     * <br><b>not implemented yet</b>
     * @param subject
     *                    the subject for which to listen. For a list of predefined
     *                    subjects see the <code>SUBJECT_*</code> constants defined as
     *                    part of this interface. Implementations will use these
     *                    constants whereever apropiate. The exact set of subjects for
     *                    which events are generated depends on the concrete
     *                    implementation.
     * @param l
     *                    the listener to register.
     * @deprecated 
     */
    public void addPrologInterfaceListener(String subject,
            PrologInterfaceListener l);

    /**
     * unregister a listener from a specified subject.
     * 
     * @param subject
     * @param l
     * @deprecated 
     */
    public void removePrologInterfaceListener(String subject,
            PrologInterfaceListener l);

    /**
     * create a consult service for an optional prefix.
     * <p>
     * consult servcices are typicaly shared instances.
     * 
     * @param prefix an optional prefix for the ConsultService that
     * will transparently prepended to all consulted filenames.
     * @return an instance of IConsultService or null if not implemented.
     */
    public abstract ConsultService getConsultService(String prefix);

    /**
     * get the life list of bootstrap libraries.
     * <br>"life" means, that any modification will affect the next startup of the pif.
     * The list contains path strings (the "prolog kind" of paths) to prolog files
     * that will be consulted during startup of the pif.
     * @return the life list of bootstrap libraries
     */
    public List getBootstrapLibraries();
    
    /**
     * @see getBootStrapLibraries()
     * @param l
     */
    public void setBootstrapLibraries(List l);
    /**
     * 
     * @return the factory instance that created this pif, or if this pif was not
     * created by a factory (unlikely :-) ). 
     */
    public PrologInterfaceFactory getFactory();

    /**
     * unregister a lifeCycleHook
     * @param reconfigureHookId
     */
    public abstract void removeLifeCycleHook(String hookId);
}