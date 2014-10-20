module draw.worldmap;

import std.stdio;
import std.conv;

import des.cl;
import des.cl.helpers;

import des.il.region;

public import draw.object.base;
import model.worldmap;
import draw.clsource;

class CLWorldMap : BaseDrawObject, WorldMap
{
protected:

    interface CLBuffer
    {
        @property CLGLMemory mem();
        @property CLCommandQueue cmd();
        final void acquireFromGL() { mem.acquireFromGL( cmd ); }
        final void releaseToGL() { mem.releaseToGL( cmd ); }
    }

    class MainDataBuffer : GLArrayBuffer, CLBuffer
    {
        CLGLMemory clmem;
        @property CLGLMemory mem() { return clmem; }
        @property CLCommandQueue cmd() { return cmdqueue; }

        this(T)( string name, uint cnt, GLType type, T[] data )
        {
            super();
            auto loc = shader.getAttribLocation( name );
            setAttribPointer( this, loc, cnt, type );
            setData( data );

            clmem = registerCLRef( CLGLMemory.createFromGLBuffer( ctx,
                                 CLMemory.Flags.READ_WRITE, this ) );
        }
    }

    class SBuffer : GLBuffer, CLBuffer
    {
        CLGLMemory clmem;
        @property CLGLMemory mem() { return clmem; }
        @property CLCommandQueue cmd() { return cmdqueue; }

        this()
        {
            super( Target.ARRAY_BUFFER );
            setData( [0] );
            clmem = registerCLRef( CLGLMemory.createFromGLBuffer( ctx,
                                 CLMemory.Flags.READ_WRITE, this ) );
        }
    }

    MainDataBuffer data;

    SBuffer pnts, near;

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

    vec4[] getFillPoints( in vec3 pos, float dst )
    {
        auto m = matrix.inv;

        auto vol = getRegion( m, pos, dst );
        auto count = vol.size.x * vol.size.y * vol.size.z;

        if( count == 0 ) return [];

        uint[8] volume = [
            cast(uint)vol.pos.x,
            cast(uint)vol.pos.y,
            cast(uint)vol.pos.z,
            0,
            cast(uint)vol.size.x,
            cast(uint)vol.size.y,
            cast(uint)vol.size.z,
            0
        ];

        near.setData( new vec4[](count) );

        stopGL();
        acquireFromGL( data, near );

        nearfind.setArgs( data.mem, to!(uint[4])( mres.data ~ 0 ),
                        cast(uint)count, volume, near.mem );

        nearfind.exec( cmdqueue, 1, [0], [32], [8] );

        releaseToGL( data, near );
        cmdqueue.flush();

        auto nearbuf = near.getData!vec4;

        vec4[] ret;
        foreach( n; nearbuf )
            ret ~= vec4( (matrix * vec4(n.xyz,1)).xyz, n.w );

        return ret;
    }

    vec3 nearestVolume( vec3 pos )
    {
        auto mpos = ( matrix.inv * vec4( pos, 1 ) ).xyz;
        if( mpos.x >= 0 && mpos.x < mres.x &&
            mpos.y >= 0 && mpos.y < mres.y &&
            mpos.z >= 0 && mpos.z < mres.z ) return vec3(0);

        vec3 r = pos;
        if( mpos.x < 0 ) r.x = -mpos.x;
        if( mpos.y < 0 ) r.y = -mpos.y;
        if( mpos.z < 0 ) r.z = -mpos.z;
        if( mpos.x >= mres.x ) r.x = mres.x - mpos.x;
        if( mpos.y >= mres.y ) r.y = mres.y - mpos.y;
        if( mpos.z >= mres.z ) r.z = mres.z - mpos.z;
        return (matrix * vec4(r,1)).xyz;
    }

    protected auto getRegion( in mat4 m, in vec3 pos, float dst )
    {
        auto pmin = ivec3( (m * vec4( pos - vec3(dst), 1 ) ).xyz );
        auto size = ivec3( (m * vec4( vec3(dst) * 2, 0 ) ).xyz );

        auto dvol = iRegion3( ivec3(0), mres );
        auto cvol = iRegion3( pmin, size );

        return dvol.overlap( cvol );
    }

    void process()
    {
        if( !loadTmp() ) return;

        auto transform = matrix.inv;

        stopGL();

        acquireFromGL( data, pnts );

        update.setArgs( data.mem, uint4MapRes,
                        pnts.mem, cast(uint)pnts.elementCount,
                        cast(float[16])transform.asArray[0..16]
                       );
        update.exec( cmdqueue, 1, [0], [1024], [32] );

        releaseToGL( data, pnts );

        cmdqueue.flush();
    }

    @property uint[4] uint4MapRes() { return to!(uint[4])( mres.data ~ 0 ); }

    protected bool loadTmp()
    {
        if( pnts_tmp_data.length == 0 ) return false;
        pnts.setData( pnts_tmp_data );
        pnts_tmp_data.length = 0;
        return true;
    }

    protected void stopGL()
    {
        glFlush();
        glFinish();
    }

    protected void acquireFromGL( CLBuffer[] list... )
    { foreach( obj; list ) obj.acquireFromGL(); }

    protected void releaseToGL( CLBuffer[] list... )
    { foreach( obj; list ) obj.releaseToGL(); }

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
        nearfind = registerCLRef( new CLKernel( program, "nearfind" ) );
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
        near = registerChildEMM( new SBuffer() );
    }
}
