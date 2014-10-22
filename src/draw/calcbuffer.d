module draw.calcbuffer;

public import des.gl.base;
public import des.cl.glsimple;

class CalcBuffer : GLBuffer, CLMemoryHandler
{
    mixin( getCLMemProperty );
    this()
    {
        super( GLBuffer.Target.ARRAY_BUFFER );
        setData( [0] );
        CLGL.initMemory(this);
    }
}
