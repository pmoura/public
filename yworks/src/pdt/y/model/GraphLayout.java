package pdt.y.model;

import y.layout.CompositeLayoutStage;
import y.layout.LayoutOrientation;
import y.layout.LayoutStage;
import y.layout.Layouter;
import y.layout.OrientationLayouter;
import y.layout.hierarchic.IncrementalHierarchicLayouter;
import y.layout.router.OrthogonalEdgeRouter;

public class GraphLayout {

	private CompositeLayoutStage stage;
	private Layouter coreLayouter;
	private LayoutStage edgeLayouter; 

	
	public GraphLayout() {
		stage  = new CompositeLayoutStage();
		edgeLayouter = createEdgeLayout();
		coreLayouter = createCoreLayout();
		
		stage.setCoreLayouter(coreLayouter);
		stage.appendStage(edgeLayouter);
	}


	protected LayoutStage createEdgeLayout() {
		OrthogonalEdgeRouter router = new OrthogonalEdgeRouter();
		return router;
	}


	protected Layouter createCoreLayout() {
		IncrementalHierarchicLayouter layout = new IncrementalHierarchicLayouter();
		
		//set some options
		layout.getNodeLayoutDescriptor().setMinimumLayerHeight(10);
		layout.getNodeLayoutDescriptor().setMinimumDistance(10);

		//use left-to-right layout orientation
		OrientationLayouter ol = new OrientationLayouter();
		ol.setOrientation(LayoutOrientation.BOTTOM_TO_TOP);
		layout.setOrientationLayouter(ol);
		layout.setBackloopRoutingEnabled(true);
		layout.setFromScratchLayeringStrategy(IncrementalHierarchicLayouter.LAYERING_STRATEGY_HIERARCHICAL_TIGHT_TREE);
		//layout.setFromScratchLayeringStrategy(IncrementalHierarchicLayouter.LAYERING_STRATEGY_HIERARCHICAL_TOPMOST);
		layout.setGroupAlignmentPolicy(IncrementalHierarchicLayouter.POLICY_ALIGN_GROUPS_CENTER);
		//layout.setSubgraphLayouter(arg0);	// here is something for stages
		layout.setGroupCompactionEnabled(true);
		layout.setRecursiveGroupLayeringEnabled(true);
		layout.setAutomaticEdgeGroupingEnabled(true);
		
		
		return layout;
	}
	
	public Layouter getLayouter(){
		return this.stage;
	}
	
	public Layouter getEdgeLayouter(){
		return this.edgeLayouter;
	}
	
	
}
