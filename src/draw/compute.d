module draw.compute;

public import des.cl;
public import des.cl.gl;
public import des.gl.base;

import des.util.arch;

class CLGLEnv : DesObject
{
    CLGLContext ctx;
    CLCommandQueue cmd;
    CLProgram prog;

    this( string src )
    {
        ctx = newEMM!CLGLContext( 0, CLDevice.Type.GPU );
        cmd = newEMM!CLCommandQueue( ctx, 0 );
        prog = registerChildEMM( CLProgram.createWithSource( ctx, src ) );

        prog.build();

        foreach( k; prog.kernel )
        {
            logger.info( k.name );
            k.setQueue( cmd );
        }
    }

    void releaseAllToGL() { ctx.releaseAllToGL( cmd ); }
}

class CalcBuffer : GLBuffer, CLMemoryHandler
{
    mixin CLMemoryHandlerHelper;

    this( CLGLEnv env )
    {
        super( GLBuffer.Target.ARRAY_BUFFER );
        setData( [0] );
        clmem = registerChildEMM( CLGLMemory.createFromGLBuffer( env.ctx, this ) );
    }

    void setAsKernelArgCallback( CLCommandQueue cmd )
    { (cast(CLGLMemory)clmem).acquireFromGL( cmd ); }
}
