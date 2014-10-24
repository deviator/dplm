module draw.render;

import des.gl.post.render;
import draw.calcbuffer;

class CalcRender : GLRenderToRB
{
protected:
    override GLRenderBuffer createDepth()
    { return new CalcRenderBuffer; }

public:
    this() { super(); }
}
