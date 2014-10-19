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

    class MainDataBuffer : GLArrayBuffer
    {
        CLGLMemory mem;

        this(T)( string name, uint cnt, GLType type, T[] data )
        {
            super();
            auto loc = shader.getAttribLocation( name );
            setAttribPointer( this, loc, cnt, type );
            setData( data );

            mem = registerCLRef( CLGLMemory.createFromGLBuffer( ctx,
                                 CLMemory.Flags.READ_WRITE, this ) );
        }

        void acquireFromGL() { mem.acquireFromGL( cmdqueue ); }
        void releaseToGL() { mem.releaseToGL( cmdqueue ); }
    }

    class SBuffer : GLBuffer
    {
        CLGLMemory mem;

        this()
        {
            super( Target.ARRAY_BUFFER );
            setData( [0] );
            mem = registerCLRef( CLGLMemory.createFromGLBuffer( ctx,
                                 CLMemory.Flags.READ_WRITE, this ) );
        }

        void acquireFromGL() { mem.acquireFromGL( cmdqueue ); }
        void releaseToGL() { mem.releaseToGL( cmdqueue ); }
    }

    MainDataBuffer data;

    SBuffer pnts;

    alias Vector!(8,float) PntData;
    alias Vector!(8,uint) VolumeData;
    PntData[] pnts_tmp_data;

    mat4 mapmtr;
    mapsize_t mres;

    CLGLContext ctx;
    CLCommandQueue cmdqueue;

    CLKernel update;
    CLKernel nearfind;

public:

    this( ivec3 res, vec3 cell )
    {
        mapmtr = mat4.diag( cell, 1 ).setCol(3, vec4(vec2(-res.xy)*cell.xy,0,1) );
        mres = mapsize_t(res.xy*2,res.z);
        prepareCL();

        super( null, SS_WorldMap_M );
    }

    void setPoints( in vec3 from, in vec4[] ppt )
    {
        foreach( pnt; ppt )
            pnts_tmp_data ~= PntData( from, 0.0f, pnt );
    }

    vec3[] getNear( in vec3 pos[], float dst )
    {
        return [];
        //auto volumes = getVolumes( pos, dst );
        //auto count = getCount( volumes );


        //auto tr = matrix.inv;

        //size_t maxcount;

        //foreach( p; pos )
        //{
        //    auto pmin = tr * vec4( pos - vec3(dst), 1 )).xyz;
        //    auto pmax = tr * vec4( pos + vec3(dst), 1 )).xyz;
        //}
    }

    void process()
    {
        if( pnts_tmp_data.length == 0 ) return;

        pnts.setData( pnts_tmp_data );
        pnts_tmp_data.length = 0;

        auto transform = matrix.inv;

        glFlush();
        glFinish();

        data.acquireFromGL();
        pnts.acquireFromGL();

        update.setArgs( data.mem, to!(uint[4])( mres.data ~ 0 ),
                        pnts.mem, cast(uint)pnts.elementCount,
                        cast(float[16])transform.asArray[0..16]
                       );
        update.exec( cmdqueue, 1, [0], [1024], [32] );

        pnts.releaseToGL();
        data.releaseToGL();

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

        data = registerChildEMM( new MainDataBuffer( "data", 1, GLType.FLOAT,
                                                      new float[](cnt) ) );

        pnts = registerChildEMM( new SBuffer() );
    }
}
