module draw.worldmap;

import std.stdio;
import std.conv;

import des.cl;
import des.cl.helpers;

public import draw.object.base;
import model.worldmap;
import draw.clsource;

class CLWorldMap : BaseDrawObject, WorldMap
{
protected:

    class CLMem
    {
        CLGLMemory mem;

        this( GLBuffer buf )
        {
            mem = registerCLRef( CLGLMemory.createFromGLBuffer( ctx,
                                 CLMemory.Flags.READ_WRITE, buf ) );
        }

        void acquireFromGL() { mem.acquireFromGL( cmdqueue ); }

        void releaseToGL() { mem.releaseToGL( cmdqueue ); }
    }

    GLBuffer data, pnts;
    CLMem cl_data, cl_pnts;

    alias Vector!(8,float) PntData;
    PntData[] pnts_data;

    mat4 mapmtr;
    mapsize_t mres;

    CLGLContext ctx;
    CLCommandQueue cmdqueue;

    CLKernel update;

public:

    this( ivec3 res, vec3 cell )
    {
        mapmtr = mat4.diag( cell, 1 ).setCol(3, vec4(vec2(-res.xy)*cell.xy,0,1) );
        mres = mapsize_t(res*2);
        prepareCL();

        super( null, SS_WorldMap_M );

        writeln( matrix );
    }

    void setPoints( in vec3 from, in vec3[] ppt )
    {
        foreach( pnt; ppt )
            pnts_data ~= PntData( from, 0.0f, pnt, 0.0f );
    }

    void process()
    {
        if( pnts_data.length == 0 ) return;

        pnts.setData( pnts_data );
        pnts_data.length = 0;

        auto transform = matrix.inv;

        glFlush();
        glFinish();

        cl_data.acquireFromGL();
        cl_pnts.acquireFromGL();

        update.setArgs( cl_data.mem, to!(uint[4])( mres.data ~ 0 ),
                        cl_pnts.mem, cast(uint)pnts.elementCount,
                        cast(float[16])transform.asArray[0..16]
                       );
        update.exec( cmdqueue, 1, [0], [1024], [16] );

        cl_pnts.releaseToGL();
        cl_data.releaseToGL();

        cmdqueue.flush();
    }

    mapsize_t size() const { return mres; }

    override void draw( Camera cam )
    {
        shader.setUniformMat( "prj", cam(this) );
        shader.setUniform!int( "size_x", cast(int)mres.w );
        shader.setUniform!int( "size_y", cast(int)mres.h );
        shader.setUniform!float( "psize", 0.03 );

        glEnable(GL_PROGRAM_POINT_SIZE);
        drawArrays( DrawMode.POINTS );
    }

    override @property mat4 matrix() const
    { return super.matrix * mapmtr; }

protected:

    void prepareCL()
    {
        auto platform = CLPlatform.getAll()[0];

        auto devices = registerCLRef( CLDevice.getAll( platform ) );

        ctx = registerCLRef( new CLGLContext( platform ) );
        ctx.initializeFromType( CLDevice.Type.GPU );

        cmdqueue = registerCLRef( new CLCommandQueue( ctx, devices[0] ) );
        auto program = registerCLRef( CLProgram.createWithSource( ctx, CLSource ) );

        try program.build( devices, [ CLBuildOption.fastRelaxedMath ] );
        catch( CLException e )
        {
            stderr.writeln( program.buildInfo()[0] );
            throw e;
        }

        update = registerCLRef( new CLKernel( program, "update" ) );
    }

    CLReference[] clrefs;

    auto registerCLRef(T)( T[] objs ) if( is( T : CLReference ) )
    {
        foreach( obj; objs )
            clrefs ~= cast(CLReference)obj;
        return objs;
    }

    auto registerCLRef(T)( T obj ) if( is( T : CLReference ) )
    {
        clrefs ~= cast(CLReference)obj;
        return obj;
    }

    void destroyCLRefs()
    {
        foreach( obj; clrefs )
            obj.release();
    }

    override void selfDestroy()
    {
        destroyCLRefs();
        super.selfDestroy();
    }

    override void prepareBuffers()
    {
        auto cnt = mres.w * mres.h * mres.d;

        data = createArrayBuffer();
        auto loc = shader.getAttribLocation( "data" );
        setAttribPointer( data, loc, 1, GLType.INT );
        data.setData( new int[](cnt) );

        pnts = registerChildEMM( new GLBuffer );
        pnts.setData( [vec3.init] );

        cl_data = new CLMem( data );
        cl_pnts = new CLMem( pnts );
    }
}

class CLWorldMap_M : BaseDrawObject, WorldMap
{
protected:
    GLBuffer data;

    mat4 mapmtr;
    mapsize_t mres;

public:

    this( ivec3 res, vec3 cell )
    {
        mapmtr = mat4.diag( cell, 1 ).setCol(3, vec4(-res.xy,0,1) );
        mres = mapsize_t(res*2);

        super( null, SS_WorldMap_M );

        writeln( matrix );
    }

    void setPoints( in vec3 from, in vec3[] ppt )
    {
    }

    mapsize_t size() const { return mres; }

    override void draw( Camera cam )
    {
        shader.setUniformMat( "prj", cam(this) );
        shader.setUniform!int( "size_x", cast(int)mres.w );
        shader.setUniform!int( "size_y", cast(int)mres.h );

        glPointSize(2);
        drawArrays( DrawMode.POINTS );
    }

    override @property mat4 matrix() const
    { return super.matrix * mapmtr; }

protected:

    override void prepareBuffers()
    {
        auto cnt = mres.w * mres.h * mres.d;

        data = createArrayBuffer();
        auto loc = shader.getAttribLocation( "data" );
        setAttribPointer( data, loc, 1, GLType.INT );
        auto buf = new int[](cnt);
        foreach( i, ref v; buf )
            v = cast(int)i;
        data.setData( buf );
    }
}