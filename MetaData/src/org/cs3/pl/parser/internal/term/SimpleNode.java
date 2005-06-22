/* Generated By:JJTree: Do not edit this line. SimpleNode.java */

package org.cs3.pl.parser.internal.term;

import java.util.Stack;

public abstract class SimpleNode implements Node, Cloneable {
	Token firstToken;

	Token lastToken;

	protected Node parent;

	protected Node[] children;

	protected int id;

	protected PrologTermParser parser;

	

	public boolean copy;

	public SimpleNode original;

	private String comment;
	
	
	
	public int getPrecedence() {
		SimpleNode s = getPrincipal();
		if (s == null||s==this) {
			return OPS.PREC_MIN;
		}
		return s.getPrecedence();
	}

	public SimpleNode getPrincipal() {
		return this;
	}

	public int getArity(){
		return 0;
	}
	public String getLabel(){
		if(getPrincipal()!=this){
			return getPrincipal().getLabel();
		}
		return getImage();
	}
	
	
	public String getFunctor(){
		return ""+getPrincipal().getLabel()+"/"+getArity();
	}
	public SimpleNode(int i) {
		id = i;
	}

	public SimpleNode(PrologTermParser p, int i) {
		this(i);
		parser = p;
	}

	public void jjtOpen() {
	}

	public void jjtClose() {
	}

	public void jjtSetParent(Node n) {
		parent = n;
	}

	/**
	 * @deprecated 
	 */
	public Node jjtGetParent() {
		return parent;
	}

	public void jjtAddChild(Node n, int i) {
		if (children == null) {
			children = new Node[i + 1];
		} else if (i >= children.length) {
			Node c[] = new Node[i + 1];
			System.arraycopy(children, 0, c, 0, children.length);
			children = c;
		}
		children[i] = n;
	}

	public Node jjtGetChild(int i) {
		return children[i];
	}

	public int jjtGetNumChildren() {
		return (children == null) ? 0 : children.length;
	}

	/** Accept the visitor. * */
	public Object jjtAccept(PrologTermParserVisitor visitor, Object data) {
		return visitor.visit(this, data);
	}

	/** Accept the visitor. * */
	public Object childrenAccept(PrologTermParserVisitor visitor, Object data) {
		if (children != null) {
			for (int i = 0; i < children.length; ++i) {
				if(children[i]==null){
					System.err.println("Debug");
					if(data!=null&&data instanceof SimpleNode){
						((SimpleNode)data).dump("");
					}
				}
				children[i].jjtAccept(visitor, data);
			}
		}
		return data;
	}

	/*
	 * You can override these two methods in subclasses of SimpleNode to
	 * customize the way the node appears when the tree is dumped. If your
	 * output uses more than one line you should override toString(String),
	 * otherwise overriding toString() is probably all you need to do.
	 */

	public String toString() {
		return PrologTermParserTreeConstants.jjtNodeName[id];
	}

	public String toString(String prefix) {
		return prefix + toString();
	}

	/*
	 * Override this method if you want to customize how the node dumps out its
	 * children.
	 */

	public void dump(String prefix) {
		String image = getImage();
		String string = toString(prefix);
		SimpleNode org = getOriginal();
		String orgstring = org.toString();
		System.out.println(string+" -->"+image+" "+(copy?"COPY ":"")
				+(original!=null?"FROM "+orgstring+org.hashCode():""));
		if (children != null) {
			for (int i = 0; i < children.length; ++i) {
				SimpleNode n = (SimpleNode) children[i];
				if (n != null) {
					n.dump(prefix + " ");
				}
			}
		}
	}

	public Token getFirstToken() {
		return firstToken;
	}

	public Token getBeginToken() {
		return getFirstToken();
	}

	public void setFirstToken(Token firstToken) {
		this.firstToken = firstToken;
	}

	public Token getLastToken() {
		return lastToken;
	}

	public Token getEndToken() {
		return lastToken.next;
	}

	public void setLastToken(Token lastToken) {
		this.lastToken = lastToken;
	}
	
	public String getImage(){
		StringBuffer sb = new StringBuffer();
		if(copy){
			 synthesizeImage(sb);
			 return sb.toString();
		}
		
		for(Token t = getBeginToken();t!=null&&t!=getEndToken();t=t.next){
			sb.append(t.image);
		}
		return sb.toString();
	}
	public final Object clone(){
		return clone(true,false);
	}
	public final  Object clone(boolean linked, boolean deep) {
		SimpleNode copy = createShallowCopy();
		if(linked){
			copy.original=this;			
		}
		if(deep){
			copy.cloneChildrenFrom(this,linked,deep);
		}else if (children!=null){
			copy.children= (Node[]) children.clone();
		}
		return copy;
	}
	public final void cloneChildrenFrom(SimpleNode src, boolean linked, boolean deep) {
		if(src.children==null){
			this.children=null;
			return;
		}
		children = new Node[src.children.length];
		for (int i = 0; i < children.length; i++) {
			SimpleNode c = (SimpleNode) ((SimpleNode) src.children[i]).clone(linked,deep);			
			c.parent=this;						
			children[i]=c;
		}		
	}
	protected abstract SimpleNode createShallowCopy();
	protected abstract void synthesizeImage(StringBuffer sb) ;
	public SimpleNode toCanonicalTerm(boolean linked, boolean deep){
		SimpleNode r = (SimpleNode) clone(linked,false);
		if(deep){
			
			for (int i = 0; children!=null&&i<children.length; i++) {
				SimpleNode c = (SimpleNode) children[i];
				r.children[i]=c.toCanonicalTerm(linked,deep);
			}
			
		}
		return r;
	}
	
	public SimpleNode getOriginal(){
		if(!copy||original==null){
			return this;
		}
		SimpleNode r = original;
		while(r.original!=null){
			r=r.original;
		}
		return r.copy?null:r;
	}
	
	public String getComment(){
		
		if(comment==null){
			if(copy){
				return null;	
			}
			Token st = getFirstToken();
			Stack stack=new Stack();
			StringBuffer sb = new StringBuffer();
			while(st.specialToken!=null){
				st=st.specialToken;
				stack.push(st);
			}
			while(!stack.isEmpty()){
				st=(Token) stack.pop();
				String image=st.image;
				int begin=0;
				
				switch(st.kind){				
				case PrologTermParser.SINGLE_LINE_COMMENT:
					while(image.charAt(begin)=='%'){
						begin ++;
					}
					if(sb.length()>0){
						sb.append("\n");
					}
					sb.append(image.substring(begin));
					break;
				case PrologTermParser.MULTI_LINE_COMMENT:
					
					image=image.replaceAll("\\n\\s*\\*","\n");
					image=image.replaceAll("/\\*+","");
					image=image.replaceAll("\\*+/","");
					sb.append(image);
					break;
				}				
				sb.append(st.image);
				
			}
			
		}
		return comment;
	}
}
