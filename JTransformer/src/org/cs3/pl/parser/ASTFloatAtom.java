/* Generated By:JJTree: Do not edit this line. ASTFloatAtom.java */

package org.cs3.pl.parser;

public class ASTFloatAtom extends ASTAtom {
  public ASTFloatAtom(int id) {
    super(id);
  }

  public ASTFloatAtom(PrologParser p, int id) {
    super(p, id);
  }


  /** Accept the visitor. **/
  public Object jjtAccept(PrologParserVisitor visitor, Object data) {
    return visitor.visit(this, data);
  }
}
