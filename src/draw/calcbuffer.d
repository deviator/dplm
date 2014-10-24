module draw.calcbuffer;

public import des.gl.base;
public import des.cl.glsimple;

import des.math.linear;

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

class CalcTexture : GLTexture, CLMemoryHandler
{
    mixin( getCLMemProperty );

    this()
    {
        super( Target.T2D );
        image( ivec2(1,1), InternalFormat.RED, Format.RED, Type.FLOAT );
        CLGL.initMemory(this);
        image( ivec2(1,1), InternalFormat.DEPTH_COMPONENT24, Format.DEPTH, Type.FLOAT );
    }
}

class CalcRenderBuffer : GLRenderBuffer, CLMemoryHandler
{
    mixin( getCLMemProperty );

    this()
    {
        super();
        storage( ivec2(1,1), Format.DEPTH_COMPONENT32F );
        CLGL.initMemory(this);
    }
}
